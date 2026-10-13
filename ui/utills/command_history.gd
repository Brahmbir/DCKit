extends RefCounted

signal changed ## emitted when entries change (hook persistence/UI here)

const FILE_NAME = "command_history.json"

var max_size: int = _DCKitSetting.get_history_limit()

var path_dir: String = _DCKitSetting.get_history_directory() # "user://DCKit/"

var path: String:
	get:
		return path_dir.path_join(FILE_NAME)
## Enabling loads from disk, set `path` first.
var persist: bool = _DCKitSetting.get_history_enabled():
	set(value):
		if persist == value:
			return
		persist = value
		if persist:
			load_from_disk()

var _entries: Array[String] = [] # oldest-first
var _matches: Array[String] = [] # current browse list, newest-first
var _cursor: int = -1 # -1 = draft, 0 = newest match
var _draft: String = ""
var _by_prefix: bool = false


func _init() -> void:
	if persist:
		load_from_disk()


func push(cmd: String) -> void:
	reset_browse()
	cmd = cmd.strip_edges()
	if cmd.is_empty():
		return
	if not _entries.is_empty() and _entries.back() == cmd:
		return
	if _entries.size() > max_size:
		_entries.remove_at(0)
	_entries.append(cmd)
	changed.emit()
	_save_if_enabled()


## Returns the text to display. Returns current_text unchanged if there's nowhere to go.
func browse_older(current_text: String, by_prefix := false) -> String:
	if _entries.is_empty():
		return current_text
	# New session, or mode switched mid-browse: rebuild from the original draft.
	if _cursor == -1 or by_prefix != _by_prefix:
		_start(current_text if _cursor == -1 else _draft, by_prefix)
	if _cursor + 1 >= _matches.size():
		return current_text
	_cursor += 1
	return _matches[_cursor]


func browse_newer(current_text: String) -> String:
	if _cursor == -1:
		return current_text
	_cursor -= 1
	return _draft if _cursor == -1 else _matches[_cursor]


## Call on submit (push does it already), and whenever an input component is attached/swapped.
func reset_browse() -> void:
	_cursor = -1
	_draft = ""
	_matches = []


func get_entries() -> Array[String]:
	return _entries.duplicate()


func clear() -> void:
	_entries.clear()
	reset_browse()
	changed.emit()
	_save_if_enabled()


func load_from_disk() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_disable_persist("can't read %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Array:
		return
	var merged: Array[String] = []
	for item in data:
		if item is String and not item.is_empty():
			merged.append(item)
	merged.append_array(_entries) # in-memory entries are newer than disk
	if merged.size() > max_size:
		merged = merged.slice(merged.size() - max_size)
	_entries.assign(merged)
	reset_browse()
	changed.emit()


func save_to_disk() -> void:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		_disable_persist("can't create %s (error %d)" % [path.get_base_dir(), err])
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_disable_persist("can't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(_entries))


func _start(draft: String, by_prefix: bool) -> void:
	_draft = draft
	_by_prefix = by_prefix
	_cursor = -1
	_matches = _entries.filter(
		func(cmd: String) -> bool:
			return not by_prefix or (cmd.begins_with(draft) and cmd != draft),
	)
	_matches.reverse()


func _disable_persist(reason: String) -> void:
	push_warning("History: %s, persistence disabled" % reason)
	persist = false


func _save_if_enabled() -> void:
	if persist:
		save_to_disk()
