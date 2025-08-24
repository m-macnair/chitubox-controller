#!/usr/bin/perl
# ABSTRACT: Given config, refresh the db with the presence or absence of wanted files
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.8';

##~ DIGEST : aa4036bbc4707df0cc53f17991ee6b2b

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
  /;

use Data::Dumper;

#make sure every file in wanted is recorded - for when one has been added after the fact or removed
sub refresh_wanted_file {
	my ( $self )      = @_;
	my $fdb           = $self->fdb();
	my $folder_config = $self->folder_config();

	# 	use Data::Dumper;
	# 	die Dumper($folder_config);
	$fdb->query( "delete from wanted_file" );
	$fdb->query( "delete from source_to_part" );

	# 	die "$folder_config->{sources_path}/wanted/";
	$self->sub_on_directory_files(
		sub {
			my ( $full_path ) = @_;

			my $file_id = $fdb->get_file_id( $full_path );

			$fdb->insert(
				'wanted_file',
				{
					file_id => $file_id
				}
			);

			my $nname       = $fdb->get_numbered_name( $file_id );
			my $part_path   = "$folder_config->{production_part_path}/$nname.chitubox";
			my $fdb_file_id = $fdb->get_file_id( $part_path );
			if ( -e $part_path ) {
				$fdb->insert(
					'source_to_part',
					{
						source_id => $file_id,
						part_id   => $fdb_file_id,
					}
				);
			}

			return 1;
		},
		$folder_config->{source_wanted_path}
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

	#TODO separate script
	$self->refresh_wanted_file();

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
