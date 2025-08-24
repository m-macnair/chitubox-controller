CREATE TABLE file_meta (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER,
	is_fragile INTEGER DEFAULT 0
);
CREATE INDEX file_meta_file_id ON file_meta(file_id);
