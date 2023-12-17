#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : 35384faa972632eb499c97e4b1f82e68

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
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
