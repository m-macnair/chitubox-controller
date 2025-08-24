#ABSTRACT: Use DBI::Abstract and SQLite for arbitrary working databases
package Moo::GenericRole::DB::Working::AbstractSQLite;
our $VERSION = 'v1.1.2';
##~ DIGEST : 0bdc4f6495a01f10d16761b5fb8c1e8e
use Try::Tiny;
use Moo::Role;
use Carp;
with qw/
  Moo::GenericRole
  Moo::GenericRole::DB
  Moo::GenericRole::DB::Abstract
  Moo::GenericRole::DB::SQLite
  /;

ACCESSORS: {
	has temp_db_path => (
		is   => 'rw',
		lazy => 1,
	);
}

sub copy_working_db {
	my ( $self, $source_db, $opt ) = @_;
	confess 'source_db not provided' unless $source_db && -f $source_db;
	$opt ||= {};
	my $temp_db_name = $opt->{temp_db_name} || 'temp.sqlite';
	my $temp_db_path = $self->tmp_dir() . $temp_db_name;
	require File::Copy;
	File::Copy::copy( $source_db, $temp_db_path ) or confess( "move failed: $!$/\t" );
	return $self->temp_db_path( $temp_db_path );
}

sub setup_working_db {
	my ( $self, $source_db, $opt ) = @_;
	$opt ||= {};
	my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $self->temp_db_path() );
	$self->dbh( $dbh );
}

sub setup_working_db_copy {
	my ( $self, $source_db, $opt ) = @_;
	$opt ||= {};
	$self->copy_working_db( $source_db, $opt );
	$self->setup_working_db( $source_db, $opt );

}
1;
