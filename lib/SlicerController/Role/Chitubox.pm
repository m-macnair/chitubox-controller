# ABSTRACT : Module for interacting with Chitubox using ControlByGui
package SlicerController::Role::Chitubox;
our $VERSION = 'v0.0.18';

##~ DIGEST : da7e70fae5e8a8379bac6875db3bdfd8
use strict;
use Moo::Role;
use 5.006;
use warnings;
use Data::Dumper;
use Carp;
use List::Util 'first';
use Clipboard;

=head1 VERSION & HISTORY
	<breaking revision>.<feature>.<patch>
	1.0.0 - 2023-11-18
		Port from chitubox_controller_3.pl
=cut

ACCESSORS: {
	has chitubox_pid => (
		is   => 'rw',
		lazy => 1,
	);
}

MODIFIERS: {
	around "check_application_status" => sub {
		my $orig = shift;
		my $self = shift;
		return $self->determine_chitubox_status();
	};
}

sub place_stl {
	my ( $self, $row, $x_current, $y_current ) = @_;
	my $x_half = ( $self->ControlByGui_values()->{margin} + $row->{x_dimension} ) / 2;
	my $y_half = ( $self->ControlByGui_values()->{margin} + $row->{y_dimension} ) / 2;

	my $x_pos = $$x_current + $x_half;
	if ( ( $x_pos + $x_half ) > $self->ControlByGui_values->{dimensions}->{'x'} ) {
		$$x_current = 0;
		$$y_current += $y_half * 2;
		$x_pos = $$x_current + $x_half;
	}
	$$x_current += $x_half * 2;

	my $y_pos = $$y_current + $y_half;

	#TODO augment select statement to use available space? Add a 'tried but can't' field?
	if ( ( $y_pos + $y_half ) > $self->ControlByGui_values->{dimensions}->{'y'} ) {

		#TODO detect duplicates, act efficiently
		Carp::carp( "Cannot fit object [$row->{file_path}] on this row" );
		return;
	}

	$x_pos = $x_pos - ( $self->ControlByGui_values->{dimensions}->{'x'} / 2 );
	$y_pos = $y_pos - ( $self->ControlByGui_values->{dimensions}->{'y'} / 2 );
	return {
		path => $row->{file_path},
		xy   => [ $x_pos, $y_pos ],
		done => $row->{rowid}
	};
}

sub import_and_position {
	my ( $self, $file, $xy, $rotate ) = @_;
	$rotate ||= 0;
	print "\tPlacing\n\t[$file]\n\t[ $xy->[0],$xy->[1]] rotating [$rotate]\n";
	$self->adjust_sleep_for_file( $file );
	$self->open_file( $file );
	my $colour = $self->get_colour_at_coordinates( $self->ControlByGui_coordinate_map->{select_all} );
	if ( $colour eq $self->ControlByGui_values->{colour}->{select_all_on} ) {
		print "\tSelect all detected - disabling$/";
		$self->click_on( 'select_all' );
	}
	$self->click_on( 'scale_button' );

	#rotate first as chitubox can change the center point
	if ( $rotate ) {
		$self->click_on( 'rotate_menu' );
		$self->click_on( 'z_rot' );

		# 		sleep(1);
		$self->xdo_key( 'BackSpace' );

		# 		sleep(1);
		$self->type_enter( qq{" $rotate"} );

		# 		sleep(1);
		$self->click_on( 'rotate_menu' );

		# 		sleep(1);
	}

	$self->click_on( 'move_button' );

	# 	sleep(1);
	$self->click_on( 'x_pos' );

	# 	sleep(1);
	$self->xdo_key( 'BackSpace' );

	# 	sleep(1);
	#TODO: verify if the leading space is required
	$self->type_enter( qq{" $xy->[0]"} );

	# 	sleep(1);
	# 	warn "pre y click";
	# 	sleep(2);
	$self->click_on( 'y_pos' );

	# 	sleep(1);
	$self->xdo_key( 'BackSpace' );

	# 	sleep(1);
	# 	warn "here  [$xy->[1]] ";
	# 	sleep(1);
	$self->type_enter( qq{" $xy->[1]"} );

	# 	sleep(1);
	#close the menu
	$self->click_on( 'move_button' );

}

