#!/usr/bin/perl
# ABSTRACT: Methods for exclusively manipulating the DB
our $VERSION = 'v3.0.20';

##~ DIGEST : faae87e8a2994a7bb029d92c1c558cf4
use strict;
use warnings;

package SlicerController::Role::ManufacturingDB;
use v5.10;
use Moo::Role;
use Carp;
use Data::Dumper;

with qw/
  Moo::Task::FileDB::Role::Core
  Moo::Task::FileDB::Role::Linux

  Moo::Task::FileDB::Role::DB::AbstractSQLite
  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::ConfigAny

  Moo::GenericRole::DB
  Moo::GenericRole::DB::Abstract
  Moo::GenericRole::DB::SQLite

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
				warn( 'DB Initialisation no longer valid' );

				# 				unless ( -d './db/' ) { mkdir( './db/' ); }
				# 				open( my $fh, ">", $db_path );
				# 				print $fh '';
				# 				close( $fh );
				# 				$self->sqlite3_file_to_dbh( $db_path );
				# 				$self->init_db_schema();
				# 				die "obsolete db schema about to be used";
				#
				# 				for my $st ( split( /;/, $sql ) ) {
				# 					$self->dbh->do( $st ) or die $!;
				# 				}
			}
			return 1;

		}

		$self->sqlite3_file_to_dbh( $db_path );
	}
}

sub import_file_id_to_work_order {
	my ( $self, $file_id, $work_order_id, $p ) = @_;
	$p ||= {};
	$self->insert(
		'work_order_element',
		{
			file_id       => $file_id,
			work_order_id => $work_order_id,
			sequence_id   => $p->{sequence_id}
		}
	);
}

sub get_work_order_id {
	my ( $self, $string ) = @_;
	die "yes";
	Carp::confess( 'String not provided' ) unless $string;
	my $row = $self->select( 'work_orders', {name => $string} )->fetchrow_hashref();
	Carp::Confess( 'Work Order row not found' ) unless $row;
	return $row->{id};

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

sub get_outstanding_files_for_work_order {
	my ( $self, $work_order_id, $margin, $max_area ) = @_;
	$margin ||= 2;
	my $sql_string = "
		SELECT 
			woe.id as woe_id,
			f.id as file_id,
			round(fd.x_dimension + $margin,2) as  x_dimension,
			round(fd.y_dimension + $margin,2) as  y_dimension,
			round(max(fd.x_dimension + $margin , fd.y_dimension + $margin),2) as longest_edge,
			round(min(fd.x_dimension + $margin , fd.y_dimension + $margin),2) as shortest_edge,
			fd.x_dimension + fd.y_dimension as area
		FROM file f 
		JOIN file_dimensions fd
			on f.id = fd.file_id
		JOIN work_order_element woe 
			on f.id = woe.file_id 
		WHERE
			woe.plate_id IS NULL
			/*SQLite + DBI oddity*/
			AND woe.work_order_id = ?
			AND fd.x_dimension > 0
			AND fd.y_dimension > 0
	";

	$sql_string .= " AND area < $max_area $/" if $max_area;
	$sql_string .= "ORDER BY area desc";
	my $get_files_sth = $self->dbh->prepare( $sql_string ) or die $!;
	$get_files_sth->execute( $work_order_id );
	my @return;
	while ( my $row = $get_files_sth->fetchrow_hashref() ) {
		push( @return, $row );
	}
	return \@return;
}

sub get_count_of_remaining_work_order_files {
	my ( $self, $work_order_id, $margin ) = @_;
	my $check_sth = $self->dbh->prepare( '
		select count(f.id) as remaining
		from file f 
		join file_dimensions fd
			on f.id = fd.file_id
		join work_order_element woe 
			on f.id = woe.file_id 
		where 
			woe.plate_id is null
			and woe.work_order_id = ?
		limit 1;
	' );
	$check_sth->execute( $work_order_id );
	return $check_sth->fetchrow_arrayref()->[0];
}

1;
