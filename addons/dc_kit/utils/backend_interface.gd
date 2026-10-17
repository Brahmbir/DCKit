extends RefCounted

const UI_HOST_INTERFACE = preload("./ui_interface.gd")


func init_ui() -> UI_HOST_INTERFACE:
	return null


func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	return null


func run(raw_string: String) -> DCResult:
	return null


func abort() -> void:
	return


func register(
	p_name: String,
	handler: Callable,
	description: String = "",
	params: Array[DCDefinition.Param] = [],
) -> bool:
	return false


func register_def(def: DCDefinition) -> bool:
	return false


func unregister(p_name: String) -> bool:
	return false


func lock_command(p_name: String) -> void:
	return


func unlock_command(p_name: String) -> void:
	return


func get_var(key: String, fallback: String = "") -> String:
	return ""


func set_var(key: String, value: String) -> bool:
	return false


func has_var(key: String) -> bool:
	return false


func delete_var(key: String) -> bool:
	return false


func get_var_keys() -> Array:
	return []
