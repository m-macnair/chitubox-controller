#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : 8f2d7fd16a027be56b05de2d42ea965f

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self     = ChituboxController->new();
	my ( $path ) = @_;
	my $res      = {db_file => $path};
	$self->get_outstanding_dimensions( $res );
	$self->play_end_sound();
}
1;
