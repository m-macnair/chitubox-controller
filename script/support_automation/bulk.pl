#!/usr/bin/perl
# ABSTRACT:
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.9';

BEGIN {
	push( @INC, "./lib/" );
	push( @INC, "../lib/" );
}

##~ DIGEST : 8fa100d50a4f16981d22b268d0af5338

use strict;
use warnings;

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/

  Moo::GenericRole::ConfigAny
  Moo::GenericRole::FileIO
  Moo::GenericRole::FileIO::CSV

  /;

1;

package main;
main( @ARGV );
use List::Util qw(any);

sub main {
	my $self = Obj->new();
	$self->_setup();
	my $csv_path = "/home/m/Hobby/Hobby-Code/chitubox-controller/ClientProjects/";
	my ( $path, $project ) = @_;

	die "Config file not provided" unless $path;

	unless ( $project ) {
		print "Project not provided - adding to default";
		$project = 'default';
	}
	$csv_path .= "$project.csv";

	my $project_config = $self->config_file( $path );
	$self->ControlByGui_x_offset( 4014 );
	$self->ControlByGui_coordinate_map->{console} = [ 2794, 1916 ];

	my $limit          = 5;
	my $size_limit     = 1024 * 1024 * 100;
	my $combined_sizes = 0;
	my $continue       = 1;
	die "Process path [$project_config->{in_path}] not found" unless -e $project_config->{in_path};
	while ( $continue ) {
		$self->set_select_all_off;
		$self->click_to( "new_project" );
		sleep( 1 );

		my @work_stack;
		$continue = 0;
		my $working_size;
		$self->sub_on_directory_files(
			sub {
				my ( $path ) = @_;
				my ( $name, $dir, $suffix ) = $self->file_parse( $path );
				warn $suffix;
				return 1 unless ( any { $_ eq $suffix } qw/ .stl .obj / );

				print "analysing [$path]$/";
				my $out = "$project_config->{out_path}/$name.chitubox";

				if ( -f $out ) {
					print "\t[$out] exists $/";
					return 1;
				}
				my $in   = $path;
				my @stat = stat $in;
				$combined_sizes += $stat[7];

				#enough items or likely to cause problems with file size
				if ( scalar( @work_stack ) == $limit ) {
					print "Resetting part limit$/";
					$continue       = 1;
					$combined_sizes = 0;
					return 0;
				}
				if ( $combined_sizes >= $size_limit ) {
					print "Resetting on combined_sizes : $combined_sizes$/";
					push( @work_stack, [ $in, $out ] );
					$continue       = 1;
					$combined_sizes = 0;
					return 0;
				}

				push( @work_stack, [ $in, $out ] );
			},
			$project_config->{in_path}
		);
		last unless ( $continue || scalar( @work_stack ) );
		for my $w ( @work_stack ) {
			$self->open_file( $w->[0] );
		}
		$self->play_sound();

		print "$/\t Press [ N ] to just export the files, [P] to auto support and wait, or just [Enter] to support all elements and export. ";
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
			my $res2 = <STDIN>;

		}

		#Do a backup unless there's only one file in play
		$self->export_file_all( "$project_config->{out_path}/backup_" . time . '.chitubox' ) unless scalar( @work_stack ) == 1;

		#set to select all as a starting point to prevent exporting everything as center_export_first_file unticks it if necessary
		unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
			$self->click_to( 'select_all' );
		}

		for my $w ( @work_stack ) {
			print "Exporting [ $w->[1] ] ";
			$self->center_export_first_file( $w->[1] );
			$self->click_to( 'delete_object' );
			my ( $name, $dir, $suffix ) = $self->file_parse( $w->[1] );
			$self->aref_to_csv( [ 1, $project_config->{out_path}, "$name$suffix" ], $csv_path );
		}
	}
	$self->play_end_sound();
	print "$/It is done. Move on.";
}

1;
