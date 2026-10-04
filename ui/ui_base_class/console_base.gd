@tool
extends Control

const FONT_SIZE = 24
const LOG_FONT_SIZE = 20
const SPACE_SIZE = 16

@export_category("components")
@export var input_component: _DCKitUINamespace.InputComponentBase
@export var log_component: _DCKitUINamespace.LoggerComponentBase
@export var error_component: _DCKitUINamespace.ErrorComponentBase

@export_category("UI Constants")
@export var default_theme: Theme:
	set(value):
		if value == default_theme:
			return
		default_theme = value
		_queue_theme_rebuild()

@export_group("ui scales", "ui_")
@export_range(0.5, 3.0, 0.05)
var ui_font_scale: float = 1.0:
	get:
		return _DCKitUINamespace.scales.font
	set(value):
		_DCKitUINamespace.scales.font = value

@export_range(0.5, 3.0, 0.05)
var ui_log_font_scale: float = 1.0:
	get:
		return _DCKitUINamespace.scales.log_font
	set(value):
		_DCKitUINamespace.scales.log_font = value

@export_range(0.5, 3.0, 0.05)
var ui_space_scale: float = 1.0:
	get:
		return _DCKitUINamespace.scales.space
	set(value):
		_DCKitUINamespace.scales.space = value

var _theme_rebuild_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_font_scale = _DCKitSetting.get_default_font_scale()
	ui_log_font_scale = _DCKitSetting.get_default_log_font_scale()
	ui_space_scale = _DCKitSetting.get_default_space_scale()
	_queue_theme_rebuild() # always, even if no scale differed from its default


func grab_focus_on_input():
	_DCKitUINamespace.not_implemented("grab_focus_on_input")


func release_focus_on_input():
	_DCKitUINamespace.not_implemented("release_focus_on_input")


func connect_executor(executor: _DCKitExecutorNamespace.Executor):
	_DCKitUINamespace.not_implemented("connect_executor")


func connect_feedback_controller(controller: _DCKitUINamespace.InputFeedbackController):
	_DCKitUINamespace.not_implemented("connect_feedback_controller")


func connect_cmd_history(history: _DCKitUINamespace.CommandHistory):
	_DCKitUINamespace.not_implemented("connect_cmd_history")


func _queue_theme_rebuild() -> void:
	if _theme_rebuild_queued:
		return
	_theme_rebuild_queued = true
	_rebuild_theme.call_deferred()


func _rebuild_theme() -> void:
	_theme_rebuild_queued = false
	if default_theme == null:
		return
	_default_theme_changed()


func _default_theme_changed():
	_DCKitUINamespace.not_implemented("_default_theme_changed")
