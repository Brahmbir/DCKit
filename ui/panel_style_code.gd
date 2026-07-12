@tool extends PanelContainer

@export var animation_duration := 0.2

@export var debug_focus_effect := false:
	set(new):
		if new == debug_focus_effect:
			return
		debug_focus_effect = new 
		_on_focus_changed(new)


const CmdEdit = preload("./cmd_edit/cmd_edit.gd")
@onready var command_submiter :CmdEdit= %CmdEdit

var _style: StyleBoxFlat
var _tween: Tween
var _highlighted_colour := Color.BLACK
var _normal_colour := Color.BLACK


func _ready() -> void:
	theme_changed.connect(set_colors)
	set_colors()
	
	_style = get_theme_stylebox("panel").duplicate()
	_style.set_expand_margin_all(1)
	_style.set_content_margin_all(1)
	
	add_theme_stylebox_override("panel",_style)
	
	if command_submiter:
		command_submiter.focus_changed.connect(_on_focus_changed)
	if debug_focus_effect:
		_on_focus_changed(true)

func set_colors():
	_highlighted_colour = get_theme_color("highlighted_colour","Consts")
	_normal_colour = get_theme_color("normal_colour","Consts")

func _on_focus_changed(has_focus: bool) -> void:
	if _style == null:
		return

	if _tween:_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	if has_focus:
		var glow := _highlighted_colour
		glow.a = 0.05

		_tween.tween_property(_style,"border_color",_highlighted_colour,animation_duration)
		_tween.tween_property(_style,"shadow_size",14,animation_duration)
		_tween.tween_property(_style,"shadow_color",glow,animation_duration)

	else:
		var shadow := _highlighted_colour
		shadow.a = 0.0

		_tween.tween_property(_style,"border_color",_normal_colour,animation_duration)
		_tween.tween_property(_style,"shadow_size",0,animation_duration)
		_tween.tween_property(_style,"shadow_color",shadow,animation_duration)
