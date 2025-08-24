/* source_to_part 
	table that determines what file counts as an original file as opposed to a softlink file
*/
CREATE TABLE source_to_part (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	source_id INTEGER,
	part_id INTEGER
);

CREATE INDEX  source_to_part_source_id ON source_to_part(source_id);
CREATE INDEX  source_to_part_part_id  ON source_to_part(part_id);
