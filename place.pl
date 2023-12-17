#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : 42e25d2f99dd0243abeb264a35c2c2c1

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
	my $project_row = $self->query( "select * from projects where project_block = ? limit 1", $project_block )->fetchrow_hashref();

	$self->clear_for_project();
	$self->machine_select( $project_row->{machine} );
	$self->update( 'projects', {'state' => 'positioned'}, {project_block => $project_block} );
	$self->place_stl_rows( lc( $project_block ) );
}
1;
