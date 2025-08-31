#ABSTRACT: The First, And Not Very Good, mechanism to pack a work order plate
package SlicerController::Role::Packer::Original;
our $VERSION = 'v1.1.3';
##~ DIGEST : f68eb36c4a02c2b01a1946097d3d403b
use Try::Tiny;
use Moo::Role;
use Carp;

sub old_populate_plate_in_db {
	my ( $self, $machine_id, $work_order_id, $opt ) = @_;

	die "Machine ID not provided"    unless $machine_id;
	die "Work Order ID not provided" unless $work_order_id;

	my $this_machine = $self->{machine_definitions}->{$machine_id};

	die "Machine [$machine_id] not found" unless $this_machine;
	my $combined_margin  = $this_machine->{margin} * 2;
	my $short_cursor     = 0;
	my $long_cursor      = 0;
	my $next_long_cursor = 0;

	my $sql_string = "
		select 
			f.id as file_id,
			woe.id as work_order_id,
			round(fd.x_dimension + $combined_margin,2) as  x_dimension,
			round(fd.y_dimension + $combined_margin,2) as  y_dimension,
			round(max(fd.x_dimension + $combined_margin , fd.y_dimension + $combined_margin),2) as longest_edge,
			round(min(fd.x_dimension + $combined_margin , fd.y_dimension + $combined_margin),2) as shortest_edge,
			round(( fd.x_dimension * fd.y_dimension ),2) as area
		from file f 
		join file_dimensions fd
			on f.id = fd.file_id
		join work_order_element woe 
			on f.id = woe.file_id 
		where 
			woe.plate_id is null
			/*SQLite + DBI oddity*/
			and longest_edge <= ( ? + 0 )
			and shortest_edge <= ( ? + 0 )
			and woe.work_order_id = ?
		order by 
			area desc
		limit 1";
	my $get_row_sth = $self->dbh->prepare( $sql_string ) or die $!;

	my $remaining_space_for_columns = my $machine_short_space = $this_machine->{x_dimension} - $combined_margin;
	my $remaining_space_for_rows    = my $machine_long_space  = $this_machine->{y_dimension} - $combined_margin;

	#TODO: stop this from being misleading by returning all unattached items instead of just those for the Work Order
	my $check_sth = $self->dbh->prepare( '
		select count(f.id) as remaining
		from file f 
		join file_dimensions fd
			on f.id = fd.file_id
		join work_order_element woe 
			on f.id = woe.file_id 
		where 
			woe.plate_id is null
			and woe.work_order_id = ?
		limit 1;
	' );
	$check_sth->execute( $work_order_id );
	my $remaining = $check_sth->fetchrow_arrayref()->[0];
	unless ( $remaining ) {
		return {
			pass      => 'Nothing Left',
			remaining => $remaining
		};
	}

	$self->insert( 'plate', {machine => $machine_id} );

	#there is an abstract way to do this but I forget what
	my $max_sth = $self->dbh->prepare( "select max(id) from plate where machine = ?" );
	$max_sth->execute( $machine_id );
	my $plate_id = $max_sth->fetchrow_arrayref->[0];

	while ( 1 ) {

		my $row_height = ( $next_long_cursor - $long_cursor ); #the available y space claimed by the largest (and first) item in this row, may be negative if nothing has been placed yet

		#if we have already determined a row height
		#if short cursor is zero then this is a new band and has to be treated as such
		if ( $short_cursor && $next_long_cursor ) {

			my $effective_long  = max( $remaining_space_for_columns, $row_height );
			my $effective_short = min( $remaining_space_for_columns, $row_height );

			# try and find something that fits in the existing row
			print "$/\tSeeking row mate with [L:$remaining_space_for_columns,S:$row_height/EL:$effective_long,ES:$effective_short]$/";
			$get_row_sth->execute( $effective_long, $effective_short, $work_order_id );
		} else {

			my $effective_long  = max( $remaining_space_for_rows, $remaining_space_for_columns );
			my $effective_short = min( $remaining_space_for_rows, $remaining_space_for_columns );

			# find the largest possible printable thing for this notional row
			print "$/\tSeeking largest possible with [L:$remaining_space_for_rows,S:$remaining_space_for_columns/EL:$effective_long,ES:$effective_short]$/";

			$get_row_sth->execute( $effective_long, $effective_short, $work_order_id );
		}

		#try to fit within Y of previously placed objects - if it's been set; this is always what I want :>
		my $row = $get_row_sth->fetchrow_hashref();
		print "\t" . Dumper( $row );
		print $/;

		#I forget why this is important
		die "long space is less than 1" if $remaining_space_for_rows < 1;

		#otherwise go to the start of a new row
		unless ( $row ) {
			$long_cursor                 = $next_long_cursor;
			$remaining_space_for_rows    = $machine_long_space - $next_long_cursor;
			$short_cursor                = 0;
			$remaining_space_for_columns = $machine_short_space;

			$remaining_space_for_rows = Math::Round::nearest_ceil( .01, $remaining_space_for_rows );

			my $effective_long  = max( $remaining_space_for_rows, $remaining_space_for_columns );
			my $effective_short = min( $remaining_space_for_rows, $remaining_space_for_columns );

			$self->Log( "\tReset cursors and re-seeking anything with [L:$effective_long,S:$effective_short]$/", {file_only => 1} );
			$get_row_sth->execute( $effective_long, $effective_short, $work_order_id );

			$row = $get_row_sth->fetchrow_hashref();
			unless ( $row ) {
				print "\t\tNo objects available for remaining space of [L:$effective_long,S:$effective_short]$/";
				last;
			}
		}

		#did we find something that's best rotated, with the assumption that we want short y and full x
		my ( $new_x, $new_y, $rotate, $do_rotate, $long_in_short, $can_rotate );

		if ( $row->{longest_edge} <= $remaining_space_for_columns ) {
			print "\tObject can fit longest edge horizontally$/";
			$can_rotate = 1;
		}

		if ( $row->{x_dimension} > $remaining_space_for_columns ) {
			print "\tObject can only fit rotated$/";
			$can_rotate = 1;
		}

		if ( $can_rotate ) {
			if (
				$row->{longest_edge} eq $row->{y_dimension}           #if the long dimension fits in the short dimension, is the long dimension on the y axis of the object
				or $row->{x_dimension} > $remaining_space_for_columns #or is rotation the only way the object will fit into the column space
			  )
			{
				#then it should be rotated
				$do_rotate = 1;
				print "\tObject will be rotated$/";
			} else {
				print "\tObject not rotated as Longest Edge [$row->{longest_edge}] is not the Y dimension [$row->{y_dimension}]$/";
			}
		} else {
			print "\tWill not fit rotated [$row->{longest_edge} <= $remaining_space_for_columns] && [$row->{shortest_edge} <= $remaining_space_for_rows]$/";
		}

		if ( $do_rotate ) {
			$new_x  = $row->{y_dimension};
			$new_y  = $row->{x_dimension};
			$rotate = 90;
		} else {
			$new_x  = $row->{x_dimension};
			$new_y  = $row->{y_dimension};
			$rotate = 0;
		}

		#'band' here signifying axis aligned band box
		my $short_band_end = $short_cursor + $combined_margin + $new_x;
		my $long_band_end  = $long_cursor + $combined_margin + $new_y;

		my $x_midpoint = ( $short_cursor + $short_band_end ) / 2;
		my $y_midpoint = ( $long_cursor + $long_band_end ) / 2;
		print "\t\tPlaced file # [$row->{file_id}] which is [$new_x,$new_y] at cursor [$short_cursor,$long_cursor] midpoint [$x_midpoint,$y_midpoint] with rotation of [$rotate] $/";

		#set a new band
		if ( $long_band_end > $next_long_cursor ) {
			print "\t\t\tSetting row height from [$next_long_cursor] to [$long_band_end]$/";
			$next_long_cursor = $long_band_end;
		}

		$short_cursor                = $short_band_end;
		$remaining_space_for_columns = $machine_short_space - $short_cursor;

		if ( $remaining_space_for_columns < 0 ) {
			$remaining_space_for_rows = $machine_long_space - $next_long_cursor;

			$remaining_space_for_rows = Math::Round::nearest_ceil( .01, $remaining_space_for_rows );

			print "\tReset for next band with cursor at [S:$short_cursor,L:$long_cursor] (margin?) starting at [L:$next_long_cursor] with [L:$remaining_space_for_rows] available for remaining rows $/";
			$long_cursor                 = $next_long_cursor;
			$short_cursor                = 0;
			$remaining_space_for_columns = $machine_short_space;
			if ( $remaining_space_for_rows < 1 ) {
				print "\t\t\tDBI/SQLite does not handle numbers less than 1 as expected and the margin is unlikely to fit anything, ending plate$/";
				last;
			}
		}

		$self->update(
			'work_order_element',
			{
				x_position => $x_midpoint,
				y_position => $y_midpoint,
				rotate     => $rotate,
				positioned => 1,
				plate_id   => $plate_id,

			},
			{
				id => $row->{work_order_id}
			}
		);
		if ( $long_cursor > $machine_long_space ) {
			print "\t\t\t Long boundary reached at [$short_cursor,$long_cursor] (likely due to margin), ending plate$/";
			last;
		}

	}
	$check_sth->execute( $work_order_id );
	$remaining = $check_sth->fetchrow_arrayref()->[0];

	return {
		pass      => 1,
		plate_id  => $plate_id,
		remaining => $remaining
	};
}
1;
