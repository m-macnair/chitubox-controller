#!/usr/bin/perl
use strict;
use warnings;
our $VERSION = 'v1.0.7';

##~ DIGEST : 74f23154e27738dd047bb629f5f9af61

use File::Find;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use List::Util;

my $start_dir = join( ' ', @ARGV );
die "start_dir not provied" unless -d $start_dir;
$start_dir = abs_path( $start_dir );

my $counter = 1;
my @stack;
find( \&wanted, $start_dir );

sub wanted {
	return unless -f $_;
	return unless /\.stl$/i;

	my $old_path = File::Spec->catfile( abs_path( $File::Find::dir ), $_ );
	push( @stack, $old_path );
}
my @pre_stamped;
my @moves;

for my $path ( sort( @stack ) ) {

	warn $path;
	if ( $path =~ m#.*/\[F-\d{4}\]_# ) {
		warn "Skipping [$path] : already stamped.$/";
		push( @pre_stamped, $1 );
		next;
	} else {
		push( @moves, $path );
	}
}

for my $path ( @moves ) {
	while ( List::Util::any { $_ == $counter } @pre_stamped ) {
		$counter++;
	}

	my ( $name, $dir, $suffix ) = fileparse( $path, qr/\.[^.]*/ );
	my $new_name = sprintf( '[S-%04d]_%s%s', $counter, $name, $suffix );
	my $new_path = File::Spec->catfile( $dir, $new_name );

	if ( -e $new_path ) {
		warn "Skipping: $new_path already exists.$/";
	} else {
		rename( $path, $new_path ) or warn "Failed to rename $path: $!$/";
		print "Renamed: $path -> $new_path$/";
		$counter++;
	}

}
