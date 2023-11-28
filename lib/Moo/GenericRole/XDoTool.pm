# ABSTRACT : Module for using XDoTool
package Moo::GenericRole::XDoTool;
our $VERSION = 'v0.0.2';

##~ DIGEST : 1215d055cdcd89d67ed35c33afa4046c
use strict;
use Moo;
use 5.006;
use warnings;

=head1 VERSION & HISTORY
	<breaking revision>.<feature>.<patch>
	1.0.0 - 2023-10-08
		Port from chitubtox_controller_2
=head1 SYNOPSIS
	Use xdotool the way I normally do 
=head2 WRAPPERS
	Should be the whole of the module 
=cut

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
	$self->move_to( $name );
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
