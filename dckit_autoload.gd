extends Node

signal console_visibility_changed(is_open: bool)

const BackendInterface = preload("./utils/backend_interface.gd")

var log_absent_backend_warnings: bool = false
var _backend_path: String:
	get:
		return get_script().resource_path.get_base_dir().path_join("backend.gd")
var _backend: BackendInterface = null
var _dc_kit_ui: BackendInterface.UI_HOST_INTERFACE = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not FileAccess.file_exists(_backend_path):
		if OS.is_debug_build():
			push_warning(
				"DCKit: backend script not found at '%s' — running without backend." % _backend_path
			)
		else:
			print("DCKit console disabled")
		return

	var backend_impl = load(_backend_path)
	if backend_impl == null:
		if OS.is_debug_build():
			push_warning("DCKit: failed to load backend script at '%s'." % _backend_path)
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
		return { }
	return _dc_kit_ui.get_configure()


func has_backend() -> bool:
	return _backend != null


# Public API
func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	if _guard():
		return null
	return _backend.analyze(input, cursor_pos)


func run(raw_string: String) -> DCResult:
	if _guard():
		return DCResult.fail("Console disabled")
	return await _backend.run(raw_string)


func abort() -> void:
	if _guard():
		return
	_backend.abort()


#region Logger API
func log_info(msg: String, details: String = "") -> void:
	if _guard():
		return
	_backend.log_info(msg, details)


func log_warn(msg: String, details: String = "") -> void:
	if _guard():
		return
	_backend.log_warn(msg, details)


func log_error(msg: String, details: String = "") -> void:
	if _guard():
		return
	_backend.log_error(msg, details)


func log_help(msg: String, details: String = "") -> void:
	if _guard():
		return
	_backend.log_help(msg, details)
#endregion


#region Definition Methods
func register(
	p_name: String,
	handler: Callable,
	description: String = "",
	params: Array[DCDefinition.Param] = [],
) -> bool:
	if _guard():
		return false
	var def := DCDefinition.new(p_name, handler, description, params)
	return register_def(def)

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
#endregion


#region Variable methods

func set_var(key: String, value: String) -> bool:
	if _guard():
		return false
	return _backend.set_var(key, value)


func get_var_value_raw(key: String) -> Variant:
	if _guard():
		return null
	return _backend.get_var_value_raw(key)


func get_var_value(key: String, fallback: Variant = null) -> Variant:
	if _guard():
		return fallback
	return _backend.get_var_value(key)


func get_typed_var(key: String, type: int, fallback: Variant = null) -> Variant:
	if _guard():
		return fallback
	return _backend.get_typed_var(key, type, fallback)


func is_var_live(key: String) -> bool:
	if _guard():
		return false
	return _backend.is_var_live(key)


func is_var_deferred(key: String) -> bool:
	if _guard():
		return false
	return _backend.is_var_deferred(key)


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


func resolve_var(key: String) -> DCResult:
	if _guard():
		return DCResult.fail("Console disabled")
	return _backend.resolve_var(key)
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


func _guard() -> bool:
	if not has_backend():
		if log_absent_backend_warnings and OS.is_debug_build():
			push_warning("DCKit: Backend unavailable. Operation aborted.")
		return true

	return false
