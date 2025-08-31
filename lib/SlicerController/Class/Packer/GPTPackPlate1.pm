#ABSTRACT: Adapted ChatGPTv4 code to do the packing problem
package SlicerController::Class::Packer::GPTPackPlate1;
our $VERSION = 'v0.0.21';

##~ DIGEST : 2e715f5c2648787c3bc6a579ce8ad73e

use Moo;
use List::Util qw(sum);

has x_dimension => ( is => 'ro', required => 1 );
has y_dimension => ( is => 'ro', required => 1 );

# Shelf-based packing algorithm with sorting + rotation
sub pack_items {
	my ( $self, $items ) = @_;

	my @placed;
	my $plate_w = $self->x_dimension;
	my $plate_h = $self->y_dimension;

	# Sort items largest-first by max dimension (better packing)
	my @sorted = sort { ( $b->{x_dimension} > $b->{y_dimension} ? $b->{x_dimension} : $b->{y_dimension} ) <=> ( $a->{x_dimension} > $a->{y_dimension} ? $a->{x_dimension} : $a->{y_dimension} ) } @$items;

	my ( $cursor_x, $cursor_y, $shelf_height ) = ( 0, 0, 0 );

	for my $item ( @sorted ) {
		my ( $w, $h ) = ( $item->{x_dimension}, $item->{y_dimension} );

		# Try both orientations and choose the one that fits best
		my ( $fit_w, $fit_h, $rotated );
		if ( $w <= $plate_w && $h <= $plate_h ) {
			( $fit_w, $fit_h, $rotated ) = ( $w, $h, 0 );
		} elsif ( $h <= $plate_w && $w <= $plate_h ) {
			( $fit_w, $fit_h, $rotated ) = ( $h, $w, 1 );
		} else {
			next; # Cannot fit in any orientation
		}

		# If it doesn’t fit in current row, start new shelf
		if ( $cursor_x + $fit_w > $plate_w ) {
			$cursor_x = 0;
			$cursor_y += $shelf_height;
			$shelf_height = 0;
		}

		# If it doesn’t fit vertically, discard
		last if $cursor_y + $fit_h > $plate_h;

		# Place item (coordinates are center of rectangle)
		my $center_x = $cursor_x + $fit_w / 2;
		my $center_y = $cursor_y + $fit_h / 2;

		push @placed, {%$item, x_position => $center_x, y_position => $center_y, rotate => $rotated};

		$cursor_x += $fit_w;
		$shelf_height = $fit_h if $fit_h > $shelf_height;
	}

	my $space_used = sum( map { $_->{x_dimension} * $_->{y_dimension} } @placed ) // 0;

	return {files => \@placed, space_used => $space_used};
}

1;

1;
