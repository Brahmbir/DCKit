extends MarginContainer

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

var _autocomplete: _DCKitNS.Core.AutoComplete = null


func _init() -> void:
	_DCKitNS.UI.mobile_layout.changed.connect(_on_layout_change)


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
	var popup := layout == Layout.PopUp
	# top_level children are skipped by the bottom container's _flow(),
	# so a popup neither gets laid out nor counted in its height.
	top_level = popup
	custom_minimum_size.y = 0.0
	_apply_layout_to_child()
	update_minimum_size()
	queue_sort()


func _apply_layout_to_child() -> void:
	pass
