extends Control

signal item_pressed(pos: int, len: int)
signal action_requested(diag, action_index: int)


func show_diagnostic(diags: Array) -> void:
	_DCKitUINamespace.not_implemented("show_diagnostic")
