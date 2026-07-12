# simple_log_view.gd
extends "./log_view_base.gd"
const _C := {
	"OK"    : "#4EC9B0",
	"FAIL"  : "#F28B82",
	"WARN"  : "#FFD166",
	"ERROR" : "#FF6B6B",
	"INFO"  : "#89B4FA",
	"CMD"   : "#89DCEB",
	"HELP"  : "#6C7086",
	"SYS"   : "#6C7086",
	"muted" : "#6C7086",
	"plain" : "#CDD6F4",
}
var _label : RichTextLabel
func _ready() -> void:
	_label = RichTextLabel.new()
	_label.name = "simple_log_viewer"
	_label.bbcode_enabled = true
	_label.scroll_following = true
	_label.selection_enabled = true
	_label.fit_content = false
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	_label.focus_mode = Control.FOCUS_NONE
	_on_cleared()
	
func _append_entry(entry: _DCKitNamespace.Tracer.LogEntry) -> void:
	_render_entry(entry)
	_label.add_text("\n")
func _on_cleared() -> void:
	_label.clear()
	_label.add_text("\n".repeat(3))
	#_label.text = "\n".repeat(3)
# Rendering
func _render_entry(entry: _DCKitNamespace.Tracer.LogEntry) -> void:
	_render_badge(_badge_level(entry))
	_label.add_text("  ")
	match entry.kind:
		"SYSTEM":
			_label.push_color(Color.html(_C.muted))
			_render_body(entry.content)
			_label.pop()
		"RESULT", "LOG":
			if entry.level == "HELP":
				_label.push_color(Color.html(_C.muted))
				_label.push_italics()
				_render_body(entry.content)
				_label.pop()  # italics
				_label.pop()  # color
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
	_label.push_color(Color.html(_C.get(level, _C.muted)))
	_label.add_text("[%s]" % level)
	_label.pop()
func _badge_level(entry: _DCKitNamespace.Tracer.LogEntry) -> String:
	match entry.kind:
		"COMMAND": return "CMD"
		"SYSTEM": return "SYS"
		"RESULT", "LOG":
			if entry.level == "HELP": return "HELP"
			return entry.level
	return ""
