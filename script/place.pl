#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.8';

##~ DIGEST : aea7208ba54c01aa2ab76b82fe2792d4

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $project_block ) = @_;
	die "Block id not provided" unless $project_block;
	$self->_do_db( {} );
	my $project_row = $self->query( "select * from projects where project_block = ? limit 1", $project_block )->fetchrow_hashref();

	$self->clear_for_project();
	$self->machine_select( $project_row->{machine} );
	$self->update( 'projects', {'state' => 'positioned'}, {project_block => $project_block} );
	$self->set_select_all_off();
	$self->place_stl_rows( lc( $project_block ) );
	$self->play_end_sound();
}
1;
