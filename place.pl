#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : 57c14bda60dbd33cb6252149660a3f5c

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	my ( $project_block ) = @_;
	die "Block id not provided" unless $project_block;
	$self->_do_db( {} );
	$self->update( 'projects', {'state' => 'positioned'}, {project_block => $project_block} );
	$self->place_stl_rows( lc( $project_block ) );
}
1;
