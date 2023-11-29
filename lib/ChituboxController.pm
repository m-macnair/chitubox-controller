#!/usr/bin/perl
# ABSTRACT: Multi-purpose chitubox controller
our $VERSION = 'v2.2.2';

##~ DIGEST : d12d9ae619015eb7baca26d15b3b32a1
use strict;
use warnings;

package ChituboxController;
use v5.10;
use Moo;
use Carp;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/
  Moo::GenericRole::ControlByGui
  Moo::GenericRole::ControlByGui::Chitubox
  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::DB::Working::AbstractSQLite
  /;                                     # AbstractSQLite is a wrapper class for all dbi actions

use Data::Dumper;
use Image::OCR::Tesseract 'get_ocr';
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
  clock_gettime clock_getres clock_nanosleep clock
  stat lstat utime);

around "new" => sub {

	#This is apparently the standard
	my $orig = shift;
	my $self = $orig->( @_ );

	my $y_offset = 0;

	#assuming window is at 0,0
	$self->ControlByGui_coordinate_map(
		{
			hamburger      => [ 35, 75 ],
			'open'         => [ 10, 220 ],
			'open_project' => [ 10, 155 ],
			'rotate_menu'  => [ 10, 460 ],

			#x
			'rotate_x45+' => [ 95,  465 ],
			'rotate_x45-' => [ 145, 495 ],

			#y
			'rotate_y45+' => [ 95,  465 ],
			'rotate_y45-' => [ 145, 495 ],

			'support_menu'      => [ 1840, 135 ],
			'add_supports_mode' => [ 1710, 830 ],
			'light_supports'    => [ 1815, 260 ],
			'add_supports'      => [ 1860, 780 ],

			#???
			'main_settings' => [ 1710, 125 ],
			'delete'        => [ 1905, 185 ],

			#project
			save_project            => [ 35,  190 ],
			save_project_all_models => [ 220, 120 ],
			save_project_single     => [ 250, 150 ],

			#scaling
			scale_button => [ 20,  530 ],
			x_dim        => [ 110, 585 ],
			y_dim        => [ 110, 620 ],
			z_dim        => [ 110, 650 ],

			#positioning
			move_button => [ 20,   360 ],
			x_pos       => [ 160,  390 ],
			y_pos       => [ 160,  425 ],
			select_all  => [ 1830, 195 ],

			progress_bar_xy => [ 10, 1070 ],

			#plate adjustment
			'first_object'  => [ 1633, 240 ],
			'second_object' => [ 1633, 275 ],
			'delete_object' => [ 1900, 200 ],

			#slice & export
			'slice_button' => [ 1700, 700 ],
			'slice_save'   => [ 1780, 560 ],
			'slice_back'   => [ 1780, 770 ],

			#Machine selection
			'print_settings'       => [ 1750, 620 ],
			'close_print_settings' => [ 1500, 240 ],

		}
	);

	$self->ControlByGui_values(
		{
			colour => {
				select_all_on          => '#808080',
				progress_bar_clear     => '#3D3D3D',
				progress_bar_wait      => '#54BBFF',
				xclip_file_path        => '#AFAFAF',
				highlighted_in_objects => '#56C3FF', # >:(
			},
		}
	);

	#offsets are the printing offset values to mask screen problems as defined in the printer setting
	$self->{machine_definitions} = {

		'm0' => {
			id              => 'm1',
			x_dimension     => 77,
			y_dimension     => 82,
			margin          => 1,
			menu_y_position => 165,

			#x_offset => 2,   y_offset => 40
		},
		'm5' => {
			id              => 'm5',
			x_dimension     => 78,
			y_dimension     => 126,
			margin          => 1,
			menu_y_position => 215,

			#x_offset => 1.5, y_offset => .2
		},

		'm7' => {
			id              => 'm5',
			x_dimension     => 69,
			y_dimension     => 122,
			margin          => 1,
			menu_y_position => 285,

			#x_offset => 3,   y_offset => 3
		},
		'm1' => {
			id              => 'm1',
			x_dimension     => 75,
			y_dimension     => 82,
			margin          => 1,
			menu_y_position => 335,

			#'A' and 'D' in the offset menu?
			x_offset => 0,
			y_offset => 18
		},

		#This probably should not be used for automation
		'm4' => {
			id              => 'm4',
			x_dimension     => 192.004,
			y_dimension     => 120,
			margin          => 1,
			menu_y_position => 495,

			#x_offset => 1.5, y_offset => .2
		},

	};
	return $self;

};

