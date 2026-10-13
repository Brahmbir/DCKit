extends MarginContainer

signal opened
signal closed

signal item_accepted(start: int, label: String)
signal selection_changed(index: int)

var _autocomplete: _DCKitNS.Core.AutoComplete = null


func setup(autocomplete: _DCKitNS.Core.AutoComplete) -> void:
	_autocomplete = autocomplete
	_autocomplete.autocomplete_need_update.connect(_on_autocomplete_need_update)

func is_open() -> bool:
	return false

func _on_autocomplete_need_update() -> void:
	return
