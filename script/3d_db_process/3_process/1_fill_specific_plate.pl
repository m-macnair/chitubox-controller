#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.10';

##~ DIGEST : d5b89b58ef0c51a3d952eabeacc188b1

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
	$self->clear_for_project();

	$self->update( 'work_order_element', {on_plate => 0,}, {plate_id => $plate_id} );
	$self->machine_select( $plate_row->{machine} );
	$self->place_files_for_plate( lc( $plate_id ) );

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
