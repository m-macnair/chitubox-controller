#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.6';
##~ DIGEST : 2f0d2114327ac93c98c5026b0101904a

package Obj;
use Moo;
use parent qw/

  SlicerController::Class::FolderScript
  /;

sub process_file {
	my ( $self, $file ) = @_;

	# 	warn $file;
	my $file_id = $self->fdb->get_existing_file_id( $file );

	# 	die $file_id if $file_id;
	if ( $file_id ) {
		print "file $file id [$file_id]$/";

		my ( $nname, $suffix ) = $self->fdb->get_numbered_name( $file_id );

		my $row = $self->fdb->select_insert_href(
			'original_as_part',
			{
				file_id => $file_id
			}
		);
		my $part_path = $self->folder_config()->{production_part_path} . "/$nname$suffix";

		unless ( $self->is_a_file( $part_path ) ) {
			symlink( $file, $part_path ) or die "failed to link [$file] to [$part_path]: $!";
			print "Added : [$part_path]$/";
		}
	}
	return 1;
}
1;

package main;
main( @ARGV );

sub main {

	my $self = Obj->new();
	$self->script_setup();

	$self->single_or_file( join( ' ', @_ ) );
}
1;
