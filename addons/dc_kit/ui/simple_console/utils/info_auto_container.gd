@tool
extends Container

@export var stacked: bool = false:
	set(value):
		stacked = value
		update_minimum_size()
		queue_sort()

# INFO Both components must be direct children of this container.
@export var auto_comp: Control:
	set(value):
		auto_comp = value
		update_minimum_size()
		queue_sort()
		update_configuration_warnings()

@export var info_comp: Control:
	set(value):
		info_comp = value
		update_minimum_size()
		queue_sort()
		update_configuration_warnings()


func _ready() -> void:
	_DCKitNS.UI.mobile_layout.changed.connect(_on_layout_change)

func _on_layout_change(is_smaller_screen:bool):
	stacked = is_smaller_screen
	

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if auto_comp and auto_comp.get_parent() != self:
		warnings.append("auto_comp must be a direct child of this container.")
	if info_comp and info_comp.get_parent() != self:
		warnings.append("info_comp must be a direct child of this container.")
	return warnings


func _get_minimum_size() -> Vector2:
	var a := _min_of(auto_comp)
	var i := _min_of(info_comp)
	if stacked:
		return Vector2(maxf(a.x, i.x), a.y + i.y)
	return Vector2(a.x + i.x, maxf(a.y, i.y))


# helpers
func _usable(c: Control) -> bool:
	return c != null and c.visible and c.get_parent() == self


func _min_of(c: Control) -> Vector2:
	return c.get_combined_minimum_size() if _usable(c) else Vector2.ZERO


# layout
func _sort() -> void:
	if stacked:
		_sort_stacked()
	else:
		_sort_wide()


func _sort_wide() -> void:
	if _usable(auto_comp):
		var m := auto_comp.get_combined_minimum_size()
		fit_child_in_rect(auto_comp, Rect2(0.0, size.y - m.y, m.x, m.y))
	if _usable(info_comp):
		var m := info_comp.get_combined_minimum_size()
		fit_child_in_rect(info_comp, Rect2(size.x - m.x, size.y - m.y, m.x, m.y))


func _sort_stacked() -> void:
	# Build upward from the bottom: auto_comp first, then info_comp on top.
	var bottom := size.y
	for c in [auto_comp, info_comp]:
		if not _usable(c):
			continue
		var h := (c as Control).get_combined_minimum_size().y
		bottom -= h
		fit_child_in_rect(c, Rect2(0.0, bottom, size.x, h))
