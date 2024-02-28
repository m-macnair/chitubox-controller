#!/usr/bin/perl
# ABSTRACT: Multi-purpose chitubox controller
our $VERSION = 'v3.0.8';

##~ DIGEST : fe3d645224146ebdf549ed9aa2c489af
use strict;
use warnings;

package SlicerController;
use v5.10;
use Moo;
use Carp;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/
  Moo::GenericRole::ControlByGui
  Moo::GenericRole::ControlByGui::Chitubox
  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::ConfigAny
  Moo::GenericRole::DB::Working::AbstractSQLite
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

	$self->{machine_definitions} = Config::Any::Merge->load_files( {files => [qw{./config/machine_definitions.perl}], flatten_to_hash => 0} );
	return $self;

};

sub _setup {
	my ( $self, $p ) = @_;
	$p ||= {};

	$self->standard_config();

	$self->ControlByGui_coordinate_map( $self->config_file( $p->{coordinate_map} || './config/chitubox_coordinate_map.perl' ) );
	$self->ControlByGui_values( $self->config_file( $p->{colour_values}          || './config/colour_values.perl' ) );

	my $ui_config = Config::Any::Merge->load_files( {files => [qw{./config/ui.perl}], flatten_to_hash => 0} );
	$self->ControlByGui_zero_point( $self->ControlByGui_coordinate_map->{zero_point} );

}

sub _do_db {
	my ( $self, $res ) = @_;
	$res ||= {};
	if ( $res->{db_file} ) {
		$self->sqlite3_file_to_dbh( $res->{db_file} );
	} else {

		#$self->setup_working_db_copy( './working_db.sqlite' );
		$self->sqlite3_file_to_dbh( './db/working_db.sqlite' );
	}
}