sub position_selected {
	my ( $self, $x, $y ) = @_;

	$self->click_on( 'move_button' );
	$self->click_on( 'x_pos' );
	$self->xdo_key( 'BackSpace' );

	#TODO: verify if the leading space is required
	$self->type_enter( " $x" );
	$self->click_on( 'y_pos' );
	$self->xdo_key( 'BackSpace' );
	$self->type_enter( " $y" );

	#close the menu
	$self->click_on( 'move_button' );

}

sub get_single_file_project_dimensions {
	my ( $self, $file ) = @_;

	print "working on $file $/";
	my ( $name, $dir, $suffix ) = $self->file_parse( $file );
	unless ( first { /$suffix/ } qw/ .chitubox .stl .obj/ ) {
		confess "[$file] is not a compatible file";
	}

	#TODO test openfile
	$self->click_on( 'main_settings' );
	$self->click_on( "hamburger" );
	$self->click_on( 'open_project' );
	$self->paste_string( $file );

	$self->adjust_sleep_for_file( $file );
	$self->dynamic_sleep();
	$self->wait_for_progress_bar();

	my $ref = $self->get_current_dimensions();
	$self->click_on( 'delete' );
	$self->clear_dynamic_sleep();
	return $ref;

}

sub get_current_dimensions {
	my ( $self ) = @_;

	$self->click_on( 'mirror_button' ); # clear any previous menu
	$self->click_on( 'scale_button' );
	$self->click_on( 'x_dim' );
	my $x = $self->return_text();

	$self->click_on( 'y_dim' );
	my $y = $self->return_text();

	$self->click_on( 'z_dim' );
	my $z = $self->return_text();

	#close the scale menu
	$self->click_on( 'scale_button' );
	return [ $x, $y, $z ];

}

sub set_supports_for_directory_files {
	my ( $self, $dir ) = @_;

	$self->sub_on_directory_files(
		sub {
			my ( $file ) = @_;
			print "working on $file $/";
			my ( $name, $dir, $suffix ) = $self->file_parse( $file );

			return 1 unless ( first { /$suffix/ } qw/ .obj .stl / );
			$self->import_support_export_file( $file );

			$self->click_on( 'delete' );
			sleep 1;
			return 1;
		},
		$dir
	);

}

sub open_file {
	my ( $self, $file ) = @_;
	Carp::confess( "File [$file] unavailable" ) unless $self->is_a_file( $file );
	$self->click_on( 'main_settings' );
	$self->click_on( "hamburger" );
	$self->hover_click( "open" );
	$self->adjust_sleep_for_file( $file );

	#can be improved with copy paste facilty perhaps
	$self->paste_string( $file );
	$self->dynamic_sleep();
	$self->wait_for_progress_bar();
}

