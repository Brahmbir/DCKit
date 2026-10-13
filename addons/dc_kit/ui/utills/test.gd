@tool
extends Container

@export var skip: bool = false:
	set(v):
		skip = v
		update_minimum_size()
		queue_sort()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			skip = not skip


func _flow() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		var ctl := c as Control
		if ctl and ctl.visible and not ctl.top_level:
			out.append(ctl)
	return out


func _get_minimum_size() -> Vector2:
	var s := Vector2.ZERO
	for k in _flow():
		var m := k.get_combined_minimum_size()
		s.x = maxf(s.x, m.x)
		if not skip:
			s.y += m.y
	return s


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

	# Skipped: no leftover space to hand out, children keep their own height.
	var extra := 0.0 if skip else maxf(size.y - used, 0.0)
	var y := 0.0
	for k in kids:
		var h := k.get_combined_minimum_size().y
		if expanders > 0 and (k.size_flags_vertical & Control.SIZE_EXPAND):
			h += extra / expanders
		fit_child_in_rect(k, Rect2(0.0, y, size.x, h))
		y += h
