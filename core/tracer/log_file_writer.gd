extends RefCounted

const _SUFFIX := "_session.log"

var enabled: bool = true

var _log_dir: String = "user://DCKit/logs"
var _max_files: int = 5
var _file: FileAccess


func configure(log_dir: String, max_files: int, is_enabled: bool) -> void:
	_log_dir = log_dir
	_max_files = max_files
	enabled = is_enabled


# Starts a fresh session file, deleting the oldest ones beyond max_files.
func open_session() -> void:
	_file = null
	if not enabled:
		return

	var err := DirAccess.make_dir_recursive_absolute(_log_dir)
	if err != OK:
		push_warning("LogFileWriter: could not create '%s' (err %d)" % [_log_dir, err])
		return

	_rotate()

	var stamp := Time.get_datetime_string_from_system(false, true) \
			.replace(":", "-") \
			.replace(" ", "_")
	var path := _log_dir.path_join(stamp + _SUFFIX)

	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("LogFileWriter: could not create '%s'" % path)


# The file stays open for the whole session; flush keeps it safe on a crash.
func append(line: String) -> void:
	if not enabled or _file == null:
		return
	_file.store_line(line)
	_file.flush()


func _rotate() -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(_log_dir):
		if f.ends_with(_SUFFIX):
			files.append(f)
	files.sort()

	while not files.is_empty() and files.size() >= _max_files:
		DirAccess.remove_absolute(_log_dir.path_join(files.pop_front()))
