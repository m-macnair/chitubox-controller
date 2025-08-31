#!/usr/bin/perl
# ABSTRACT: Multi-purpose chitubox controller and root module of the project
our $VERSION = 'v3.0.21';

##~ DIGEST : 40a37d5597e4d25bf8ec81ddffc56950
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
  Moo::GenericRole::FileIO::CSV
  Moo::GenericRole::ConfigAny

  SlicerController::Role::ManufacturingDB
  SlicerController::Role::Chitubox
  Moo::Task::ControlByGui::Role::Core
  Moo::Task::ControlByGui::Role::Linux

  /;

use Data::Dumper;
use Test::More;
use Time::HiRes qw(
  usleep
  ualarm
  gettimeofday
  tv_interval
  nanosleep
  clock_gettime
  clock_getres
  clock_nanosleep
  clock
  stat
  lstat
  utime
);
use Math::Round;
use List::Util qw(min max);
around "new" => sub {

	#This is apparently the standard
	my $orig = shift;
	my $self = $orig->( @_ );

	$self->_setup();

	#There used to be a reason this was necessary but now everything is handled in _setup

	return $self;

};

sub _setup {
	my ( $self, $p ) = @_;
	$p ||= {};

	my $config = $self->standard_config();
	$self->_do_db();
	$self->ControlByGui_coordinate_map( $self->config_file( $p->{coordinate_map} || './config/chitubox_coordinate_map.perl' ) );
	$self->ControlByGui_values( $self->config_file( $p->{colour_values}          || './config/colour_values.perl' ) );

	my $ui_config = Config::Any::Merge->load_files( {files => [qw{./config/ui.perl}], flatten_to_hash => 0, use_ext => 1} );
	$self->ControlByGui_zero_point( $self->ControlByGui_coordinate_map->{zero_point} );

	$self->{machine_definitions} = Config::Any::Merge->load_files( {files => [qw{./config/machine_definitions.perl}], flatten_to_hash => 0, use_ext => 1} );

	CONFIGVALIDATION: {
		for my $key (
			qw/
			dynamic_sleep_megabyte_size
			/
		  )
		{
			ok( defined( $self->config->{dynamic_sleep_megabyte_size} ), "Combined config key [$key] defined" );
		}

		done_testing();
	}

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
	my ( $self, $p ) = @_;
	$p ||= {};

	#note that .id is ambiguous here and will show up with a null value if accessed without table qualifier
	my $sql = <<SQL;
	select distinct(f.id)
	from file f 
	left join file_dimensions fd 
		on f.id = fd.file_id 
	left join file_meta m 
		on f.id = m.file_id
SQL
	my $supplement = <<SQL2;
	where fd.file_id is null
	and (m.is_supported = 1 or m.file_id is null )
	and ( m.no_dimensions != 1 or m.no_dimensions is null)
SQL2

	my $sth;
	if ( $p->{work_order} ) {
		$supplement .= "$/and wo.name = ? ";
		$sql        .= "left join work_order_element woe on woe.file_id = f .id
		left join work_order wo on woe.work_order_id = wo.id";
		$sth = $self->query( $sql . $supplement, $p->{work_order} );
	} else {
		$sth = $self->query( $sql . $supplement );
	}

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

#load a plate definition, load a packer/s, send all the un-placed file details to the packer/s, pick the best response from the packers and return that
sub get_machine_coordinates_for_work_order {
	my ( $self, $machine_id, $work_order_id, $opt ) = @_;

	die "Machine ID not provided"    unless $machine_id;
	die "Work Order ID not provided" unless $work_order_id;
	my $this_machine = $self->{machine_definitions}->{$machine_id};

	die "Machine [$machine_id] not found" unless $this_machine;

	my $items = $self->get_outstanding_files_for_work_order( $work_order_id, 2, ( ( $this_machine->{x_dimension} * $this_machine->{y_dimension} ) / 4 ) );

	use SlicerController::Class::Packer::GPTPackPlate1;
	my $gpp    = SlicerController::Class::Packer::GPTPackPlate1->new( $this_machine );
	my $return = my $gpp_res = $gpp->pack_items( $items );

	return $return;
}

sub adjust_coordinates_for_center_origin {
	my ( $self, $files, $x, $y );

}

sub get_plate_row {
	my ( $self, $plate_id ) = @_;
	confess 'Plate ID not supplied' unless $plate_id;
	my $plate_row = $self->query( "select * from plate where id = ? limit 1", $plate_id )->fetchrow_hashref();
	confess "plate [$plate_id] not found" unless $plate_row->{id};
	return $plate_row;
}

#from the db positions, actually interact with chitubox to place them -
#
#!!assumes the machine on-screen is correct !!
#

sub place_files_for_plate {

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
	use Data::Dumper;

	# 	die Dumper($self->{machine_definitions});
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
			and (
				woe.on_plate is null
				or
					woe.on_plate = 0
			)
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

#given machine id and array of whatever file ids, place them
sub place_files_on_plate {

	my ( $self, $machine_id, $files ) = @_;
	my $this_machine = $self->get_machine( $machine_id );

	my $this_machine_x_zero = ( $this_machine->{x_dimension} / 2 ) - $this_machine->{x_offset};
	my $this_machine_y_zero = ( $this_machine->{y_dimension} / 2 ) - $this_machine->{y_offset};
	$self->Log( "this_machine_x_zero is 0 - this might not be a problem", {level => 'Attention'} ) unless ( $this_machine_x_zero );
	$self->Log( "this_machine_y_zero is 0 - this might not be a problem", {level => 'Attention'} ) unless ( $this_machine_y_zero );

	$self->set_select_all_off();
	$self->Log( "Placing on [$machine_id] with zero point modifiers [$this_machine_x_zero,$this_machine_y_zero]" );
	for my $row ( @{$files} ) {
		warn Dumper( $row );
		my $x         = ( $row->{x_position} - $this_machine_x_zero );
		my $y         = ( $row->{y_position} - $this_machine_y_zero );
		my $file_path = $self->get_file_path_from_id( $row->{file_id} );
		$self->Log( "Placing [$file_path] with original position of [$row->{x_position},$row->{y_position}] and adjusted position of [$x,$y]" );
		$self->import_and_position(
			$file_path,

			#offsets such as the necessary for M1 are to move the 0 point around as it's always in the middle of the nominal center of the plate otherwise
			[ $x, $y ],
			$row->{rotate}
		);
	}
	$self->Log( "Finished positioning items in [$machine_id]", {level => 'Attention'} );
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

sub get_machine {
	my ( $self, $machine_id ) = @_;
	$machine_id = lc( $machine_id );
	my $this_machine = $self->{machine_definitions}->{$machine_id};
	$self->Log( "[$machine_id] dimensions: [$this_machine->{x_dimension},$this_machine->{y_dimension}]" );
	$self->Log( "[$machine_id] offsets: [$this_machine->{x_offset},$this_machine->{y_offset}]" );
	Carp::confess( "Machine [$machine_id] not found" ) unless $this_machine;
	return $this_machine;

}

1;
