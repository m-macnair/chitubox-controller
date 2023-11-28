# ABSTRACT : Module using various for interacting with a GUI application through perl
package Moo::GenericRole::ControlByGui;
our $VERSION = 'v0.0.2';

##~ DIGEST : 3c2296816b2027788564bfbb3d6f334c
use strict;
use Moo::Role;
use 5.006;
use warnings;
use Data::Dumper;

=head1 VERSION & HISTORY
	<breaking revision>.<feature>.<patch>
	1.0.0 - 2023-10-08
		Port from chitubtox_controller_2
=head1 SYNOPSIS
	Use xdotool the way I normally do 
=head2 WRAPPERS
	Should be the whole of the module 
=cut

=head3 Output to program
=cut

has ControlByGui_settings => (
	is      => 'rw',
	lazy    => 1,
	default => sub {
		return {zero_coordinates => [ 0, 0 ]};
	}
);

has ControlByGui_coordinate_map => (
	is      => 'rw',
	lazy    => 1,
	default => sub {
		die "ControlByGui_coordinate_map not overwritten";
	}
);

has ControlByGui_values => (
	is   => 'rw',
	lazy => 1,
);

sub ctrl_copy {
	print `xdotool key Ctrl+c`;
}

sub return_clipboard {
	return `xsel -o`;
}

sub return_text {
	my ( $self ) = @_;
	$self->ctrl_copy();
	return $self->return_clipboard();
}

sub click_to {
	my ( $self, $name ) = @_;
	$self->move_to_named( $name );
	$self->click();
}

sub click {
	print `xdotool click 1`;
}

sub type {
	my ( $self, $string ) = @_;
	print `xdotool type "$string"`;
}

sub type_enter {
	my ( $self, $string ) = @_;
	$self->type( $string );
	print `xdotool key Return`;
}

sub xdo_key {
	my ( $self, $key ) = @_;
	return `xdotool key $key`;
}

=head3 Read from window 

=cut

sub get_colour_at_coordinates {
	my ( $self, $xy ) = @_;
	my ( $x, $y )     = @{$xy};
	my $output = `import -window root -depth 8 -crop 1x1+$x+$y txt:-`;
	my @values = split( '  ', $output );
	print "Found colour [$values[1]] at coordinates [$x,$y]$/";
	return $values[1];
}

sub get_colour_at_named {
	my ( $self, $name ) = @_;
	my $xy = $self->get_named_xy_coordinates( $name );
	return $self->get_colour_at_coordinates( $xy );
}

sub if_colour_at_named {
	my ( $self, $want_colour, $name ) = @_;
	my $colour = $self->get_colour_at_named( $name );

	#54BBFF
	if ( $colour eq $want_colour ) {
		return 1;
	} else {
		print "Colour mismatch: $colour !eq $want_colour$/";
	}
	return 0;
}

sub if_colour_name_at_named {
	my ( $self, $want_name, $name ) = @_;
	my $colour = $self->ControlByGui_values->{colour}->{$want_name};
	die "Named colour value [$want_name] not found." unless $colour;
	return $self->if_colour_at_named( $colour, $name );

}

=head3 
	Given a name, move the cursor to such and such with railings

=cut

sub move_to_named {
	my ( $self, $name ) = @_;
	my $xy = $self->get_named_xy_coordinates( $name );

	return $self->move_to( $xy );
}

sub move_to {
	my ( $self, $xy, $zero ) = @_;
	if ( $zero ) {
		print `xdotool mousemove $zero->[0] $zero->[1]`;
		print `xdotool mousemove_relative $xy->[0] $xy->[1]`;
	} else {
		print `xdotool mousemove $xy->[0] $xy->[1]`;
	}
}

sub get_named_xy_coordinates {
	my ( $self, $name, $map ) = @_;
	$map ||= $self->ControlByGui_coordinate_map();
	my $return = $map->{$name};
	die "[$name] Not found in map" unless $return;
	return $return;
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
