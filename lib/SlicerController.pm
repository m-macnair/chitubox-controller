#!/usr/bin/perl
# ABSTRACT: Multi-purpose chitubox controller and root module of the project
our $VERSION = 'v3.0.14';

##~ DIGEST : 9055ad8370ee2d6ff800a9fe43a2d5f2
use strict;
use warnings;

package SlicerController;

=head1 TODO
	Extend on basic dimensions to do iterative rotations until a best possible orientation has been found
		this will involve rotating by e.g. 5 degrees in chitubox over and over 
	WXWidgets UI
		kek
	Logging 
		MooseX::Log::Log4perl
	PerlPack
	Web service (?)
		generate xmove commands? 
	Normalise DB component with updated DB format
		I think this is done
	Rationalise item placement as parametrically set which axis (x or y) should be favored 
	project specific attributes ( margin etc)
=cut

use v5.10;
use Moo;
use Carp;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/

  Moo::GenericRole::ControlByGui::Chitubox
  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::ConfigAny
  Moo::GenericRole::DB::Working::AbstractSQLite
  SlicerController::DB
  Moo::Task::ControlByGui::Role::Core
  Moo::Task::ControlByGui::Role::Linux
  /;                                     # AbstractSQLite is a wrapper class for all dbi actions

use Data::Dumper;
use Image::OCR::Tesseract 'get_ocr';
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
  clock_gettime clock_getres clock_nanosleep clock
  stat lstat utime);
use Math::Round;
use List::Util qw(min max);
around "new" => sub {

	#This is apparently the standard
	my $orig = shift;
	my $self = $orig->( @_ );

	my $y_offset = 0;

	$self->_setup();

	#assuming window is at 0,0
	#offsets are the printing offset values to mask screen problems as defined in the printer setting

	$self->{machine_definitions} = Config::Any::Merge->load_files( {files => [qw{./config/machine_definitions.perl}], flatten_to_hash => 0, use_ext => 1} );
	return $self;

};

sub _setup {
	my ( $self, $p ) = @_;
	$p ||= {};

	$self->standard_config();

	$self->ControlByGui_coordinate_map( $self->config_file( $p->{coordinate_map} || './config/chitubox_coordinate_map.perl' ) );
	$self->ControlByGui_values( $self->config_file( $p->{colour_values}          || './config/colour_values.perl' ) );

	my $ui_config = Config::Any::Merge->load_files( {files => [qw{./config/ui.perl}], flatten_to_hash => 0, use_ext => 1} );
	$self->ControlByGui_zero_point( $self->ControlByGui_coordinate_map->{zero_point} );

}

sub default_work_order {
	my ( $self, $work_order_string ) = @_;
	unless ( $work_order_string ) {
		print q{Work order string not provided - setting to 'default'} . $/;
		$work_order_string = 'default';
	}
	return $work_order_string;

}

#Open each asset file in the file list that has not yet had dimensions set, and record them
#TODO limit to specific project on param
sub get_basic_dimensions {
	my ( $self, $res ) = @_;
	$self->_do_db( $res );

	#note that .id is ambiguous here and will show up with a null value if accessed without table qualifier
	my $sql = <<SQL;
	select f.id
	from file f 
	left join file_dimensions fd 
		on f.id = fd.file_id 
	left join file_meta m 
		on f.id = m.file_id
	where fd.file_id is null
	and (m.is_supported = 1 or m.file_id is null )
	and ( m.no_dimensions != 1 or m.no_dimensions is null)
		
SQL
	my $sth = $self->query( $sql );

	while ( my $file_row = $sth->fetchrow_hashref() ) {
		my $file_path = $self->get_file_path_from_id( $file_row->{id} );
		print "[$file_path] retrieved for file [$file_row->{id}] $/";
		if ( -f $file_path ) {
			$self->clear_for_project();
			my $dim = $self->get_single_file_project_dimensions( $file_path );

			$self->insert(
				'file_dimensions',
				{
					file_id     => $file_row->{id},
					x_dimension => $dim->[0],
					y_dimension => $dim->[1],
					z_dimension => $dim->[2],
				}
			);
		} else {
			warn "[$file_path] not found for file [$file_row->{id}], skipping $/";
		}
	}

}

