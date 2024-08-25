#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.6';

##~ DIGEST : 9e3c5625f6405ed6788aeaa4a6d5f3b5

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $block_id ) = @_;
	die "Block id not provided" unless $block_id;
	$self->_do_db( {} );

	$self->slice_and_save_plate( lc( $block_id ) );
	$self->play_end_sound();
}
1;
