#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.9';

##~ DIGEST : 51e8e8daa8f309f3e0cf27836bbf5c86

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

	$self->update( 'work_order_element', {on_plate => 0,}, {plate_id => $plate_id} );
	$self->machine_select( $plate_row->{machine} );
	$self->place_files_for_plate( lc( $plate_id ) );

	$self->play_end_sound();
}
1;
