#!/usr/bin/perl
# ABSTRACT: perform DB cleanup operations before doing anything time consuming on unwanted files
use strict;
use warnings;

our $VERSION = 'v1.0.6';

##~ DIGEST : 2a33e837707555479c7f051131e92943

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
	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();

	#Deleting something in the work order table should now cascade into the work order elements
	$self->query( '
		DELETE FROM work_order_element
		WHERE work_order_id NOT IN (
			SELECT id FROM work_order
		);
	' );

	# work orders with no elements are useless - work order entry is generated at point of woe loading
	$self->query( '
		DELETE FROM work_order
		WHERE id NOT IN (
			SELECT work_order_id FROM work_order_element
		);
	' );

	#Need to make file type marking more consistent before this is safe
	# files without a work order entry are fluff and at this point from workflows so old that any associated dimensions are unreliable
	# 	$self->query('
	# 		DELETE FROM file
	# 		WHERE id NOT IN (
	# 			SELECT file_id FROM work_order_element
	# 		)
	# 		and type eq ;
	# 	');
	#
	# 	#a file that has no dimensions and no work order is of no use
	# 	$self->query('
	# 		DELETE FROM file
	# 		WHERE id in (
	# 			SELECT f.id
	# 			FROM file f
	# 			LEFT JOIN file_dimensions fd ON f.id = fd.file_id
	# 			LEFT JOIN work_order_element woe ON f.id = woe.file_id
	# 			WHERE fd.file_id IS NULL
	# 			AND woe.file_id IS NULL
	# 		)
	# 	');

	# A directory that's not referenced in a file serves no purpose
	$self->query( '
		DELETE FROM dir
		WHERE id NOT IN (
			SELECT dir_id FROM file
		);
	' );

	#remove orphaned dimensions
	$self->query( '
		DELETE FROM file_dimensions
		WHERE file_id NOT IN (
			SELECT id FROM file
		);
	' );

}
1;