sub open_multiple_files {
	my ( $self, $stack ) = @_;

	for my $file ( @$stack ) {
		Carp::confess( "File path [$file] unavailable" ) unless $self->is_a_file( $file );
		$self->adjust_sleep_for_file( $file );
	}
	$self->click_on( 'main_settings' );
	$self->click_on( "hamburger" );
	$self->hover_click( "open" );

	my @string_stack = map { qq{\"$_\"} } @$stack;
	use Data::Dumper;
	my $string = join( ',', @string_stack );
	$self->paste_string( $string );
	$self->dynamic_sleep();
	$self->wait_for_progress_bar();
}

sub machine_select {
	my ( $self, $machine_id, $p ) = @_;
	$p ||= {};
	$self->wait_for_progress_bar();
	$self->click_on( 'print_settings' );

	#this causes a crash potentially?
	sleep( 1 );
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;
	print "$/\tSelecting [$machine_id] at ";
	$self->move_to_named( 'printer_select', {y_mini_offset => $this_machine->{menu_y_position}} );
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->click();
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->move_to_named( 'close_print_settings' );
	$self->dynamic_sleep(); #highlight transitions cause crashes
	$self->click_on( 'close_print_settings' );

}

#content & DB agnostic slice & save
sub slice_and_save_plate_to {
	my ( $self, $dir, $name_string, $machine_id ) = @_;
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	die "Machine [$machine_id] not found" unless $this_machine;

	$self->click_on( 'viewing_angle' );
	$self->hover_click( 'slice_button' );
	my $o_path = $self->make_path( "$dir/$name_string/" );

	$self->Log( "Checking for over limit warning" );
	if ( $self->if_colour_name_at_named( 'over_plate_yes_button', 'slice_platform_yes' ) ) {
		$self->hover_click( 'slice_platform_yes' );
		$self->Log( "GOING OVER LIMIT", {level => 'ALERT'} );
		$self->dynamic_sleep();
	}

	#waiting for slice preview to finish
	$self->wait_for_progress_bar();
	$self->Log( "save offset: $this_machine->{save_offset}", {level => 'ALERT'} );
	$self->hover_click( 'slice_save', {offset => $this_machine->{save_offset} || []} );
	$self->dynamic_sleep();

	my $measure_path = "$o_path/measurements.png";
	my $preview_path = "$o_path/preview.png";
	my $sliced_path  = "$o_path/$name_string.ctb";
	unlink( $measure_path ) if -e $measure_path;
	unlink( $preview_path ) if -e $measure_path;

	#TODO add margins as this does not work right now
	# 	print `import -window root -quality 95 -compress none -negate -crop 330x225+1650+235 $measure_path`;
	# 	print `import -window root -quality 50 -crop 1000x1000+100+100 $preview_path`;

	$self->Log( "saving to $sliced_path" );
	$self->paste_string( $sliced_path );
	sleep( 3 ); #because it can still fail
	$self->dynamic_wait_for_progress_bar();
	unless ( -f $sliced_path ) {
		$self->play_sound();
		die "Unknown failure - output file not created";
	}
	$self->click_on( 'slice_back' );
	return $sliced_path;
}

sub slice_and_save_plate_old {
	my ( $self, $plate_id, $p ) = @_;
	$p ||= {};
	$self->click_on( 'viewing_angle' );
	my $plate_row = $self->query( "select * from plate where id = ?", $plate_id )->fetchrow_hashref();

	my $this_machine = $self->{machine_definitions}->{$plate_row->{machine}};

	my $o_dir;
	unless ( $p->{o_dir} ) {
		$o_dir = $self->config->{sliced_files_directory};
	}

	#TODO make this actually a write check; add sugar
	die "output path [$o_dir] not writable" unless -d $o_dir;

	my $plate_name_string;
	GETPLATENAMESTRING: {
		my $name_query_sth = $self->query( 'select distinct(wo.name) from plate join work_order_element woe on woe.plate_id = plate.id join work_order wo on woe.work_order_id = wo.id where plate.id =? order by name desc', $plate_id );

		while ( my $row = $name_query_sth->fetchrow_arrayref() ) {
			if ( $plate_name_string ) {
				$plate_name_string .= ",$row->[0]";
			} else {
				$plate_name_string = $row->[0];
			}
		}

		#[ and ] not allowed in file names
		$plate_name_string = sprintf( '%s-%s-%s', lc( $plate_row->{machine} ), $plate_name_string, $plate_id );
	}

	my $extra_path             = $self->make_path( "$o_dir/$plate_name_string\_extra" );
	my $backup_project_path    = $self->export_file_all( $self->safe_duplicate_path( "$extra_path/$plate_name_string\_backup_project.chitubox" ) );
	my $backup_project_file_id = $self->get_file_id( $backup_project_path );

	$self->insert( 'plate_files', {file_id => $backup_project_file_id, plate_id => $plate_id, type => 'backup project'} );

	$self->wait_for_progress_bar();
	$self->hover_click( 'slice_button' );

	print "$/Checking for over limit warning$/";
	if ( $self->if_colour_name_at_named( 'over_plate_yes_button', 'slice_platform_yes' ) ) {
		$self->hover_click( 'slice_platform_yes' );
		print "$/\t GOING OVER LIMIT$/";
		$self->dynamic_sleep();
	}

	#waiting for slice preview to finish
	$self->wait_for_progress_bar();
	warn "save offset: $this_machine->{save_offset}";
	$self->hover_click( 'slice_save', {offset => $this_machine->{save_offset} || []} );
	$self->dynamic_sleep();

	my $o_path = "$o_dir/$plate_name_string.ctb";
	if ( -e $o_path ) {

		#TODO: sound prompt? console prompt?
		print "[$o_path] already exists!";
	}

	my $measure_path = "$extra_path/$plate_name_string\_measurements.png";
	my $preview_path = "$extra_path/$plate_name_string\_preview.png";
	unlink( $measure_path ) if -e $measure_path;
	unlink( $preview_path ) if -e $measure_path;

	#TODO add margins as this does not work right now
	# 	print `import -window root -quality 95 -compress none -negate -crop 330x225+1650+235 $measure_path`;
	# 	print `import -window root -quality 50 -crop 1000x1000+100+100 $preview_path`;
	$o_path = $self->safe_duplicate_path( $o_path );

	print "$/\tsaving to $o_path$/";
	$self->paste_string( $o_path );
	sleep( 3 ); #because it can still fail
	$self->dynamic_wait_for_progress_bar();
	unless ( -f $o_path ) {
		$self->play_sound();
		die "Unknown failure - output file not created";
	}
	my $output_file_id = $self->get_file_id( $o_path );
	$self->insert( 'plate_files', {file_id => $output_file_id, plate_id => $plate_id, type => 'sliced file'} );
	$self->click_on( 'slice_back' );
}

sub clear_plate {
	my ( $self ) = @_;
	unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
		$self->click_on( 'select_all' );
	}
	$self->click_on( 'delete_object' );
	$self->wait_for_progress_bar();
	$self->set_select_all_off();
}

sub export_file_all {
	my ( $self, $out_path ) = @_;

	return $self->_export_file( $out_path, {export_button_name => 'save_project_all_models'} );

}

sub export_file_single {
	my ( $self, $out_path ) = @_;
	if ( -e $out_path ) {
		my $msg = "File [$out_path] already exists!";
		$self->Log( $msg );
		die $msg;
	}
	return $self->_export_file( $out_path, {export_button_name => 'save_project_single'} );

}

sub _export_file {
	my ( $self, $out_path, $p ) = @_;

	$self->click_on( 'main_settings' );
	$self->click_on( "hamburger" );
	$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
	sleep( 1 );
	$self->click_on( $p->{export_button_name} );

	$self->paste_string( $out_path );
	$self->wait_for_progress_bar();
	$self->click_on( 'hamburger' );
	return $out_path;

}

sub center_export_first_file {
	my ( $self, $out_path, $p ) = @_;

	#switch off export multi
	$self->set_select_all_off();
	$self->click_on( 'first_object' );
	$self->position_selected( 0, 0 );
	my $path = $self->export_file_single( $out_path, $p );
	$self->wait_for_progress_bar();
	unless ( $self->is_a_file( $path ) ) {

		$self->play_sound();
		Carp::confess( "Path [$path] does not exist after export - probably a silent failure" );
	}
	return $path;

}

sub import_support_export_file {
	my ( $self, $file, $opt ) = @_;
	$opt ||= {};

	$self->open_file( $file );
	if ( defined( $opt->{'pre_supports_sub'} ) ) {
		&{$opt->{pre_supports_sub}}();
	}
	$self->auto_supports();

	$self->click_on( 'main_settings' );
	$self->click_on( "hamburger" );
	$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
	sleep( 1 );
	$self->click_on( 'save_project_all_models' );
	my $out_path = $opt->{out_path};

	unless ( $out_path ) {
		my ( $name, $dir, $suffix ) = $self->file_parse( $file );
		my $new_path = qq{$dir/$name.chitubox};
		$out_path = $self->safe_duplicate_path( $new_path );
	}
	print $out_path;

}

sub rotate_file_x {
	my ( $self ) = @_;
	for my $click_on (
		qw/
		rotate_menu
		rotate_x45+
		rotate_menu
		/
	  )
	{
		$self->click_on( $click_on );
	}
}

sub rotate_file_y {
	my ( $self ) = @_;
	for my $click_on (
		qw/
		rotate_menu
		rotate_y45+
		rotate_menu
		/
	  )
	{
		$self->click_on( $click_on );
	}
}

sub rotate_file_corner {
	my ( $self ) = @_;
	for my $click_on (
		qw/
		rotate_menu
		rotate_x45-
		rotate_y45+
		rotate_menu
		/
	  )
	{
		$self->click_on( $click_on );
	}

}

sub auto_supports {
	my ( $self ) = @_;
	$self->click_on( 'support_menu' );
	$self->wait_for_progress_bar();
	for my $click_on (
		qw/
		add_supports_mode
		light_supports
		add_supports
		/
	  )
	{
		$self->click_on( $click_on );
		sleep( 3 );
		$self->wait_for_progress_bar();
	}
	$self->wait_for_progress_bar();
}

sub wait_for_progress_bar {
	my ( $self ) = @_;
	my ( $x, $y ) = @{$self->get_named_xy_coordinates( 'progress_bar_xy' )};
	$self->wait_for_pixel_colour( $x, $y, $self->ControlByGui_values()->{colour}->{progress_bar_clear} );
}

sub dynamic_wait_for_progress_bar {
	my ( $self, $sleep, $p ) = @_;
	$self->dynamic_sleep( $sleep, $p );
	$self->wait_for_progress_bar();
}

sub set_select_all_on {
	my ( $self ) = @_;
	unless ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
		$self->Log( "Enabling select_all" );
		$self->click_on( 'select_all' );
	}
}

