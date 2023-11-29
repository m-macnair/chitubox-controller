#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : e56fe1da767645c8335a6018e379c2bc

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	my ( $project_string ) = @_;

	$self->_do_db( {} );

	for my $project_block ( split( ',', $project_string ) ) {
		print "$/";
		print "Processing Project Block [$project_block]$/";

		#prep
		my $project_row = $self->query( "select * from projects where project_block = ? ", $project_block )->fetchrow_hashref();
		die "Block id not provided" unless $project_block;
		$self->update( 'projects', {'state' => 'positioned'}, {project_block => $project_block} );

		#work
		$self->clear_plate();
		$self->machine_select( $project_row->{machine} );
		$self->place_stl_rows( lc( $project_block ) );
		$self->slice_and_save( lc( $project_block ) );
	}
}
1;
