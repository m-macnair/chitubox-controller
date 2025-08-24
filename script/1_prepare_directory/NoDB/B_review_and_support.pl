#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.5';

##~ DIGEST : f90b616a369eeacd492da3f60c971bb0

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

sub load_work {
	my ( $self, $work_stack ) = @_;
	my $project_config = $self->project_config();
	$self->set_select_all_off;
	$self->clear_for_project();
	sleep( 1 );
	my $this_stack = $self->get_next_slice_of_workstack( $work_stack );
	for my $w ( @{$this_stack} ) {
		$self->open_file( $w );
	}
	$self->play_sound();

	INTERACT1: {
		print "$/After review,Press  $/\t[N] to export the files as they are$/\t[P] to auto support and wait for user input (for when more than auto support is needed)$/\t[Enter] to support all elements and export$/$/";
		my $res = <STDIN>;
		chomp( $res );
		unless ( lc( $res ) eq 'n' ) {
			unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
				$self->click_to( 'select_all' );
			}
			sleep( 1 );
			$self->auto_supports();
		}
		if ( lc( $res ) eq 'p' ) {
			$self->play_end_sound();
			print "$/Auto supports applied, press [Enter] to continue to export step$/";
			my $res2 = <STDIN>;

		}

		BACKUP: {
			if ( -d $project_config->{chitubox_backup_path} ) {

				#Do a backup unless there's only one file in play
				$self->export_file_all( "$project_config->{chitubox_backup_path}/" . time . '.chitubox' ) unless scalar( @$this_stack ) == 1;
			} else {
				print "!!!!Cannot create backup, folder [$project_config->{chitubox_backup_path}] is missing$/";
			}
		}

		for my $this ( @$this_stack ) {
			my ( $name, $dir, $suffix ) = $self->file_parse( $this );
			my $new_path = "$project_config->{chitubox_part_path}/$name.chitubox";
			print "Exporting [$this] to [$new_path]";
			$self->center_export_first_file( $new_path );

			my $dim         = $self->get_current_dimensions( $new_path );
			my $out_file_id = $self->get_file_id( $new_path );

			$self->insert(
				'file_dimensions',
				{
					file_id     => $out_file_id,
					x_dimension => $dim->[0],
					y_dimension => $dim->[1],
					z_dimension => $dim->[2],
				}
			);

			$self->click_to( 'delete_object' );
		}
	}
}

# get a subset of the workstack that will fit
sub get_next_slice_of_workstack {
	my ( $self, $work_stack ) = @_;

	#5 seems to be a good limit due to non-size based delays
	my $limit          = 3;
	my $size_limit     = 1024 * 1024 * 100;
	my $combined_sizes = 0;
	my @return;
	do {
		my $path = shift( @{$work_stack} );
		print "analysing [$path]$/";
		my @stat = stat $path;
		$combined_sizes += $stat[7];
		push( @return, $path );

		#enough items or likely to cause problems with file size
		if ( scalar( @return ) + 1 > $limit ) {
			print "Resetting on part limit$/";
			return \@return;
		}

		if ( $combined_sizes >= $size_limit ) {
			print "Resetting on combined_sizes : $combined_sizes$/";
			return \@return;
		}
	} while ( @$work_stack );
	return \@return;
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
	my $project_config = $self->get_asset_project_config( $config_path );
	$self->project_config( $project_config );

	#get all assets in the wanted directory
	print "Processing [$project_config->{source_wanted_path}]$/";
	$project_config->{source_wanted_path} =~ s|//|/|g;
	my @wanted;
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			print "assessing [$full_path]$/";
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
			unless ( $self->is_a_file( "$project_config->{chitubox_part_path}/$name.chitubox" ) ) {
				push( @wanted, $full_path );
			}
			return 1;
		},
		$project_config->{source_wanted_path},
	);
	while ( @wanted ) {
		$self->load_work( \@wanted );
	}
	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
