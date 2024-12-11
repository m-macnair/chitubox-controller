#!/usr/bin/perl
# ABSTRACT: Class for the db used to determine, arrange and automate supports for files
our $VERSION = 'v1.0.2';

##~ DIGEST : 51d3f402c18f1c7a2e997e0d481544e7
use strict;
use warnings;

package Class::FolderAutomationDB;

use v5.10;
use Moo;
use Carp;
use parent 'Moo::Task::FileDB::Class::Standard::Linux';

sub get_numbered_name {
	my ( $self, $file_id ) = @_;
	my $original_file_row = $self->select_insert_href( 'original_file', {file_id => $file_id} );
	my ( $name, $dir, $suffix ) = $self->file_parse( $self->get_file_path_from_id( $file_id ) );
	if ( wantarray() ) {
		return ( "$original_file_row->{id} - $name", $suffix );
	}
	return "$original_file_row->{id} - $name";
}

sub get_all_path_from_file_id {
	my ( $self, $file_id ) = @_;
	$self->directory_db()->get_numbered_name( $file_id );

}

1;
