extends Node

signal console_opened # Emitted when the console UI becomes visible.
signal console_closed # Emitted when the console UI is hidden.

const BackendInterface = preload("./utils/backend_interface.gd")

const DCBackend_Class_Path = "res://addons/dc_kit/backend.gd"

var _backend: BackendInterface = null
var _dc_kit_ui: BackendInterface.UI_HOST_INTERFACE = null


func _init() -> void:
	if not FileAccess.file_exists(DCBackend_Class_Path):
		push_warning(
			"DC: backend script not found at '%s' — running without backend." % DCBackend_Class_Path
		)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	var backend_impl = load(DCBackend_Class_Path)
	if backend_impl == null:
		push_error("DC: failed to load backend script at '%s'." % DCBackend_Class_Path)
		return

	_backend = backend_impl.new() as BackendInterface
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
	if _guard():
		return null
	return _backend.analyze(input, cursor_pos)


func run(raw_string: String) -> DCResult:
	if _guard():
		return DCResult.fail("Console disabled")
	return await _backend.run(raw_string) as DCResult


func abort() -> void:
	if _guard():
		return
	_backend.abort()


func register(
	p_name: String,
	handler: Callable,
	description: String = "",
	params: Array = [],
) -> bool:
	if _guard():
		return false
	return _backend.register(p_name, handler, description, params)


func register_def(def: DCDefinition) -> bool:
	if _guard():
		return false
	return _backend.register_def(def)


func unregister(p_name: String) -> bool:
	if _guard():
		return false
	return _backend.unregister(p_name)


func lock_command(p_name: String) -> void:
	if _guard():
		return
	_backend.lock_command(p_name)


func unlock_command(p_name: String) -> void:
	if _guard():
		return
	_backend.unlock_command(p_name)


func get_var(key: String, fallback: String = "") -> String:
	if _guard():
		return fallback
	return _backend.get_var(key, fallback)


func set_var(key: String, value: String) -> bool:
	if _guard():
		return false
	return _backend.set_var(key, value)


func has_var(key: String) -> bool:
	if _guard():
		return false
	return _backend.has_var(key)


func delete_var(key: String) -> bool:
	if _guard():
		return false
	return _backend.delete_var(key)


func get_var_keys() -> Array:
	if _guard():
		return []
	return _backend.get_var_keys()
#endregion


#region visibility API
func show_console() -> void:
	if not _dc_kit_ui:
		return

	_dc_kit_ui.show_console()
	console_opened.emit()


func hide_console() -> void:
	if not _dc_kit_ui:
		return

	_dc_kit_ui.hide_console()

	console_closed.emit()


func toggle_console() -> void:
	if not _dc_kit_ui:
		return

	_dc_kit_ui.toggle_console()

	if is_console_open():
		console_opened.emit()
	else:
		console_closed.emit()


func is_console_open() -> bool:
	if not _dc_kit_ui:
		return false

	return _dc_kit_ui.is_console_open() as bool
#endregion


func _guard(backend_required: bool = true) -> bool:
	if backend_required and not has_backend():
		push_error("DCKit: method called with no backend — aborting.")
		return true
	return false


class ui_config extends RefCounted:
	pass
