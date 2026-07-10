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

var _label   : RichTextLabel
var _handler : BBCodeHandler

func _ready() -> void:
	_handler = BBCodeHandler.new() \
		.allow(["b", "i", "u", "s", "color", "wave", "tornado", "rainbow", "shake", "url"]) \
		.color("error", "#F28B82") \
		.color("warn",  "#FFD166") \
		.color("ok",    "#4EC9B0") \
		.color("muted", "#6C7086") \
		.color("cmd",   "#89DCEB") \
		.color("dim",   "#6C7086")
	_label = RichTextLabel.new()
	_label.focus_mode = Control.FOCUS_NONE
	_label.bbcode_enabled = true
	_label.scroll_following = true
	_label.selection_enabled = true
	_label.fit_content = false
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
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
	_render_node(_handler.styled_tree(text))


func _render_node(node: Dictionary) -> void:
	if node.has("text"):
		_label.add_text(node.text)
		return

	var s      : Dictionary = node.style
	var pushed : bool       = false

	if   s.has("color"):                  _label.push_color(s.color);       pushed = true
	elif s.get("bold",          false):   _label.push_bold();                pushed = true
	elif s.get("italic",        false):   _label.push_italics();             pushed = true
	elif s.get("underline",     false):   _label.push_underline();           pushed = true
	elif s.get("strikethrough", false):   _label.push_strikethrough();       pushed = true

	for child : Dictionary in node.children:
		_render_node(child)

	if pushed:
		_label.pop()


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
