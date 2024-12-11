#!/usr/bin/perl
# ABSTRACT: wrapper role for common script operations
our $VERSION = 'v3.0.18';

##~ DIGEST : 244709099c982c4365530d81aba3b1fb
use strict;
use warnings;

package SlicerController::Role::FolderScript;

use v5.10;
use Moo::Role;

use Carp;

ACCESSORS: {

	has project_config => (
		is   => 'rw',
		lazy => 1,
	);
	has automation_paths => (
		is      => 'rw',
		lazy    => 1,
		default => sub { return {} },
	);

	has directory_db => (
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
	$self->{suite_root} = $self->abs_path( $value || "$ENV{HOME}/chitubox-controller/" );
	mkdir( $self->{suite_root} ) unless -d $self->{suite_root};
	return $self->{suite_root};
}

sub set_asset_project_config {
	my ( $self, $config_path ) = @_;
	$self->project_config( $self->get_asset_project_config( $config_path ) );

}

sub get_asset_project_config {
	my ( $self, $config_path ) = @_;
	$config_path ||= './current_automation_project/config.perl';

	die "Config [$config_path] not supplied" unless -f $config_path || -l $config_path;
	my $project_config = $self->config_file( $config_path );
	for my $key (
		qw/root_path
		source_wanted_path
		chitubox_part_path
		/
	  )
	{
		die "required key $key missing" unless ( $project_config->{$key} );
	}

	return $project_config;
}

sub script_setup {
	my ( $self, $p ) = @_;
	$p ||= {};

	$self->_setup();
	$self->_do_db();

}

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

sub script_single_or_file {
	my ( $self, $path ) = @_;

}

sub setup_directory_db {
	my ( $self, $db_file, $chitubox_controller_root ) = @_;
	die "cannot determine chitubox_controller_root value" unless $chitubox_controller_root;
	use Class::FolderAutomationDB;
	unless ( -f $db_file ) {
		open my $fh, '>', $db_file or die "Cannot create file: $!";
		close $fh;
	}
	my $ddb = Class::FolderAutomationDB->new(
		{
			sqlite_path => $db_file,
		}
	);

	$ddb->sqlite3_file_to_dbh( $db_file );

	unless ( $ddb->table_exists( 'file' ) ) {
		$ddb->execute_file( "$chitubox_controller_root/foreign/Moo-Task-FileDB/etc/db/core.sql" );
	}

	for my $table_name (
		qw/
		original_file
		wanted_file
		source_to_part

		/
	  )
	{
		unless ( $ddb->table_exists( $table_name ) ) {
			$ddb->execute_file( "$chitubox_controller_root/etc/db/automation_sub_db/$table_name.sql" );
		}
	}
	return $ddb;
}

sub load_automation_paths {
	my ( $self, $target_directory ) = @_;
	$target_directory ||= $self->project_config()->{root_path};
	die "target directory not set" unless $target_directory;
	$target_directory = $self->abs_path( $target_directory );
	my $ap = $self->automation_paths();
	$ap->{master_folder} = "$target_directory/production_automation";
	$ap->{sources_path}  = "$ap->{master_folder}/source";
	$ap->{chitubox_path} = "$ap->{master_folder}/chitubox";
	$ap->{master_folder} =~ s|//|/|g;
	$ap->{sources_path}  =~ s|//|/|g;
	$ap->{chitubox_path} =~ s|//|/|g;

	( undef, $ap->{target_directory_parent} ) = $self->file_parse( $target_directory );
	$self->automation_paths( $ap );
	$self->init_automation_paths();
	$self->load_ddb();
	return $ap;

}

sub set_relative_path {
	my ( $self, $script_path ) = @_;
	my ( undef, $dir )         = $self->file_parse( $script_path );
	my $ap = $self->automation_paths();
	$ap->{chitubox_controller_root} = "$dir/../../";
}

sub load_ddb {
	my ( $self ) = @_;
	my $ap       = $self->automation_paths();
	my $ddb      = $self->setup_directory_db( "$ap->{master_folder}/files.db", $ap->{chitubox_controller_root} );
	$self->directory_db( $ddb );

}

sub init_automation_paths {
	my ( $self ) = @_;
	my $ap = $self->automation_paths();

	unless ( -d $ap->{master_folder} ) {
		mkdir( $ap->{master_folder} );
	}

	unless ( -d $ap->{master_folder} ) {
		mkdir( $ap->{master_folder} );
	}

	SOURCES: {
		unless ( -d $ap->{sources_path} ) {
			mkdir( $ap->{sources_path} );
			$self->make_dirs(
				$ap->{sources_path},
				[
					qw/
					  all
					  wanted
					  to_modify
					  modified
					  /
				]
			);
		}
	}
	CHITUBOX: {
		unless ( -d $ap->{chitubox_path} ) {
			mkdir( $ap->{chitubox_path} );
			$self->make_dirs(
				$ap->{chitubox_path},
				[
					qw/
					  parts
					  plates
					  backups
					  /
				]
			);
		}
	}
}
1;
