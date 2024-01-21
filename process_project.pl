#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.7';

##~ DIGEST : 1769f429eda41aff47742c1f3665f0a4

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $project ) = @_;
	$self->_do_db( {} );
	my $project_set_rs = $self->query( "select distinct(project_block) as project_block from projects where project = ? and state = 'positioned' order by project_block asc ", $project );
	while ( my $project_block_row = $project_set_rs->fetchrow_hashref ) {

		print "Processing Project Block [ $project_block_row->{project_block} ] $/";

		$self->update( 'projects', {'state' => 'positioned'}, {project_block => $project_block_row->{project_block}} );
		my $project_row = $self->query( "select * from projects where project_block = ? and state = 'positioned' limit 1 ", $project_block_row->{project_block} )->fetchrow_hashref();
		die "Missing project row (!?) for [$project_row->{project_block}]$/" unless $project_row;

		#work
		$self->clear_for_project();

		$self->machine_select( $project_row->{machine} );
		print "Placing$/";
		$self->place_stl_rows( lc( $project_row->{project_block} ) );
		print "Slice & Saving $/";
		$self->slice_and_save( lc( $project_row->{project_block} ) );
	}
	$self->play_sound();
}
1;
