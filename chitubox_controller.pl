#!/usr/bin/perl
# ABSTRACT: POC for chitubox controller role
our $VERSION = 'v1.0.7';

##~ DIGEST : de58783fc2093223b644cd5adc0ba967
use strict;
use warnings;

package ThisObj;
use v5.10;
use Moo;
use Carp;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/
  Moo::GenericRole::DB::Working::AbstractSQLite
  Moo::GenericRole::ControlByGui
  Moo::GenericRole::ControlByGui::Chitubox
  Moo::GenericRole::FileIO::CSV

  /;
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

			#
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
			dimensions => {

				#mm
				'x' => '82',
				'y' => '130',
				'z' => '160',
			},
			margin => 2,
		}
	);

	#TODO: offsets
	$self->{machine_definitions} = {
		'm5' => {id => 'm5', x_dimension => 78, y_dimension => 126, margin => 1},
		'm7' => {id => 'm5', x_dimension => 69, y_dimension => 122, margin => 1},
		'm1' => {id => 'm1', x_dimension => 77, y_dimension => 82,  margin => 1},
	};
	return $self;

};

sub process {
	my ( $self, $res ) = @_;

	given ( $res->{action} ) {
		when ( $res->{action} eq 'full' ) {
			$self->setup_working_db_copy( './stl_processing_template.sqlite' );
			my $stack = $self->get_file_list( $res->{csv_file} );
			for my $row ( @{$stack} ) {
				my $dim = $self->get_single_file_project_dimensions( $row->{path} );
				$self->expand_to_db( $row->{path}, $dim, $row->{count} );
				sleep( 1 ); # required for chitubox reasons
			}

			#M4
			#my $block_1 = {id => 1, x_dimension => 298.080 - 10, y_dimension => 165.600 - 10, margin => 1};
			#M5
			#my $block_1 = {id => 1, x_dimension => 82.620 - 15, y_dimension => 130.560 - 10, margin => 2};

			#$self->position_in_db( $self-> );

			my $row;
			do {
				$row = $self->query( "select *,rowid from files where state ='positioned' and id  =1 " )->fetchrow_hashref();
				last unless $row;

				#$self->import_and_position( $row->{file_path}, [ $row->{x_position} - ( $block_1->{x_dimension} / 2 ), $row->{y_position} - ( $block_1->{y_dimension} / 2 ) ] );
				$self->update(
					'files',
					{
						'state' => 'placed',
					},
					{
						rowid => $row->{rowid}
					}
				);
			} while ( $row );

		}

		when ( $res->{action} eq 'import_csv_to_db' ) {
			if ( $res->{db_file} ) {
				$self->sqlite3_file_to_dbh( $res->{db_file} );
			} else {
				$self->setup_working_db_copy( './stl_processing_template.sqlite' );
			}
			my $stack = $self->get_file_list( $res->{csv_file} );
			for my $row ( @{$stack} ) {
				my $dim = $self->get_single_file_project_dimensions( $row->{path} );
				$self->expand_to_db( $row->{path}, $dim, $row->{count} );
				sleep( 1 ); # required for chitubox reasons
			}
		}

		when ( $res->{action} eq 'existing_db_allocate' ) {
			$self->sqlite3_file_to_dbh( $res->{db_file} );

			for my $machine_id ( split( ',', $res->{machine_ids} ) ) {

				$self->allocate_position_in_db_mk2( lc( $machine_id ), $res->{block_id} );
			}
		}

		when ( $res->{action} eq 'existing_db_place' ) {
			$self->sqlite3_file_to_dbh( $res->{db_file} );
			$self->place_stl_rows( lc( $res->{block_id} ) );
		}

		when ( $res->{action} eq 'export_rotate' ) {
			my $stack = $self->get_file_list( $res->{csv_file} );
			die Dumper( $stack );
			for my $row ( @{$stack} ) {
				$self->import_support_export_file(
					$row->{path},
					{
						pre_supports_sub => sub {
							$self->rotate_file_corner();
						}
					}
				);
				$self->click_to( 'delete' );
			}
		}
		when ( $res->{action} eq 'export_plate' ) {
			$self->export_plate_as_single_files( $res->{dir_target} );

		}

		default {
			die 'No valid action selected';
		}
	}
	print "$/It is done. Move on.$/";

}

