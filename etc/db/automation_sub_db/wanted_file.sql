/* wanted_file */
CREATE TABLE wanted_file (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER
);
CREATE INDEX  wanted_file_file_id  ON wanted_file(file_id);
