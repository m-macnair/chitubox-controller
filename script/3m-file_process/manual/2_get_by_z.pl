#!/usr/bin/perl
# ABSTRACT: return the current project's .chitubox files in ascending order of Z dimension
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v1.0.7';

##~ DIGEST : 7736689884370f61d12e8f8d5104f5ae

BEGIN {
	push( @INC, './lib/' );
}

package Obj;

use Moo;
use parent qw/

  SlicerController
  /;

with qw/
  SlicerController::Role::FolderScript

  /;

1;

package main;
main( @ARGV );

sub main {
	my ( $work_order_string, $desc ) = @_;
	die "No work order string provided" unless $work_order_string;
	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();

	my $order_by = 'ASC';
	$order_by = 'DESC' if $desc;

	my $z_sth = $self->dbh->prepare( "
		SELECT DISTINCT f.id AS file_id
		FROM work_order wo
		JOIN work_order_element woe ON wo.id = woe.work_order_id
		JOIN file f ON woe.file_id = f.id
		JOIN file_dimensions fd ON f.id = fd.file_id
		JOIN file_type ft ON f.file_type_id = ft.id
		WHERE wo.name = ?
		ORDER BY fd.z_dimension $order_by
	" );

	$z_sth->execute( $work_order_string );
	my @group;
	my $counter = 1;
	while ( my $row = $z_sth->fetchrow_hashref() ) {

		# 		warn Dumper($row);
		my $file_path = $self->get_file_path_from_id( $row->{file_id} );
		$file_path =~ s|5_parts|5_wanted_parts|;
		if ( -e $file_path ) {
			push( @group, qq{"$file_path"} );
		}
		if ( scalar( @group ) > 9 ) {
			print "#$counter$/$/";
			$counter++;
			print join( ',', @group ), $/, $/;
			@group = ();
		}

	}

}
1;
