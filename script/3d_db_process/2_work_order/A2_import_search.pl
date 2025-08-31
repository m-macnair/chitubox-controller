#!/usr/bin/perl
# ABSTRACT: through ScriptHelper Defaults, add file/s to a project
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.4';
##~ DIGEST : 42ab4009f89c899e30c5a85f97ce163b

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::ScriptHelper
  Moo::GenericRole::ConfigAny
  /;

ACCESSORS: {

	has work_order_id => (
		is   => 'rw',
		lazy => 1,
	);
}

sub process_file {
	my ( $self, $file ) = @_;
	my $file_id = $self->get_file_id( $file );
	$self->import_file_id_to_work_order( $file_id );
}
1;

package main;
main( @ARGV );

sub main {
	my ( $path, $work_order ) = @_;
	unless ( $work_order ) {
		print "Project not supplied, setting as 'default'";
		$work_order = 'default';
	}
	my $self           = Obj->new();
	my $work_order_row = $self->select_insert_href( 'work_order', {name => $work_order}, [qw/* id/] );
	$self->work_order_id( $work_order_row->{id} );
	$selk->script_single_or_file( $path );
}
1;
