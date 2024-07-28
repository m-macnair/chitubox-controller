#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.8';

##~ DIGEST : c969b7b06cb05bc96b1741d169d40ab9

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $block_id ) = @_;
	die "Block id not provided" unless $block_id;
	$self->_do_db( {} );
	my $project_row = $self->query( "select * from projects where project_block = ? limit 1", $block_id )->fetchrow_hashref();

	$self->clear_for_project();
	$self->machine_select( $project_row->{machine} );
	$self->update( 'projects', {'state' => 'positioned'}, {project_block => $block_id} );
	$self->set_select_all_off();
	$self->place_stl_rows( lc( $block_id ) );
	$self->slice_and_save( lc( $block_id ) );
	$self->play_end_sound();
}
1;
