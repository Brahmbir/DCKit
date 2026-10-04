extends Container

var _padding_left: float = 0.0
var _padding_top: float = 0.0
var _padding_right: float = 0.0
var _padding_bottom: float = 0.0


func set_edge_padding(left: float, top: float, right: float, bottom: float) -> void:
	_padding_left = left
	_padding_top = top
	_padding_right = right
	_padding_bottom = bottom
	update_minimum_size()
	queue_sort()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var rect := Rect2(
			_padding_left,
			_padding_top,
			size.x - _padding_left - _padding_right,
			size.y - _padding_top - _padding_bottom
		)
		for child in get_children():
			if child is Control and child.visible:
				fit_child_in_rect(child, rect)


func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	for child in get_children():
		if child is Control and child.visible:
			result = result.max(child.get_combined_minimum_size())
	return result + Vector2(_padding_left + _padding_right, _padding_top + _padding_bottom)


func connect_logger(logger: _DCKitExecutorNamespace.Tracer) -> void:
	_DCKitUINamespace.not_implemented('connect_logger')
