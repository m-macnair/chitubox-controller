#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.10';

##~ DIGEST : dd01e3777ff2dc0cb97cc86e3153c5ff

use strict;
use warnings;

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript
  Moo::GenericRole::ConfigAny
  /;

use Data::Dumper;

sub process {
	my ( $self ) = @_;

	my $folder_config = $self->folder_config();

	my $file_id_stack = $self->get_more_files();
	unless ( @$file_id_stack ) {
		$self->Log( "Nothing left to do" );
		return;
	}
	$self->set_select_all_off;
	$self->clear_for_project();
	sleep( 1 );

	do {
		my $file_id_stack = $self->get_more_files();
		unless ( @{$file_id_stack} ) {
			$self->Log( "Nothing left to do" );
			return;
		}

		my @file_stack;
		for my $file_id ( @{$file_id_stack} ) {
			my ( $file, $suffix ) = $self->fdb()->get_file_path_from_id( $file_id );

			push( @file_stack, $file );
		}

		$self->open_multiple_files( \@file_stack );

		$self->play_sound();

		INTERACT1: {
			print "$/After review,Press  $/\t[N] to export the files as they are$/\t[P] to auto support and wait for user input (for when more than auto support is needed)$/\t[Enter] to support all elements and export$/$/";
			my $res = <STDIN>;
			chomp( $res );
			unless ( lc( $res ) eq 'n' ) {
				$self->set_select_all_on();
				sleep( 1 );
				$self->auto_supports();
			}
			if ( lc( $res ) eq 'p' ) {
				$self->play_end_sound();
				print "$/Auto supports applied, press [Enter] to continue to export step$/";
				my $res2 = <STDIN>;

			}

			BACKUP: {
				#This never worked until now lol
				my $backup_dir = $self->config()->{folders}->{backups};
				if ( -d $backup_dir ) {

					#Do a backup unless there's only one file in play
					my $backup_path = "$backup_dir/" . time . '.chitubox';
					$self->Log( "Saving full plate backup to $backup_path" );
					$self->export_file_all( $backup_path ) unless scalar( @$file_id_stack ) == 1;
				} else {
					$self->Log( "!!!!Cannot create backup, folder [$backup_dir] is missing$/" );
				}
			}

			for my $file_id ( @$file_id_stack ) {

				# TODO - rework so that file sequencing for supported parts is [SP-#][F-#]<filename>
				$self->set_select_all_off();
				my $nname = $self->fdb()->get_numbered_name( $file_id );

				my $new_path = "$folder_config->{folders}->{parts}/$nname.chitubox";
				$self->Log( "Exporting [$file_id] to [$new_path]" );
				$self->center_export_first_file( $new_path );

				my $dim = $self->get_current_dimensions( $new_path );

				#this is a _different database_ using different IDs
				my $main_db_file_id = $self->get_file_id( $new_path );
				my $fdb_file_id     = $self->fdb()->get_file_id( $new_path );

				$self->insert(
					'file_dimensions',
					{
						file_id     => $main_db_file_id,
						x_dimension => $dim->[0],
						y_dimension => $dim->[1],
						z_dimension => $dim->[2],
					}
				);

				$self->fdb()->insert(
					'source_to_part',
					{
						source_id => $file_id,
						part_id   => $fdb_file_id,
					}
				);

				$self->click_to( 'delete_object' );
			}
			$self->clear_dynamic_sleep();
		}
	} while ( 1 );
}
#
# get a subset of the workstack that will fit
sub get_more_files {
	my ( $self ) = @_;

	#10 should be considered both the maximum and the optimal - the scroll bar is added otherwise which messes with things
	my $limit          = 10;
	my $size_limit     = 1024 * 1024 * 250;
	my $combined_sizes = 0;
	my @return;
	my $sth = $self->fdb()->query( "
		select f.id from file f
		join original_file of 
			on f.id = of.file_id
		join wanted_file wf 
			on f.id = wf.file_id
		left join source_to_part stp 
			on f.id = stp.source_id
		where stp.source_id is null
		order by of.id asc
		limit ?
		
	", $limit );

	while ( my $row = $sth->fetchrow_hashref() ) {
		my $path = $self->fdb()->get_file_path_from_id( $row->{id} );
		$self->Log( "analysing [$path]" );
		my @stat = stat $path;
		$combined_sizes += $stat[7];
		push( @return, $row->{id} );

		#enough items or likely to cause problems with file size
		if ( scalar( @return ) + 1 > $limit ) {
			$self->Log( "Resetting on part limit" );
			return \@return;
		}

		if ( $combined_sizes >= $size_limit ) {
			$self->Log( "Resetting on combined_sizes : $combined_sizes" );
			return \@return;
		}
	}
	return \@return;
}

1;

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $config_path ) = @_;

	my $self = Obj->new();
	$self->_setup();

	$self->script_setup();

	$self->process();

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
