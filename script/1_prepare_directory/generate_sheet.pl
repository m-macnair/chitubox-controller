#!/usr/bin/perl
# ABSTRACT: Given config for current work environment, generate a fresh instance of the csv file for all chitubox part files in the corresponding directory
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.6';

##~ DIGEST : 134808f8b909f8d7bad1afc6a2e5077b

use strict;
use warnings;

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::ScriptHelper
  Moo::GenericRole::ConfigAny
  Moo::GenericRole::FileIO
  Moo::GenericRole::FileIO::CSV
  /;

use Data::Dumper;

1;

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $config_path ) = @_;
	$config_path ||= './current_automation_project/project_config.perl';
	my $self = Obj->new();
	$self->_setup();
	my $project_config = $self->get_asset_project_config( $config_path );
	my ( undef, $project_dir ) = $self->file_parse( $self->abs_path( $config_path ) );
	my $output_csv = "$project_dir/" . time . '.csv';
	$self->project_config( $project_config );

	#get all assets in the wanted directory
	print "Processing [$project_config->{source_wanted_path}]$/";
	$project_config->{chitubox_part_path} =~ s|//|/|g;
	my @res;
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			print "assessing [$full_path]$/";
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
			$self->aref_to_csv( [ 1, $dir, "$name$suffix" ], $output_csv );
			return 1;
		},
		$project_config->{chitubox_part_path}
	);
	print "$output_csv$/$/";

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
