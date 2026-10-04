extends Control

signal focus_changed(has_focus: bool)
signal command_submitted(raw: String)
signal abort_requested

signal cmd_text_changed(text: String, caret_pos: int)
signal cmd_caret_location_changed(caret_pos: int)


func get_input_node() -> Control:
	_DCKitUINamespace.not_implemented("get_input_node")
	return null


func connect_history_obj(hist_obj: _DCKitUINamespace.CommandHistory) -> void:
	_DCKitUINamespace.not_implemented("connect_history_obj")


func connect_executor(executor) -> void:
	_DCKitUINamespace.not_implemented("connect_executor")
