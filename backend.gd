extends "./utils/backend_interface.gd"

const CORE: Array[Resource] = [
	preload("./modules/variables_module.gd"),
	preload("./modules/diagnostics_module.gd"),
]
const OPTIONAL: Array[Dictionary] = [
	{ "path": "modules/utility_module.gd", "setting": _DCKitSetting.MODULES_UTILITY },
	{ "path": "modules/logic_module.gd", "setting": _DCKitSetting.MODULES_LOGIC },
	{ "path": "modules/math_module.gd", "setting": _DCKitSetting.MODULES_MATH },
	{ "path": "modules/string_module.gd", "setting": _DCKitSetting.MODULES_STRING },
	{ "path": "modules/batch_module.gd", "setting": _DCKitSetting.MODULES_BATCH },
	{ "path": "modules/system_module.gd", "setting": _DCKitSetting.MODULES_SYSTEM },
]

const UI_HOST_PRIVATE_INTERFACE = preload("./ui/dckit_host_interface.gd")
const DCKit_Host = preload("./ui/dckit_ui_host.tscn")

var _cmd_reg: _DCKitNS.Registries.CommandRegistry = null
var _ctor_reg: _DCKitNS.Registries.ConstructorRegistry = null
var _var_store: _DCKitNS.Core.VariableStore = null
var _tracer: _DCKitNS.Core.Tracer = null

var _analyzer: _DCKitNS.Analyzer.Analyzer = null
var _executor: _DCKitNS.Executor.Executor = null

var _input_feedback_controller: _DCKitNS.UI.InputFeedbackController = null

var _dckit_host_ref := WeakRef.new()

var _modules: Dictionary = { } # id → DCModule


func _init() -> void:
	_cmd_reg = _DCKitNS.Registries.CommandRegistry.new()
	_ctor_reg = _DCKitNS.Registries.ConstructorRegistry.new()
	_var_store = _DCKitNS.Core.VariableStore.new()

	_tracer = _DCKitNS.Core.Tracer.new()
	_tracer.open_session()

	_analyzer = _DCKitNS.Analyzer.Analyzer.new(_cmd_reg, _ctor_reg, _var_store)

	var auto = _DCKitNS.Core.AutoComplete.new(_cmd_reg, _ctor_reg, _var_store)

	_input_feedback_controller = _DCKitNS.UI.InputFeedbackController.new(_analyzer)
	_input_feedback_controller.set_completion_provider(auto)

	_executor = _DCKitNS.Executor.Executor.new(_cmd_reg, _ctor_reg, _var_store, _analyzer, _tracer)

	_register_modules()


func init_ui() -> UI_HOST_INTERFACE:
	var dckit_host := DCKit_Host.instantiate() as UI_HOST_INTERFACE
	_dckit_host_ref = weakref(dckit_host)

	var valid := true

	if not dckit_host:
		push_error("DCKit_Host is `null`")
		return null

	dckit_host.ready.connect(dckit_host.hide_console)
	dckit_host.set_connection_request_callback(_on_host_connection_requested)

	return dckit_host


#region Public API
func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	if input.is_empty():
		return null
	return _executor._analyzer.analyze(input, cursor_pos)


func run(raw_string: String) -> DCResult:
	if raw_string.is_empty():
		return DCResult.fail("Empty string passed")
	return await _executor.run(raw_string)


func abort() -> void:
	_executor.abort()


# Command register API

func register_def(def: DCDefinition) -> bool:
	if not def:
		push_warning("Definition is null")
		return false
	return _cmd_reg.register(def)


func unregister(p_name: String) -> bool:
	return _cmd_reg.unregister(p_name)


func lock_command(p_name: String) -> void:
	_cmd_reg.lock(p_name)


func unlock_command(p_name: String) -> void:
	_cmd_reg.unlock(p_name)


# Public: built-in and user modules take the same path. Add-only.
func add_module(module: DCModule) -> bool:
	if module == null or module.get_id().is_empty():
		push_warning("DCKit: module is null or has no id.")
		return false
	if _modules.has(module.get_id()):
		push_warning("DCKit: module '%s' already added." % module.get_id())
		return false
	_modules[module.get_id()] = module

	module.setup(_build_services(module.get_needs())) # always called; default is a no-op
	for def in module.get_commands():
		_cmd_reg.register(def)
	return true


# Lets callers reach a module's own public API (e.g. batch aliases).
func get_module(id: String) -> DCModule:
	return _modules.get(id)
#endregion


#region Logger API
# `details` is optional short context (max 100 chars) shown as a tooltip on
# the badge and written to the log file. Executor entries fill it with the
# breadcrumb themselves; callers here normally leave it empty.
func log_info(msg: String, details: String = "") -> void:
	_tracer.info(msg, details)


func log_warn(msg: String, details: String = "") -> void:
	_tracer.warn(msg, details)


func log_error(msg: String, details: String = "") -> void:
	_tracer.error(msg, details)


func log_help(msg: String, details: String = "") -> void:
	_tracer.help(msg, details)
#endregion


#region Variable store API
func get_var_value_raw(key: String) -> Variant:
	return _var_store.get_value_raw(key)


func get_typed_var(key: String, type: int, fallback: Variant = null) -> Variant:
	return _var_store.get_typed(key, type, fallback)


func is_var_live(key: String) -> bool:
	return _var_store.is_live(key)


func is_var_deferred(key: String) -> bool:
	return _var_store.is_deferred(key)


func set_var(key: String, value: Variant) -> bool:
	return _var_store.set_value(key, value).ok


func has_var(key: String) -> bool:
	return _var_store.has(key)


func delete_var(key: String) -> bool:
	return _var_store.delete(key)


func get_var_keys() -> Array:
	return _var_store.get_keys()


func get_var_value(key: String, fallback: Variant = null) -> Variant:
	if _var_store.is_deferred(key):
		_tracer.warn("get_var('%s') is a deferred variable, use 'await DCKit.resolve_var()'." % key)
		return fallback
	return _var_store.get_value(key, fallback)
	
func resolve_var(key: String) -> DCResult:
	return await _executor.resolve_var(key)
#endregion


func _register_modules() -> void:
	for path in CORE:
		add_module(path.new())

	for entry in OPTIONAL:
		if not _DCKitSetting.is_module_enabled(entry.setting):
			continue # skipped before anything is created or set up
		var module_res := load(get_script().resource_path.get_base_dir().path_join(entry.path))
		if module_res:
			add_module(module_res.new())


func _build_services(needs: int) -> DCModule.Services:
	var s := DCModule.Services.new()
	if needs & DCModule.Need.VARIABLES:
		s.variables = _var_store
	if needs & DCModule.Need.LOGGER:
		s.logger = _tracer
	if needs & DCModule.Need.PROFILER:
		s.profiler = _executor.profiler
	if needs & DCModule.Need.REGISTRY:
		s.registry = _cmd_reg
	return s


func _on_host_connection_requested() -> void:
	var dckit_host = _dckit_host_ref.get_ref() as UI_HOST_PRIVATE_INTERFACE
	if not dckit_host:
		push_warning("dckit_host is null in '_on_host_connection_requested' function")
		return
	var console = dckit_host.get_console_node()
	if not console:
		push_warning("console is null in '_on_host_connection_requested' function")
		return
	console.connect_executor(_executor)
	console.connect_tracer(_tracer)
	console.connect_feedback_controller(_input_feedback_controller)
