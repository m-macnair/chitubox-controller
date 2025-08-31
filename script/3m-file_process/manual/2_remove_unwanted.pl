#!/usr/bin/perl
# ABSTRACT: return the current project's .chitubox files in ascending order of Z dimension
use strict;
use warnings;
use Data::Dumper;
our $VERSION = 'v1.0.7';

##~ DIGEST : d261a10be5cafb23b3d63b4c3e3c7f04

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
  Moo::GenericRole::FileIO
  /;

1;

package main;
main( @ARGV );

sub main {
	my ( $input_path ) = @_;
	$input_path ||= './script/3m-process_manual/unwanted.txt';
	my $self = Obj->new();
	$self->_setup();
	$self->script_setup();
	my @files;
	$self->sub_on_file_lines(
		sub {
			my ( $line ) = @_;

			my @these_files = split( ',', $line );
			@these_files = grep { defined $_ && $_ ne '' } @these_files;
			map { chomp; $_ } @these_files;
			push( @files, @these_files );
		},
		$input_path
	);

	for my $file ( @files ) {
		next unless $file;
		$file =~ s/"//g;
		$self->Log( "Unlinking [$file]" );
		if ( -e $file ) {
			unlink( $file ) or die $!;
		} else {
			$self->Log( "[$file] not found", {level => 'Alert'} );
		}

	}

}
1;
