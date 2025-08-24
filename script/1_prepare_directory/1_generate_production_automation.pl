#!/usr/bin/perl
# ABSTRACT: add standard folders to a directory, create soft links for stls to original_files, and soft link everything inside into soft_links
our $VERSION = 'v1.0.5';

##~ DIGEST : 875bbbd62cba43d4bb24fca3b5352eb8

use strict;
use warnings;

package Obj;
use Moo;
use parent 'SlicerController::Class::FolderScript';
use List::Util qw(any);
use Data::Dumper;

sub process {
	my ( $self, $target_directory ) = @_;

	my $fc = $self->generate_folder_config( $target_directory );
	$self->init_folder_config();
	GETROOT: {
		my ( undef, $dir ) = $self->file_parse( __FILE__ );
		$fc->{chitubox_controller_root} = $self->abs_path( "$dir/../../" );
	}

	# 	die Dumper($fc);
	my $fdb = $self->load_fdb();

	#make softlinks in the production_automation directory for each useful file

	my @source_files;
	GETSOURCEFILES: {

		#get lists of all potentially linked files
		$self->sub_on_find_files(
			sub {
				my ( $full_path, $misc_path ) = @_;
				return 1 unless -f $full_path;
				if ( index( $misc_path, 'production_automation' ) != -1 ) {
					return 1;
				}
				my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
				if ( any { $_ eq lc( $suffix ) } qw/ .stl .obj .chitubox/ ) {
					push( @source_files, $full_path );
				}
				return 1;
			},
			$target_directory
		);
	}

	SETUPSOFTLINKS: {
		my @links;
		my $parent_stack = '../../../'; # relative path to the production_automation directory
		for my $full_path ( sort( @source_files ) ) {
			my $file_id = $fdb->get_file_id( $full_path );

			#TODO replace with get_numbered_name() from helper some time
			my $original_file_row = $fdb->select_insert_href( 'original_file', {file_id => $file_id} );
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );

			my $partial_path = $full_path;
			$partial_path =~ s|$fc->{target_directory_parent}||;
			if ( lc( $suffix ) eq '.chitubox' ) {
				push( @links, [ $full_path, "$fc->{production_path}/parts/$name$suffix" ] );

				my $new_path = $self->get_safe_path( "$fc->{production_path}/parts/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			} else {
				my $new_path = $self->get_safe_path( "$fc->{sources_path}/all/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
				$new_path = $self->get_safe_path( "$fc->{sources_path}/wanted/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			}
			print "Processed $full_path [$file_id]$/";
		}

		for my $pair ( @links ) {
			symlink( $pair->[0], $pair->[1] );
		}
	}

	#Create a configuration file in the automation directory with hard links to all relevant paths, then softlink it to the current_automation_project directory in the chitubox controller directory
	my $project_config = "$fc->{master_folder}/config.perl";
	INITPROJECTCONFIG: {
		unless ( -e $project_config ) {
			my $def = {
				master_folder            => $self->abs_path( $fc->{master_folder} ),
				root_path                => $self->abs_path( "$fc->{master_folder}/../" ),
				source_wanted_path       => "$fc->{sources_path}/wanted",
				production_part_path     => "$fc->{production_path}/parts",
				production_backup_path   => "$fc->{production_path}/backups",
				chitubox_controller_root => $self->abs_path( $fc->{chitubox_controller_root} )
			};
			my $string = Dumper( $def );
			$string =~ s/^(?:.*\n)/return {\n/;
			open( my $of, '>', $project_config ) or die $!;
			print $of $string;
			close( $of );
		}
	}
	my $current_config = $self->suite_root() . '/current_config.perl';
	unlink( $current_config ) if -e $current_config;
	symlink( $project_config, $current_config );
}

1;

package main;

main( @ARGV );

sub main {
	my $self             = Obj->new();
	my $target_directory = join( ' ', @_ );
	die "path not provided" unless $target_directory;
	print "$/processing [$target_directory]$/";
	die "path invalid" unless -d $target_directory;
	$self->process( $target_directory );
	$self->play_sound();

}
