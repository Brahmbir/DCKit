extends Node
 
# INFO SIGNALS  — for game code to connect to

signal console_opened # Emitted when the console UI becomes visible.
signal console_closed # Emitted when the console UI is hidden.

const BatchRunner = preload("./basic_command/batch_runner.gd")
const BasicCMD = preload("./basic_command/basic_commands.gd")
const ControlFlowCMD = preload("./basic_command/control_flow_commands.gd")

const _CmdReg := preload("./core/registries/command_registry/command_registry.gd")
const _CtorReg := preload("./core/registries/constructor_registry/constructor_registry.gd")
const _VarStore := preload("./core/variable_store.gd")

const _Analyzer := preload("./core/analyzer/analyzer.gd")
const AutoComplete = preload("./core/autocomplete.gd")
const _ViewController := preload("./view_controllers/view_controller.gd")

const _Executor := preload("./core/executor/executor.gd")

const _UI_SCENE = preload("./ui/dev_console_ui.tscn")

# INFO In a release export, the command and ui is never added.
var _enabled := OS.is_debug_build()

var _cmd_reg : _CmdReg = null  # CommandRegistry
var _ctor_reg : _CtorReg = null  # ConstructorRegistry
var _var_store : _VarStore = null  # VariableStore
 
var _analyzer : _Analyzer = null  # Analyzer
var _view_controller = null  # ViewController
 
var _executor : _Executor = null # Executor
 

const SETTING := preload("./setting_utils.gd")


func _init() -> void:
	_read_project_settings()

func _read_project_settings() -> void:
	var enabled_in_release: bool = SETTING.get_setting(
		SETTING._SETTING_ENABLED_IN_RELEASE,
		false
	)
	_enabled = OS.is_debug_build() or enabled_in_release


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_systems()
	
	if _enabled:
		_init_ui()

func _init_systems() -> void:
	_cmd_reg = _CmdReg.new()
	_ctor_reg = _CtorReg.new()
	_var_store = _VarStore.new()
		
	_analyzer = _Analyzer.new(_cmd_reg, _ctor_reg, _var_store)
	
	_view_controller = _ViewController.new(_analyzer)
	_view_controller.set_autocomplete(AutoComplete.new(_cmd_reg, _ctor_reg, _var_store))
	
	_executor = _Executor.new(_cmd_reg, _ctor_reg, _var_store, _analyzer)
	
	_register_commands(_cmd_reg)
	 
#region Public API 
 
func analyze(input: String, cursor_pos: int = -1) -> _Analyzer.DCAnalysisResult :
	_view_controller.on_text_changed(input, cursor_pos)
	return _view_controller.last_result
 
func run(raw_string: String) -> DCResult:
	if not _enabled:
		return DCResult.fail("Console disabled")
	return await _executor.run(raw_string)

func abort() -> void: _executor.abort()

# Command register API
func register(
		p_name      : String,
		handler     : Callable,
		description : String         = "",
		params      : Array[DCParam] = []) -> bool:
	
	if not _enabled:
		return false
	
	var def := DCDefinition.new(p_name, handler, description, params)
	return _cmd_reg.register(def)

func register_def(def: DCDefinition) -> bool: 
	if not _enabled:
		return false
	return _cmd_reg.register(def)

func unregister(p_name: String) -> bool: return _cmd_reg.unregister(p_name)
func lock_command(p_name: String) -> void: _cmd_reg.lock(p_name)
func unlock_command(p_name: String) -> void: _cmd_reg.unlock(p_name)

# Variable store API
func get_var(key: String, fallback: String = "") -> String: return _var_store.get_value(key, fallback)
func set_var(key: String, value: String) -> bool:   return _var_store.set_value(key, value).ok
func has_var(key: String) -> bool:   return _var_store.has(key)
func delete_var(key: String) -> bool:   return _var_store.delete(key)
func get_var_keys() -> Array:  return _var_store.get_keys()

# ui Logic
var _ui : Control

func _init_ui() -> void:
	_ui = _UI_SCENE.instantiate()
	_ui.setup_ui_controller(_view_controller)
	_ui.setup_executor_connection(_executor)
	add_child(_ui)
	_ui.hide()

func has_ui() -> bool:
	return _ui != null

# visibility API
func show_console() -> void:
	if not has_ui(): return
	
	if _ui.visible:
		return
	_ui.show()
	_ui.focus_input()
	console_opened.emit()

func hide_console() -> void:
	if not has_ui(): return

	if not _ui.visible:
		return
	_ui.hide()
	console_closed.emit()

func toggle_console() -> void:
	if not has_ui(): return

	if _ui.visible:
		hide_console()
	else:
		show_console()

func is_console_open() -> bool:
	return has_ui() and _ui.visible
#endregion

func _register_defs(defs: Array[DCDefinition]) -> void:
	for def in defs:
		_cmd_reg.register(def)

func _register_commands(command_reg : _CmdReg) -> void :
	if not _enabled: return
	
	if BasicCMD: _register_defs(BasicCMD.get_command_def_array())
	if ControlFlowCMD: _register_defs(ControlFlowCMD.get_command_def_array())
	
	
	if BatchRunner: _register_defs(BatchRunner.new().get_command_def_array())
	if _var_store : _register_defs(_var_store.get_command_def_array())
	if _executor : _register_defs(_executor.get_command_def_array())
	
	
	#if has_ui(): _ui.get_command_def_array()
