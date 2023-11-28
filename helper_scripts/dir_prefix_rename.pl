#!/usr/bin/perl
# ABSTRACT: create a soft link in lower snake case with a single space prefix for all file names at the first level of a directory - helps imagemagick read file names in the chitubox menu
our $VERSION = 'v0.0.4';

##~ DIGEST : 717a77f865316eeca44ae8ad3738bce3

use strict;
use warnings;

package Obj;
use Moo;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common

sub process {
	my ( $self, $path ) = @_;
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;

			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );

			#print "working on [$full_path]$/";

			$name =~ s/^\s+|\s+$//g;
			$name =~ s/^_//g;
			$name =~ s/_$//g;
			$name = lc( $name );
			$name =~ s| |_|g;
			$name = " $name";

			my $new_path = "$dir/$name$suffix";
			if ( -e $new_path ) {
				warn "existing file $new_path found, SKIPPING";
			} else {
				symlink( $full_path, $new_path );
			}
			return 1;

		},
		$path
	);
}
1;

package main;

main( @ARGV );

sub main {
	my $self = Obj->new();
	my ( $path ) = @_;
	die "path not provided" unless $path;
	print "$/processing [$path]$/";
	$self->process( $path );

}
