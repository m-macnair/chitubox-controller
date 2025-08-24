#ABSTRACT: Given an input csv, turn into just the things we care about
#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : dc6919d5fad01584aa47de0b89a64af9

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $project_id ) = @_;

	unless ( $project_id ) {

		die "$/\tNo project id provided";
	}
	$self->_do_db( {} );
	$self->query( "delete from projects where project = ?", $project_id );
}
1;
