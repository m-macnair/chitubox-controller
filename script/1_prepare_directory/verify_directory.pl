#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, load each file and interactively delete - for situations where the export didn't work correctly
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.5';

##~ DIGEST : 0241d96ac9718160d4cc27d7ccb0e6c0

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

ACCESSORS: {
	has project_config => (
		is   => 'rw',
		lazy => 1,
	);
}

# sub load_work {
# 	my ( $self, $work_stack ) = @_;
# 	my $project_config = $self->project_config();
# 	$self->set_select_all_off;
# 	$self->clear_for_project();
# 	sleep( 1 );
# 	my $this_stack = $self->get_next_slice_of_workstack( $work_stack );
# 	for my $w ( @{$this_stack} ) {
# 		$self->open_file( $w );
# 	}
# 	$self->play_sound();
#

#
# 		BACKUP: {
# 			if ( -d $project_config->{chitubox_backup_path} ) {
#
# 				#Do a backup unless there's only one file in play
# 				$self->export_file_all( "$project_config->{chitubox_backup_path}/" . time . '.chitubox' ) unless scalar( @$this_stack ) == 1;
# 			} else {
# 				print "!!!!Cannot create backup, folder [$project_config->{chitubox_backup_path}] is missing$/";
# 			}
# 		}
#
# 		for my $this ( @$this_stack ) {
# 			my ( $name, $dir, $suffix ) = $self->file_parse( $this );
# 			my $new_path = "$project_config->{chitubox_part_path}/$name.chitubox";
# 			print "Exporting [$this] to [$new_path]";
# 			$self->center_export_first_file( $new_path );
# 			$self->click_to( 'delete_object' );
# 		}
# 	}
# }
#
# # get a subset of the workstack that will fit
# sub get_next_slice_of_workstack {
# 	my ( $self, $work_stack ) = @_;
#
# 	#5 seems to be a good limit due to non-size based delays
# 	my $limit          = 1;
# 	my $size_limit     = 1024 * 1024 * 100;
# 	my $combined_sizes = 0;
# 	my @return;
# 	do {
# 		my $path = shift( @{$work_stack} );
# 		print "$/Processing [$path]$/";
# 		return \@return;
# 		}
# 	} while ( @$work_stack );
# 	return \@return;
# }

1;

package main;
main( @ARGV );
use List::Util qw(any);
use Data::Dumper;

sub main {
	my ( $config_path ) = @_;

	my $self = Obj->new();
	$self->script_setup();
	my $project_config = $self->get_asset_project_config( $config_path );
	$self->project_config( $project_config );

	#get all assets in the wanted directory
	print "Processing [$project_config->{chitubox_part_path}]$/";
	$project_config->{chitubox_part_path} =~ s|//|/|g;
	my @wanted;
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			my $file_id = $self->get_file_id( $full_path );
			print "assessing [$full_path]$/";
			my $file_meta_row = $self->get(
				'file_meta',
				{
					file_id => $file_id,
				}
			);
			warn Dumper( $file_meta_row );
			return 1 if $file_meta_row->{manually_verified};

			$self->clear_for_project();
			$self->open_file( $full_path );

			INTERACT1: {
				print "[$file_id:$full_path]$/$/After review, Press$/\t[X] to delete the chitubox file and any meta attributes$/$/\t[Enter] to verify the file$/$/";
				my $res = <STDIN>;
				chomp( $res );
				if ( lc( $res ) eq 'x' ) {
					unlink( $full_path ) or die "Failed to delete chitubox file:$!";
					$self->delete( 'file_meta',       {file_id => $file_id} );
					$self->delete( 'file_dimensions', {file_id => $file_id} );
					return 1;
				}

				$self->select(
					'file_meta',
					qw[*],
					{
						file_id => $file_id,
					}
				);

				unless ( $file_meta_row->{file_id} ) {
					print "creating meta row$/";
					$file_meta_row = $self->select_insert_href( 'file_meta', {file_id => $file_id}, [qw/* id/] );
				}
				$self->update(
					'file_meta',
					{
						manually_verified => 1
					},
					{
						file_id => $file_id,
					}
				);
				$self->commit_force();
			}

			return 1;
		},
		$project_config->{chitubox_part_path},
	);

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
