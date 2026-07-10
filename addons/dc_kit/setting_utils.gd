extends Node

enum LOGGER_PRINT_THRESHOLD{
	OK = 0,
	INFO = 1, # HELP as well,
	FAIL = 2,
	WARN = 3,
	ERROR = 4,
}
s
const SETTING_PATH = "addons/DCKit/"

const SETTING_ENABLED_IN_RELEASE = "export/enable_in_release"
const SETTING_EXPORT_BATCH_DIR = "export/batch_directory"
#const SETTING_ = "logging/max_session_files"
#const SETTING_   = "logging/print_threshold"

const SETTING_LOGGING_ENABLED = "logging/enabled"
const SETTING_LOGGING_DIRECTORY = "logging/directory"
const SETTING_LOGGING_MAX_SESSION_FILES = "logging/max_session_files"
const SETTING_LOGGING_PRINT_THRESHOLD = "logging/print_threshold"


static func get_setting(key: String, default_value: Variant) -> Variant:
	return ProjectSettings.get_setting(SETTING_PATH + key, default_value)


static func _register_project_settings(prefix:String = SETTING_PATH) -> void:
	_declare_setting(prefix + SETTING_ENABLED_IN_RELEASE, false, TYPE_BOOL)
		
	_declare_setting(
		prefix + SETTING_EXPORT_BATCH_DIR,
		"res://batch_file/", 
		TYPE_STRING, 
		{"hint": PROPERTY_HINT_GLOBAL_DIR})
	
	_declare_setting(prefix + SETTING_LOGGING_ENABLED, true, TYPE_BOOL)
	_declare_setting(
		prefix + SETTING_LOGGING_DIRECTORY, 
		"user://DCKit/logs/", 
		TYPE_STRING, 
		{"hint": PROPERTY_HINT_GLOBAL_DIR})
	_declare_setting(prefix + SETTING_LOGGING_MAX_SESSION_FILES, 5, TYPE_INT)
	_declare_setting(prefix + SETTING_LOGGING_PRINT_THRESHOLD,
		LOGGER_PRINT_THRESHOLD.WARN,
		TYPE_INT,
		{"hint": PROPERTY_HINT_ENUM,"hint_string": ",".join(LOGGER_PRINT_THRESHOLD.keys()) })

static func _unregister_project_settings(prefix:String = SETTING_PATH) -> void:
	_undeclare_setting(prefix + SETTING_ENABLED_IN_RELEASE)
	_undeclare_setting(prefix + SETTING_EXPORT_BATCH_DIR)
	_undeclare_setting(prefix + SETTING_LOGGING_ENABLED)
	_undeclare_setting(prefix + SETTING_LOGGING_DIRECTORY)
	_undeclare_setting(prefix + SETTING_LOGGING_MAX_SESSION_FILES)
	_undeclare_setting(prefix + SETTING_LOGGING_PRINT_THRESHOLD)

static func _declare_setting(key: String, default_value: Variant, type: int, hint: Dictionary = {} ) -> void:
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, default_value)
		ProjectSettings.set_initial_value(key, default_value)
		var info = { "name": key, "type": type }
		info.merge(hint,true)
		ProjectSettings.add_property_info(info)
		ProjectSettings.save()

static func _undeclare_setting(key: String ) -> void:
	if ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, null)
		ProjectSettings.save()
