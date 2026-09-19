extends RefCounted

const BatchRunner = preload("./basic_command/batch_runner.gd")
const BasicCMD = preload("./basic_command/basic_commands.gd")
const ControlFlowCMD = preload("./basic_command/control_flow_commands.gd")

const ViewController := preload("./view_controllers/view_controller.gd")

const DCKit_UI_PackScene = preload("./ui/dev_console_ui.tscn")

var _cmd_reg: _DCKitRegistriesNamespace.CommandRegistry = null
var _ctor_reg: _DCKitRegistriesNamespace.ConstructorRegistry = null
var _var_store: _DCKitCoreNamespace.VariableStore = null

var _analyzer: _DCKitAnalyzerNamespace.Analyzer = null
var _executor: _DCKitExecutorNamespace.Executor = null

var _view_controller = null # ViewController

var _hint := """[i][b][color=gray]Keyboard shortcuts:[/color][/b]
[color=#6C7086][color=gray]Autocomplete[/color]
		[b]Ctrl+Space[/b] — toggle autocomplete
		[b]Up[/b] / [b]Down[/b] — navigate suggestions (when open)
		[b]Tab[/b] / [b]Enter[/b] — accept highlighted suggestion (when open)
		[b]Esc[/b] — close autocomplete (when open)
[color=gray]History[/color]
		[b]Up[/b] / [b]Down[/b] — navigate history
		[b]Ctrl+Up[/b] / [b]Ctrl+Down[/b] — navigate prefix-matched history
[color=gray]Misc[/color]
		[b]Enter[/b] — submit
		[b]Ctrl+Shift+Space[/b] — expand/collapse info panel[/i][/color]"""


func _init() -> void:
	_init_systems()


func init_ui() -> Control:
	var dc_kit_ui := DCKit_UI_PackScene.instantiate()
	dc_kit_ui.setup_ui_controller(_view_controller)
	dc_kit_ui.setup_executor_connection(_executor)

	_executor.logger.simple_print(_get_shotcuts_hint())

	dc_kit_ui.hide()
	return dc_kit_ui


#region Public API
func analyze(input: String, cursor_pos: int = -1) -> DCAnalysisResult:
	if input.is_empty():
		return null
	_view_controller.on_text_changed(input, cursor_pos)
	return _view_controller.last_result


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


func _init_systems() -> void:
	_cmd_reg = _DCKitRegistriesNamespace.CommandRegistry.new()
	_ctor_reg = _DCKitRegistriesNamespace.ConstructorRegistry.new()
	_var_store = _DCKitCoreNamespace.VariableStore.new()

	_analyzer = _DCKitAnalyzerNamespace.Analyzer.new(_cmd_reg, _ctor_reg, _var_store)

	_view_controller = ViewController.new(_analyzer)
	_view_controller.set_autocomplete(_DCKitCoreNamespace.AutoComplete.new(
			_cmd_reg,
			_ctor_reg,
			_var_store,
		))

	_executor = _DCKitExecutorNamespace.Executor.new(_cmd_reg, _ctor_reg, _var_store, _analyzer)

	_register_commands(_cmd_reg)


func _register_defs(defs: Array[DCDefinition]) -> void:
	for def in defs:
		_cmd_reg.register(def)


func _register_commands(_command_reg: _DCKitRegistriesNamespace.CommandRegistry) -> void:
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


func _get_shotcuts_hint() -> String:
	return _hint
