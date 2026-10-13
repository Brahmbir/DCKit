@tool
extends Control

const STR_NAME_SIZE_GROUP = &"editor_ui_"

const STR_NAME_FONT_SIZE = STR_NAME_SIZE_GROUP + &"font_scale"
const STR_NAME_LOG_FONT_SIZE = STR_NAME_SIZE_GROUP + &"log_font_scale"
const STR_NAME_SPACE_SIZE = STR_NAME_SIZE_GROUP + &"space_scale"

const FONT_SIZE = 24
const LOG_FONT_SIZE = 20
const SPACE_SIZE = 16

@export_category("components")
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


func _ready() -> void:
	_queue_theme_rebuild() # always, even if no scale differed from its default


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "UI Scales",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": STR_NAME_SIZE_GROUP,
		},
		{
			"name": STR_NAME_FONT_SIZE,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.5,3.0,0.05",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
		},
		{
			"name": STR_NAME_LOG_FONT_SIZE,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.5,3.0,0.05",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
		},
		{
			"name": STR_NAME_SPACE_SIZE,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.5,3.0,0.05",
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
		},
	]


func _property_can_revert(property: StringName) -> bool:
	return property in [STR_NAME_FONT_SIZE, STR_NAME_LOG_FONT_SIZE, STR_NAME_SPACE_SIZE]


func _property_get_revert(property: StringName) -> Variant:
	match property:
		STR_NAME_FONT_SIZE:
			return _DCKitSetting.get_default_font_scale()

		STR_NAME_LOG_FONT_SIZE:
			return _DCKitSetting.get_default_log_font_scale()

		STR_NAME_SPACE_SIZE:
			return _DCKitSetting.get_default_space_scale()

	return null


func _get(property: StringName) -> Variant:
	match property:
		STR_NAME_FONT_SIZE:
			return _DCKitNS.UI.mobile_layout.get_scales().font

		STR_NAME_LOG_FONT_SIZE:
			return _DCKitNS.UI.mobile_layout.get_scales().log_font

		STR_NAME_SPACE_SIZE:
			return _DCKitNS.UI.mobile_layout.get_scales().space

	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		STR_NAME_FONT_SIZE:
			_DCKitNS.UI.mobile_layout.get_scales().font = value
			return true

		STR_NAME_LOG_FONT_SIZE:
			_DCKitNS.UI.mobile_layout.get_scales().log_font = value
			return true

		STR_NAME_SPACE_SIZE:
			_DCKitNS.UI.mobile_layout.get_scales().space = value
			return true
	return false


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
