my $default_margin = .75;

#Offset is where the zero point is from 0,0 - which if there is an offset in the A/B/C/D fields, means the median value of the two; if both sides of an axis have the same offset, the midpoint is zero, if not, it drifts

sub get_menu_position_coord {
	my ( $position ) = @_;

	#y345 is the starting position including the vertical offset ; the positions are relative to the top left of the menu, not the screen
	#consequently the y offset should be <something> - 220 to be absolute
	#this starts at 0
	my $button_height     = 39;        #from top of the button to the top of the next button - 1 ; 39 px
	my $mid_point         = 20;
	my $starting_position = 340 - 220 + $button_height; # bottom of first machine button
	return $starting_position + ( $position  * $button_height ) - $mid_point;
}

return {
# 	'm0' => {
# 		id          => 'm1',
# 		x_dimension => 77,
# 		y_dimension => 82,
# 		margin      => $default_margin,
# 
# 		# 			menu_y_position => 165,
# 		menu_y_position => get_menu_position_coord( 0 ),
# 
# 		#x_offset => 2,   y_offset => 40
# 	},
# 	'm5' => {
# 		id          => 'm5',
# 		x_dimension => 60,
# 		y_dimension => 70,
# 		margin      => $default_margin,
# 
# 		# 			menu_y_position => 215,
# 		menu_y_position => get_menu_position_coord( 0 ),
# 
# 		y_offset => 59.5 / 2,
# 	},

	'm6' => {
		id          => 'm6',
		x_dimension => 64,
		y_dimension => 116,
		margin      => $default_margin,

		#			menu_y_position => 245,
		menu_y_position => get_menu_position_coord( 1 ),
		x_offset => 0,
		y_offset => 0
	},

	'm7' => {
		id          => 'm7',
		x_dimension => 68,
		y_dimension => 110,
		margin      => $default_margin,

		# 			menu_y_position => 285,
		menu_y_position => get_menu_position_coord( 2 ),

		x_offset => -2,
		y_offset => -5
	},

	'm3' => {
		id          => 'm3',
		x_dimension => 184,
		y_dimension => 112,
		margin      => $default_margin,

		# 			menu_y_position => 495,
		menu_y_position => get_menu_position_coord( 3 ),
		save_offset => [ 0, 55 ], #offset for the save dialogue button due to other options

		#x_offset => 1.5, y_offset => .2
	},

	'm8' => {	
		id          => 'm8',
		x_dimension => 80,
		y_dimension => 128,
		margin      => $default_margin,

		# 			menu_y_position => 495,
		menu_y_position => get_menu_position_coord( 5 ),
		#save_offset => [ 0, 55 ], #offset for the save dialogue button due to other options

		x_offset => 0,
		y_offset => -1
	},
	

# 	'm1' => {
# 		id          => 'm1',
# 		x_dimension => 75,
# 		y_dimension => 82,
# 		margin      => $default_margin,
# 
# 		#			menu_y_position => 335,
# 		menu_y_position => get_menu_position_coord( 8 ),
# 
# 		#'A' and 'D' in the offset menu?
# 		x_offset => 0,
# 		y_offset => 18
# 	},

	'm4' => {
		id          => 'm4',
		x_dimension => 188,
		y_dimension => 116,
		margin      => $default_margin,

		# 			menu_y_position => 495,
		menu_y_position => get_menu_position_coord( 9 ),
		save_offset => [ 0, 55 ], #offset for the save dialogue button due to other options - for network attached printers

		x_offset => 1,
		y_offset => -1
	},

	'm9' => {
		id          => 'm9',
		x_dimension => 188,
		y_dimension => 116,
		margin      => $default_margin,

		# 			menu_y_position => 495,
		menu_y_position => get_menu_position_coord( 7 ),
		save_offset => [ 0, 55 ], #offset for the save dialogue button due to other options - for network attached printers

		x_offset => 1,
		y_offset => -1
	},

	
	
};

