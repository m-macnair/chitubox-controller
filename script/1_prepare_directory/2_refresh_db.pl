#!/usr/bin/perl
# ABSTRACT: Given config, refresh the db with the presence or absence of wanted files
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.7';

##~ DIGEST : 12787b33e820d8d0c15506f2c67ba634

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
  /;

use Data::Dumper;

#make sure every file in wanted is recorded - for when one has been added after the fact or removed
sub refresh_wanted_file {
	my ( $self )       = @_;
	my $ddb            = $self->directory_db();
	my $project_config = $self->project_config();
	$ddb->query( "delete from wanted_file" );
	$ddb->query( "delete from source_to_part" );
	my $ap = $self->automation_paths();

	# 	die "$ap->{sources_path}/wanted/";
	$self->sub_on_directory_files(
		sub {
			my ( $full_path ) = @_;

			my $file_id = $ddb->get_file_id( $full_path );

			$ddb->insert(
				'wanted_file',
				{
					file_id => $file_id
				}
			);

			my $nname                = $self->directory_db()->get_numbered_name( $file_id );
			my $part_path            = "$project_config->{chitubox_part_path}/$nname.chitubox";
			my $directory_db_file_id = $self->directory_db()->get_file_id( $part_path );
			if ( -e $part_path ) {
				$self->directory_db()->insert(
					'source_to_part',
					{
						source_id => $file_id,
						part_id   => $directory_db_file_id,
					}
				);
			}

			return 1;
		},
		"$ap->{sources_path}/wanted"
	);

}

1;

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $config_path ) = @_;

	my $self = Obj->new();
	$self->script_setup();

	$self->set_relative_path( __FILE__ );
	my $project_config = $self->set_asset_project_config( $config_path );
	my $ap             = $self->load_automation_paths();
	my $ddb            = $self->directory_db();

	#TODO separate script
	$self->refresh_wanted_file();

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
