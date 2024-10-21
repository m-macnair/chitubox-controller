#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.7';

##~ DIGEST : a02f52da5998e7ef3fa0b4996bfadd25

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

	for my $machine_id ( split( ',', $machines ) ) {
		print "$/\tProcessing machine [$machine_id]";
		$self->populate_plate_in_db( lc( $machine_id ), $work_order_row->{id} );
	}
}
1;
