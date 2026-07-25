class_name CompletionPopup
extends PanelContainer


@export_group("icon","icon")
@export var icon_command : Texture2D = preload("res://addons/dc_kit/assets/images/command.svg")
@export var icon_command_alias : Texture2D = preload("res://addons/dc_kit/assets/images/alias.svg")

@export var icon_variable : Texture2D = preload("res://addons/dc_kit/assets/images/variable.svg")
@export var icon_type : Texture2D = preload("res://addons/dc_kit/assets/images/ctype.svg")
@export var icon_text : Texture2D = preload("res://addons/dc_kit/assets/images/text.svg")


signal item_accepted(start: int, label: String)
signal selection_changed(index: int)

const MAX_VISIBLE := 8

@onready var item_list: ItemList = %ItemList

var _selected_index := 0
var _start  : int   = 0
var _items  : Array = [] # Array[_DCKitNamespace.AutoComplete.CompletionItem]
var _autocomplete : _DCKitNamespace.AutoComplete = null


func _ready() -> void:
	item_list.item_activated.connect(_on_item_accept)
	hide_popup()


func setup(autocomplete: _DCKitNamespace.AutoComplete) -> void:
	_autocomplete = autocomplete
	_autocomplete.autocomplete_need_update.connect(_on_autocomplete_need_update)


func _on_autocomplete_need_update() -> void:
	var r := _autocomplete.get_completions()
	_start = r.start
	_items = r.items

	populate()


func populate() -> void:
	item_list.clear()
	_selected_index = 0

	for i in _items.size():
		var item: _DCKitNamespace.AutoComplete.CompletionItem = _items[i]
		var idx := item_list.add_item(item.label)
		match item.kind:
			_DCKitNamespace.AutoComplete.CompletionItem.Kind.COMMAND: item_list.set_item_icon(idx, icon_command)
			_DCKitNamespace.AutoComplete.CompletionItem.Kind.COMMAND_ALIAS: item_list.set_item_icon(idx, icon_command_alias)
			_DCKitNamespace.AutoComplete.CompletionItem.Kind.VARIABLE: item_list.set_item_icon(idx, icon_variable)
			_DCKitNamespace.AutoComplete.CompletionItem.Kind.TYPE: item_list.set_item_icon(idx, icon_type)
			_DCKitNamespace.AutoComplete.CompletionItem.Kind.VALUE, _: item_list.set_item_icon(idx, icon_text)
		if not item.detail.is_empty():
			var regex = RegEx.new()
			regex.compile("\\[.+?\\]")
			item_list.set_item_tooltip(idx, regex.sub(item.detail, "", true))

	var h := expected_height()
	custom_minimum_size.y = h
	size.y = h

	if has_items():
		item_list.select(0)
		selection_changed.emit(_selected_index)

	if has_items():
		item_list.select(0)
		custom_minimum_size.y = expected_height()
		selection_changed.emit(_selected_index)


func has_items() -> bool:
	return item_list.item_count > 0


func _item_height() -> float:
	var font      := item_list.get_theme_font("font")
	var font_size := item_list.get_theme_font_size("font_size")
	return font.get_height(font_size) + item_list.get_theme_constant("v_separation")


func _frame_margin() -> float:
	var m := 0.0
	var item_list_panel := item_list.get_theme_stylebox("panel")
	if item_list_panel: m += item_list_panel.get_margin(SIDE_TOP) + item_list_panel.get_margin(SIDE_BOTTOM)
	var self_panel := get_theme_stylebox("panel")
	if self_panel: m += self_panel.get_margin(SIDE_TOP) + self_panel.get_margin(SIDE_BOTTOM)
	return m


func expected_height(count: int = -1) -> float:
	if count < 0: count = item_list.item_count
	if count == 0: return 0.0
	return _item_height() * mini(count, MAX_VISIBLE) + _frame_margin()


# Show / hide
func show_popup() -> bool:
	if not has_items():
		return false
	visible = true
	return true


func hide_popup() -> void:
	visible = false


func is_open() -> bool:
	return visible


# Navigation
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
	if not has_items():
		return ""
	return item_list.get_item_text(_selected_index)

# Accept
func accept() -> void:
	if not has_items():
		return
	var item = _items[_selected_index]
	hide_popup()
	item_accepted.emit(_start, item.label)


func _on_item_accept(index: int) -> void:
	_selected_index = index
	accept()
