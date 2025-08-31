#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.10';

##~ DIGEST : 0600cf45bf2e6a509361fefb8dbc5be1

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
  Moo::GenericRole::ConfigAny
  /;

use Data::Dumper;

sub process {
	my ( $self, $plate_id ) = @_;
	my $plate_row = $self->get( 'plate', {id => $plate_id} );
	die "Plate [$plate_id] not found" unless $plate_row;

	$self->update( 'work_order_element', {on_plate => 0,}, {plate_id => $plate_id} );
	$self->machine_select( $plate_row->{machine} );
	$self->slice_and_save_plate( lc( $plate_id ) );

}

package main;
main( @ARGV );

sub main {
	my $self = Obj->new();
	my ( $plate_id ) = @_;
	die "Plate id not provided" unless $plate_id;

	$self->_setup();
	$self->script_setup();

	$self->process( $plate_id );
	$self->play_end_sound();
}
1;
