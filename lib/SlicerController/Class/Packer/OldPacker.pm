#ABSTRACT: Brutally mangled db detached version of the original row packer
package SlicerController::Class::Packer::OldPacker;
our $VERSION = 'v0.0.19';
use Moo;
##~ DIGEST : d0ba9c67d5a9d57cc435610928a87e0b

has x_dimension => ( is => 'ro', required => 1 );
has y_dimension => ( is => 'ro', required => 1 );

sub pack_plate {
	my ( $self, $items ) = @_;

	# items: [ {file_id => ..., x_dimension => ..., y_dimension => ...}, ... ]

	# Round dimensions to 2 decimal places
	for my $it ( @{$items} ) {
		$it->{x_dimension} = sprintf( "%.2f", $it->{x_dimension} );
		$it->{y_dimension} = sprintf( "%.2f", $it->{y_dimension} );
	}

	my @free = ( {x_dimension => 0, y_dimension => 0, w => $self->x_dimension, h => $self->y_dimension} );
	my @placed;
	my $space_used = 0;

	ITEM: for my $item ( sort { $b->{y_dimension} <=> $a->{y_dimension} || $b->{x_dimension} <=> $a->{x_dimension} } @$items ) {
		my $best_choice;
		my $best_waste = 1e12;

		for my $f ( 0 .. $#free ) {
			my $space = $free[$f];
			for my $rot ( 0, 1 ) {
				my ( $w_dim, $h_dim ) = $rot ? ( $item->{y_dimension}, $item->{x_dimension} ) : ( $item->{x_dimension}, $item->{y_dimension} );
				next if $w_dim > $space->{w} || $h_dim > $space->{h};

				# wasted area heuristic
				my $waste = ( $space->{w} * $space->{h} ) - ( $w_dim * $h_dim );
				if ( $waste < $best_waste ) {
					$best_waste  = $waste;
					$best_choice = {
						f           => $f,
						x_dimension => $w_dim,
						y_dimension => $h_dim,
						rotate      => $rot,
					};
				}
			}
		}

		next ITEM unless $best_choice;

		my $space = $free[ $best_choice->{f} ];

		# convert to center-origin
		my $cx_dim = $space->{x_dimension} - $self->x_dimension / 2;
		my $cy_dim = $space->{y_dimension} - $self->y_dimension / 2;

		push @placed,
		  {
			file_id    => $item->{file_id},
			woe_id     => $item->{woe_id},
			x_position => $cx_dim,
			y_position => $cy_dim,
			width      => $best_choice->{x_dimension},
			height     => $best_choice->{y_dimension},
			rotate     => $best_choice->{rot},
		  };

		$space_used += $best_choice->{x_dimension} * $best_choice->{y_dimension};

		# split free space
		my @new_free;
		push @new_free,
		  {
			x_dimension => $space->{x_dimension} + $best_choice->{x_dimension},
			y_dimension => $space->{y_dimension},
			w           => $space->{w} - $best_choice->{x_dimension},
			h           => $best_choice->{y_dimension},
		  } if $space->{w} > $best_choice->{x_dimension};
		push @new_free,
		  {
			x_dimension => $space->{x_dimension},
			y_dimension => $space->{y_dimension} + $best_choice->{y_dimension},
			w           => $space->{w},
			h           => $space->{h} - $best_choice->{y_dimension},
		  } if $space->{h} > $best_choice->{y_dimension};

		splice @free, $best_choice->{f}, 1;
		push @free, @new_free;
	}

	return {
		files      => \@placed,
		space_used => sprintf( "%.2f", $space_used ),
	};
}

1;
