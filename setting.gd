class_name _DCKitSetting
extends RefCounted

enum LoggerPrintThershold {
	OK = 0,
	INFO = 1, # HELP as well,
	FAIL = 2,
	WARN = 3,
	ERROR = 4,
}

enum ConsoleMode {
	DOCK,
	WINDOW, # not supported yet
}
enum WindowEdge {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
}

const SETTING_PATH = "addons/DCKit/"

# setting path
const CONSOLE_MODE = "console_mode"
const WINDOW_EDGE = "window_edge"

const BATCH_DIR = "batch_directory"

const DEFAULT_FONT_SCALE = "scale/default_font_scale"
const DEFAULT_SPACE_SCALE = "scale/default_space_scale"
const DEFAULT_LOGGER_FONT_SCALE = "scale/default_logger_font_scale"

const MAX_EXECUTION_DEPTH = "execution/max_depth"
const MAX_ARGUMENT_DEPTH = "execution/max_argument_depth"

const ENABLED_IN_RELEASE = "export/enable_in_release"

const LOGGING_ENABLED = "logging/enabled"
const LOGGING_DIRECTORY = "logging/directory"
const LOGGING_MAX_SESSION_FILES = "logging/max_session_files"
const LOGGING_PRINT_THRESHOLD = "logging/print_threshold"

const HISTORY_ENABLED = "cmd_history/enabled"
const HISTORY_DIRECTORY = "cmd_history/directory"
const HISTORY_LIMIT = "cmd_history/limit"


#region Generic
static func get_setting(key: String, default_value: Variant) -> Variant:
	return ProjectSettings.get_setting(SETTING_PATH + key, default_value)


static func set_dckit_settings_as_internal(internal: bool) -> void:
	for property in ProjectSettings.get_property_list():
		var name: String = property.name
		if name.begins_with(SETTING_PATH):
			ProjectSettings.set_as_internal(name, internal)
	ProjectSettings.save()


static func register_dckit_settings():
	declare_setting(
		CONSOLE_MODE,
		ConsoleMode.DOCK,
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		_enum_hint_string(ConsoleMode),
	)
	declare_setting(
		WINDOW_EDGE,
		WindowEdge.BOTTOM,
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		_enum_hint_string(WindowEdge),
	)

	declare_setting(BATCH_DIR, "res://batch_file", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR)

	declare_setting(
		DEFAULT_FONT_SCALE,
		1.0,
		TYPE_FLOAT,
		PROPERTY_HINT_RANGE,
		"0.5,3.0,0.05,suffix:x",
	)
	declare_setting(
		DEFAULT_SPACE_SCALE,
		1.0,
		TYPE_FLOAT,
		PROPERTY_HINT_RANGE,
		"0.5,3.0,0.05,suffix:x",
	)
	declare_setting(
		DEFAULT_LOGGER_FONT_SCALE,
		1.0,
		TYPE_FLOAT,
		PROPERTY_HINT_RANGE,
		"0.5,3.0,0.05,suffix:x",
	)

	declare_setting(MAX_EXECUTION_DEPTH, 16, TYPE_INT, PROPERTY_HINT_RANGE, "1,32,1")
	declare_setting(MAX_ARGUMENT_DEPTH, 32, TYPE_INT, PROPERTY_HINT_RANGE, "1,128,1")

	declare_setting(ENABLED_IN_RELEASE, false, TYPE_BOOL)

	declare_setting(LOGGING_ENABLED, true, TYPE_BOOL)
	declare_setting(LOGGING_DIRECTORY, "user://DCKit/logs", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR)
	declare_setting(LOGGING_MAX_SESSION_FILES, 5, TYPE_INT)
	declare_setting(
		LOGGING_PRINT_THRESHOLD,
		LoggerPrintThershold.WARN,
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		_enum_hint_string(LoggerPrintThershold),
	)

	declare_setting(HISTORY_ENABLED, false, TYPE_BOOL)
	declare_setting(HISTORY_DIRECTORY, "user://DCKit", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR)
	declare_setting(HISTORY_LIMIT, 100, TYPE_INT, PROPERTY_HINT_RANGE, "20,400,1")

	ProjectSettings.save()


static func declare_setting(
	key: String,
	value: Variant,
	type: Variant.Type,
	hint: PropertyHint = PROPERTY_HINT_NONE,
	hint_str: String = "",
) -> void:
	if !ProjectSettings.has_setting(SETTING_PATH + key):
		ProjectSettings.set_setting(SETTING_PATH + key, value)

	ProjectSettings.set_initial_value(SETTING_PATH + key, value)
	ProjectSettings.set_as_basic(SETTING_PATH + key, true)
	ProjectSettings.add_property_info(
		{ "name": SETTING_PATH + key, "type": type, "hint": hint, "hint_string": hint_str }
	)


static func set_setting(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(SETTING_PATH + key, value)
#endregion


#region console
static func get_console_mode() -> ConsoleMode:
	return clampi(get_setting(CONSOLE_MODE, ConsoleMode.DOCK), 0, ConsoleMode.size() - 1)


static func get_window_edge() -> WindowEdge:
	return clampi(get_setting(WINDOW_EDGE, WindowEdge.BOTTOM), 0, WindowEdge.size() - 1)
#endregion


#region Batch Directory
static func get_batch_directory() -> String:
	return get_setting(BATCH_DIR, "res://batch_file") as String
#endregion


#region UI
static func get_default_font_scale() -> float:
	return clampf(get_setting(DEFAULT_FONT_SCALE, 1.0) as float, 0.5, 3.0)


static func get_default_space_scale() -> float:
	return clampf(get_setting(DEFAULT_SPACE_SCALE, 1.0) as float, 0.5, 3.0)


static func get_default_log_font_scale() -> float:
	return clampf(get_setting(DEFAULT_LOGGER_FONT_SCALE, 1.0) as float, 0.5, 3.0)
#endregion


#region Execution
static func get_max_execution_depth() -> int:
	return clampi(get_setting(MAX_EXECUTION_DEPTH, 16) as int, 1, 32)


static func get_max_argument_depth() -> int:
	return clampi(get_setting(MAX_ARGUMENT_DEPTH, 32) as int, 1, 128)
#endregion


#region Export
static func get_enabled_in_release() -> bool:
	return get_setting(ENABLED_IN_RELEASE, false) as bool
#endregion


#region Logging
static func get_logging_enabled() -> bool:
	return get_setting(LOGGING_ENABLED, true) as bool


static func get_logging_directory() -> String:
	return get_setting(LOGGING_DIRECTORY, "user://DCKit/logs") as String


static func get_logging_max_session_files() -> int:
	return get_setting(LOGGING_MAX_SESSION_FILES, 5) as int


static func get_logging_print_threshold() -> LoggerPrintThershold:
	return clampi(
		get_setting(LOGGING_PRINT_THRESHOLD, LoggerPrintThershold.WARN),
		0,
		LoggerPrintThershold.size() - 1,
	)
#endregion


#region History
static func get_history_enabled() -> bool:
	return get_setting(HISTORY_ENABLED, false) as bool


static func get_history_limit() -> int:
	return clampi(get_setting(HISTORY_LIMIT, 100) as int, 20, 400)


static func get_history_directory() -> String:
	return get_setting(HISTORY_DIRECTORY, "user://DCKit") as String
#endregion


static func _enum_hint_string(obj):
	var parts := []
	for key in obj:
		parts.append("%s:%d" % [key, obj[key]])
	return ",".join(parts)
