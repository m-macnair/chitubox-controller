# ABSTRACT : Module using various for interacting with a GUI application through perl
package Moo::GenericRole::ControlByGui;
our $VERSION = 'v0.0.9';

##~ DIGEST : 74510f089e69f3dd0692acc1fa1d7ea0
use strict;
use Moo::Role;
use 5.006;
use warnings;
use Data::Dumper;
use Carp;
use POSIX;
use List::Util qw(min max);

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

has ControlByGui_zero_point => (
	is      => 'rw',
	lazy    => 1,
	default => sub {
		Carp::confess "ControlByGui_zero_point not overwritten";
	}
);
has ControlByGui_coordinate_map => (
	is      => 'rw',
	lazy    => 1,
	default => sub {
		Carp::confess "ControlByGui_coordinate_map not overwritten";
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
	my ( $self, $name, $p ) = @_;
	$self->move_to_named( $name, $p );
	$self->click();

	#sleep(1);
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

sub play_sound {
	my ( $self, $path ) = @_;
	$path ||= '/usr/share/sounds/Oxygen-Im-Nudge.ogg';
	`cvlc $path vlc://quit &`;
}

sub play_end_sound {
	my ( $self ) = @_;
	$self->play_sound( '/usr/share/sounds/Oxygen-Sys-App-Positive.ogg' );

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
	my ( $self, $name, $p ) = @_;
	my $xy = $self->get_named_xy_coordinates( $name, $p );

	#offset here being the offset from the default zero point which is the baseline for everything else
	if ( $p->{offset} ) {
		$xy->[0] += $p->{offset}->[0];
		$xy->[1] += $p->{offset}->[1];
	}
	my $x = $xy->[0] + ( defined( $p->{x_mini_offset} ) ? $p->{x_mini_offset} : 0 );
	my $y = $xy->[1] + ( defined( $p->{y_mini_offset} ) ? $p->{y_mini_offset} : 0 );

	return $self->move_to( [ $x, $y ] );
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
	my ( $self, $name, $p ) = @_;
	$p ||= {};
	my $map = $p->{'map'} || $self->ControlByGui_coordinate_map();
	die "[$name] Not found in map" unless $map->{$name};
	my ( $x, $y ) = @{$map->{$name}};

	print "$name original -> $x,$y$/";
	unless ( $p->{no_offset} ) {
		$x += $self->ControlByGui_zero_point->[0];
		$y += $self->ControlByGui_zero_point->[1];
	}

	print "$name offset -> $x,$y$/";
	return [ $x, $y ];
}

#calculate a sensible duration to sleep - particularly relevant when many lots of memory is in use and basic functions might take longer than expected for the progress bar to show

sub dynamic_sleep {
	my ( $self, $sleep, $p ) = @_;
	$p ||= {};
	sleep( max( $sleep || 0, $p->{sleep_for} || 0, $self->{sleep_for} || 0, 1 ) );
}

sub dynamic_short_sleep {
	my ( $self ) = @_;

	my $sleep_for = ceil( ( $self->{sleep_for} || 1 ) / ( $self->config->{dynamic_sleep_short_divider} || 1 ) );
	$sleep_for = 1 if $sleep_for < 1;
	print "dynamic_short_sleep : $sleep_for$/";
	sleep( $sleep_for );

}

sub adjust_sleep_for_file {
	my ( $self, $path ) = @_;

	my $filename = $path;
	my @stat     = stat $filename;
	$self->{workspace_size} += $stat[7];

	#sleep 1 second for every x mb
	$self->{sleep_for} = ceil( $self->{workspace_size} / ( 1024 * 1024 * $self->config->{dynamic_sleep_megabyte_size} ) );
	warn "adjusted sleep for to $self->{sleep_for}";

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
