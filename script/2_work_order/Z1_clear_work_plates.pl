#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.11';

##~ DIGEST : f4568635f2c6c91101a1bc41d75a7a8b

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $work_order_name, $plate_id ) = @_;
	die "No work order provided" unless $work_order_name;
	my @plate_ids;
	if ( $plate_id ) {
		@plate_ids = split( ',', $plate_id );
	}

	$self->_do_db( {} );
	my $work_order_row = $self->select( 'work_order', [qw/* id/], {name => $work_order_name} )->fetchrow_hashref();
	die "Work order not found" unless $work_order_row->{name};

	$self->delete(
		'work_order_plate',
		{
			plate_id => {
				'!=' => \@plate_ids
			},

			work_order_id => $work_order_row->{id}
		}
	);
	$self->update(
		'work_order_element',
		{
			plate_id   => undef,
			x_position => undef,
			y_position => undef,
			positioned => undef,
			on_plate   => undef,
			rotate     => undef,
		},
		{
			work_order_id => $work_order_row->{id},
			plate_id      => {
				'!=' => \@plate_ids
			},
		}
	);

}
1;
