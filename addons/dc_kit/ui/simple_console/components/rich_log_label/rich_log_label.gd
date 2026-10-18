extends "../../../ui_base_class/logger_comp_base.gd"

@export var _label: RichTextLabel

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


func set_colour_map(data:={}):
	COLOR_MAP = data
	return


func _enter_tree() -> void:
	_ensure_label()
	_attach()


func _exit_tree() -> void:
	_detach()


# PUBLIC API
# Attach to [param logger]. Safe to call multiple times — swaps loggers cleanly.
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
