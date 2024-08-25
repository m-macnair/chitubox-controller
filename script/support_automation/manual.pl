#!/usr/bin/perl
# ABSTRACT:
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v0.0.4';

BEGIN {
	push( @INC, "../lib/" );
}

##~ DIGEST : 3a378e0edc3d21db72770f85960bc561

use strict;
use warnings;

package Obj;
use Moo;
use parent qw/

  SlicerController
  /;

with qw/

  Moo::GenericRole::ConfigAny

  /;

1;

package main;
main( @ARGV );

sub main {
	my $self = Obj->new();
	$self->_setup();

	my ( $path ) = @_;

	my $project_config = $self->config_file( $path );
	$self->ControlByGui_x_offset( 4014 );
	$self->ControlByGui_coordinate_map->{console} = [ 2794, 1916 ];

	$self->sub_on_directory_files(
		sub {
			my ( $path ) = @_;
			my ( $name, $dir, $suffix ) = $self->file_parse( $path );
			print "analysing [$path]$/";
			my $out = "$project_config->{out_path}/$name.chitubox";

			if ( -f $out ) {
				print "\t[$out] exists $/";
				return 1;
			}
			my $in = $path;
			process( $self, $in, $out );
		},
		$project_config->{in_path}
	);
	print "$/It is done. Move on.";
}

sub process {
	my ( $self, $in, $out ) = @_;
	$self->clear_for_project();
	unless ( $in ) {

	} else {
		print "\tworking on file [$in]$/";
	}
	$self->open_file( $in );
	print "$/\tPress [X] to rotate and support on x axis, [Y] on y axis, [C] to rotate to a corner, [S] to support and export,  or  enter once placed manually$/\tWill write to [ $out ] after keypress : ";
	$self->click_to( 'console', {no_offset => 1} );
	my $res = <STDIN>;
	chomp( $res );
	if ( lc( $res ) eq 'x' ) {
		$self->click_to( 'mirror_button' );
		$self->rotate_file_x();
		$self->auto_supports();
	}
	if ( lc( $res ) eq 'y' ) {
		$self->click_to( 'mirror_button' );
		$self->rotate_file_y();

		$self->auto_supports();
	}

	if ( lc( $res ) eq 'c' ) {
		$self->click_to( 'mirror_button' );
		$self->rotate_file_corner();
		$self->auto_supports();
	}

	if ( lc( $res ) eq 's' ) {
		$self->click_to( 'mirror_button' );
		$self->auto_supports();
	}

	$self->click_to( 'mirror_button' );
	$self->click_to( 'move_button' );
	$self->click_to( 'center' );
	$self->click_to( 'move_button' );

	$self->export_file_single( $out );
	$self->click_to( 'console', {no_offset => 1} );

}

1;