sub process {
	my ( $self, $res ) = @_;

	given ( $res->{action} ) {

		# 		when ( $res->{action} eq 'full' ) {
		# 			$self->setup_working_db_copy( './stl_processing_template.sqlite' );
		# 			my $stack = $self->get_file_list( $res->{csv_file} );
		# 			for my $row ( @{$stack} ) {
		# 				my $dim = $self->get_single_file_project_dimensions( $row->{path} );
		# 				$self->expand_to_db( $row->{path}, $dim, $row->{count} );
		# 				sleep( 1 ); # required for chitubox reasons
		# 			}
		#
		# 			my $row;
		# 			do {
		# 				$row = $self->query( "select *,rowid from files where state ='positioned' and id  =1 " )->fetchrow_hashref();
		# 				last unless $row;
		#
		# 				#$self->import_and_position( $row->{file_path}, [ $row->{x_position} - ( $block_1->{x_dimension} / 2 ), $row->{y_position} - ( $block_1->{y_dimension} / 2 ) ] );
		# 				$self->update(
		# 					'files',
		# 					{
		# 						'state' => 'placed',
		# 					},
		# 					{
		# 						rowid => $row->{rowid}
		# 					}
		# 				);
		# 			} while ( $row );
		#
		# 		}

		when ( $res->{action} eq 'import' ) {

			$self->import_work_list( $res );

		}

		when ( $res->{action} eq 'dimensions' ) {
			$self->get_outstanding_dimensions( $res );
		}

		when ( $res->{action} eq 'allocate_single' ) {
			$self->_do_db( $res );

			for my $machine_id ( split( ',', $res->{machine_ids} ) ) {

				$self->allocate_position_in_db_mk2( lc( $machine_id ), $res->{project_id} );
			}
		}

		when ( $res->{action} eq 'place' ) {
			$self->_do_db( $res );
			$self->place_stl_rows( lc( $res->{block_id} ) );
		}

		#TODO: hard_place - force the specific machine for given project id

		when ( $res->{action} eq 'export' ) {
			$self->export_plate_as_single_file_projects( $res->{dir_target} );
		}

		default {
			die 'No valid action selected';
		}
	}
	print "$/It is done. Move on.$/";

}

