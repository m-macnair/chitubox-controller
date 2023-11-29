# ABSTRACT : Module for interacting with Chitubox using ControlByGui
package Moo::GenericRole::ControlByGui::Chitubox;
our $VERSION = 'v0.0.3';

##~ DIGEST : f623e861cbc220ab3f53d0a14a4cc94f
use strict;
use Moo::Role;
use 5.006;
use warnings;
use Data::Dumper;
use Carp;
use List::Util 'first';

=head1 VERSION & HISTORY
	<breaking revision>.<feature>.<patch>
	1.0.0 - 2023-11-18
		Port from chitubox_controller_3.pl
=cut

sub place_stl {
	my ( $self, $row, $x_current, $y_current ) = @_;
	my $x_half = ( $self->ControlByGui_values()->{margin} + $row->{x_dimension} ) / 2;
	my $y_half = ( $self->ControlByGui_values()->{margin} + $row->{y_dimension} ) / 2;

	my $x_pos = $$x_current + $x_half;
	if ( ( $x_pos + $x_half ) > $self->ControlByGui_values->{dimensions}->{'x'} ) {
		$$x_current = 0;
		$$y_current += $y_half * 2;
		$x_pos = $$x_current + $x_half;
	}
	$$x_current += $x_half * 2;

	my $y_pos = $$y_current + $y_half;

	#TODO augment select statement to use available space? Add a 'tried but can't' field?
	if ( ( $y_pos + $y_half ) > $self->ControlByGui_values->{dimensions}->{'y'} ) {

		#TODO detect duplicates, act efficiently
		Carp::carp( "Cannot fit object [$row->{file_path}] on this row" );
		return;
	}

	$x_pos = $x_pos - ( $self->ControlByGui_values->{dimensions}->{'x'} / 2 );
	$y_pos = $y_pos - ( $self->ControlByGui_values->{dimensions}->{'y'} / 2 );
	return {
		path => $row->{file_path},
		xy   => [ $x_pos, $y_pos ],
		done => $row->{rowid}
	};
}

sub import_and_position {
	my ( $self, $file, $xy ) = @_;
	warn "Placing \n\t$file \n at\n\t$xy->[0],$xy->[1]\n";
	$self->open_file( $file );

	my $colour = $self->get_colour_at_coordinates( $self->ControlByGui_coordinate_map->{select_all} );
	if ( $colour eq $self->ControlByGui_values->{colour}->{select_all_on} ) {
		print "Select all detected - disabling$/";
		$self->click_to( 'select_all' );
	}

	$self->click_to( 'move_button' );
	$self->click_to( 'x_pos' );
	$self->xdo_key( 'BackSpace' );

	#TODO: verify if the leading space is required
	$self->type_enter( " $xy->[0]" );
	$self->click_to( 'y_pos' );
	$self->xdo_key( 'BackSpace' );
	$self->type_enter( " $xy->[1]" );

	#close the menu
	$self->click_to( 'move_button' );
}

sub position_selected {
	my ( $self, $x, $y ) = @_;

	$self->click_to( 'move_button' );
	$self->click_to( 'x_pos' );
	$self->xdo_key( 'BackSpace' );

	#TODO: verify if the leading space is required
	$self->type_enter( " $x" );
	$self->click_to( 'y_pos' );
	$self->xdo_key( 'BackSpace' );
	$self->type_enter( " $y" );

	#close the menu
	$self->click_to( 'move_button' );

}

sub get_single_file_project_dimensions {
	my ( $self, $file ) = @_;

	print "working on $file $/";
	my ( $name, $dir, $suffix ) = $self->file_parse( $file );
	unless ( first { /$suffix/ } qw/ .chitubox .stl .obj/ ) {
		confess "[$file] is not a compatible file";
	}

	#TODO test openfile
	$self->click_to( 'main_settings' );
	$self->click_to( "hamburger" );
	$self->click_to( 'open_project' );
	$self->type_enter( $file );

	$self->wait_for_progress_bar();
	sleep( 1 );
	$self->click_to( 'scale_button' );
	$self->click_to( 'x_dim' );
	my $x = $self->return_text();

	$self->click_to( 'y_dim' );
	my $y = $self->return_text();

	$self->click_to( 'z_dim' );
	my $z = $self->return_text();

	$self->click_to( 'delete' );

	#close the scale menu
	$self->click_to( 'scale_button' );
	return [ $x, $y, $z ];

}

