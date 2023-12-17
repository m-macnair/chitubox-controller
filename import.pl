#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.3';

##~ DIGEST : fc0469851858504f54f426f37b833745

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	my ( $path, $project_id ) = @_;
	die "Path not provided"       unless $path;
	die "Path invalid"            unless -f $path;
	die "Project ID not provided" unless $project_id;
	my $res = {
		csv_file   => $path,
		project_id => $project_id,
	};
	$self->import_work_list( $res );
}
1;
