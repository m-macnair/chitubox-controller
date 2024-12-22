/* original_file 
	table that determines what file counts as an original file as opposed to a softlink file
*/
CREATE TABLE original_file (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER
);

CREATE INDEX  original_file_file_id  ON original_file(file_id);
