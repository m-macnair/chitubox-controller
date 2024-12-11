#!/usr/bin/perl
# ABSTRACT: Given config pointing to input asset and output chitubox directories, for each asset without a corresponding chitubox file, load into chitubox for manual assessment and optional support
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.7';

##~ DIGEST : e28fe9e048f6d936ff90e396245d5834

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

sub process {
	my ( $self ) = @_;
	my $project_config = $self->project_config();

	my $file_id_stack = $self->get_more_files();
	unless ( @$file_id_stack ) {
		print "Nothing left to do$/";
		return;
	}
	$self->set_select_all_off;
	$self->clear_for_project();
	sleep( 1 );

	do {
		my $file_id_stack = $self->get_more_files();
		return unless $file_id_stack;
		for my $file_id ( @{$file_id_stack} ) {
			my ( $file, $suffix ) = $self->directory_db()->get_numbered_name( $file_id );

			# 		die $file;
			$self->open_file( "$project_config->{source_wanted_path}/$file$suffix" );
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
					$self->export_file_all( "$project_config->{chitubox_backup_path}/" . time . '.chitubox' ) unless scalar( @$file_id_stack ) == 1;
				} else {
					print "!!!!Cannot create backup, folder [$project_config->{chitubox_backup_path}] is missing$/";
				}
			}

			for my $file_id ( @$file_id_stack ) {
				my $nname = $self->directory_db()->get_numbered_name( $file_id );

				my $new_path = "$project_config->{chitubox_part_path}/$nname.chitubox";
				print "Exporting [$file_id] to [$new_path]";
				$self->center_export_first_file( $new_path );

				my $dim = $self->get_current_dimensions( $new_path );

				#this is a _different database_ using different IDs
				my $main_db_file_id      = $self->get_file_id( $new_path );
				my $directory_db_file_id = $self->directory_db()->get_file_id( $new_path );

				$self->insert(
					'file_dimensions',
					{
						file_id     => $main_db_file_id,
						x_dimension => $dim->[0],
						y_dimension => $dim->[1],
						z_dimension => $dim->[2],
					}
				);

				$self->directory_db()->insert(
					'source_to_part',
					{
						source_id => $file_id,
						part_id   => $directory_db_file_id,
					}
				);

				$self->click_to( 'delete_object' );
			}
		}
	} while ( 1 );
}
#
# get a subset of the workstack that will fit
sub get_more_files {
	my ( $self ) = @_;

	#5 seems to be a good limit due to non-size based delays
	my $limit          = 10;
	my $size_limit     = 1024 * 1024 * 100;
	my $combined_sizes = 0;
	my @return;
	my $sth = $self->directory_db()->query( "
		select f.id from file f
		join original_file of 
			on f.id = of.file_id
		join wanted_file wf 
			on f.id = wf.file_id
		left join source_to_part stp 
			on f.id = stp.source_id
		where stp.source_id is null
		order by of.id asc
		limit ?
		
	", $limit );

	while ( my $row = $sth->fetchrow_hashref() ) {
		my $path = $self->directory_db()->get_file_path_from_id( $row->{id} );
		print "analysing [$path]$/";
		my @stat = stat $path;
		$combined_sizes += $stat[7];
		push( @return, $row->{id} );

		#enough items or likely to cause problems with file size
		if ( scalar( @return ) + 1 > $limit ) {
			print "Resetting on part limit$/";
			return \@return;
		}

		if ( $combined_sizes >= $size_limit ) {
			print "Resetting on combined_sizes : $combined_sizes$/";
			return \@return;
		}
	}
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

	$self->set_relative_path( __FILE__ );
	my $project_config = $self->set_asset_project_config( $config_path );
	my $ap             = $self->load_automation_paths();
	my $ddb            = $self->directory_db();

	$self->process();

	$self->play_end_sound();
	print "It is done. Move on.$/";

}
1;
