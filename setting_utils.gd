extends Node

enum LoggerPrintThershold {
	OK = 0,
	INFO = 1, # HELP as well,
	FAIL = 2,
	WARN = 3,
	ERROR = 4,
}

const SETTING_PATH = "addons/DCKit/"

const SETTING_BATCH_DIR = "batch_directory"
const SETTING_UI_SCALE = "ui_scale"
const SETTING_ENABLED_IN_RELEASE = "export/enable_in_release"
#const SETTING_   = "logging/print_threshold"
const SETTING_LOGGING_ENABLED = "logging/enabled"
const SETTING_LOGGING_DIRECTORY = "logging/directory"
const SETTING_LOGGING_MAX_SESSION_FILES = "logging/max_session_files"
const SETTING_LOGGING_PRINT_THRESHOLD = "logging/print_threshold"


static func get_setting(key: String, default_value: Variant) -> Variant:
	return ProjectSettings.get_setting(SETTING_PATH + key, default_value)


static func set_settings_internal(internal: bool, prefix := SETTING_PATH) -> void:
	for property in ProjectSettings.get_property_list():
		var name: String = property.name

		if name.begins_with(prefix):
			ProjectSettings.set_as_internal(name, internal)

	ProjectSettings.save()


static func _register_project_settings(prefix: String = SETTING_PATH) -> void:
	#region All settings
	_declare_setting(
		prefix + SETTING_UI_SCALE,
		1.0,
		TYPE_FLOAT,
		{
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.5,3.0,0.05,suffix:x",
			"doc": "Scales the Dev Console user interface. A value of 1.0 uses the default size.",
		},
	)
	_declare_setting(
		prefix + SETTING_BATCH_DIR,
		"res://batch_file/",
		TYPE_STRING,
		{ "hint": PROPERTY_HINT_GLOBAL_DIR, "doc": "Directory containing batch scripts" },
	)

	_declare_setting(
		prefix + SETTING_ENABLED_IN_RELEASE,
		false,
		TYPE_BOOL,
		{
			"doc": "Enables DCKit functionality in exported release builds. "
			+ "Disable this to strip all editor-only features from production builds."
		},
	)

	_declare_setting(
		prefix + SETTING_LOGGING_ENABLED,
		true,
		TYPE_BOOL,
		{
			"doc": "Enables DCKit's logging system. "
			+ "When disabled, no log files or console output are produced."
		},
	)
	_declare_setting(
		prefix + SETTING_LOGGING_DIRECTORY,
		"user://DCKit/logs/",
		TYPE_STRING,
		{
			"hint": PROPERTY_HINT_GLOBAL_DIR,
			"doc": "Directory where DCKit stores log files. "
			+ "Supports the user:// virtual filesystem.",
		},
	)
	_declare_setting(
		prefix + SETTING_LOGGING_MAX_SESSION_FILES,
		5,
		TYPE_INT,
		{
			"doc": "Maximum number of log sessions to retain. "
			+ "Older log files are automatically deleted when this limit is exceeded."
		},
	)
	_declare_setting(
		prefix + SETTING_LOGGING_PRINT_THRESHOLD,
		LoggerPrintThershold.WARN,
		TYPE_INT,
		{
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(LoggerPrintThershold.keys()),
			"doc": "Minimum log severity printed to the editor Output panel. "
			+ "Messages below this level are ignored by the console.",
		},
	)
	#endregion

	ProjectSettings.save()


static func _declare_setting(
	key: String,
	default_value: Variant,
	type: int,
	hint: Dictionary = { },
	_count: int = 0,
) -> void:
	if !ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, default_value)

	ProjectSettings.set_initial_value(key, default_value)
	ProjectSettings.set_as_basic(key, true)
	#ProjectSettings.set_order(key, count)
	var info := { "name": key, "type": type }
	info.merge(hint, true)

	ProjectSettings.add_property_info(info)
