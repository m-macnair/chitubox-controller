return  
{
	#sleep for 1 second for every X megabytes of files currently loaded - stops the progress bars being skipped
	dynamic_sleep_megabyte_size => 50,
	#divide the sleep value by this when it's less likely to be significant (rounding up)
	dynamic_sleep_short_divider => 5,
	sliced_files_directory => '/home/m/git/chitubox-controller/sliced/',
};
