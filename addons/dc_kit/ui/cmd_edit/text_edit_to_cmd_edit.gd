extends TextEdit

signal text_submitted(text: String)

const CmdHighlighter = preload("./dc_syntax_highlighter.gd")

@export var palette := CmdHighlighter.ColorScheme.Tokyo_Night:
	set(new):
		if palette == new:
			return
		palette = new
		if syntax_highlighter != null:
			syntax_highlighter.palette = palette
			syntax_highlighter.update_cache()
		

func _init() -> void:
	syntax_highlighter = CmdHighlighter.new()
	syntax_highlighter.palette = palette

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if not editable:
		return
	var ctrl := false
	if event is InputEventWithModifiers:
		ctrl = event.is_command_or_control_pressed()
	if ctrl and event.keycode == KEY_V:
		get_viewport().set_input_as_handled()
		_my_custom_paste()
		return

	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_submit()
		get_viewport().set_input_as_handled()
		return

	if ctrl:
		match event.keycode:
			KEY_UP:
				_browse_prefix(-1)
				get_viewport().set_input_as_handled()
				return

			KEY_DOWN:
				_browse_prefix(1)
				get_viewport().set_input_as_handled()
				return
	else:
		match event.keycode:
			KEY_UP:
				_browse_history(-1)
				get_viewport().set_input_as_handled()
				return

			KEY_DOWN:
				_browse_history(1)
				get_viewport().set_input_as_handled()
				return
func _my_custom_paste():
	var clipboard_text: String = DisplayServer.clipboard_get()
	var modified_text = clipboard_text.replace("\n", " ").replace("\r", "")
	insert_text_at_caret(modified_text)

func _on_submit() -> void:
	var cmd := text.strip_edges()
	text = "" # this is for force update syntax_highlighter and stop highlighter color bleeding
	text_changed.emit()
	clear()
	clear_undo_history()
	_reset_history_state()
	if not cmd.is_empty():
		if _history.is_empty() or _history.back() != cmd:
			_history.append(cmd)
		text_submitted.emit(cmd)
	if syntax_highlighter:
		syntax_highlighter.clear_highlighting_cache()

func _set_line_text(t: String) -> void:
	text = t
	set_caret_column(t.length())
	text_changed.emit()

#region History
# Storage: oldest-first. _history_index: -1 = draft, 0 = newest, size-1 = oldest.
var _history: Array[String] = []
var _history_index: int = -1
var _draft: String = ""

# direction: -1 = older, +1 = newer
func _browse_history(direction: int) -> void:
	if _history.is_empty():
		return
	# Switching in from prefix mode — keep the draft that was already saved.
	if _prefix_index != -1:
		_prefix_index = -1
		_prefix_matches = []
		_prefix = ""
	if _history_index == -1:
		if direction == 1:   # already at draft, can't go newer
			return
		_draft = text
	# Higher index → older entry, so invert direction for the index arithmetic.
	var next := _history_index - direction
	if next >= _history.size():  # already at oldest, clamp
		return
	if next < 0:                 # navigated past newest → restore draft
		_history_index = -1
		_set_line_text(_draft)
		return
	_history_index = next
	_set_line_text(_history[(_history.size() - 1) - _history_index])
#endregion

#region Prefix Browse
var _prefix: String = ""
var _prefix_matches: Array[String] = []
var _prefix_index: int = -1

func _browse_prefix(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index != -1:
		_history_index = -1
	if _prefix_index == -1:
		if direction == 1:
			return
		_draft = text
		_prefix = text
		_prefix_matches = _history.filter(
			func(cmd: String) -> bool: return cmd.begins_with(_prefix) and cmd != _prefix
		)
		_prefix_matches.reverse()   # newest match at index 0
	if _prefix_matches.is_empty():
		return
	var next := _prefix_index - direction
	if next >= _prefix_matches.size():  # at oldest, clamp
		return
	if next < 0:                         # past newest → restore draft
		_prefix_index = -1
		_set_line_text(_draft)
		return
	_prefix_index = next
	_set_line_text(_prefix_matches[_prefix_index])
#endregion

func _reset_history_state() -> void:
	_history_index  = -1
	_draft          = ""
	_prefix         = ""
	_prefix_matches = []
	_prefix_index   = -1
