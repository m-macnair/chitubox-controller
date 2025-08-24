#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : ce313594d27e0e4158df1d6e64310130

BEGIN {
	push( @INC, './lib/' );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $path, $work_order_name ) = @_;
	die 'Path not provided' unless $path;
	die 'Path invalid'      unless -f $path;
	my $res = {
		csv_file        => $path,
		work_order_name => $work_order_name,
	};
	$self->import_work_list( $res );
}
1;
