#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.11';

##~ DIGEST : 2f80e5e50141edd7b39fdc0dc30964af

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $machines, $work_order_name ) = @_;

	unless ( $work_order_name ) {
		$work_order_name = "default";
		print "$/\tNo Work Order provided, set to [$work_order_name]$/";
	}
	$self->_do_db( {} );
	my $work_order_row = $self->select( 'work_order', [qw/* id/], {name => $work_order_name} )->fetchrow_hashref();

	my @plates;
	my $remaining;
	for my $machine_id ( split( ',', $machines ) ) {
		print "$/\tProcessing machine [$machine_id]";
		my $res = $self->populate_plate_in_db( lc( $machine_id ), $work_order_row->{id} );
		$remaining = $res->{remaining};
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
			print "Non Fatal absence of plate : $res->{pass}$/";

		} else {
			die "Unhandled failure in populate_plate_in_db";
		}
	}

	print "$/Prepared plates " . join( ',', @plates ) if @plates;
	print "$/Remaining files: $remaining";
}
1;
