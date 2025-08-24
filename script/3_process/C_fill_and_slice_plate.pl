#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.8';

##~ DIGEST : d8d1fe0b02c31da98efc8fc31bc967a0

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerScript;

package main;
main( @ARGV );

sub main {
	my $self = SlicerScript->new();
	my ( $plate_id ) = @_;
	die "Plate id not provided" unless $plate_id;
	$self->script_setup( {} );

	my $plate_row = $self->get( 'plate', {id => $plate_id} );
	die "Plate [$plate_id] not found" unless $plate_row;

	$self->set_select_all_off;
	$self->clear_for_project();

	$self->update( 'work_order_element', {on_plate => 0,}, {plate_id => $plate_id} );
	$self->machine_select( $plate_row->{machine} );
	$self->place_on_plate( lc( $plate_id ) );

	$self->slice_and_save_plate( lc( $plate_id ) );
	$self->play_end_sound();
}
1;
