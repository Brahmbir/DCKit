@tool
extends "../../../ui_base_class/info_panel_base.gd"

enum Alignment {
	BEGIN,
	END,
}

const InfoCompInterface = preload("./info_panel_component/info_comp_base.gd")

@export var toggle_shortcut: Shortcut = _DCKitNS.UI.make_shortcut(KEY_SPACE, true, true)

@export var info_panel: InfoCompInterface

@export var alignment: Alignment = Alignment.BEGIN:
	set(v):
		alignment = v
		queue_sort()

@export var skip: bool = false:
	set(v):
		skip = v
		update_minimum_size()
		queue_sort()
@export var stretch_curve: Curve

@export_group("spacer")
## Stretch ratio the curve's top (Y = 1) maps to.
@export_range(0.0, 2.0, 0.01) var max_ratio: float = 1.5

@onready var control: Control = $HBoxContainer/Control


func _enter_tree() -> void:
	_DCKitNS.UI.mobile_layout.changed.connect(_change_layout)

	var parent := get_parent_control()
	if parent and not Engine.is_editor_hint() and not parent.resized.is_connected(_refresh_width):
		parent.resized.connect(_refresh_width)


func _ready() -> void:
	_change_layout()
	if info_panel:
		info_panel.sizing_parent = get_parent()


func _exit_tree() -> void:
	var parent := get_parent_control()
	if parent and parent.resized.is_connected(_refresh_width):
		parent.resized.disconnect(_refresh_width)

	_DCKitNS.UI.mobile_layout.changed.disconnect(_change_layout)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return

	var kids := _flow()
	var used := 0.0
	var expanders := 0
	for k in kids:
		used += k.get_combined_minimum_size().y
		if k.size_flags_vertical & Control.SIZE_EXPAND:
			expanders += 1

	var extra := 0.0 if skip else maxf(size.y - used, 0.0)
	var total := used + (extra if expanders > 0 else 0.0)

	# BEGIN starts at the top edge. END ends on the bottom edge,
	# which is a negative start when skipped (size.y is 0).
	var y := 0.0 if alignment == Alignment.BEGIN else size.y - total
	for k in kids:
		var h := k.get_combined_minimum_size().y
		if expanders > 0 and (k.size_flags_vertical & Control.SIZE_EXPAND):
			h += extra / expanders
		fit_child_in_rect(k, Rect2(0.0, y, size.x, h))
		y += h


func _get_minimum_size() -> Vector2:
	var s := Vector2.ZERO
	for k in _flow():
		var m := k.get_combined_minimum_size()
		s.x = maxf(s.x, m.x)
		if not skip:
			s.y += m.y
	return s


func show_info(info: _DCKitNS.UI.Signature.SignatureInfo) -> void:
	if info_panel:
		info_panel.info = info


func set_active(index: int) -> void:
	if info_panel:
		info_panel.active_index = index


func _shortcut_input(event: InputEvent) -> void:
	if _DCKitNS.UI.shortcut_pressed(event, toggle_shortcut):
		info_panel.toggle()
		get_viewport().set_input_as_handled()
		return


func _flow() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		var ctl := c as Control
		if ctl and ctl.visible and not ctl.top_level:
			out.append(ctl)
	return out


func _refresh_width() -> void:
	if _DCKitNS.UI.mobile_layout.screen or not stretch_curve or not control:
		return
	var parent := get_parent_control()
	var w := (parent.size.x if parent else size.x) / _DCKitNS \
			.UI \
			.mobile_layout \
			.get_breakpoint_width()
	var ratio := stretch_curve.sample_baked(w - 1) * max_ratio
	if not is_equal_approx(ratio, control.size_flags_stretch_ratio):
		control.size_flags_stretch_ratio = ratio


func _change_layout(_val := false) -> void:
	skip = not _DCKitNS.UI.mobile_layout.screen
	if _DCKitNS.UI.mobile_layout.screen:
		if control:
			control.size_flags_stretch_ratio = 0.0
	else:
		_refresh_width()
