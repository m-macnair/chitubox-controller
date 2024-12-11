#!/usr/bin/perl
# ABSTRACT: add standard folders to a directory, create soft links for stls to original_files, and soft link everything inside into soft_links
our $VERSION = 'v1.0.4';

##~ DIGEST : b93e8abf862b519445e33fcac7b4aa6d

use strict;
use warnings;

package Obj;
use Moo;
use parent 'SlicerController::Class::FolderScript';
use List::Util qw(any);
use Data::Dumper;

sub process {
	my ( $self, $target_directory ) = @_;

	$self->set_relative_path( __FILE__ );
	my $ap  = $self->load_automation_paths( $target_directory );
	my $ddb = $self->directory_db();

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
			my $file_id = $ddb->get_file_id( $full_path );

			#TODO replace with get_numbered_name() from helper some time
			my $original_file_row = $ddb->select_insert_href( 'original_file', {file_id => $file_id} );
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );

			my $partial_path = $full_path;
			$partial_path =~ s|$ap->{target_directory_parent}||;
			if ( lc( $suffix ) eq '.chitubox' ) {
				push( @links, [ $full_path, "$ap->{chitubox_path}/parts/$name$suffix" ] );

				my $new_path = $self->get_safe_path( "$ap->{chitubox_path}/parts/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			} else {
				my $new_path = $self->get_safe_path( "$ap->{sources_path}/all/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
				$new_path = $self->get_safe_path( "$ap->{sources_path}/wanted/$original_file_row->{id} - $name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			}
			print "Processed $full_path [$file_id]$/";
		}

		for my $pair ( @links ) {
			symlink( $pair->[0], $pair->[1] );
		}
	}

	#Create a configuration file in the automation directory with hard links to all relevant paths, then softlink it to the current_automation_project directory in the chitubox controller directory
	my $project_config = "$ap->{master_folder}/config.perl";
	INITPROJECTCONFIG: {
		unless ( -e $project_config ) {
			my $def = {
				root_path            => $self->abs_path( "$ap->{master_folder}/../" ),
				source_wanted_path   => "$ap->{sources_path}/wanted",
				chitubox_part_path   => "$ap->{chitubox_path}/parts",
				chitubox_backup_path => "$ap->{chitubox_path}/backups",
			};
			my $string = Dumper( $def );
			$string =~ s/^(?:.*\n)/return {\n/;
			open( my $of, '>', $project_config ) or die $!;
			print $of $string;
			close( $of );
		}
	}
	my $current_config = $self->suite_root() . '/current_config.pl';
	warn $current_config;
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
