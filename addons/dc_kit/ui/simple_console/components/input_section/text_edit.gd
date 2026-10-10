extends TextEdit

signal text_submitted(text: String)

## Owned by the parent UI. Swapping it (or the input) ends any browse session.
var _history: _DCKitNS.UI.CommandHistory
## Text we last put into the box ourselves; null once the user edits or submits.
var _shown: Variant = null


func _enter_tree() -> void:
	text_changed.connect(_on_user_edited)


func _exit_tree() -> void:
	text_changed.disconnect(_on_user_edited)


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not editable:
		return

	var ctrl := key.is_command_or_control_pressed()

	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			accept_event()
			_submit()
		KEY_UP:
			accept_event()
			if _history != null:
				_show(_history.browse_older(text, ctrl))
		KEY_DOWN:
			accept_event()
			if _history != null:
				_show(_history.browse_newer(text))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return false # TODO one day wasted
	return editable and typeof(data) == TYPE_STRING


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not editable or not data is String:
		return
	insert_text_at_caret(_to_single_line(data as String))


func set_history_obj(new_history: _DCKitNS.UI.CommandHistory) -> void:
	if _history == new_history:
		return
	if _history != null:
		_history.reset_browse() # end the session on the old object too
	_history = new_history
	_shown = null
	if _history != null:
		_history.reset_browse()


func _submit() -> void:
	var cmd := text.strip_edges()
	_shown = null
	clear()

	if _history != null:
		_history.push(cmd) # ignores empty, dedupes, resets browse

	if not cmd.is_empty():
		text_submitted.emit(cmd)


func _show(t: String) -> void:
	if t == text:
		return
	_shown = t
	text = t
	set_caret_column(t.length())


func _on_user_edited() -> void:
	# Ignore the change event caused by our own _show().
	if _shown != null and text == _shown:
		return
	_shown = null
	if _history != null:
		_history.reset_browse()


func _to_single_line(text: String) -> String:
	return text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ").strip_edges()


func _paste(caret_index: int) -> void:
	_paste_single_line(caret_index)


func _paste_primary_clipboard(caret_index: int) -> void:
	_paste_single_line(caret_index)


func _paste_single_line(caret_col := -1) -> void:
	var clip := DisplayServer.clipboard_get()
	insert_text_at_caret(_to_single_line(clip), caret_col)
