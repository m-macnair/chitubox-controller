#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : 9a4b1ddf3a3b9a6d4084b8380570c283

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
	$self->machine_select( lc( $block_id ) );
}
1;
