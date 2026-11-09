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


func log_info(msg: String, details: String = "") -> void:
	pass


func log_warn(msg: String, details: String = "") -> void:
	pass


func log_error(msg: String, details: String = "") -> void:
	pass


func log_help(msg: String, details: String = "") -> void:
	pass


func register(p_name: String, fn: Callable, description: String = "") -> bool:
	return false


func set_param(
	command: String,
	index: int,
	p_name: String,
	suggestor: Variant = null,
) -> DCDefinition.Param:
	return null


func remove_param(command: String, index: int) -> bool:
	return false


func get_aliases(command: String) -> PackedStringArray:
	return PackedStringArray()


func set_aliases(command: String, aliases: PackedStringArray) -> bool:
	return false


func add_alias(command: String, alias: String) -> bool:
	return false


func remove_alias(alias: String) -> bool:
	return false


func clear_aliases(command: String) -> void:
	pass


func register_def(def: DCDefinition) -> bool:
	return false


func unregister(p_name: String) -> bool:
	return false


func lock_command(p_name: String) -> void:
	return


func unlock_command(p_name: String) -> void:
	return


func get_var_value_raw(key: String) -> Variant:
	return null


func get_var_value(key: String, fallback: Variant = null) -> Variant:
	return null


func get_typed_var(key: String, type: int, fallback: Variant = null) -> Variant:
	return null


func is_var_live(key: String) -> bool:
	return false


func is_var_deferred(key: String) -> bool:
	return false


func set_var(key: String, value: Variant) -> bool:
	return false


func has_var(key: String) -> bool:
	return false


func delete_var(key: String) -> bool:
	return false


func get_var_keys() -> Array:
	return []


func resolve_var(key: String) -> DCResult:
	return null
