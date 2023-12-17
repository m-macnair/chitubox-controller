#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.2';

##~ DIGEST : 09a6853d530d28cb09ff19bbde643df8

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
}
1;
