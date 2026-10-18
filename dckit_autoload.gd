extends Node

signal console_visibility_changed(is_open: bool)

const BackendInterface = preload("./utils/backend_interface.gd")
const DCBackend_Class_Path = "res://addons/dc_kit/backend.gd"

var log_absent_backend_warnings: bool = false
var _backend: BackendInterface = null
var _dc_kit_ui: BackendInterface.UI_HOST_INTERFACE = null


func _init() -> void:
	if not FileAccess.file_exists(DCBackend_Class_Path):
		if OS.is_debug_build():
			push_warning(
				"DCKit: backend script not found at '%s' — running without backend."
				% DCBackend_Class_Path
			)
		else:
			print("DCKit console disabled")
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	var backend_impl = load(DCBackend_Class_Path)
	if backend_impl == null:
		if OS.is_debug_build():
			push_warning("DCKit: failed to load backend script at '%s'." % DCBackend_Class_Path)
		return

	_backend = backend_impl.new() as BackendInterface
	if _backend == null:
		push_error("DCKit: backend instantiation returned null.")

	_dc_kit_ui = _backend.init_ui()
	if _dc_kit_ui:
		_dc_kit_ui.console_visibility_changed.connect(console_visibility_changed.emit)
		add_child(_dc_kit_ui)


func configure_ui(config: Dictionary) -> void:
	if not _dc_kit_ui:
		push_warning("DCKit: configure_ui called with no UI — config ignored.")
		return
	_dc_kit_ui.configure(config)

func get_ui_config() -> Dictionary:
	if not _dc_kit_ui:
		return {}
	return _dc_kit_ui.get_configure()

func has_backend() -> bool:
	return _backend != null


#region Public API
func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	if _guard("analyze"):
		return null
	return _backend.analyze(input, cursor_pos)


func run(raw_string: String) -> DCResult:
	if _guard("run"):
		return DCResult.fail("Console disabled")
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


func register_def(def: DCDefinition) -> bool:
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
	if not _dc_kit_ui:
		return

	_dc_kit_ui.show_console()


func hide_console() -> void:
	if not _dc_kit_ui:
		return

	_dc_kit_ui.hide_console()


func toggle_console() -> void:
	if not _dc_kit_ui:
		return

	_dc_kit_ui.toggle_console()


func is_console_open() -> bool:
	if not _dc_kit_ui:
		return false

	return _dc_kit_ui.is_console_open() as bool
#endregion


func _guard(method_name := "", backend_required: bool = true) -> bool:
	if backend_required and not has_backend():
		if log_absent_backend_warnings and OS.is_debug_build():
			push_warning(
				"DCKit:%s method called with no backend — aborting."
				% ["" if method_name.is_empty() else (" '%s'" % method_name)]
			)
		return true

	return false
