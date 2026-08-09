@tool
extends MarginContainer
## Scale factor for each side.
## -1 = disabled (use the raw theme value)
## 0 → ∞ = percentage (100 = 100%, 50 = half, 200 = double, etc.)

enum MarginSide {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
}

const CONST_NAMES := {
	MarginSide.LEFT: "margin_left",
	MarginSide.RIGHT: "margin_right",
	MarginSide.TOP: "margin_top",
	MarginSide.BOTTOM: "margin_bottom",
}

@export_group("Margin Scale")
@export_range(-1.0, 100.0, 0.1, "or_greater")
var margin_scale_left: float = 0.0:
	set = _set_left
@export_range(-1.0, 100.0, 0.1, "or_greater")
var margin_scale_right: float = 0.0:
	set = _set_right
@export_range(-1.0, 100.0, 0.1, "or_greater")
var margin_scale_top: float = 0.0:
	set = _set_top
@export_range(-1.0, 100.0, 0.1, "or_greater")
var margin_scale_bottom: float = 0.0:
	set = _set_bottom

var _base_values: Dictionary = { }
var _in_theme_update := false # reentrancy guard


func _ready() -> void:
	_refresh_base_values()
	_update_all_margins()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if _in_theme_update:
			return # ignore notifications caused by our own overrides
		_in_theme_update = true
		_refresh_base_values()
		_update_all_margins()
		_in_theme_update = false


func _set_left(v: float) -> void:
	if is_equal_approx(v, margin_scale_left):
		return
	margin_scale_left = v
	_apply_side(MarginSide.LEFT, v)


func _set_right(v: float) -> void:
	if is_equal_approx(v, margin_scale_right):
		return
	margin_scale_right = v
	_apply_side(MarginSide.RIGHT, v)


func _set_top(v: float) -> void:
	if is_equal_approx(v, margin_scale_top):
		return
	margin_scale_top = v
	_apply_side(MarginSide.TOP, v)


func _set_bottom(v: float) -> void:
	if is_equal_approx(v, margin_scale_bottom):
		return
	margin_scale_bottom = v
	_apply_side(MarginSide.BOTTOM, v)


func _refresh_base_values() -> void:
	for side in CONST_NAMES:
		remove_theme_constant_override(CONST_NAMES[side])
	for side in CONST_NAMES:
		_base_values[side] = get_theme_constant(CONST_NAMES[side], "MarginContainer")


func _update_all_margins() -> void:
	_apply_side(MarginSide.LEFT, margin_scale_left)
	_apply_side(MarginSide.RIGHT, margin_scale_right)
	_apply_side(MarginSide.TOP, margin_scale_top)
	_apply_side(MarginSide.BOTTOM, margin_scale_bottom)


func _apply_side(side: MarginSide, scale: float) -> void:
	var constant_name: String = CONST_NAMES[side]
	if scale < 0.0:
		remove_theme_constant_override(constant_name)
		return
	var base: int = _base_values.get(side, get_theme_constant(constant_name, "MarginContainer"))
	add_theme_constant_override(constant_name, int(round(base * (scale / 100.0))))
