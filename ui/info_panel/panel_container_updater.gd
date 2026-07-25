@tool
extends PanelContainer

@export var source_panel: PanelContainer:
	set(value):
		source_panel = value
		_update_stylebox()

@export var style_override: StyleBoxFlat:
	set(value):
		style_override = value
		_update_stylebox()

var _in_theme_update := false

func _ready() -> void:
	_update_stylebox()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if _in_theme_update:
			return

		_in_theme_update = true
		_update_stylebox()
		_in_theme_update = false


func _update_stylebox() -> void:
	if !is_inside_tree():
		return

	if source_panel == null:
		remove_theme_stylebox_override("panel")
		return

	var source := source_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if source == null:
		return

	var stylebox := source.duplicate(true) as StyleBoxFlat

	if style_override:
		_merge_stylebox(stylebox, style_override)

	add_theme_stylebox_override("panel", stylebox)

func _merge_stylebox(dst: StyleBoxFlat, src: StyleBoxFlat) -> void:
	dst.bg_color = src.bg_color

	dst.corner_detail = src.corner_detail
	
	dst.corner_radius_top_left = src.corner_radius_top_left
	dst.corner_radius_top_right = src.corner_radius_top_right
	dst.corner_radius_bottom_left = src.corner_radius_bottom_left
	dst.corner_radius_bottom_right = src.corner_radius_bottom_right

	dst.border_color = src.border_color
	dst.border_width_left = src.border_width_left
	dst.border_width_top = src.border_width_top
	dst.border_width_right = src.border_width_right
	dst.border_width_bottom = src.border_width_bottom

	dst.shadow_color = src.shadow_color
	dst.shadow_size = src.shadow_size
	dst.shadow_offset = src.shadow_offset

	dst.expand_margin_left = src.expand_margin_left
	dst.expand_margin_top = src.expand_margin_top
	dst.expand_margin_right = src.expand_margin_right
	dst.expand_margin_bottom = src.expand_margin_bottom

	dst.content_margin_left = src.content_margin_left
	dst.content_margin_top = src.content_margin_top
	dst.content_margin_right = src.content_margin_right
	dst.content_margin_bottom = src.content_margin_bottom

	dst.anti_aliasing = src.anti_aliasing
	dst.anti_aliasing_size = src.anti_aliasing_size

	dst.skew = src.skew
