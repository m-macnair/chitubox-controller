#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.11';

##~ DIGEST : 150ea3730dede26f8dd57e6f28e7e7c1

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
	die "No plate ID provided"   unless $plate_id;

	$self->_do_db( {} );
	my $work_order_row = $self->select( 'work_order', [qw/* id/], {name => $work_order_name} )->fetchrow_hashref();
	die "Work order not found" unless $work_order_row->{name};

	my $plate_row = $self->select( 'plate', [qw/* id/], {id => $plate_id} )->fetchrow_hashref();
	die "Plate not found for [$plate_id]" unless $work_order_row->{name};

	my $existing_row = $self->select( 'work_order_plate', [qw/* id/], {plate_id => $plate_id} )->fetchrow_hashref();
	die "Plate assignment already exists for [$plate_id]" if $existing_row->{name};

	$self->insert(
		'work_order_plate',
		{
			work_order_id => $work_order_row->{id},
			plate_id      => $plate_id
		}
	);
}
1;
