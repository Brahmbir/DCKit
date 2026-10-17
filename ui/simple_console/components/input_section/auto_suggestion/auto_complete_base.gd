extends Container

signal opened
signal closed

signal item_accepted(start: int, label: String)
signal selection_changed(index: int)

enum Layout {
	HorizontalBar,
	PopUp,
}

@export var layout := Layout.HorizontalBar:
	set = set_layout

var _popup_x := 0.0

var _autocomplete: _DCKitNS.Core.AutoComplete = null


func _init() -> void:
	_DCKitNS.UI.mobile_layout.changed.connect(_on_layout_change)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	for child in get_children():
		if not (child is Control) or not child.visible:
			continue
		var child_min: Vector2 = child.get_combined_minimum_size()
		result.x = maxf(result.x, child_min.x)
		# Popup reserves no height, so the bottom container ignores it.
		if layout != Layout.PopUp:
			result.x = maxf(result.x, child_min.x)
			result.y = maxf(result.y, child_min.y)
	return result


## PopUp only. x is in the slot's local space; clamped so the popup stays inside the row.
func set_popup_x(x: float) -> void:
	_popup_x = x
	queue_sort()

## Pass the caret's global x; the popup's left edge follows it, kept inside the parent rect.
func move_to_caret(global_x: float) -> void:
	var bounds := _bounds_rect()
	var w := minf(_popup_width(), bounds.size.x)
	var gx := clampf(global_x, bounds.position.x, bounds.end.x - w)
	set_popup_x(gx - global_position.x)


func _bounds_rect() -> Rect2:
	var p := get_parent() as Control
	return p.get_global_rect() if p else get_global_rect()


func _popup_width() -> float:
	var w := 0.0
	for child in get_children():
		if child is Control and child.visible:
			w = maxf(w, child.get_combined_minimum_size().x)
	return w

# Layout
func set_layout(new_val: Layout) -> void:
	if new_val == layout:
		return
	layout = new_val
	if is_node_ready():
		_apply_layout()


func setup(autocomplete: _DCKitNS.Core.AutoComplete) -> void:
	_autocomplete = autocomplete
	_autocomplete.autocomplete_need_update.connect(_on_autocomplete_need_update)


func is_open() -> bool:
	return false


func input_handler(event: InputEvent) -> bool:
	return false


func _on_layout_change(_v := false):
	var is_small = true if _DCKitNS.UI.mobile_layout.screen else false
	set_layout(Layout.HorizontalBar if is_small else Layout.PopUp)


func _on_autocomplete_need_update() -> void:
	return


func _apply_layout() -> void:
	# No top_level: the popup stays in the tree and lips out of a 0-height slot.
	custom_minimum_size.y = 0.0
	_apply_layout_to_child()
	update_minimum_size()
	queue_sort()


func _apply_layout_to_child() -> void:
	pass


func _sort_children() -> void:
	for child in get_children():
		if not (child is Control) or not child.visible:
			continue
		if layout == Layout.PopUp:
			var cm: Vector2 = child.get_combined_minimum_size()
			var w := minf(cm.x, size.x)
			var x := clampf(_popup_x, 0.0, maxf(size.x - w, 0.0))
			fit_child_in_rect(child, Rect2(x, -cm.y, w, cm.y))
		else:
			fit_child_in_rect(child, Rect2(Vector2.ZERO, size))
