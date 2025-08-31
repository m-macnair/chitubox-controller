#!/usr/bin/perl
# ABSTRACT: soft link work order element files into the wanted_parts directory, avoiding duplicates
use strict;
use warnings;
use File::Spec;

our $VERSION = 'v1.0.8';

##~ DIGEST : 81b1c811f99c436a5ba20ce1609c3a73

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
  Moo::GenericRole::FileSystem
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

	my $get_sth = $self->dbh->prepare( "
		SELECT 
			woe.id as woe_id, 
			f.id as file_id , 
			woe.sequence_id as sequence_id , 
			woe.work_order_id as wo_id

		FROM work_order_element woe 
		JOIN file f ON woe.file_id = f.id
		JOIN work_order wo on woe.work_order_id = wo.id
		WHERE element_softlink_id IS NULL
		AND wo.name = ?
	" );

	$get_sth->execute( $work_order_string );
	my $wp = $self->config()->{folders}->{'wanted_parts'};
	while ( my $row = $get_sth->fetchrow_hashref() ) {
		my $source_path = $self->get_file_path_from_id( $row->{file_id} );
		my ( $name, $dir, $suffix ) = $self->file_parse( $source_path );
		my $new_name = "$wp/" . sprintf( '[W-%04d]_%s', $row->{sequence_id}, "$name$suffix" );

		if ( -e $new_name ) {
			$self->Log( "Not creating [$new_name], already present" );
		} else {
			$self->Log( "Softllinking [$new_name]" );
			symlink( $source_path, $new_name ) or die $!;
			my $abs_soft_link = File::Spec->rel2abs( $new_name );
			my $file_id       = $self->get_file_id( $abs_soft_link );
			$self->Log( "Softlink for  [$new_name] given id [$file_id]" );
			$self->update( 'work_order_element', {element_softlink_id => $file_id}, {id => $row->{woe_id}} );
		}
	}
}
1;