sub _do_db {
	my ( $self, $res ) = @_;
	$res ||= {};
	if ( $res->{db_file} ) {
		$self->sqlite3_file_to_dbh( $res->{db_file} );
	} else {

		#$self->setup_working_db_copy( './working_db.sqlite' );
		$self->sqlite3_file_to_dbh( './working_db.sqlite' );
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

		while ( $project_row_href->{count} ) {

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

		#die "working on $file_row->{file_path}";
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
		unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
			$self->click_to( 'select_all' );
		}
		$self->click_to( 'first_object' );

		#better contrast when the target item is the one highlighted after the select all has been turned off
		$self->click_to( 'select_all' );

		my $path = $self->tmp_dir;
		$path = './working_mono.png';
		print `import -window root -quality 95 -compress none -negate -crop 275x27+1630+225 $path`;
		my $text = get_ocr( $path );
		$text =~ s/\#.*//;
		$text =~ s/stl//;
		$text =~ s/\.//;
		$text = lc( substr( $text, 1 ) );
		$text =~ s/^\s+|\s+$//g;
		$text =~ s/\s/_/g;

		$self->click_to( 'first_object' ); # actually select the first object
		$self->position_selected( 0, 0 );

		my $out_path = $self->safe_duplicate_path( "$out_dir/$text.chitubox" );
		$self->click_to( 'main_settings' );
		$self->click_to( "hamburger" );
		$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
		sleep( 1 );
		$self->click_to( 'save_project_single' );
		$self->type_enter( $out_path );

		#Today the lesson is - 1. wait for progress always and 2. lock the screen (smartly) when an action is actioning in  a gui application
		$self->wait_for_progress_bar();
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
				warn( "[$file_path] not found" );
				sleep( 1 );
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

	my $row;

	my $combined_margin = $this_machine->{margin} * 2;
	my $x_cursor        = 0;
	my $y_cursor        = 0;
	my $next_y_cursor   = 0;
	my $x_space         = $this_machine->{x_dimension};
	my $y_space         = $this_machine->{y_dimension};
	my $get_row_sth     = $self->dbh->prepare( '
		select 
			f.file_path,
			f.x_dimension ,
			f.y_dimension, 
			p.rowid,
			p.file_id
		from files f 
		join projects p 
			on f.rowid = p.file_id 
		where 
			project_block is null
			and (
					(f.x_dimension <= ? and f.y_dimension <= ?)
				or
					(f.y_dimension <= ? and f.x_dimension <= ?)
			)
			and project = ? 
		order by 
			f.x_dimension desc, 
			f.y_dimension desc 
		limit 1' );

	while ( 1 ) {
		my $available_x = $x_space - $combined_margin;
		my $available_y = $y_space - $combined_margin;
		print "\tSeeking with [$available_x,$available_y]$/";
		$get_row_sth->execute( $available_x, $available_y, $available_x, $available_y, $project_id );

		$row = $get_row_sth->fetchrow_hashref();

		unless ( $row ) {

			$y_cursor    = $next_y_cursor;
			$y_space     = $this_machine->{y_dimension} - $next_y_cursor;
			$x_cursor    = 0;
			$x_space     = $this_machine->{x_dimension};
			$available_x = $x_space - $combined_margin;
			$available_y = $y_space - $combined_margin;
			print "\t\tRe-seeking with [$available_x,$available_y]$/";
			$get_row_sth->execute( $available_x, $available_y, $available_x, $available_y, $project_id );

			$row = $get_row_sth->fetchrow_hashref();
			unless ( $row ) {
				print "\t\tNo objects available for remaining space of [$available_x, $available_y]$/";
				last;
			}
		}

		#did we find something that's best rotated
		my ( $new_x, $new_y, $rotate );
		if ( $row->{x_dimension} > $available_x ) {
			warn "Rotated $row->{rowid}";
			$new_x  = $row->{y_dimension};
			$new_y  = $row->{x_dimension};
			$rotate = 90;
		} else {
			$new_x = $row->{x_dimension};
			$new_y = $row->{y_dimension};

		}

		#'band' here signifying axis aligned band box
		my $x_band_end = $x_cursor + $combined_margin + $new_x;
		my $y_band_end = $y_cursor + $combined_margin + $new_y;

		#if this object is somehow taller than those before, adjust the future cursor accordingly
		if ( $y_band_end > $next_y_cursor ) {
			print "\tadjusting future Y cursor minimum from [$next_y_cursor] to [$y_band_end]$/";
			$next_y_cursor = $y_band_end;
		}

		my $x_midpoint = ( $x_cursor + $x_band_end ) / 2;
		my $y_midpoint = ( $y_cursor + $y_band_end ) / 2;
		print "\tPlaced file # [$row->{file_id}] which is [$new_x,$new_y] at [$x_midpoint,$y_midpoint]$/";

		$x_cursor = $x_band_end;
		$x_space  = $this_machine->{x_dimension} - $x_cursor;

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

	}
	my $sum_row = $self->query( "select max(project_block) from projects " )->fetchrow_arrayref();
	my $max     = $sum_row->[0];
	if ( $max <= 0 ) {
		$max = 1;
	} else {
		$max++;
	}

	$self->query( "update projects set project_block = ? where project_block = -1", $max );
	my $assigned_row  = $self->query( "select count(*) as count from projects where project_block = ? ",                     $max )->fetchrow_arrayref();
	my $remaining_row = $self->query( "select count(*) as count from projects where project_block is null and project = ? ", $project_id )->fetchrow_arrayref();
	print "$/\tPlaced [$assigned_row->[0]] Items in Block [$max] $/\t[$remaining_row->[0]] Items remaining that have not been placed$/";
	return 0;
}

#from the db positions, actually interact with chitubox to place them
sub place_stl_rows {
	my ( $self, $project_block ) = @_;
	die "Project ID not provided" unless $project_block;
	my $machine_row = $self->query( "select machine from projects where project_block = ? limit 1 ", $project_block )->fetchrow_arrayref();
	die "Machine for project block [$project_block] not found" unless $machine_row;
	my $this_machine = $self->{machine_definitions}->{$machine_row->[0]};
	die "Machine [$machine_row->[0]] not found" unless $this_machine;
	my $row;

	my $this_machine_x_zero = ( $this_machine->{x_dimension} / 2 ) + $this_machine->{x_offset};
	my $this_machine_y_zero = ( $this_machine->{y_dimension} / 2 ) + $this_machine->{y_offset};
	print "\tPlacing on $machine_row->[0] with zero point modifiers [$this_machine_x_zero,$this_machine_y_zero]$/";
	do {
		$row = $self->query(
			"select 
			f.file_path,
			f.x_dimension ,
			f.y_dimension, 
			p.x_position ,
			p.y_position, 
			p.rowid
		from files f 
		join projects p 
			on f.rowid = p.file_id 
		where 
			state ='positioned'
			and project_block  =? ", $project_block
		)->fetchrow_hashref();

		unless ( $row ) {
			print "No positioned items found for [$project_block] on machine [$machine_row->[0]]";
			return;
		}
		print "\tPlacing with original position of [$row->{x_position},$row->{y_position}]$/";
		$self->import_and_position(
			$row->{file_path},

			#offsets such as the necessary for M1 are to move the 0 point around as it's always in the middle of the nominal center of the plate otherwise
			[ ( $row->{x_position} - $this_machine_x_zero ), ( $row->{y_position} - $this_machine_y_zero ) ]
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
		) or die "!?";
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
	my $project_row = $self->query( "select * from projects where project_block = ? ", $project_block )->fetchrow_hashref();
	die "project row not found" unless $project_row;

	$self->wait_for_progress_bar();
	$self->click_to( 'slice_button' );
	$self->wait_for_progress_bar();
	$self->click_to( 'slice_save' );
	my $project_string = join( '_', ( $project_row->{project}, uc( $project_row->{machine} ), 'P' . uc( $project_row->{project_block} ), ) );
	my $o_dir;
	unless ( $p->{o_dir} ) {
		require FindBin;
		$o_dir = $FindBin::Bin;
	}

	my $o_path = "$o_dir/$project_string.chitubox";
	if ( -e $o_path ) {
		print "[$o_path] already exists!";
	}
	$o_path = $self->safe_duplicate_path( $o_path );
	print "$/\tsaving to $o_path$/";
	$self->type_enter( $o_path );
	sleep( 3 );
	$self->wait_for_progress_bar();
	my $measure_path = "$o_dir/$project_string.png";
	unlink( $measure_path ) if -e $measure_path;
	print `import -window root -quality 95 -compress none -negate -crop 330x225+1650+235 $measure_path`;
	$self->click_to( 'slice_back' );
}

sub machine_select {
	my ( $self, $machine_id, $p ) = @_;
	$p ||= {};
	$self->wait_for_progress_bar();
	$self->click_to( 'print_settings' );
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;
	print "$/\t Selecting [$machine_id]";
	$self->move_to( [ 450, 225 + $this_machine->{menu_y_position} ] );
	$self->click();
	sleep( 1 ); #loading time non-trivial
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
