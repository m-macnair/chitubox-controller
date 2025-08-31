#!/usr/bin/perl
# ABSTRACT: Given config for current work environment, generate a fresh instance of the csv file for all chitubox part files in the corresponding directory
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.8';

##~ DIGEST : 628b7dfb5c9b4e09001f157c1e3cbddf

use strict;
use warnings;

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript

  Moo::GenericRole::ConfigAny
  Moo::GenericRole::FileIO
  Moo::GenericRole::FileIO::CSV
  /;

use Data::Dumper;

sub process {
	my ( $self, $dir ) = @_;
	my $folder_config = $self->folder_config();

	my $project_dir = $self->config()->{master_folder};
	my $wanted_dir  = $self->config()->{folders}->{parts};
	my $output_csv  = "$project_dir/" . time . '.csv';

	#get all assets in the parts directory
	$self->Log( "Processing [$wanted_dir]" );
	$wanted_dir =~ s|//|/|g;
	my @res;
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			$self->Log( "assessing [$full_path]" );
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
			$self->aref_to_csv( [ 1, $dir, "$name$suffix" ], $output_csv );
			return 1;
		},
		$wanted_dir
	);
	$self->Log( "$output_csv" );
}

1;

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $dir ) = @_;

	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();

	$self->process( $dir );

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
