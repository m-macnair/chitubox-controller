#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# ABSTRACT: given a work order name, or default, do all outstanding work required
our $VERSION = 'v1.0.8';

##~ DIGEST : 09844c3d07a99a11937d68daedc2e9db

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $work_order ) = @_;
	$work_order = $self->default_work_order( $work_order );
	$self->_do_db( {} );

	#plate may/not consist entirely of a single work order's contents, hence no direct relation between plate and work_order. I'm still not 100% about it
	my $work_order_plates_rs = $self->query( "
		select plate_id,wo.name,p.machine, p.id as plate_id from work_order wo
		join work_order_element woe 
			on woe.work_order_id = wo.id
		join plate p
			on woe.plate_id = p.id
		where p.file_id is null
		and wo.name = ?
		group by plate_id
	", $work_order );

	while ( my $work_order_plate_row = $work_order_plates_rs->fetchrow_hashref ) {

		print "Processing Work Order [$work_order_plate_row->{name}] Plate [ $work_order_plate_row->{plate_id} ] $/";

		#work
		$self->clear_for_project();
		$self->machine_select( $work_order_plate_row->{machine} );

		#reset the plate just in case - should prep this out of the loop
		$self->query( "
			update work_order_element 
			set on_plate = null
			where plate_id = ?
		", $work_order_plate_row->{plate_id} );

		print "Placing$/";
		$self->place_on_plate( lc( $work_order_plate_row->{plate_id} ) );
		$self->slice_and_save_plate( lc( $work_order_plate_row->{plate_id} ) );
	}
	$self->play_sound();
}
1;
