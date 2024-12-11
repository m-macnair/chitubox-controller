#!/usr/bin/perl
# ABSTRACT: add standard folders to a directory, create soft links for stls to original_files, and soft link everything inside into soft_links
our $VERSION = 'v1.0.2';

##~ DIGEST : 341bc66c5afcc0fe0f06bc8ec2d89afc

use strict;
use warnings;

package Obj;
use Moo;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
use List::Util qw(any);
use Data::Dumper;

sub process {
	my ( $self, $path ) = @_;
	$path = $self->abs_path( $path );

	#the strings are used next but the directories should be created after the file::find
	my $master_folder = "$path/production_automation";
	my $sources_path  = "$master_folder/source";
	my $chitubox_path = "$master_folder/chitubox";

	#make softlinks in the production_automation directory for each useful file
	my ( undef, $path_parent ) = $self->file_parse( $path );
	my $parent_stack = '../../../';
	my @links;

	#get lists of all potentially linked files
	$self->sub_on_find_files(
		sub {
			my ( $full_path ) = @_;
			return 1 unless -f $full_path;
			my $partial_path = $full_path;
			$partial_path =~ s|$path_parent||;
			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );

			# 			print "processing [$full_path]$/";
			#softlink raw asset files to be processed
			if ( any { $_ eq lc( $suffix ) } qw/ .stl .obj / ) {
				my $new_path = $self->get_safe_path( "$sources_path/all/$name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
				$new_path = $self->get_safe_path( "$sources_path/wanted/$name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			}

			#softlink parts that probably have supports
			if ( lc( $suffix ) eq '.chitubox' ) {
				print "[$full_path] to chitubox$/";
				my $new_path = $self->get_safe_path( "$chitubox_path/parts/$name$suffix" );
				push( @links, [ "$parent_stack$partial_path", $new_path ] );
			}
			return 1;
		},
		$path
	);

	#Actually move things now because file::find can feasibly go into an infinite loop otherwise
	MAKEDIRS: {
		mkdir( $master_folder );
		mkdir( $sources_path );
		mkdir( $chitubox_path );
		$self->make_dirs(
			$sources_path,
			[
				qw/
				  all
				  wanted
				  to_modify
				  modified
				  /
			]
		);

		$self->make_dirs(
			$chitubox_path,
			[
				qw/
				  parts
				  plates
				  backups
				  /
			]
		);
	}

	for my $pair ( @links ) {
		symlink( $pair->[0], $pair->[1] );
	}

	#Create a configuration file in the automation directory with hard links to all relevant paths, then softlink it to the current_automation_project directory in the chitubox controller directory
	my $project_config = "$master_folder/config.perl";
	unless ( -e $project_config ) {
		my $def = {
			source_wanted_path   => "$sources_path/wanted",
			chitubox_part_path   => "$chitubox_path/parts",
			chitubox_backup_path => "$chitubox_path/backups",
		};
		my $string = Dumper( $def );
		$string =~ s/^(?:.*\n)/return {\n/;
		open( my $of, '>', $project_config ) or die $!;
		print $of $string;
		close( $of );
	}

	#this will probably break if not called from the chitubox-controller working directory
	use Cwd;
	my $project_path = Cwd::abs_path() . '/current_automation_project';

	my $config_link_path = "$project_path/project_config.perl";
	if ( -e $config_link_path ) {
		unlink( $config_link_path );
	}
	`ln -s "$project_config" "$config_link_path" `;

}
1;

package main;

main( @ARGV );

sub main {
	my $self = Obj->new();
	my $path = join( ' ', @_ );
	die "path not provided" unless $path;
	print "$/processing [$path]$/";
	die "path invalid" unless -d $path;
	$self->process( $path );

}
