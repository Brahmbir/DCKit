extends RefCounted

signal changed ## emitted when entries change (hook persistence/UI here)

var max_size: int = 500

var _entries: Array[String] = []  # oldest-first
var _matches: Array[String] = []  # current browse list, newest-first
var _cursor: int = -1             # -1 = draft, 0 = newest match
var _draft: String = ""
var _by_prefix: bool = false


func push(cmd: String) -> void:
	reset_browse()
	cmd = cmd.strip_edges()
	if cmd.is_empty():
		return
	if not _entries.is_empty() and _entries.back() == cmd:
		return
	_entries.append(cmd)
	if _entries.size() > max_size:
		_entries.remove_at(0)
	changed.emit()


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


func _start(draft: String, by_prefix: bool) -> void:
	_draft = draft
	_by_prefix = by_prefix
	_cursor = -1
	_matches = _entries.filter(
		func(cmd: String) -> bool:
			return not by_prefix or (cmd.begins_with(draft) and cmd != draft)
	)
	_matches.reverse()
