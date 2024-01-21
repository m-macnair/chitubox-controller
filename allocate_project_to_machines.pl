#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : d94980b43099d925f81372df84da8289

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $project_id, $machines ) = @_;

	unless ( $project_id ) {
		$project_id = "default";
		print "$/\tNo project id provided, set to [$project_id]$/";
	}
	$project_id ||= "default";

	$self->_do_db( {} );
	for my $machine_id ( split( ',', $machines ) ) {
		print "$/\tProcessing machine [$machine_id]";
		$self->allocate_position_in_db_mk2( lc( $machine_id ), $project_id );
	}
}
1;
