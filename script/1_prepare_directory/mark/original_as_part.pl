#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.7';
##~ DIGEST : 9c5c047d05776c70c3e2fb4a0ed844bc

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
		my $part_path = $self->folder_config()->{folders}->{parts} . "/$nname$suffix";

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
