#!/usr/bin/perl
# ABSTRACT: dump typically desirable directory contents into a given spreadsheet
our $VERSION = 'v0.0.5';

##~ DIGEST : cb67939293c7b5f9872d7216c25e255a

use strict;
use warnings;

package Obj;
use Moo;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/
  Moo::GenericRole::FileIO
  Moo::GenericRole::FileIO::CSV
  /;
use List::Util qw(any);

sub process {
	my ( $self, $path, $csv ) = @_;
	$self->set_column_order_for_path( [qw/#count dir file/], $csv );
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
			return 1 unless ( any { $_ eq $suffix } qw/ .stl .obj / );

			$self->href_to_csv(
				{
					'#count' => 0,
					dir      => $dir,
					file     => "$name$suffix",
				},
				$csv
			);
		},
		$path
	);
}
1;

package main;

main( @ARGV );

sub main {
	my $self = Obj->new();
	my ( $dir, $csv ) = @_;
	$csv ||= "./default.csv";
	die "path not provided" unless $dir;
	print "$/processing [$dir] into [$csv]$/";
	$self->process( $dir, $csv );

}
