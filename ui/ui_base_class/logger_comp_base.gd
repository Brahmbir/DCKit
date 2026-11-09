extends Container

var _logger_ref: WeakRef = null

var _hint := """[i][b][color=gray]Keyboard shortcuts:[/color][/b]
[color=#858aa0][color=gray]Autocomplete[/color]
		[b]Ctrl+Space[/b] — toggle autocomplete
		[b]Up[/b] / [b]Down[/b] / [b]Tab[/b] — navigate suggestions (when open)
		[b]Enter[/b] — accept highlighted suggestion (when open)
		[b]Esc[/b] — close autocomplete (when open)
[color=gray]History[/color]
		[b]Up[/b] / [b]Down[/b] — navigate history
		[b]Ctrl+Up[/b] / [b]Ctrl+Down[/b] — navigate prefix-matched history
[color=gray]Misc[/color]
		[b]Enter[/b] — submit
		[b]Ctrl+Shift+Space[/b] — expand/collapse info panel[/i][/color]"""


func set_colour_map(data := { }):
	_DCKitNS.not_implemented("set_colour_map")
	return


func connect_logger(logger: _DCKitNS.Core.Tracer) -> void:
	var previous := _get_logger()
	_detach()
	_logger_ref = weakref(logger) if logger else null

	if is_inside_tree():
		_attach()

	# Hint is tied to the logger changing, so re-calling setup() with the
	# same logger doesn't spam it.
	if logger and logger != previous:
		logger.simple_print(_hint)


func _get_logger() -> _DCKitNS.Core.Tracer:
	return _logger_ref.get_ref() if _logger_ref else null


func _attach() -> void:
	var logger := _get_logger() as _DCKitNS.Core.Tracer
	if logger == null:
		return
	if not logger.entry_added.is_connected(_append_entry):
		logger.entry_added.connect(_append_entry)
	if not logger.cleared.is_connected(_on_cleared):
		logger.cleared.connect(_on_cleared)


func _detach() -> void:
	var logger := _get_logger()
	if logger == null:
		return
	if logger.entry_added.is_connected(_append_entry):
		logger.entry_added.disconnect(_append_entry)
	if logger.cleared.is_connected(_on_cleared):
		logger.cleared.disconnect(_on_cleared)


func _append_entry(entry: _DCKitNS.Core.Tracer.LogEntry) -> void:
	_DCKitNS.not_implemented("_append_entry")
	return


func _on_cleared() -> void:
	_DCKitNS.not_implemented("_on_cleared")
	return
