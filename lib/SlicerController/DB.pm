#!/usr/bin/perl
# ABSTRACT: DB Setup and import methods
our $VERSION = 'v3.0.12';

##~ DIGEST : 223dc522a5b9b2c56deaf7fba474e954
use strict;
use warnings;

package SlicerController::DB;
use v5.10;
use Moo::Role;
use Carp;
use Data::Dumper;

with qw/
  Moo::Task::FileDB::Role::Core
  Moo::Task::FileDB::Role::Linux
  Moo::GenericRole::DB::Working::AbstractSQLite
  Moo::Task::FileDB::Role::DB::SQLite::Setup
  Moo::Task::FileDB::Role::DB::AbstractSQLite

  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::ConfigAny
  /; # AbstractSQLite is a wrapper class for all dbi actions

sub _do_db {
	my ( $self, $res ) = @_;
	$res ||= {};
	if ( $res->{db_file} ) {
		$self->sqlite3_file_to_dbh( $res->{db_file} );
	} else {
		my $db_path = './db/working_db.sqlite';

		unless ( -e $db_path ) {

			DBSETUP: {
				unless ( -d './db/' ) { mkdir( './db/' ); }
				open( my $fh, ">", $db_path );
				print $fh '';
				close( $fh );
				$self->sqlite3_file_to_dbh( $db_path );
				$self->init_db_schema();

				my $sql = <<'SQL';
	
	CREATE TABLE projects (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL UNIQUE
	);
	
	CREATE TABLE plates (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		machine TEXT NOT NULL
	);

	CREATE TABLE project_elements (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		project_id INTEGER,
		file_id INTEGER,
		plate_id INTEGER,
		x_position REAL,
		y_position REAL,
		rotate REAL
	);
	CREATE INDEX project_elements_plate_id ON project_elements(plate_id); 
	CREATE INDEX project_elements_project_name ON project_elements(project_id); 
	
	CREATE TABLE file_dimensions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_id INTEGER,
		x_dimension REAL,
		y_dimension REAL,
		z_dimension REAL
	);
	CREATE INDEX file_dimensions_file_id ON file_dimensions(file_id); 
SQL
				for my $st ( split( /;/, $sql ) ) {
					$self->dbh->do( $st ) or die $!;
				}
			}
			return 1;

		}

		$self->sqlite3_file_to_dbh( $db_path );
	}
}

sub import_work_list {
	my ( $self, $p ) = @_;
	$self->_do_db( $p );
	my $stack = $self->get_file_list( $p->{csv_file} );
	my $project_name;
	if ( $p->{project_name} ) {
		$project_name = $p->{project_name};
	} else {
		$project_name = "default";
		warn( "no project id provided for import_work_list; set to [$project_name]" );
	}

	my $project_row = $self->select_insert_href( 'projects', {name => $project_name}, [qw/* rowid/] );

	for my $project_row_href ( @{$stack} ) {
		print "processing $project_row_href->{path}$/";
		my $file_id = $self->get_file_id( $project_row_href->{path} );
		while ( $project_row_href->{count} > 0 ) {
			$self->insert(
				'project_elements',
				{
					file_id    => $file_id,
					project_id => $project_row->{rowid}
				}
			);
			$project_row_href->{count}--;
		}

	}
}

sub get_project_id {
	my ( $self, $string ) = @_;
	Carp::Confess( 'String not provided' ) unless $string;
	my $project_row = $self->select( 'projects', {name => $string} )->fetchrow_hashref();
	Carp::Confess( 'Project row not found' ) unless $project_row;
	return $project_row->{id};

}

#turn csv file into <number> <filepath>
sub get_file_list {
	my ( $self, $csv_file ) = @_;
	my @stack;
	$self->sub_on_csv(
		sub {
			my ( $row ) = @_;
			my ( $x, $y, $z ) = @{$row};

			return 1 unless ( $x );
			my $file_path;
			if ( -d $y ) {
				$file_path = "$y/$z";
			} else {
				$file_path = $y;
			}
			$file_path =~ s|//|/|g;
			$file_path =~ s/\s+$//g;
			chomp( $file_path );
			if ( -e $file_path ) {
				push( @stack, {count => $x, path => $file_path} );

			} else {
				my $alt = $file_path;
				$alt =~ s| |\ |g;
				if ( -e $alt ) {
					warn "spaces problem on [$alt]";
					push( @stack, {count => $x, path => $file_path} );
				} else {

					warn( "[$file_path] not found" );

					#why is this here?
					$self->dynamic_sleep();
				}
			}
			return 1;
		},
		$csv_file
	);
	return \@stack;

}

1;