sub set_supports_for_directory_files {
	my ( $self, $dir ) = @_;

	$self->sub_on_directory_files(
		sub {
			my ( $file ) = @_;
			print "working on $file $/";
			my ( $name, $dir, $suffix ) = $self->file_parse( $file );

			return 1 unless ( first { /$suffix/ } qw/ .obj .stl / );
			$self->import_support_export_file( $file );

			$self->click_to( 'delete' );
			sleep 1;
			return 1;
		},
		$dir
	);

}

sub open_file {
	my ( $self, $file ) = @_;

	$self->click_to( 'main_settings' );
	$self->click_to( "hamburger" );
	$self->click_to( "open" );

	#can be improved with copy paste facilty
	$self->type_enter( $file );
	$self->wait_for_progress_bar();
}

sub import_support_export_file {
	my ( $self, $file, $opt ) = @_;
	$opt ||= {};

	$self->open_file( $file );
	if ( defined( $opt->{'pre_supports_sub'} ) ) {
		&{$opt->{pre_supports_sub}}();
	}
	$self->auto_supports();

	$self->click_to( 'main_settings' );
	$self->click_to( "hamburger" );
	$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
	sleep( 1 );
	$self->click_to( 'save_project_all_models' );
	my $out_path = $opt->{out_path};
	unless ( $out_path ) {
		my ( $name, $dir, $suffix ) = $self->file_parse( $file );
		my $new_path = qq{$dir/$name.chitubox};
		$out_path = $self->safe_duplicate_path( $new_path );
	}
	print $out_path;
	$self->type_enter( $out_path );
	$self->wait_for_progress_bar();
	$self->click_to( 'hamburger' );
	return $out_path;
}

sub rotate_file_corner {
	my ( $self ) = @_;
	for my $click_to (
		qw/
		rotate_menu
		rotate_x45-
		rotate_y45+
		rotate_menu
		/
	  )
	{
		$self->click_to( $click_to );
	}

}

sub auto_supports {
	my ( $self ) = @_;
	$self->click_to( 'support_menu' );
	$self->wait_for_progress_bar();
	for my $click_to (
		qw/
		add_supports_mode
		light_supports
		add_supports
		/
	  )
	{
		$self->click_to( $click_to );
		sleep( 1 );
	}
	$self->wait_for_progress_bar();
}

sub wait_for_progress_bar {
	my ( $self ) = @_;
	my ( $x, $y ) = @{$self->ControlByGui_coordinate_map->{progress_bar_xy}};
	$self->wait_for_pixel_colour( $x, $y, $self->ControlByGui_values()->{colour}->{progress_bar_clear} );
}

sub wait_for_pixel_colour {
	my ( $self, $x, $y, $wanted ) = @_;
	Carp::confess( 'Wanted not supplied' ) unless $wanted;
	sleep( 1 ); # Mandatory - anything that might want this, might load too fast
	my $colour = $self->get_colour_at_coordinates( [ $x, $y ] );

	if ( $colour eq $wanted ) {
		print "Progress bar is clear$/";
	} else {
		print "Waiting on progress bar [$colour] != [$wanted]$/";
		sleep( 1 );
		$self->wait_for_pixel_colour( $x, $y, $wanted );
	}
	return;
}

=head1 AUTHOR
	mmacnair, C<< <mmacnair at cpan.org> >>
=head1 BUGS
	TODO Bugs
=head1 SUPPORT
	TODO Support
=head1 ACKNOWLEDGEMENTS
	TODO
=head1 COPYRIGHT
 	Copyright 2023 mmacnair.
=head1 LICENSE
	TODO
=cut

1;