#calculate and assign the band box middle positions for every object that will fit on a given plate starting from bottom left
sub populate_plate_in_db {
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
	warn $sql_string;

	#TODO: remove concepts of x and y and switch to min and max dimensions
	#use List::Util qw(min);

	my $remaining_space_for_columns = my $machine_short_space = $this_machine->{x_dimension} - $combined_margin;
	my $remaining_space_for_rows    = my $machine_long_space  = $this_machine->{y_dimension} - $combined_margin;

	#Math::Round::nearest_ceil(.01, );

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

			print "\tReset cursors and re-seeking anything with [L:$effective_long,S:$effective_short]$/";
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

	#TODO status
	return 0;
}

sub get_plate_row {
	my ( $self, $plate_id ) = @_;
	confess 'Plate ID not supplied' unless $plate_id;
	my $plate_row = $self->query( "select * from plate where id = ? limit 1", $plate_id )->fetchrow_hashref();
	confess "plate [$plate_id] not found" unless $plate_row->{id};
	return $plate_row;
}

#from the db positions, actually interact with chitubox to place them - assumes the correct machine definition has already been set already
sub place_on_plate {

	my ( $self, $plate_id, $p ) = @_;
	$p ||= {};
	my $plate_row;
	if ( $p->{plate_row} ) {
		$plate_row = $p->{plate_row};
		$plate_id  = $plate_row->{id};
	} else {
		$plate_row = $self->get_plate_row( $plate_id );
	}
	die "Plate ID not provided" unless $plate_id;

	my $this_machine = $self->{machine_definitions}->{$plate_row->{machine}};
	die "Machine [$plate_row->{machine}] definition not found" unless $this_machine;
	my $row;

	my $this_machine_x_zero = ( $this_machine->{x_dimension} / 2 ) - $this_machine->{x_offset};
	my $this_machine_y_zero = ( $this_machine->{y_dimension} / 2 ) - $this_machine->{y_offset};

	$self->set_select_all_off();
	print "\tPlacing on [$plate_row->{machine}] with zero point modifiers [$this_machine_x_zero,$this_machine_y_zero]$/";
	do {
		$row = $self->query(
			"select 
			woe.file_id,
			fd.x_dimension ,
			fd.y_dimension, 
			woe.x_position ,
			woe.y_position,
			woe.rotate,
			woe.id
		from work_order_element woe
		join file f 
			on woe.file_id = f.id
		join file_dimensions fd
			on fd.file_id = f.id 
		where 
			woe.positioned = 1
			and woe.on_plate is null
			and plate_id = ?
		order by 
			woe.y_position	ASC,
			woe.x_position	ASC
			", $plate_id
		)->fetchrow_hashref();

		unless ( $row ) {
			print "No positioned items found for [$plate_id] on machine [$plate_row->{machine}]";
			return;
		}
		print "\tPlacing with original position of [$row->{x_position},$row->{y_position}]$/";
		my $file_path = $self->get_file_path_from_id( $row->{file_id} );
		$self->import_and_position(
			$file_path,

			#offsets such as the necessary for M1 are to move the 0 point around as it's always in the middle of the nominal center of the plate otherwise
			[ ( $row->{x_position} - $this_machine_x_zero ), ( $row->{y_position} - $this_machine_y_zero ) ],
			$row->{rotate}
		);
		$self->update(
			'work_order_element',
			{
				'on_plate' => 1,
			},
			{
				id => $row->{id}
			}
		);
	} while ( $row );
	print "Finished positioning items in [$plate_id]";
	return;
}

sub clear_dynamic_sleep {
	my ( $self ) = @_;
	$self->{sleep_for}      = 1;
	$self->{workspace_size} = 0;

}

sub object_stack_to_bands {
	my ( $self, $stack ) = @_;

	for my $line ( @{$stack} ) {
		my ( $path ) = ( keys( %{$line} ) );
		$self->insert(
			'files',
			{
				file_path   => $path,
				x_dimension => $line->{$path}->[0],
				y_dimension => $line->{$path}->[1],
				done        => 0,
			}
		) or die "unknown db error !?";
	}
	my $row;
	my @return;
	my $x_current = 0;
	my $y_current = 0;
	do {
		$row = $self->query( "select *,rowid from files where done = 0 order by x_dimension desc limit 1" )->fetchrow_hashref();
		if ( $row ) {

			#dimensions are from the center point, so need margins
			my $res = $self->place_stl( $row, \$x_current, \$y_current );
			if ( $res ) {
				$self->update(
					'files',
					{
						'state' => 1,
					},
					{
						rowid => $res->{done}
					}
				);
				push( @return, $res );
			} else {
				undef( $row );
			}
		}
	} while ( $row );
	return \@return;
}

1;
