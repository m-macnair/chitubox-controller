#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.7';

##~ DIGEST : 0546148267aa257aa0b679fa02e90d4f

BEGIN {
	push( @INC, './lib/' );
}

package Obj;

use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript

  /;

1;

package main;
main( @ARGV );

sub main {
	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();

	my ( $path, $work_order_name ) = @_;
	die 'Path not provided'       unless $path;
	die 'Path invalid'            unless -f $path;
	die 'Work Order Not Provided' unless $work_order_name;
	my $res = {
		csv_file        => $path,
		work_order_name => $work_order_name,
	};

	$self->_do_db( $res );
	my $stack = $self->get_file_list( $res->{csv_file} );
	my $work_order_name;
	if ( $res->{work_order_name} ) {
		$work_order_name = $res->{work_order_name};
	} else {
		$work_order_name = "default";
		warn( "no work_order id provided for import_work_list; set to [$work_order_name]" );
	}
	my $sequence_start_row = $self->query( '
		SELECT COALESCE(MAX(woe.sequence_id),1) AS max_sequence
		FROM work_order_element woe
		JOIN work_order wo ON woe.work_order_id = wo.id
		WHERE wo.name = ?;
	' )->fetchrow_arrayref();
	my $sequence_counter = defined( $sequence_start_row ) ? $sequence_start_row->[0] : 1;

	my $work_order_row = $self->select_insert_href( 'work_order', {name => $work_order_name}, [qw/* id/] );

	for my $work_order_row_href ( @{$stack} ) {
		$self->Log( "processing $work_order_row_href->{path}" );
		my $file_id = $self->get_file_id( $work_order_row_href->{path} );
		while ( $work_order_row_href->{count} > 0 ) {
			$self->Log( "Added file [$file_id] at sequence position [$sequence_counter] to work order [$work_order_name]" );

			$self->import_file_id_to_work_order(
				$file_id,
				$work_order_row->{id},
				{
					sequence_id => $sequence_counter
				}
			);
			$work_order_row_href->{count}--;
			$sequence_counter++;
		}
	}

}
1;
