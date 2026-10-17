extends TextEdit

signal text_submitted(text: String)

const AutoCompleteBase = preload("./auto_suggestion/auto_complete_base.gd")

var _auto_complete_ref: WeakRef = WeakRef.new()


func set_history_obj(new_history: _DCKitNS.UI.CommandHistory) -> void:
	_DCKitNS.not_implemented("set_history_obj")
	return


func set_auto_complete_ref(auto_complete: AutoCompleteBase):
	_auto_complete_ref = weakref(auto_complete)


func _is_event_handle_by_auto_complete(event: InputEvent) -> bool:
	var auto_complete := _auto_complete_ref.get_ref() as AutoCompleteBase

	if auto_complete:
		return auto_complete.input_handler(event)

	return false
