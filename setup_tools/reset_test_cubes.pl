#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : e0349b83d105a551e2b60d855e5da20f

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	$self->_do_db( {} );
	$self->query( "update projects set state = null where project = 'test_cubes'" );
}
1;
