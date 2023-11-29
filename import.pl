#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run ChituboxController::import_work_list()
our $VERSION = 'v1.0.1';

##~ DIGEST : 03a15c997878803003aeb446e50f9270

BEGIN {
	push( @INC, "./lib/" );
}
use ChituboxController;

package main;
main( @ARGV );

sub main {
	my $self = ChituboxController->new();
	my ( $path, $project_id ) = @_;
	die "Path not provided" unless $path;
	my $res = {
		csv_file   => $path,
		project_id => $project_id,
	};
	$self->import_work_list( $res );
}
1;
