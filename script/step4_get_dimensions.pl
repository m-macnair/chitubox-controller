#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : 2b2d49017c85ec18edc8d7dfdb2b2273

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self     = SlicerController->new();
	my ( $path ) = @_;
	my $res      = {db_file => $path};
	$self->get_basic_dimensions( $res );
	$self->play_end_sound();
}
1;