sub set_select_all_off {
	my ( $self ) = @_;
	if ( $self->if_colour_name_at_named( 'select_all_on', 'select_all' ) ) {
		$self->Log( "Disabling select_all" );
		$self->click_on( 'select_all' );
		sleep( 1 );
	}
}

sub get_chitubox_pid {
	my ( $self ) = @_;
	if ( $self->chitubox_pid() ) {
		return $self->chitubox_pid();
	} else {
		my @output = `ps -ef | grep -i \./Chitubox`;
		for my $line ( @output ) {
			if ( $self->match_ps_for_chitubox( $line ) ) {
				my @fields = split( /\s+/, $line );
				$self->chitubox_pid( $fields[1] );
				return $self->chitubox_pid();
			}
		}
		Carp::cluck( 'Chitubox PID could not be determined from ps -ef' );
		return 0;
	}
}

sub determine_chitubox_status {
	my ( $self )     = @_;
	my $chitubox_pid = $self->get_chitubox_pid();
	my @output       = `ps -fp $chitubox_pid`;
	for my $line ( @output ) {
		if ( $self->match_ps_for_chitubox( $line ) ) {
			return 1;
		}
	}
	$self->play_sound();
	Carp::confess( "Chitubox PID [$chitubox_pid] did not return a valid process ID from ps -fp - Chitubox probably crashed" );
	return 0;
}

