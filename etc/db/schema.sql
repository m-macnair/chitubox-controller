CREATE TABLE file_type (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	suffix TEXT NOT NULL UNIQUE,
	mime_type TEXT NOT NULL
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX file_type_suffix ON file_type(suffix);
CREATE INDEX file_type_mime_type ON file_type(mime_type);
CREATE TABLE dir (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL,
	host TEXT
);
CREATE INDEX dir_name ON dir(name);
CREATE INDEX dir_host ON dir(host);
CREATE TABLE hash (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER,
	hashed BOOLEAN CHECK (hashed IN (0, 1)),
	md5_string TEXT,
	sha1_string TEXT
);
CREATE INDEX hash_file_id ON hash(file_id);
CREATE INDEX hash_md5_string ON hash(md5_string);
CREATE INDEX hash_sha1_string ON hash(sha1_string);
CREATE TABLE file (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL,
	dir_id INTEGER,
	file_type_id INTEGER,
	hash_id INTEGER,
	size INTEGER
);
CREATE INDEX file_name ON file(name);
CREATE INDEX file_dir_id ON file(dir_id);
CREATE INDEX file_file_type_id ON file(file_type_id);
CREATE INDEX file_hash_id ON file(hash_id);
CREATE INDEX file_size ON file(size);
CREATE TABLE plate (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	machine TEXT NOT NULL
, file_id INTEGER);
CREATE TABLE file_dimensions (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	file_id INTEGER,
	x_dimension REAL,
	y_dimension REAL,
	z_dimension REAL
);
CREATE INDEX file_dimensions_file_id ON file_dimensions(file_id);
CREATE TABLE file_meta (
id INTEGER PRIMARY KEY AUTOINCREMENT,
file_id INTEGER,
is_supported BOOLEAN 
, no_dimensions BOOLEAN);
CREATE TABLE work_order (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL UNIQUE
);
CREATE TABLE work_order_element (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	work_order_id INTEGER,
	file_id INTEGER,
	plate_id INTEGER,
	x_position REAL,
	y_position REAL,
	positioned BOOLEAN,
	on_plate BOOLEAN,
	rotate REAL
);
CREATE INDEX work_order_element_plate_id ON work_order_element(plate_id);
CREATE INDEX work_order_element_project_name ON work_order_element(work_order_id);
CREATE TABLE plate_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER,
        plate_id INTEGER,
        type TEXT
);

/* Not every work order will have one and this is correct in cases where plates were multi-order etc */
CREATE TABLE work_order_plate (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_order_id INTEGER,
        plate_id INTEGER
);
CREATE INDEX work_order_plate_plate_id ON work_order_plate(plate_id);
CREATE INDEX work_order_plate_work_order_id ON work_order_plate(work_order_id);
