to use:

	perlll to load the libraries normally
	
	#load the list of files to process
	script/work_order/import.pl <csv>
	
	#Detect and resolve missing dimension records
	script/setup/get_dimensions.pl
	
	#distribute project elements around machines
	script/work_order/import.pl <comma seperated machine tags> [work order name || default]
	
$work_order_string

ALTER TABLE plate
ADD COLUMN file_id INTEGER
