@tool
extends Control

signal ui_close_requested

@export_category("components")
@export var header_component: _DCKitNS.UI.HeaderComponentBase

@export var input_component: _DCKitNS.UI.InputComponentBase
@export var log_component: _DCKitNS.UI.LoggerComponentBase
@export var error_component: _DCKitNS.UI.ErrorComponentBase

@export var info_component: _DCKitNS.UI.InfoComponentBase

@export_category("UI Constants")
@export var default_theme: Theme:
	set(value):
		if value == default_theme:
			return
		default_theme = value
		_queue_theme_rebuild()

var _theme_rebuild_queued := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_title_bar_visibility(visibility: bool):
	_DCKitNS.not_implemented("set_title_bar_visibility")


func grab_focus_on_input():
	_DCKitNS.not_implemented("grab_focus_on_input")


func release_focus_on_input():
	_DCKitNS.not_implemented("release_focus_on_input")


func connect_executor(executor: _DCKitNS.Executor.Executor):
	_DCKitNS.not_implemented("connect_executor")


func connect_feedback_controller(controller: _DCKitNS.UI.InputFeedbackController):
	_DCKitNS.not_implemented("connect_feedback_controller")


func connect_cmd_history(history: _DCKitNS.UI.CommandHistory):
	_DCKitNS.not_implemented("connect_cmd_history")


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
	_DCKitNS.not_implemented("_default_theme_changed")
