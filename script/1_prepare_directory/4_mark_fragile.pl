#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.5';
##~ DIGEST : fd6dab8bdcf862c00ffc92959ef23fb9

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::ScriptHelper
  Moo::GenericRole::ConfigAny
  /;

sub process_file {
	my ( $self, $file ) = @_;
	my $file_id = $self->get_file_id( $file );
	print "file $file id [$file_id]$/";
	my $row = $self->select_insert_href(
		'file_meta',
		{
			file_id => $file_id
		}
	);

	$self->update(
		'file_meta',
		{
			is_fragile => 1,
		},
		{
			id => $row->{id}
		}
	);
}
1;

package main;
main( @ARGV );

sub main {
	my ( $path ) = @_;
	my $self = Obj->new();
	$self->script_single_or_file( $path );
}
1;
