#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.4';

##~ DIGEST : 52c21540748dda6c0b66450f2cde5fe8

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
	$self->get_outstanding_dimensions( $res );
	$self->play_end_sound();
}
1;
