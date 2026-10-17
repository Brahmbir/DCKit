extends "./utils/backend_interface.gd"

const BatchRunner = preload("./basic_command/batch_runner.gd")
const BasicCMD = preload("./basic_command/basic_commands.gd")
const ControlFlowCMD = preload("./basic_command/control_flow_commands.gd")

const UI_HOST_PRIVATE_INTERFACE = preload("./ui/dckit_host_interface.gd")
const DCKit_Host = preload("./ui/dckit_ui_host.tscn")

var _cmd_reg: _DCKitNS.Registries.CommandRegistry = null
var _ctor_reg: _DCKitNS.Registries.ConstructorRegistry = null
var _var_store: _DCKitNS.Core.VariableStore = null

var _analyzer: _DCKitNS.Analyzer.Analyzer = null
var _executor: _DCKitNS.Executor.Executor = null

var _input_feedback_controller: _DCKitNS.UI.InputFeedbackController = null

var _dckit_host_ref := WeakRef.new()


func _init() -> void:
	_cmd_reg = _DCKitNS.Registries.CommandRegistry.new()
	_ctor_reg = _DCKitNS.Registries.ConstructorRegistry.new()
	_var_store = _DCKitNS.Core.VariableStore.new()

	_analyzer = _DCKitNS.Analyzer.Analyzer.new(_cmd_reg, _ctor_reg, _var_store)

	var auto = _DCKitNS.Core.AutoComplete.new(_cmd_reg, _ctor_reg, _var_store)

	_input_feedback_controller = _DCKitNS.UI.InputFeedbackController.new(_analyzer)
	_input_feedback_controller.set_completion_provider(auto)

	_executor = _DCKitNS.Executor.Executor.new(_cmd_reg, _ctor_reg, _var_store, _analyzer)

	_register_commands(_cmd_reg)


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
func register(
	p_name: String,
	handler: Callable,
	description: String = "",
	params: Array[DCDefinition.Param] = [],
) -> bool:
	var def := DCDefinition.new(p_name, handler, description, params)
	return _cmd_reg.register(def)


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
#endregion


#region Variable store API
func get_var(key: String, fallback: String = "") -> String:
	return _var_store.get_value(key, fallback)


func set_var(key: String, value: String) -> bool:
	return _var_store.set_value(key, value).ok


func has_var(key: String) -> bool:
	return _var_store.has(key)


func delete_var(key: String) -> bool:
	return _var_store.delete(key)


func get_var_keys() -> Array:
	return _var_store.get_keys()
#endregion


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
	console.connect_feedback_controller(_input_feedback_controller)


func _register_defs(defs: Array[DCDefinition]) -> void:
	for def in defs:
		_cmd_reg.register(def)


func _register_commands(_command_reg: _DCKitNS.Registries.CommandRegistry) -> void:
	if BasicCMD:
		_register_defs(BasicCMD.get_command_def_array())
	if ControlFlowCMD:
		_register_defs(ControlFlowCMD.get_command_def_array())

	if BatchRunner:
		_register_defs(BatchRunner.new().get_command_def_array())
	if _var_store:
		_register_defs(_var_store.get_command_def_array())
	if _executor:
		_register_defs(_executor.get_command_def_array())
