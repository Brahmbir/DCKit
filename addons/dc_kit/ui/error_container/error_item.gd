extends PanelContainer

signal pressed(pos: int, len: int)

@onready var title: Label = %kind
@onready var location: Label = %location
@onready var message_lbl: RichTextLabel = %message
@onready var button: Button = $Button

var _pos := -1
var _len := -1
var _pending_data: Dictionary = {}

var col_error := Color("ff6b6b")
var col_warn := Color("ffd166")
var col_hint := Color("4dabf7")

func set_color(_col_error: Color, _col_warn: Color, _col_hint: Color) -> void:
	col_error = _col_error
	col_warn = _col_warn
	col_hint = _col_hint

func set_diagnostic_data(data: Dictionary) -> void:
	_pending_data = data
	if is_node_ready():
		_apply_data(data)

func _ready() -> void:
	button.pressed.connect(_on_btn_pressed)
	if not _pending_data.is_empty():
		_apply_data(_pending_data)

func _on_btn_pressed() -> void:
	if _pos == -1 or _len == -1:
		return
	pressed.emit(_pos, _len)

func _apply_data(data: Dictionary) -> void:
	message_lbl.text = " " + str(data.get("message", ""))

	_pos = int(data.get("position", -1))
	_len = int(data.get("length", -1))

	location.text = str(data.get("range_text", ""))
	location.add_theme_font_size_override(
		"font_size",
		int(location.get_theme_font_size("font_size") * 0.7)
	)

	title.text = str(data.get("source_name", ""))
	
	var color := Color.AZURE
	match int(data.get("severity", 0)):
		2:color = col_error
		1:color = col_warn
		0:color = col_hint

	title.add_theme_color_override("font_color", color)
	self_modulate = color
