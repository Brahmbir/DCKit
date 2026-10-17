extends "./auto_complete_base.gd"

const MAX_VISIBLE := 8
const _DETAIL_TAGS := "\\[.+?\\]"

@export var toggle_shortcut: Shortcut = null

@export_group("nodes")
@export var item_list: ItemList

@export_group("icon", "icon")
@export var icon_command: Texture2D = preload("res://addons/dc_kit/assets/images/command.svg")
@export var icon_command_alias: Texture2D = preload("res://addons/dc_kit/assets/images/alias.svg")
@export var icon_variable: Texture2D = preload("res://addons/dc_kit/assets/images/variable.svg")
@export var icon_type: Texture2D = preload("res://addons/dc_kit/assets/images/ctype.svg")
@export var icon_text: Texture2D = preload("res://addons/dc_kit/assets/images/text.svg")

var _selected_index := 0
var _start := 0
var _items: Array = [] # Array[_DCKitNS.Core.AutoComplete.CompletionItem]
var _tag_regex := RegEx.create_from_string(_DETAIL_TAGS)


func _ready() -> void:
	if toggle_shortcut == null:
		toggle_shortcut = _DCKitNS.UI.make_shortcut(KEY_SPACE, true)

	hide_popup()
	item_list.item_activated.connect(_on_item_activated)
	#item_list.item_selected.connect(_on_item_activated)

	#item_list.item_clicked.connect(
	#func(idx, _p, _mbi):
	#_on_item_activated(idx),
	#)
	item_list.item_selected

	_DCKitNS.UI.mobile_layout.get_scales().font_changed.connect(_on_scale_change)
	_DCKitNS.UI.mobile_layout.get_scales().space_changed.connect(_on_scale_change)

	_on_scale_change()




func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control and c.visible:
				fit_child_in_rect(c, Rect2(Vector2.ZERO, size))


func _get_minimum_size() -> Vector2:
	var s := Vector2.ZERO
	for c in get_children():
		if c is Control and c.visible:
			s = s.max(c.get_combined_minimum_size())
	return s


## PopUp only. Pins the popup's bottom-left to a global rect (e.g. the input line).
func place_above(anchor: Rect2) -> void:
	if layout != Layout.PopUp:
		return
	size.x = anchor.size.x
	global_position = anchor.position - Vector2(0.0, size.y)


# Data
func populate() -> void:
	item_list.clear()
	_selected_index = 0

	for item: _DCKitNS.Core.AutoComplete.CompletionItem in _items:
		var idx := item_list.add_item(item.label, _icon_for(item.kind))

	if layout == Layout.PopUp:
		_fit_popup_height()

	if has_items():
		item_list.select(_selected_index)
		selection_changed.emit(_selected_index)


func has_items() -> bool:
	return item_list.item_count > 0


func expected_height(count: int = -1) -> float:
	if count < 0:
		count = item_list.item_count
	if count == 0:
		return 0.0
	return _item_height() * mini(count, MAX_VISIBLE) + _frame_margin()


# Show / hide
func show_popup() -> bool:
	if not has_items():
		return false
	visible = true

	_selected_index = clampi(_selected_index, 0, item_list.item_count - 1)
	item_list.select(_selected_index)
	item_list.ensure_current_is_visible()

	opened.emit()
	return true


func hide_popup() -> void:
	closed.emit()
	visible = false


func is_open() -> bool:
	return visible


# Navigation / accept
func navigate(delta: int) -> void:
	if not has_items():
		return
	_selected_index = clampi(_selected_index + delta, 0, item_list.item_count - 1)
	item_list.select(_selected_index)
	item_list.ensure_current_is_visible()

	selection_changed.emit(_selected_index)


func get_selected_index() -> int:
	return _selected_index


func get_selected_text() -> String:
	return item_list.get_item_text(_selected_index) if has_items() else ""


func accept() -> void:
	if not has_items():
		return
	var item = _items[_selected_index]
	hide_popup()
	item_accepted.emit(_start, item.label)


func input_handler(event: InputEvent) -> bool:
	if _DCKitNS.UI.shortcut_pressed(event, toggle_shortcut):
		if is_open():
			hide_popup()
		elif show_popup():
			pass
		get_viewport().set_input_as_handled()
		return true

	if not is_open():
		return false

	match event.keycode:
		KEY_UP:
			navigate(-1)
			get_viewport().set_input_as_handled()
			return true
		KEY_DOWN:
			navigate(1)
			get_viewport().set_input_as_handled()
			return true
		KEY_TAB:
			if not event.echo:
				if event.shift_pressed:
					navigate(-1)
				else:
					accept()
				get_viewport().set_input_as_handled()
				return true
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				accept()
				get_viewport().set_input_as_handled()
				return true
		KEY_ESCAPE:
			if not event.echo:
				hide_popup()
				get_viewport().set_input_as_handled()
				return true

	return false


func _on_scale_change():
	if item_list:
		var space = _DCKitNS.UI.mobile_layout.get_scales().em_space(1)
		item_list.add_theme_constant_override("icon_margin", space)

		var px = _DCKitNS.UI.mobile_layout.get_scales().em_font(1.15)
		item_list.fixed_icon_size = Vector2i(px, px)



func _apply_layout_to_child() -> void:
	var popup := layout == Layout.PopUp
	if popup:
		item_list.max_columns = 1
		_fit_popup_height()
	else:
		item_list.max_columns = 0


func _fit_popup_height() -> void:
	var h := expected_height()
	custom_minimum_size.y = h
	size.y = h


func _icon_for(kind) -> Texture2D:
	var Kind := _DCKitNS.Core.AutoComplete.CompletionItem.Kind
	match kind:
		Kind.COMMAND:
			return icon_command
		Kind.COMMAND_ALIAS:
			return icon_command_alias
		Kind.VARIABLE:
			return icon_variable
		Kind.TYPE:
			return icon_type
	return icon_text


func _item_height() -> float:
	var font := item_list.get_theme_font("font")
	var font_size := item_list.get_theme_font_size("font_size")
	return font.get_height(font_size) + item_list.get_theme_constant("v_separation")


func _frame_margin() -> float:
	var panel := item_list.get_theme_stylebox("panel")
	return panel.get_margin(SIDE_TOP) + panel.get_margin(SIDE_BOTTOM) if panel else 0.0


func _on_autocomplete_need_update() -> void:
	var r := _autocomplete.get_completions()
	_start = r.start
	_items = r.items
	populate()


func _on_item_activated(index: int) -> void:
	_selected_index = index
	accept()
