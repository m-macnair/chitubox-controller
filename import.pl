#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.4';

##~ DIGEST : 519b9a3a27814a10977a0c42d32c6ee2

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
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
