# complex_log_view.gd
extends "./log_view_base.gd"

const _GUTTER_LEVEL := 0
# const _GUTTER_FOLD := 1

const _REF_LEVEL := "ERROR"   # widest token — used to size the level gutter

const _EMPTY_TEXT_LINE := 6

# Gutter style properties

## Custom font for the level gutter.
## Leave null to inherit the CodeEdit theme font.
var gutter_font : Font = null:
	set(v):
		gutter_font = v
		if is_instance_valid(_edit):
			_fit_gutter_widths()
			_edit.queue_redraw()

## Point size for gutter text. Set to 0 to inherit the CodeEdit theme size.
var gutter_font_size : int = 0:
	set(v):
		gutter_font_size = v
		if is_instance_valid(_edit):
			_fit_gutter_widths()
			_edit.queue_redraw()

## Per-level colours for the level gutter.
var level_colors : Dictionary = {
	"OK"    : Color("#4EC9B0"),
	"FAIL"  : Color("#F28B82"),
	"WARN"  : Color("#FFD166"),
	"ERROR" : Color("#FF6B6B"),
	"INFO"  : Color("#89B4FA"),
	"CMD"   : Color("#89DCEB"),
	"SYS"   : Color("#6C7086"),
	"HELP"  : Color("#6C7086"),
}:
	set(v):
		level_colors = v
		if is_instance_valid(_edit): _edit.queue_redraw()

## Fallback colour for level tokens not in level_colors.
var level_default_color : Color = Color("#6C7086"):
	set(v):
		level_default_color = v
		if is_instance_valid(_edit): _edit.queue_redraw()


# Private state

var _edit      : CodeEdit
var _line      : int        = 0
var _handler   : BBCodeHandler
var _line_data : Dictionary = {}   # line index → { "entry": LogEntry, "tree": Dictionary, "plain": String }


# Lifecycle

func _ready() -> void:
	# Configure handler — only plain text goes into CodeEdit, so no standard
	# tags need to be allowed. Custom tags are registered for the syntax
	# highlighter to colour later via _line_data.
	_handler = BBCodeHandler.new() \
		.color("error", "#F28B82") \
		.color("warn",  "#FFD166") \
		.color("ok",    "#4EC9B0") \
		.color("muted", "#6C7086") \
		.color("cmd",   "#89DCEB") \
		.color("dim",   "#6C7086")

	_edit = CodeEdit.new()
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.editable = false
	_edit.focus_mode = Control.FOCUS_NONE
	_edit.set_line_folding_enabled(true)
	_edit.indent_size = 1
	_edit.gutters_draw_fold_gutter = true
	_edit.gutters_draw_line_numbers = false
	_edit.gutters_draw_bookmarks = false
	_edit.gutters_draw_breakpoints_gutter = false
	_edit.set_fit_content_width_enabled(true)
	_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_edit.add_gutter(_GUTTER_LEVEL)
	_edit.set_gutter_name(_GUTTER_LEVEL, "level")
	_edit.set_gutter_type(_GUTTER_LEVEL, TextEdit.GUTTER_TYPE_CUSTOM)
	_edit.set_gutter_clickable(_GUTTER_LEVEL, false)
	_edit.set_gutter_custom_draw(_GUTTER_LEVEL, _draw_level_gutter)

	# _edit.add_gutter(_GUTTER_FOLD)
	# _edit.set_gutter_name(_GUTTER_FOLD, "fold")
	# _edit.set_gutter_type(_GUTTER_FOLD, TextEdit.GUTTER_TYPE_STRING)
	# _edit.set_gutter_clickable(_GUTTER_FOLD, true)
	# _edit.gutter_clicked.connect(_on_gutter_clicked)

	add_child(_edit)
	_fit_gutter_widths()
	_on_cleared()

	# Syntax highlighter attach point.
	# Assign a SyntaxHighlighter subclass here that reads from _line_data
	# to produce per-column colour mappings:
	#
	#   _edit.syntax_highlighter = LogSyntaxHighlighter.new(_line_data, level_colors)
	#
	# The highlighter receives the full parsed tree per line so it can walk
	# spans without re-parsing. See _line_data for the stored structure.


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_instance_valid(_edit):
		_fit_gutter_widths()
		_edit.queue_redraw()


# Gutter visibility

func set_level_gutter_visible(v: bool) -> void: _edit.set_gutter_draw(_GUTTER_LEVEL, v)
func is_level_gutter_visible() -> bool: return _edit.is_gutter_drawn(_GUTTER_LEVEL)


# Base overrides

func _append_entry(entry: _InternalLogger.LogEntry) -> void:
	var tree  : Dictionary = _handler.styled_tree(entry.content)
	var plain : String     = _plain_from_styled(tree)
	var indent := " ".repeat(entry.stack.size() * _edit.indent_size)

	_edit.editable = true
	var last := _edit.get_line_count() - 1
	_edit.set_caret_line(last)
	_edit.set_caret_column(_edit.get_line(last).length())
	_edit.insert_text_at_caret(indent + plain + "\n")
	_edit.editable = false

	_edit.set_line_gutter_text(_line, _GUTTER_LEVEL, _badge(entry))

	# tree is now style-resolved — the syntax highlighter walks it directly
	# with no tag-name logic; only "text" leaves and { style, children } branches.
	_line_data[_line] = { "entry": entry, "tree": tree, "plain": indent + plain }

	_line += 1
	_edit.scroll_vertical = _edit.get_line_count()

func _plain_from_styled(node: Dictionary) -> String:
	if node.has("text"):
		return node.text
	var out := ""
	for child : Dictionary in node.children:
		out += _plain_from_styled(child)
	return out

func _on_cleared() -> void:
	_edit.text = "\n".repeat(_EMPTY_TEXT_LINE)
	_line      = _EMPTY_TEXT_LINE
	_line_data.clear()


# Gutter draw

func _draw_level_gutter(line: int, _gutter: int, area: Rect2) -> void:
	var text := _edit.get_line_gutter_text(line, _GUTTER_LEVEL)
	if text.is_empty():
		return
	var font      := _resolve_font()
	var font_size := _resolve_font_size()
	var color     : Color = level_colors.get(text, level_default_color)
	_edit.draw_string(
		font,
		_text_baseline(area, font, font_size),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color)


# Helpers

func _badge(entry: _InternalLogger.LogEntry) -> String:
	return "CMD" if entry.kind == "COMMAND" else \
		   "SYS" if entry.kind == "SYSTEM"  else \
		   entry.level

func _text_baseline(area: Rect2, font: Font, font_size: int) -> Vector2:
	var ascent  := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var y       := area.position.y + (area.size.y - ascent - descent) * 0.5 + ascent
	return Vector2(area.position.x + 4.0, y)

func _resolve_font() -> Font:
	return gutter_font if gutter_font != null else _edit.get_theme_font("font")

func _resolve_font_size() -> int:
	return gutter_font_size if gutter_font_size > 0 \
		else int(_edit.get_theme_font_size("font_size") * 0.9)

func _fit_gutter_widths() -> void:
	if not is_instance_valid(_edit):
		return
	var font      := _resolve_font()
	var font_size := _resolve_font_size()
	var w := int(font.get_string_size(_REF_LEVEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 8
	_edit.set_gutter_width(_GUTTER_LEVEL, w)
