#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.7';

##~ DIGEST : 8d4767f763f4b2684b890c7f15069977

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

	$self->slice_and_save_plate( lc( $plate_id ) );
	$self->play_end_sound();
}
1;
