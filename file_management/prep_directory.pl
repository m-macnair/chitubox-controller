#!/usr/bin/perl
# ABSTRACT: add standard folders to a directory, move all stls to original_files, and soft link everything inside into soft_links
our $VERSION = 'v0.0.7';

##~ DIGEST : 6b19a4bda090e7a9ef15bf753534c471

use strict;
use warnings;

package Obj;
use Moo;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
use List::Util qw(any);

sub process {
	my ( $self, $path ) = @_;
	$path = $self->abs_path( $path );
	my $work_path = "/home/m/Hobby/Hobby-Code/chitubox-controller/";
	for my $folder (
		qw/
		original_files
		wanted_soft_links
		chitubox
		pending_modification
		modified
		/
	  )
	{
		my $new = "$path/$folder";

		unless ( -d $new ) {
			mkdir( $new ) or die $!;
		}
	}

	$self->sub_on_directory_files(
		sub {
			my ( $full_path ) = @_;

			return 1 unless -f $full_path;

			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
			if ( any { $suffix } qw/ .stl .obj / ) {
				my $new_path = $self->safe_mvf( $full_path, "$path/original_files" );
				symlink( "../original_files/$name$suffix", "$path/wanted_soft_links/$name$suffix" );
			}
			return 1;
		},
		$path
	);
	use Data::Dumper;
	unless ( -e "$path/config.perl" ) {
		my $def = {
			in_path  => "$path/wanted_soft_links",
			out_path => "$path/chitubox"
		};
		my $string = Dumper( $def );
		$string =~ s/^(?:.*\n)/return {\n/;
		open( my $of, '>', "$path/config.perl" ) or die $!;
		print $of $string;
		close( $of );
	}
	my $link_path = "$work_path/bulk_config.perl";
	if ( -e $link_path ) {
		unlink( $link_path );
	}
	`ln -s "$path/config.perl" "$link_path" `;

}
1;

package main;

main( @ARGV );

sub main {
	my $self = Obj->new();
	@_;
	my $path = join( ' ', @_ );
	die "path not provided" unless $path;
	print "$/processing [$path]$/";
	$self->process( $path );

}

#
#
# 	$self->sub_on_directory(
# 		sub {
# 			my ( $full_path ) = @_;
#
# 			my ( $name, $dir, $suffix ) = $self->file_parse( $full_path );
#
# 			#print "working on [$full_path]$/";
#
# 			$name =~ s/^\s+|\s+$//g;
# 			$name =~ s/^_//g;
# 			$name =~ s/_$//g;
# 			$name = lc( $name );
# 			$name =~ s| |_|g;
# 			$name = " $name";
#
# 			my $new_path = "$dir/$name$suffix";
# 			if ( -e $new_path ) {
# 				warn "existing file $new_path found, SKIPPING";
# 			} else {
# 				symlink( $full_path, $new_path );
# 			}
# 			return 1;
#
# 		},
# 		$path
# 	);
