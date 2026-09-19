extends Node

signal console_opened # Emitted when the console UI becomes visible.
signal console_closed # Emitted when the console UI is hidden.

const DCBackend_Class_Path = "res://addons/dc_kit/backend.gd"

#region commit after editing the addon (dc_kit) files 
#const DCBackend = preload(DCBackend_Class_Path)
#var _backend: DCBackend = null
#endregion

var _backend = null

var _dc_kit_ui: Control = null


func _init() -> void:
	if not FileAccess.file_exists(DCBackend_Class_Path):
		push_warning(
			"DC: backend script not found at '%s' — running without backend." % DCBackend_Class_Path
		)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	var DCBackend = load(DCBackend_Class_Path)
	if DCBackend == null:
		push_error("DC: failed to load backend script at '%s'." % DCBackend_Class_Path)
		return

	_backend = DCBackend.new()
	if _backend == null:
		push_error("DC: backend instantiation returned null.")


func _ready() -> void:
	if not _backend:
		return
	_dc_kit_ui = _backend.init_ui()
	if _dc_kit_ui:
		add_child(_dc_kit_ui)


func has_backend() -> bool:
	return _backend != null


#region Public API
func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	if _guard("analyze"):
		return null
	return _backend.analyze(input, cursor_pos)


func run(raw_string: String) -> DCResult:
	if _guard("run"):
		return null
	return await _backend.run(raw_string) as DCResult


func abort() -> void:
	if _guard("abort"):
		return
	_backend.abort()


func register(
	p_name: String,
	handler: Callable,
	description: String = "",
	params: Array = [],
) -> bool:
	if _guard("register"):
		return false
	return _backend.register(p_name, handler, description, params)


func register_def(def) -> bool:
	if _guard("register_def"):
		return false
	return _backend.register_def(def)


func unregister(p_name: String) -> bool:
	if _guard("unregister"):
		return false
	return _backend.unregister(p_name)


func lock_command(p_name: String) -> void:
	if _guard("lock_command"):
		return
	_backend.lock_command(p_name)


func unlock_command(p_name: String) -> void:
	if _guard("unlock_command"):
		return
	_backend.unlock_command(p_name)


func get_var(key: String, fallback: String = "") -> String:
	if _guard("get_var"):
		return fallback
	return _backend.get_var(key, fallback)


func set_var(key: String, value: String) -> bool:
	if _guard("set_var"):
		return false
	return _backend.set_var(key, value)


func has_var(key: String) -> bool:
	if _guard("has_var"):
		return false
	return _backend.has_var(key)


func delete_var(key: String) -> bool:
	if _guard("delete_var"):
		return false
	return _backend.delete_var(key)


func get_var_keys() -> Array:
	if _guard("get_var_keys"):
		return []
	return _backend.get_var_keys()
#endregion


#region visibility API
func show_console() -> void:
	if not _has_dc_kit_ui():
		return

	if _dc_kit_ui.visible:
		return
	_dc_kit_ui.show()
	_dc_kit_ui.focus_input()
	console_opened.emit()


func hide_console() -> void:
	if not _has_dc_kit_ui():
		return

	if not _dc_kit_ui.visible:
		return
	_dc_kit_ui.hide()
	console_closed.emit()


func toggle_console() -> void:
	if not _has_dc_kit_ui():
		return

	if _dc_kit_ui.visible:
		hide_console()
	else:
		show_console()


func is_console_open() -> bool:
	return _has_dc_kit_ui() and _dc_kit_ui.visible
#endregion


func _has_dc_kit_ui() -> bool:
	return _dc_kit_ui != null


func _guard(caller: String, backend_required: bool = true) -> bool:
	if backend_required and not has_backend():
		push_error("DCKit: '%s' called with no backend — aborting." % caller)
		return false
	return true
