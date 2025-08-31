#!/usr/bin/perl
#ABSTRACT: given an optional work order name for filtering, process all files in the db without recorded dimensions
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.8';

package Obj;
##~ DIGEST : 375266234aed2600010caf0875356b2a
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript

  /;

1;

sub process {
	my ( $self, $work_order ) = @_;

	$self->get_basic_dimensions(
		{
			work_order => $work_order
		}
	);
}

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $work_order ) = @_;

	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();

	$self->process( $work_order );

	$self->play_end_sound();
	print "It is done. Move on.$/";

}

1;