sub export_plate_as_single_files {
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

#turn csv file into instruction list
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

sub expand_to_db {
	my ( $self, $string, $xy, $multiple ) = @_;
	while ( $multiple ) {

		$self->insert(
			'files',
			{
				file_path   => $string,
				x_dimension => $xy->[0],
				y_dimension => $xy->[1],
				x_position  => undef,
				y_position  => undef,
			}
		);
		$multiple--;
	}
	$self->dbh->commit();
}

#record top left start absolute positions in the DB to be translated as requried
sub allocate_position_in_db {
	my ( $self, $machine_id, $opt ) = @_;

	my $row;
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;
	THISBLOCK: {
		my $this_band = {
			xc => 0,
			yc => 0,
			yn => 0,
		};
		do {
			$row = $self->query( "select *,rowid from files where state is null order by x_dimension desc, y_dimension desc limit 1" )->fetchrow_hashref();
			if ( $row ) {

				#can this object fit in the x axis?
				my $this_x_start = $this_band->{xc};
				my $this_x_end   = $this_x_start + $row->{x_dimension} + $this_machine->{margin};

				#where should this object start from ?
				my $this_y_start = $this_band->{yc};

				#is this object's y bigger than any previous on this band?
				my $this_y_end = $this_band->{yc} + $row->{y_dimension} + $this_machine->{margin};
				if ( $this_y_end > $this_band->{yn} ) {
					warn "extending Y band : $this_y_end > $this_band->{yn}";
					$this_band->{yn} = $this_y_end;
				}

				if ( $this_x_end >= $this_machine->{x_dimension} ) {
					if ( $this_y_end >= $this_machine->{y_dimension} ) {

						#no more space
						last THISBLOCK;
					} else {
						warn "new x band with $this_x_end";

						#reset calculations for new row
						$this_x_start = 0;
						$this_x_end   = $this_x_start + $row->{x_dimension} + $this_machine->{margin};

						$this_y_start = $this_y_end;
						$this_y_end   = $this_y_start + $row->{y_dimension} + $this_machine->{margin};

						$this_band = {
							xc => $this_x_end,
							yc => $this_y_start,
							yn => $this_y_end
						};
					}

				} else {

					#set the starting point for the next object on x axis
					$this_band->{xc} = $this_x_end;
				}

				#get the middle x position
				my $x_mid = $this_x_start + ( ( $row->{x_dimension} + $this_machine->{margin} ) / 2 );

				#get the middle y position
				my $y_mid = $this_y_start + ( ( $row->{y_dimension} + $this_machine->{margin} ) / 2 );

				$self->update(
					'files',
					{
						'state'    => 'positioned',
						x_position => $x_mid,
						y_position => $y_mid,
						id         => $this_machine->{id}
					},
					{
						rowid => $row->{rowid}
					}
				);

			} else {
				warn "no row";
			}
		} while ( $row );
	}
	my $sum_row = $self->query( "select count(*) as count from files where state is null " )->fetchrow_arrayref();
	if ( $sum_row ) {
		my $count = $sum_row->[0];
		print $/ . "[$count] Items remaining that have not been placed$/";
	}
	return 0;
}

#record top left start absolute positions in the DB to be translated as requried
sub allocate_position_in_db_mk2 {
	my ( $self, $machine_id, $block_id, $opt ) = @_;
	die "Machine ID not provided" unless $machine_id;
	unless ( $block_id ) {
		warn "No explicit block ID provided - defaulting to machine id [$machine_id]";
		sleep( 1 );
		$block_id = $machine_id;
	}

	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;

	my $row;

	my $combined_margin = $this_machine->{margin} * 2;
	my $x_cursor        = 0;
	my $y_cursor        = 0;
	my $next_y_cursor   = 0;
	my $x_space         = $this_machine->{x_dimension};
	my $y_space         = $this_machine->{y_dimension};
	my $get_row_sth     = $self->dbh->prepare( 'select *, rowid from files where state is null and x_dimension <= ? and y_dimension <= ? order by x_dimension desc, y_dimension desc limit 1' );

	while ( 1 ) {
		$get_row_sth->execute( $x_space - $combined_margin, $y_space - $combined_margin );
		$row = $get_row_sth->fetchrow_hashref();

		unless ( $row ) {
			$y_cursor = $next_y_cursor;
			$y_space  = $this_machine->{y_dimension} - $next_y_cursor;
			$x_cursor = 0;
			$x_space  = $this_machine->{x_dimension};

			$get_row_sth->execute( $x_space - $combined_margin, $y_space - $combined_margin );
			$row = $get_row_sth->fetchrow_hashref();
			unless ( $row ) {
				print "No more space on plate for available objects$/";
				last;
			}
		}

		#'band' here signifiying axis aligned band box

		my $x_band_end = $x_cursor + $combined_margin + $row->{x_dimension};
		my $y_band_end = $y_cursor + $combined_margin + $row->{y_dimension};

		#if this object is somehow taller than those before, adjust the future cursor accordingly
		if ( $y_band_end > $next_y_cursor ) {
			warn "adjusting future Y cursor minimum from [$next_y_cursor] to [$y_band_end]";
			$next_y_cursor = $y_band_end;
		}
		my $x_midpoint = ( $x_cursor + $x_band_end ) / 2;
		my $y_midpoint = ( $y_cursor + $y_band_end ) / 2;

		$x_cursor = $x_band_end;
		$x_space  = $this_machine->{x_dimension} - $x_cursor;

		$self->update(
			'files',
			{
				'state'    => 'positioned',
				x_position => $x_midpoint,
				y_position => $y_midpoint,
				id         => $block_id
			},
			{
				rowid => $row->{rowid}
			}
		);

	}

	my $sum_row = $self->query( "select count(*) as count from files where state is null " )->fetchrow_arrayref();
	if ( $sum_row ) {
		my $count = $sum_row->[0];
		print $/ . "[$count] Items remaining that have not been placed$/";
	}
	return 0;
}

sub place_stl_rows {
	my ( $self, $label ) = @_;
	die "label not provided " unless $label;
	my $this_machine = $self->{machine_definitions}->{$label};
	my $row;
	do {
		$row = $self->query( "select *,rowid from files where state ='positioned' and id  =? ", $label )->fetchrow_hashref();
		unless ( $row ) {
			print "No positioned items found for [$label]";
			return;
		}

		$self->import_and_position( $row->{file_path}, [ $row->{x_position} - ( $this_machine->{x_dim ension} / 2 ), $row->{y_position} - ( $this_machine->{y_dimension} / 2 ) ] );
		$self->update(
			'files',
			{
				'state' => 'placed',
			},
			{
				rowid => $row->{rowid}
			}
		);
	} while ( $row );
	print "Finished positioning [$label]";
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

1;

package main;
use Data::Dumper;
main();

sub main {
	my $self = ThisObj->new();

	my $res = $self->get_config(
		[
			qw/

			/
		],
		[
			qw/
			  action
			  csv_file
			  db_file
			  machine_ids
			  block_id
			  dir_target
			  /
		],
		{
			required => {},
			optional => {}
		}
	);
	warn Dumper( $res );
	$self->process( $res );

}
1;
