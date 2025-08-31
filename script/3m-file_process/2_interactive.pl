#!/usr/bin/perl
# ABSTRACT: return the current project's .chitubox files in ascending order of Z dimension
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v1.0.10';

##~ DIGEST : a747d620364062f65212b0cf4c31c36b

BEGIN {
	push( @INC, './lib/' );
}

package Obj;
use Data::Dumper;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript
  Moo::GenericRole::InteractiveCLI

  /;

sub setup {
	my ( $self ) = @_;
	my $sql = '
	SELECT 
		woe.element_softlink_id AS file_id,
		woe.id as woe_id,
		woe.sequence_id as sequence_id,
		round(( fd.x_dimension * fd.y_dimension ),2) as area
	FROM 
		work_order_element woe
		INNER JOIN work_order wo ON wo.id = woe.work_order_id
		INNER JOIN file_dimensions fd ON woe.file_id = fd.file_id
	WHERE 
		woe.on_plate IS NULL
		AND wo.name = ?
	';
	$self->{z_desc_sth} = $self->dbh->prepare( $sql . ' ORDER BY fd.z_dimension DESC ' );
	$self->{z_asc_sth}  = $self->dbh->prepare( $sql . ' ORDER BY fd.z_dimension ASC ' );

	$self->{area_desc_sth} = $self->dbh->prepare( $sql . ' ORDER BY area DESC ' );
	$self->{area_asc_sth}  = $self->dbh->prepare( $sql . ' ORDER BY area ASC ' );

}

sub process {
	my ( $self ) = @_;
	$self->_setup();
	$self->script_setup();
	$self->setup();

	$self->simple_term_readline_menu(
		{
			prompt  => 'Fill plate by [z] value (default) or by [a]rea, or [d]one?',
			choices => {
				z         => 'by_height',
				'default' => 'by_height',
				d         => 'done',
			}
		}
	);
}

sub first_open {
	my ( $self ) = @_;
	unless ( $self->{first_open} ) {

		$self->set_select_all_off;
		$self->clear_for_project();
		sleep( 1 );
		$self->{first_open} = 1;
	}

}

sub done {
	my ( $self ) = @_;

	my $machine_string = $self->prompt_to_value(
		{
			prompt => 'Which machine is this plate on?'
		}
	);
	my $work_order_row = $self->get( 'work_order', {name => $self->{work_order_string}} );
	$self->insert(
		'plate',
		{
			machine       => $machine_string,
			work_order_id => $work_order_row->{id}
		}
	);
	my $plate_id  = $self->last_id();
	my $plate_row = $self->get( 'plate', {id => $plate_id} );

	my @woe_ids      = map { $_->{woe_id} } @{$self->{plate_contents}};
	my @sequence_ids = map { $_->{sequence_id} } @{$self->{plate_contents}};
	my $plate_dir    = $self->config()->{folders}->{plates};

	my $abv_string  = $self->abbreviate_ranges( @sequence_ids );
	my $name_string = "$machine_string - [WO_s-$self->{work_order_string}][PL_id-$plate_row->{id}] - $abv_string";
	my $output_path = "$plate_dir/$name_string.chitubox";
	$self->export_file_all( $output_path );

	eval {
		$self->dbh->begin_work();
		my $plate_file_id = $self->get_file_id( $output_path );

		$self->update(
			'work_order_element',
			{
				on_plate => 1,
				plate_id => $plate_id
			},
			{
				id => \@woe_ids
			}
		);
		my $sliced_path    = $self->slice_and_save_plate_to( $plate_dir, $name_string, lc( $machine_string ) );
		my $sliced_file_id = $self->get_file_id( $output_path );

		$self->update(
			'plate',
			{
				layout_file_id => $plate_file_id,
				sliced_file_id => $sliced_file_id
			},
			{
				id => \@woe_ids
			}
		);

		$self->dbh->commit();

	} or do {
		my $err = $@ || "Unknown error";
		eval { $self->dbh->rollback }; # ROLLBACK on failure
		die "Final transaction failed: [$err]";
	};
	$self->play_end_sound();
	print "It is done. Move on.$/";
	exit;
}

sub by_height {
	my ( $self ) = @_;
	my @file_stack;
	$self->simple_term_readline_menu(
		{
			prompt  => 'Load by [a]scending (Default), [d]escending, or go [b]ack?',
			choices => {
				a         => 'by_height_ascending',
				'default' => 'by_height_ascending',
				b         => sub { print "Going back$/"; return 0; }
			}
		}
	);
}

sub by_height_ascending {
	my ( $self ) = @_;
	$self->_shared_prompt( 'z_asc_sth' );
}

sub _shared_prompt {
	my ( $self, $sth_string, $p ) = @_;
	my $default_load = 2;
	my $gsth         = $self->{$sth_string};
	$gsth->execute( $self->{work_order_string} );

	$self->value_prompt_to_sub(
		{
			prompt   => "Enter how many should load [default $default_load], go [b]ack, [r]emove the last item from the working stack or [d]one",
			specific => {
				d => sub { $self->done(); },
				b => sub { print "Going back$/"; return 0; },
				r => sub {
					my ( $v ) = @_;

					my $res = pop( @{$self->{plate_contents}} );

					print "removed sequenced file [$res->{sequence_id}] from working stack$/";
					print "Working stack is now: ";
					for my $row ( @{$self->{plate_contents}} ) {
						my $path = $self->get_file_path_from_id( $row->{file_id} );
						print "$row->{sequence_id} - [$path]$/";
					}
					return 1;
				},
			},
			'sub' => sub {
				$self->first_open();
				my ( $value ) = @_;
				$value ||= $default_load;

				my @load_stack;
				while ( $value ) {
					$value--;

					my $row = $self->{next_row} || $gsth->fetchrow_hashref();
					if ( $row ) {
						push( @{$self->{plate_contents}}, $row );
						my ( $file, $suffix ) = $self->get_file_path_from_id( $row->{file_id} );
						push( @load_stack, $file );
						$self->{next_row} = $gsth->fetchrow_hashref();
					} else {
						undef( $self->{next_row} );
					}

				}
				print "Next file is: [" . $self->get_file_path_from_id( $self->{next_row}->{file_id} ) . "]$/" if $self->{next_row};
				$self->open_multiple_files( \@load_stack );

				return 1;
			}
		}
	);

}

sub abbreviate_ranges {
	my $self = shift;
	my @vals = sort { $a <=> $b } @_;
	my @out;

	while ( @vals ) {
		my $start = shift @vals;
		my $end   = $start;
		while ( @vals && $vals[0] == $end + 1 ) {
			$end = shift @vals;
		}

		push @out, ( $start == $end ? $start : "$start-$end" );
	}

	return join( ",", @out );
}

1;

package main;
main( @ARGV );

sub main {
	my ( $work_order_string, $desc ) = @_;
	die "No work order string provided" unless $work_order_string;

	my $self = Obj->new();
	$self->{work_order_string} = $work_order_string;

	$self->process();

}

1;
