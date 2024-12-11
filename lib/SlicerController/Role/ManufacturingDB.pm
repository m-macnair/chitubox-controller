#!/usr/bin/perl
# ABSTRACT: DB Setup and import methods
our $VERSION = 'v3.0.17';

##~ DIGEST : 5995a888c32c7f19dc9a04b10145768b
use strict;
use warnings;

package SlicerController::Role::DB;
use v5.10;
use Moo::Role;
use Carp;
use Data::Dumper;

with qw/
  Moo::Task::FileDB::Role::Core
  Moo::Task::FileDB::Role::Linux
  Moo::GenericRole::DB::Working::AbstractSQLite
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

sub import_work_list {
	my ( $self, $p ) = @_;
	$self->_do_db( $p );
	my $stack = $self->get_file_list( $p->{csv_file} );
	my $work_order_name;
	if ( $p->{work_order_name} ) {
		$work_order_name = $p->{work_order_name};
	} else {
		$work_order_name = "default";
		warn( "no work_order id provided for import_work_list; set to [$work_order_name]" );
	}

	my $work_order_row = $self->select_insert_href( 'work_order', {name => $work_order_name}, [qw/* id/] );

	for my $work_order_row_href ( @{$stack} ) {
		print "processing $work_order_row_href->{path}$/";
		my $file_id = $self->get_file_id( $work_order_row_href->{path} );
		while ( $work_order_row_href->{count} > 0 ) {
			$self->import_file_id_to_work_order( $file_id, $work_order_row->{id} );
			$work_order_row_href->{count}--;
		}
	}
}

sub import_file_id_to_work_order {
	my ( $self, $file_id, $work_order_id, $p ) = @_;

	$self->insert(
		'work_order_element',
		{
			file_id       => $file_id,
			work_order_id => $work_order_id
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

1;
