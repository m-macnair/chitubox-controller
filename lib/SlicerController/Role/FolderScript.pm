#!/usr/bin/perl
# ABSTRACT: wrapper role for common script operations
our $VERSION = 'v3.0.22';

##~ DIGEST : 4b707bb597c51d3afb325c0ede23d875
use strict;
use warnings;

package SlicerController::Role::FolderScript;

use v5.10;
use Moo::Role;
with qw/
  Moo::GenericRole::LogAnyAdapter
  /;

use Carp qw/confess/;
use SlicerController::Class::FolderAutomationDB;
ACCESSORS: {

	has folder_config => (
		is      => 'rw',
		lazy    => 1,
		default => sub { return {} },
	);

	has fdb => (
		is   => 'rw',
		lazy => 1,
	);
	has suite_root => (
		is      => 'rw',
		lazy    => 1,
		default => sub {
			my $self = shift;
			$self->setup_suite_root();
		},
	);
}

sub setup_suite_root {
	my ( $self, $value ) = @_;

	$self->{suite_root} = $self->abs_path( $value || "$ENV{HOME}/git/chitubox-controller/" );
	mkdir( $self->{suite_root} ) unless -d $self->{suite_root};
	return $self->{suite_root};
}

sub load_folder_config {
	my ( $self, $config_path ) = @_;
	$self->folder_config( $self->get_asset_folder_config( $config_path ) );

	#... how did this work before
	$self->config( {%{$self->config()}, %{$self->folder_config()}} );
	$self->Log( $self->config(), {file_only => 1} );
}

sub get_asset_folder_config {
	my ( $self, $config_path ) = @_;
	$config_path ||= $self->abs_path( $self->suite_root() . '/config/config.perl' );

	die "Config [$config_path] not found" unless $self->is_a_file( $config_path );
	my $folder_config = $self->config_file( $config_path );
	for my $key (
		qw/
		root_path
		chitubox_controller_root
		/
	  )
	{
		die "required key $key missing" unless ( $folder_config->{$key} );
	}
	for my $key (
		qw/

		all wanted modify modified parts plates backups
		/
	  )
	{
		die "required configured folder [$key] missing" unless ( $folder_config->{folders}->{$key} );
	}

	return $folder_config;
}

sub script_setup {
	my ( $self, $p ) = @_;
	$p ||= {};
	$self->load_folder_config();
	$self->load_fdb();

}

#TODO: generic?
sub single_or_file {
	my ( $self, $path ) = @_;

	if ( $self->is_a_file( $path ) ) {
		$self->process_file( $path );
	} else {
		$self->sub_on_find_files(
			sub {
				my ( $full_path ) = @_;
				$self->process_file( $full_path );
			},
			$path
		);
	}
}

sub setup_fdb {
	my ( $self, $db_file, $chitubox_controller_root ) = @_;
	confess "cannot determine chitubox_controller_root value" unless $chitubox_controller_root;

	unless ( -f $db_file ) {
		open my $fh, '>', $db_file or confess "Cannot create db file [$db_file]: $!";
		close $fh;
	}
	my $fdb = Class::FolderAutomationDB->new(
		{
			sqlite_path => $db_file,
		}
	);

	$fdb->sqlite3_file_to_dbh( $db_file );

	unless ( $fdb->table_exists( 'file' ) ) {
		$fdb->execute_file( "$chitubox_controller_root/foreign/Moo-Task-FileDB/etc/db/core.sql" );
	}

	for my $table_name (
		qw/
		original_file
		wanted_file
		source_to_part
		original_as_part
		/
	  )
	{
		unless ( $fdb->table_exists( $table_name ) ) {
			$fdb->execute_file( "$chitubox_controller_root/etc/db/automation_sub_db/$table_name.sql" );
		}
	}
	return $fdb;
}

#this should only ever be done once in script/1/1 and read from config thereafter
sub generate_folder_config {
	my ( $self, $target_directory ) = @_;
	$target_directory ||= $self->folder_config()->{root_path};
	die "target directory not set" unless $target_directory;
	$target_directory = $self->abs_path( $target_directory );
	my $fc = $self->folder_config();
	$fc->{master_folder} = "$target_directory/production_automation";
	$fc->{master_folder} =~ s|//|/|g;

	( undef, $fc->{target_directory_parent} ) = $self->file_parse( $target_directory );
	$self->folder_config( $fc );
	return $self->folder_config();

}

sub load_fdb {
	my ( $self ) = @_;
	my $fc       = $self->folder_config();
	my $fdb      = $self->setup_fdb( "$fc->{master_folder}/files.db", $fc->{chitubox_controller_root} );
	return $self->fdb( $fdb );

}

sub init_folder_config {
	my ( $self ) = @_;
	my $fc = $self->folder_config();
	unless ( -d $fc->{master_folder} ) {
		mkdir( $fc->{master_folder} );
	}
	my $counter = 1;
	for my $folder (
		qw/
		all
		wanted
		modify
		modified
		parts
		wanted_parts
		plates
		backups
		/
	  )
	{

		$self->make_dirs( $fc->{master_folder}, ["$counter\_$folder"] );
		$fc->{folders}->{$folder} = "$fc->{master_folder}/$counter\_$folder";
		$counter++;
	}

}
1;
