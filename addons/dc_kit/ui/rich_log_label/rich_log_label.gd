extends "../ui_base_class/logger_comp_base.gd"

var COLOR_MAP := {
	"OK": Color("4EC9B0"),
	"FAIL": Color("F28B82"),
	"WARN": Color("FFD166"),
	"ERROR": Color("FF6B6B"),
	"INFO": Color("89B4FA"),
	"CMD": Color("89DCEB"),
	"HELP": Color("6C7086"),
	"SYS": Color("6C7086"),
	"muted": Color("6C7086"),
	"plain": Color("CDD6F4"),
}

@export var _label: RichTextLabel

var _hint := """[i][b][color=gray]Keyboard shortcuts:[/color][/b]
[color=#858aa0][color=gray]Autocomplete[/color]
		[b]Ctrl+Space[/b] — toggle autocomplete
		[b]Up[/b] / [b]Down[/b] — navigate suggestions (when open)
		[b]Tab[/b] / [b]Enter[/b] — accept highlighted suggestion (when open)
		[b]Esc[/b] — close autocomplete (when open)
[color=gray]History[/color]
		[b]Up[/b] / [b]Down[/b] — navigate history
		[b]Ctrl+Up[/b] / [b]Ctrl+Down[/b] — navigate prefix-matched history
[color=gray]Misc[/color]
		[b]Enter[/b] — submit
		[b]Ctrl+Shift+Space[/b] — expand/collapse info panel[/i][/color]"""

var _logger_ref: WeakRef = null


func _enter_tree() -> void:
	_ensure_label()
	_attach()


func _exit_tree() -> void:
	_detach()


# PUBLIC API
# Attach to [param logger]. Safe to call multiple times — swaps loggers cleanly.
func connect_logger(logger: _DCKitNS.Executor.Tracer) -> void:
	var previous := _get_logger()
	_detach()
	_logger_ref = weakref(logger) if logger else null

	# Hint is tied to the logger changing, so re-calling setup() with the
	# same logger doesn't spam it.
	if logger and logger != previous:
		logger.simple_print(_hint)

	if is_inside_tree():
		_attach()


func _get_logger() -> _DCKitNS.Executor.Tracer:
	return _logger_ref.get_ref() if _logger_ref else null


func _attach() -> void:
	var logger := _get_logger() as _DCKitNS.Executor.Tracer
	if logger == null:
		return
	if not logger.entry_added.is_connected(_append_entry):
		logger.entry_added.connect(_append_entry)
	if not logger.cleared.is_connected(_on_cleared):
		logger.cleared.connect(_on_cleared)
	_replay_all(logger) # resync, covers anything missed while detached


func _detach() -> void:
	var logger := _get_logger()
	if logger == null:
		return
	if logger.entry_added.is_connected(_append_entry):
		logger.entry_added.disconnect(_append_entry)
	if logger.cleared.is_connected(_on_cleared):
		logger.cleared.disconnect(_on_cleared)


func _ensure_label() -> void:
	if _label:
		return
	_label = RichTextLabel.new()
	_label.name = "simple_log_viewer"
	_label.bbcode_enabled = true
	_label.scroll_following = true
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.selection_enabled = true
	_label.fit_content = false
	_label.focus_mode = Control.FOCUS_ACCESSIBILITY
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.theme_type_variation = &"Looger_RichTextLabel"
	add_child(_label)


func _append_entry(entry: _DCKitNS.Executor.Tracer.LogEntry) -> void:
	_render_entry(entry)
	_label.add_text("\n")


func _on_cleared() -> void:
	_label.clear()


# Rendering
func _render_entry(entry: _DCKitNS.Executor.Tracer.LogEntry) -> void:
	_render_badge(_badge_level(entry))
	match entry.kind:
		"SYSTEM":
			_label.push_color(COLOR_MAP.get("muted", Color.WHITE))
			_render_body(entry.content)
			#_label.pop()
		"RESULT", "LOG":
			if entry.level == "HELP":
				_label.push_color(COLOR_MAP.get("muted", Color.WHITE))
				_label.push_italics()
				_render_body(entry.content)
			else:
				_render_body(entry.content)
		_:
			_render_body(entry.content)


func _render_body(text: String) -> void:
	# Raw text is fed straight to the RichTextLabel's own bbcode parser.
	# pop_all() guarantees that any tag left open by malformed/unbalanced
	# markup in this entry cannot bleed into the next entry's styling.
	_label.append_text(text)
	_label.pop_all()


func _render_badge(level: String) -> void:
	if level.is_empty():
		return
	_label.push_color(COLOR_MAP.get(level, COLOR_MAP.get("muted", Color.WHITE)))
	_label.add_text("[%s]  " % level)
	_label.pop()


func _badge_level(entry: _DCKitNS.Executor.Tracer.LogEntry) -> String:
	match entry.kind:
		"COMMAND":
			return "CMD"
		"SYSTEM":
			return "SYS"
		"RESULT", "LOG":
			if entry.level == "HELP":
				return "HELP"
			return entry.level
	return ""


func _replay_all(logger: _DCKitNS.Executor.Tracer) -> void:
	_on_cleared()
	if logger == null:
		return
	for entry: _DCKitNS.Executor.Tracer.LogEntry in logger.get_all():
		_append_entry(entry)
