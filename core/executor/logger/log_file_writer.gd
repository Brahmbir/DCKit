extends RefCounted

class_name LogFileWriter

var enabled: bool = true

var _file_path: String = ""
var _log_dir: String = "user://DCKit/logs/"
var _max_files: int = 5


func configure(log_dir: String, max_files: int, is_enabled: bool) -> void:
	_log_dir = log_dir
	_max_files = max_files
	enabled = is_enabled


func open_session() -> void:
	if not enabled:
		return

	var err := DirAccess.make_dir_recursive_absolute(_log_dir)
	if err != OK:
		push_warning("LogFileWriter: could not create log dir '%s' (err %d)" % [_log_dir, err])
		return

	var dir := DirAccess.open(_log_dir)
	if dir == null:
		push_warning("LogFileWriter: could not open log dir '%s'" % _log_dir)
		return

	var files: Array = []

	dir.list_dir_begin()

	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with("_session.log"):
			files.append(f)
		f = dir.get_next()

	dir.list_dir_end()

	files.sort()

	while files.size() >= _max_files:
		DirAccess.remove_absolute(_log_dir + files.pop_front())

	var datetime := Time.get_datetime_string_from_system(false, true) \
		.replace(":", "-") \
		.replace(" ", "_")

	_file_path = _log_dir + datetime + "_session.log"

	var file := FileAccess.open(_file_path, FileAccess.WRITE)

	if file == null:
		push_warning("LogFileWriter: could not create '%s'" % _file_path)
		_file_path = ""
		return

	file.store_line("=== DevConsole session %s ===" % datetime)
	file.store_line("")
	file.close()


func append(line: String) -> void:
	if not enabled or _file_path.is_empty():
		return

	var file := FileAccess.open(_file_path, FileAccess.READ_WRITE)

	if file == null:
		file = FileAccess.open(_file_path, FileAccess.WRITE)

	if file == null:
		push_warning("LogFileWriter: lost access to '%s'" % _file_path)
		_file_path = ""
		return

	file.seek_end()
	file.store_line(line)
	file.close()