#This will be a problem one day - the order matters and the folder structure would be an issue
sub match_ps_for_chitubox {
	my ( $self, $line ) = @_;
	if (   ( $line =~ 'konsole --hold -e ./CHITUBOX' && index( $line, 'grep' ) == -1 )
		or ( $line =~ "./CHITUBOX$/" && index( $line, 'grep' ) == -1 )
		or ( $line =~ "./Chitubox$/" && index( $line, 'grep' ) == -1 ) )
	{
		return 1;
	}
	return;
}

sub clear_for_project {
	my ( $self ) = @_;
	$self->clear_plate();
	$self->dynamic_sleep();
	$self->click_on( "hamburger" );
	$self->dynamic_sleep();
	$self->clear_dynamic_sleep();

	#this may fix a crash caused by the highlight not having time to show
	$self->hover_click( 'new_project' );
	$self->dynamic_sleep();

}

=head2 export_plate_as_single_file_projects
	export a working plate with multiple projects as multiple individual projects - these are the items to actually print 
=cut

sub export_plate_as_single_file_projects {
	my ( $self, $out_dir, $p ) = @_;
	die 'THIS IS OBSOLETE BUT MAY BE USEFUL REWRITTEN';
	unless ( $out_dir ) {
		print "Output directory defaulting to ./";
		$out_dir = './';
	}
	die "Invalid directory [$out_dir]" unless ( -d $out_dir );

	$p ||= {};
	my $has_remaining;
	do {
		$self->set_select_all_off();
		$self->click_on( 'first_object' );

		#better contrast when the target item is the one highlighted after the select all has been turned off
		$self->click_on( 'select_all' );

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

		$self->click_on( 'first_object' ); # actually select the first object
		$self->position_selected( 0, 0 );

		my $out_path = $self->safe_duplicate_path( "$out_dir/$text.chitubox" );
		$self->click_on( 'main_settings' );
		$self->click_on( "hamburger" );
		$self->move_to_named( 'save_project' ); # this is a hover menu so we need to give it time to appear
		$self->dynamic_sleep();
		$self->click_on( 'save_project_single' );
		$self->paste_string( $out_path );

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

		$self->click_on( 'first_object' );

		$self->click_on( 'delete_object' );
		$self->adjust_sleep_for_removed_file( $out_path );

		#check if more objects remain
		$self->click_on( 'first_object' );

		$has_remaining = $self->if_colour_name_at_named( 'highlighted_in_objects', 'first_object' );

	} while ( $has_remaining );

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
