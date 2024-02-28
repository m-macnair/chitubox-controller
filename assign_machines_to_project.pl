#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.6';

##~ DIGEST : f1a47f89290c98c27fe0c5acd8b0aa60

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $machines, $project_id ) = @_;

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