sub import_work_list {
	my ( $self, $res ) = @_;
	$self->_do_db( $res );
	my $stack = $self->get_file_list( $res->{csv_file} );
	my $project_id;
	if ( $res->{project_id} ) {
		$project_id = $res->{project_id};
	} else {
		$project_id = "default";
		Carp::cluck( "no project id provided for import_work_list; set to [$project_id]" );
	}

	for my $project_row_href ( @{$stack} ) {

		#print "processing $project_row_href->{path}$/";
		my $file_row = $self->select( 'files', [qw/* rowid/], {file_path => $project_row_href->{path}} )->fetchrow_hashref;
		unless ( $file_row ) {
			$self->insert( 'files', {file_path => $project_row_href->{path}} );
			$file_row = $self->select( 'files', [qw/* rowid/], {file_path => $project_row_href->{path}} )->fetchrow_hashref;
		}
		$project_row_href->{count} =~ s/^\s+|\s+$//g;
		print "\tImporting  [$project_row_href->{count}] of [$project_row_href->{path}]$/";

		while ( $project_row_href->{count} > 0 ) {

			$self->insert(
				'projects',
				{
					file_id => $file_row->{rowid},
					project => $project_id
				}
			);
			$project_row_href->{count}--;
		}

	}
}

#Open each .chitubox file in the file list that has not yet had dimensions set, and record them
sub get_outstanding_dimensions {
	my ( $self, $res ) = @_;
	$self->_do_db( $res );
	while ( my $file_row = $self->select( 'files', [qw/* rowid/], {x_dimension => undef} )->fetchrow_hashref() ) {

		if ( -f $file_row->{file_path} ) {

			my $dim = $self->get_single_file_project_dimensions( $file_row->{file_path} );
			$self->update(
				'files',
				{
					x_dimension => $dim->[0],
					y_dimension => $dim->[1],
					z_dimension => $dim->[2],
				},
				{
					rowid => $file_row->{rowid}
				}
			);
		} else {
			warn "[$file_row->{file_path}] not found for file [$file_row->{rowid}], skipping $/";
		}
	}
}

=head2 export_plate_as_single_file_projects
	export a working plate with multiple projects as multiple individual projects - these are the items to actually print 
=cut

sub export_plate_as_single_file_projects {
	my ( $self, $out_dir, $p ) = @_;
	unless ( $out_dir ) {
		print "Output directory defaulting to ./";
		$out_dir = './';
	}
	die "Invalid directory [$out_dir]" unless ( -d $out_dir );

	$p ||= {};
	my $has_remaining;
	do {
		$self->set_select_all_off();
		$self->click_to( 'first_object' );

		#better contrast when the target item is the one highlighted after the select all has been turned off
		$self->click_to( 'select_all' );

		my $path = $self->tmp_dir;
		$path = './working_mono.png';
		print `import -window root -quality 95 -compress none -negate -crop 275x27+1630+225 $path`;
		my $text = get_ocr( $path );

		unless ( $text ) {
			warn "no text returned from OCR";
			$text = "file_" . int( rand( 100_000 ) );
		}
		$text =~ s/[^\x00-\x7F]/_/g;
		$text = lc( $text );
		$text =~ s/\#.*//;
		$text =~ s/stl^//;
		$text =~ s/obj^//;
		$text =~ s/\.//;
		$text = substr( $text, 1 );
		$text =~ s/^\s+|\s+$//g;
		$text =~ s/\s/_/g;

		$self->click_to( 'first_object' ); # actually select the first object
		$self->position_selected( 0, 0 );

		my $out_path = $self->safe_duplicate_path( "$out_dir/$text.chitubox" );
		$self->click_to( 'main_settings' );
		$self->click_to( "hamburger" );
		$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
		$self->dynamic_sleep();
		$self->click_to( 'save_project_single' );
		$self->type_enter( $out_path );

		#Today the lesson is - 1. wait for progress always and 2. lock the screen (smartly) when an action is actioning in  a gui application
		$self->wait_for_progress_bar();
		unless ( $p->{skip} ) {
			my $dim = $self->get_current_dimensions();

			$self->insert(
				'files',
				{
					file_path   => $out_path,
					x_dimension => $dim->[0],
					y_dimension => $dim->[1],
					z_dimension => $dim->[2],
				}
			);
		}

		$self->click_to( 'first_object' );

		$self->click_to( 'delete_object' );

		#check if more objects remain
		$self->click_to( 'first_object' );

		$has_remaining = $self->if_colour_name_at_named( 'highlighted_in_objects', 'first_object' );

	} while ( $has_remaining );

}

#turn csv file into <number> <filepath>
sub get_file_list {
	my ( $self, $csv_file ) = @_;
	my @stack;
	$self->sub_on_csv(
		sub {
			my ( $row ) = @_;
			my ( $x, $y, $z ) = @{$row};

			return 1 unless ( $x );
			my $file_path;
			if ( -d $y ) {
				$file_path = "$y/$z";
			} else {
				$file_path = $y;
			}
			$file_path =~ s|//|/|g;
			$file_path =~ s/\s+$//g;
			chomp( $file_path );
			if ( -e $file_path ) {
				push( @stack, {count => $x, path => $file_path} );

			} else {
				my $alt = $file_path;
				$alt =~ s| |\ |g;
				if ( -e $alt ) {
					warn "spaces problem on [$alt]";
					push( @stack, {count => $x, path => $file_path} );
				} else {

					warn( "[$file_path] not found" );
					$self->dynamic_sleep();
				}
			}
			return 1;
		},
		$csv_file
	);
	return \@stack;

}

#calculate and assign the band box middle positions for every object that will fit on a given plate starting from bottom left
sub allocate_position_in_db_mk2 {
	my ( $self, $machine_id, $project_id, $opt ) = @_;

	die "Machine ID not provided" unless $machine_id;
	die "Project ID not provided" unless $project_id;

	my $this_machine = $self->{machine_definitions}->{$machine_id};

	die "Machine [$machine_id] not found" unless $this_machine;
	my $combined_margin  = $this_machine->{margin} * 2;
	my $short_cursor     = 0;
	my $long_cursor      = 0;
	my $next_long_cursor = 0;

	my $get_row_sth = $self->dbh->prepare( "
		select 
			f.file_path,
			round(f.x_dimension + $combined_margin,2) as  x_dimension,
			round(f.y_dimension + $combined_margin,2) as  y_dimension,
			round(max(f.x_dimension + $combined_margin , f.y_dimension + $combined_margin),2) as longest_edge,
			round(min(f.x_dimension + $combined_margin , f.y_dimension + $combined_margin),2) as shortest_edge,
			p.rotate,
			p.rowid,
			p.file_id,
			round(( f.x_dimension * f.y_dimension ),2) as area
		from files f 
		join projects p 
			on f.rowid = p.file_id 
		where 
			state is null
			/*SQLite + DBI oddity*/
			and longest_edge <= ( ? + 0 )
			and shortest_edge <= ( ? + 0 )
			and project = ? 
		order by 
			area desc
		limit 1" );

	#TODO: remove concepts of x and y and switch to min and max dimensions
	#use List::Util qw(min);

	my $remaining_space_for_columns = my $machine_short_space = $this_machine->{x_dimension} - $combined_margin;
	my $remaining_space_for_rows    = my $machine_long_space  = $this_machine->{y_dimension} - $combined_margin;

	#Math::Round::nearest_ceil(.01, );

	while ( 1 ) {

		my $row_height = ( $next_long_cursor - $long_cursor ); #the available y space claimed by the largest (and first) item in this row, may be negative if nothing has been placed yet

		#if we have already determined a row height
		#if short cursor is zero then this is a new band and has to be treated as such
		if ( $short_cursor && $next_long_cursor ) {

			my $effective_long  = max( $remaining_space_for_columns, $row_height );
			my $effective_short = min( $remaining_space_for_columns, $row_height );

			# try and find something that fits in the existing row
			print "$/\tSeeking row mate with [L:$remaining_space_for_columns,S:$row_height/EL:$effective_long,ES:$effective_short]$/";
			$get_row_sth->execute( $effective_long, $effective_short, $project_id );
		} else {

			my $effective_long  = max( $remaining_space_for_rows, $remaining_space_for_columns );
			my $effective_short = min( $remaining_space_for_rows, $remaining_space_for_columns );

			# find the largest possible printable thing for this notional row
			print "$/\tSeeking largest possible with [L:$remaining_space_for_rows,S:$remaining_space_for_columns/EL:$effective_long,ES:$effective_short]$/";

			$get_row_sth->execute( $effective_long, $effective_short, $project_id );
		}

		#try to fit within Y of previously placed objects - if it's been set; this is always what I want :>
		my $row = $get_row_sth->fetchrow_hashref();
		print "\t" . Dumper( $row );
		print $/;
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
			$get_row_sth->execute( $effective_long, $effective_short, $project_id );

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
			'projects',
			{
				'state'       => 'positioned',
				x_position    => $x_midpoint,
				y_position    => $y_midpoint,
				rotate        => $rotate,
				machine       => $machine_id,
				project_block => -1
			},
			{
				rowid => $row->{rowid}
			}
		);
		if ( $long_cursor > $machine_long_space ) {
			print "\t\t\t Long boundary reached at [$short_cursor,$long_cursor] (likely due to margin), ending plate$/";
			last;
		}

	}
	my $sum_row = $self->query( "select max(project_block) from projects " )->fetchrow_arrayref();
	my $max     = $sum_row->[0];
	if ( $max <= 0 ) {
		$max = 1;
	} else {
		$max++;
	}

	$self->query( "update projects set project_block = ? where project_block = -1", $max );
	my $assigned_row  = $self->query( "select count(*) as count from projects where project_block = ? ",             $max )->fetchrow_arrayref();
	my $remaining_row = $self->query( "select count(*) as count from projects where state is null and project = ? ", $project_id )->fetchrow_arrayref();
	print "$/\tPlaced [$assigned_row->[0]] Items in Block [$max] using machine [$machine_id]$/\t[$remaining_row->[0]]  Items remaining in project [$project_id] that have not been placed$/";
	return 0;
}

#from the db positions, actually interact with chitubox to place them - assumes the correct machine definition is in use
sub place_stl_rows {

	my ( $self, $project_block ) = @_;
	$self->set_select_all_off();
	die "Project ID not provided" unless $project_block;
	my $machine_row = $self->query( "select machine from projects where project_block = ? limit 1 ", $project_block )->fetchrow_arrayref();
	die "Machine for project block [$project_block] not found" unless $machine_row;
	my $this_machine = $self->{machine_definitions}->{$machine_row->[0]};
	die "Machine [$machine_row->[0]] not found" unless $this_machine;
	my $row;

	my $this_machine_x_zero = ( $this_machine->{x_dimension} / 2 ) - $this_machine->{x_offset};
	my $this_machine_y_zero = ( $this_machine->{y_dimension} / 2 ) - $this_machine->{y_offset};
	print "\tPlacing on $machine_row->[0] with zero point modifiers [$this_machine_x_zero,$this_machine_y_zero]$/";
	do {
		$row = $self->query(
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
			state ='positioned'
			and project_block  =?
		order by 

			p.y_position	ASC,
			p.x_position	ASC
			", $project_block
		)->fetchrow_hashref();

		unless ( $row ) {
			print "No positioned items found for [$project_block] on machine [$machine_row->[0]]";
			return;
		}
		print "\tPlacing with original position of [$row->{x_position},$row->{y_position}]$/";
		$self->import_and_position(
			$row->{file_path},

			#offsets such as the necessary for M1 are to move the 0 point around as it's always in the middle of the nominal center of the plate otherwise
			[ ( $row->{x_position} - $this_machine_x_zero ), ( $row->{y_position} - $this_machine_y_zero ) ],
			$row->{rotate}
		);
		$self->update(
			'projects',
			{
				'state' => 'placed',
			},
			{
				rowid => $row->{rowid}
			}
		);
	} while ( $row );
	print "Finished positioning items in [$project_block]";
	return;
}

sub clear_for_project {
	my ( $self ) = @_;
	$self->clear_plate();
	$self->dynamic_sleep();
	$self->click_to( "hamburger" );
	$self->dynamic_sleep();
	$self->clear_dynamic_sleep();
	$self->click_to( "new_project" );
	$self->dynamic_sleep();

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

sub slice_and_save {
	my ( $self, $project_block, $p ) = @_;
	$p ||= {};
	$self->click_to( 'viewing_angle' );
	my $project_row = $self->query( "select * from projects where project_block = ? ", $project_block )->fetchrow_hashref();

	die "project row not found" unless $project_row;
	my $this_machine = $self->{machine_definitions}->{$project_row->{machine}};
	$self->wait_for_progress_bar();
	$self->click_to( 'slice_button' );
	$self->dynamic_sleep();
	print "$/Checking for over limit warning$/";
	if ( $self->if_colour_name_at_named( 'over_plate_yes_button', 'slice_platform_yes' ) ) {
		$self->click_to( 'slice_platform_yes' );
		print "$/\t GOING OVER LIMIT$/";
		$self->dynamic_sleep();
	}

	#waiting for slice preview to finish
	$self->wait_for_progress_bar();
	$self->click_to( 'slice_save', {offset => $this_machine->{save_offset} || []} );
	$self->dynamic_sleep();

	my $project_string = join( '_', ( $project_row->{project}, 'P' . uc( $project_row->{project_block} ), uc( $project_row->{machine} ), ) );
	my $o_dir;
	unless ( $p->{o_dir} ) {
		$o_dir = '/home/m/Hobby/Hobby-Huge/Automation/PrintPlates/';
	}

	my $o_path = "$o_dir/$project_string.ctb";
	if ( -e $o_path ) {
		print "[$o_path] already exists!";
	}
	my $measure_path = "$o_dir/$project_string\_measurements.png";
	my $preview_path = "$o_dir/$project_string\_preview.png";
	unlink( $measure_path ) if -e $measure_path;
	unlink( $preview_path ) if -e $measure_path;

	#TODO add margin
	print `import -window root -quality 95 -compress none -negate -crop 330x225+1650+235 $measure_path`;
	print `import -window root -quality 50 -crop 1000x1000+100+100 $preview_path`;
	$o_path = $self->safe_duplicate_path( $o_path );
	print "$/\tsaving to $o_path$/";
	$self->type_enter( $o_path );
	$self->dynamic_wait_for_progress_bar();
	unless ( -f $o_path ) {
		$self->play_sound();
		die "Unknown failure - output file not created";
	}
	$self->click_to( 'slice_back' );
}

sub machine_select {
	my ( $self, $machine_id, $p ) = @_;
	$p ||= {};
	$self->wait_for_progress_bar();
	$self->click_to( 'print_settings' );
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;
	print "$/\tSelecting [$machine_id] at ";
	$self->move_to_named( 'printer_select', {y_mini_offset => $this_machine->{menu_y_position}} );
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->click();
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->move_to_named( 'close_print_settings' );
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->click_to( 'close_print_settings' );

}

sub clear_plate {
	my ( $self ) = @_;
	unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
		$self->click_to( 'select_all' );
	}
	$self->click_to( 'delete_object' );
	$self->wait_for_progress_bar();
}

1;
