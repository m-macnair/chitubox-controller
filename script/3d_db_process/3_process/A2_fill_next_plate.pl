#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: run SlicerScript::import_work_list()
our $VERSION = 'v1.0.10';

##~ DIGEST : 014414ebd4dc127b281bf26a4933a7fa

BEGIN {
	push( @INC, "./lib/" );
}
use SlicerScript;

package main;
main( @ARGV );

sub main {
	my $self = SlicerScript->new();
	my ( $work_order_name ) = @_;
	die "Work Order name not provided" unless $work_order_name;
	$self->script_setup( {} );

	my $work_order_row = $self->select( 'work_order', [qw/* id/], {name => $work_order_name} )->fetchrow_hashref();
	die "Work order not found" unless $work_order_row->{name};

	my $sth = $self->query( '
		select wop.plate_id from work_order_plate wop
		left join plate_files pf 
			on wop.plate_id = pf.plate_id
		left join file f
			on pf.file_id = f.id
		where 
			wop.work_order_id = ?
		and
			pf.id is null
	', $work_order_row->{id} );
	my $plate_row = $sth->fetchrow_arrayref();

	if ( !$plate_row ) {
		print "No remaining plates found for work order [$work_order_row->{id}]$/";
	} else {
		$self->set_select_all_off;
		$self->clear_for_project();
		sleep( 1 );
		my $plate_id  = $plate_row->[0];
		my $plate_row = $self->get( 'plate', {id => $plate_id} );
		$self->update( 'work_order_element', {on_plate => 0,}, {plate_id => $plate_id} );
		$self->machine_select( $plate_row->{machine} );
		$self->place_files_for_plate( lc( $plate_id ) );
	}
	$self->play_end_sound();
}
1;
