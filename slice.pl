#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerController::import_work_list()
our $VERSION = 'v1.0.5';

##~ DIGEST : a21869977306dc34a5283bf0f2432c67

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerController;

package main;
main( @ARGV );

sub main {
	my $self = SlicerController->new();
	my ( $block_id ) = @_;
	die "Block id not provided" unless $block_id;
	$self->_do_db( {} );

	my $rows = $self->query(
		"select 
			f.file_path,
			f.x_dimension ,
			f.y_dimension, 
			p.x_position ,
			p.y_position,
			p.rotate,
			p.rowid
		from files f 
		join projects p 
			on f.rowid = p.file_id 
		where 
			 project_block  =?
		order by 

			p.y_position	ASC,
			p.x_position	ASC
			", $block_id
	);
	while ( my $row = $rows->fetchrow_hashref() ) {

		$self->adjust_sleep_for_file( $row->{file_path} );
	}

	$self->slice_and_save( lc( $block_id ) );
	$self->play_end_sound();
}
1;
