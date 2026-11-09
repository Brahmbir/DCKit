extends "../../../ui_base_class/logger_comp_base.gd"

const SYMBOL_MAP := {
	"OK": "✓",
	"FAIL": "X",
	"ERROR": "X",
	"WARN": "!",
	"INFO": "i",
	"HELP": "?",
	"DEBUG": "D",
	"CMD": ">",
	"SYS": "-",
}

## When the log reaches this many lines, the oldest [member trim_lines] are dropped.
@export var max_lines: int = 1500
@export var trim_lines: int = 650

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


func _enter_tree() -> void:
	_ensure_label()
	_attach()


func _exit_tree() -> void:
	_detach()


func set_colour_map(data := { }):
	COLOR_MAP = data
	return


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


func _append_entry(entry: _DCKitNS.Core.Tracer.LogEntry) -> void:
	_render_entry(entry)
	_label.add_text("\n")
	_trim_if_needed()


func _trim_if_needed() -> void:
	if _label.get_paragraph_count() < max_lines:
		return
	for i in mini(trim_lines, max_lines):
		_label.remove_paragraph(0)


func _on_cleared() -> void:
	_label.clear()


# Rendering
func _render_entry(entry: _DCKitNS.Core.Tracer.LogEntry) -> void:
	_render_badge(entry.tag)
	if entry.kind == "SYSTEM" or entry.level == "HELP":
		_label.push_color(COLOR_MAP.get("muted", Color.WHITE))
	if entry.level == "HELP":
		_label.push_italics()
	_render_body(entry.content)


func _render_body(text: String) -> void:
	# Raw text is fed straight to the RichTextLabel's own bbcode parser.
	# pop_all() guarantees that any tag left open by malformed/unbalanced
	# markup in this entry cannot bleed into the next entry's styling.
	_label.append_text(text)
	_label.pop_all()


func _render_badge(level: String, details: String = "") -> void:
	if level.is_empty():
		return
	var hinted := not details.is_empty()
	if hinted:
		_label.push_hint(details)
	_label.push_color(COLOR_MAP.get(level, COLOR_MAP.get("muted", Color.WHITE)))
	_label.add_text("[%s]" % SYMBOL_MAP.get(level, "-"))
	_label.pop() # color
	if hinted:
		_label.pop() # hint
	_label.add_text(" ")
