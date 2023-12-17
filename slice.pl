#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : 2b9b5ad0fa29e830add919657f9f9e03

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	my ( $block_id ) = @_;
	die "Block id not provided" unless $block_id;
	$self->_do_db( {} );
	$self->slice_and_save( lc( $block_id ) );
}
1;
