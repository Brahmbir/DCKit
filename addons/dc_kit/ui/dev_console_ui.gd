@tool
extends Control

#  SCENE NODE REFS
const CMDEdit = preload("./cmd_edit/cmd_edit.gd")
const ErrorContainer = preload("./error_container/error_container.gd")
const LogViewerController = preload("./log_view/log_view_controller.gd")
const InfoPanel = preload("./info_panel/info_panel.gd")

#region handlers — link with controller
const ViewController := preload("../view_controllers/view_controller.gd")

@export_group("shortcuts", "sct")
@export var sct_toggle_info_panel: Shortcut = _get_default_toggle_info_panel_sct()

#region themes_colour change logic
@export_color_no_alpha var normal_colour := Color.ALICE_BLUE:
	set(value):
		if normal_colour == value:
			return
		normal_colour = value
		_rebuild_theme()
@export_color_no_alpha var highlighted_colour := Color("3b82f6"):
	set(value):
		if highlighted_colour == value:
			return
		highlighted_colour = value
		_rebuild_theme()

@export_range(0.5, 3.0, 0.05)
var font_scale: float = 1.0:
	set(value):
		value = max(value, 0.1)
		if is_equal_approx(font_scale, value):
			return
		font_scale = value
		_rebuild_theme()

#region handlers — link with executor
var _executor_ref: WeakRef = WeakRef.new()
var _is_executor_bound := false
var _ui_controller: WeakRef = WeakRef.new()
var _is_controller_bound := false

@onready var margin_container: MarginContainer = $MarginContainer

@onready var _input_comp: CMDEdit = %CmdEdit
@onready var _error_container: ErrorContainer = %ErrorContainer
@onready var _log_view: LogViewerController = %log_viewer
@onready var _info_panel: InfoPanel = %info_panel


func _init() -> void:
	font_scale = _DCKitNamespace.Setting.get_setting(_DCKitNamespace.Setting.SETTING_UI_SCALE, 1.0)
	_rebuild_theme()


func _ready() -> void:
	_rebuild_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS

	if _input_comp.has_signal("focus_changed") and _input_comp.has_signal("abort_requested"):
		_input_comp.command_submitted.connect(_on_command_submitted)
		_input_comp.abort_requested.connect(_on_abort_requested)
	_error_container.item_pressed.connect(
		func(p: int, l: int):
			_input_comp.move_caret_to(p),
	)

	_error_container.expanded = false

	_bind_controller()
	_bind_executor()


func _input(event: InputEvent) -> void:
	if _shortcut_pressed(event, sct_toggle_info_panel):
		_info_panel.toggle()
		accept_event()
		return


func focus_input():
	_input_comp.focus()


func get_command_def_array() -> Array[DCDefinition]:
	var def_arr: Array[DCDefinition] = []
	return def_arr


func setup_executor_connection(executor: _DCKitNamespace.Executor) -> void:
	_executor_ref = weakref(executor)
	_is_executor_bound = false

	if is_node_ready():
		_bind_executor()


func setup_ui_controller(controller: ViewController) -> void:
	_ui_controller = weakref(controller)
	_is_controller_bound = false

	if is_node_ready():
		_bind_controller()


func _rebuild_theme():
	var pixels := int(font_scale * 18)

	var t_util := _DCKitNamespace.ThemeUtil.new()

	var font_theme := t_util.get_dckit_theme(pixels, normal_colour, highlighted_colour)
	if font_theme != null and is_node_ready():
		theme = font_theme
#endregion


func _get_default_toggle_info_panel_sct() -> Shortcut:
	return _make_shortcut(KEY_SPACE, true, true)


func _bind_executor():
	if _is_executor_bound:
		return

	var ref = _executor_ref.get_ref()
	if (ref == null and not (ref is _DCKitNamespace.Executor)):
		return

	_is_executor_bound = true

	var executor: _DCKitNamespace.Executor = ref
	_is_controller_bound = true

	_log_view.setup(executor.logger)

	executor.command_executed.connect(_on_execution_finished)
	executor.command_aborted.connect(
		func():
			if _input_comp != null:
				_input_comp.set_busy(false),
	)


func _on_command_submitted(raw: String) -> void:
	_input_comp.set_busy(true)
	var ref = _executor_ref.get_ref()
	if (ref == null and not (ref is _DCKitNamespace.Executor)):
		return
	(ref as _DCKitNamespace.Executor).run(raw)


func _on_execution_finished(_raw = null, _result = null) -> void:
	_input_comp.set_busy(false)


func _on_abort_requested() -> void:
	var ref = _executor_ref.get_ref()
	if (ref == null and not (ref is _DCKitNamespace.Executor)):
		return
	(ref as _DCKitNamespace.Executor).abort()
#endregion


func _bind_controller() -> void:
	if _is_controller_bound:
		return

	var ref = _ui_controller.get_ref()
	if (ref == null and not (ref is ViewController)):
		return

	var controller: ViewController = ref
	_is_controller_bound = true

	_input_comp.input_text_changed.connect(
		func(text: String, caret_pos: int) -> void:
			if controller:
				controller.on_text_changed(text, caret_pos),
	)
	_input_comp.caret_changed.connect(
		func(caret_pos: int) -> void:
			if controller:
				controller.on_cursor_moved(caret_pos),
	)
	_input_comp.autocomplete_popup.setup(controller.autocomplete)

	controller.on_text_changed("", 0) # initial analysis to fill autocomplete popup
	controller.error_view_ctl.update_posted.connect(
		func(_result):
			_error_container.show_diagnostic(_result),
	)
	controller.info_view_ctl.update_posted.connect(
		func(_result):
			_info_panel.show_info(_result),
	)
#endregion


#region  helpers
func _shortcut_pressed(event: InputEvent, shortcut: Shortcut) -> bool:
	return (event is InputEventKey and event.pressed and shortcut.matches_event(event))


func _make_shortcut(key: Key, ctrl := false, shift := false, alt := false) -> Shortcut:
	var key_event := InputEventKey.new()

	key_event.keycode = key
	key_event.ctrl_pressed = ctrl
	key_event.shift_pressed = shift
	key_event.alt_pressed = alt
	key_event.command_or_control_autoremap = true

	var shortcut := Shortcut.new()
	shortcut.events = [key_event]

	return shortcut
#endregion
