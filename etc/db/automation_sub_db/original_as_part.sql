/* original_as_part 
	table that determines what file counts as an original file as opposed to a softlink file
*/
CREATE TABLE original_as_part (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER
);

CREATE INDEX  original_as_part_file_id  ON original_as_part(file_id);
