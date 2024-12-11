#!/usr/bin/perl
#ABSTRACT: given an optional work order name for filtering, process all files in the db without recorded dimensions
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.6';

package Obj;
##~ DIGEST : 5d261378e0adfbc951ad36f523ba5da2
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::ScriptHelper

  /;

1;

package main;
main( @ARGV );

sub main {

	my $self = Obj->new();
	$self->script_setup();
	my ( $work_order ) = @_;

	$self->get_basic_dimensions(
		{
			work_order => $work_order
		}
	);
	$self->play_end_sound();
}
1;
