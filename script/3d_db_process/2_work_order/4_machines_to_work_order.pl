#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.15';

##~ DIGEST : 119bde42ba3c309cdbe41712b93615b1

BEGIN {
	push( @INC, "./lib/" );
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
	my ( $machines, $work_order_name ) = @_;

	unless ( $work_order_name ) {
		$work_order_name = "default";
		$self->Log( "No Work Order provided, set to [$work_order_name]", {level => 'Alert'} );
	}
	$self->_do_db( {} );
	my $work_order_row = $self->select( 'work_order', [qw/* id/], {name => $work_order_name} )->fetchrow_hashref();

	my @plates;
	my $remaining;
	for my $machine_id ( split( ',', $machines ) ) {

		$self->Log( "Processing machine [$machine_id]" );
		my $res = $self->get_machine_coordinates_for_work_order( lc( $machine_id ), $work_order_row->{id} );
		warn Dumper( $res );

		$self->place_files_on_plate( $machine_id, $res->{files} );

		if ( $res->{plate_id} ) {
			push( @plates, $res->{plate_id} );

			$self->insert(
				'work_order_plate',
				{
					work_order_id => $work_order_row->{id},
					plate_id      => $res->{plate_id}
				}
			);

		} elsif ( $res->{pass} ) {
			$self->Log( "Non Fatal absence of plate : $res->{pass}" );

		} else {
			die "Unhandled failure in populate_plate_in_db";
		}
	}

	$self->Log( "Prepared plates: " . join( ',', @plates ) ) if @plates;
	$self->Log( "Remaining files: $remaining", {level => 'Attention'} );

}
1;
