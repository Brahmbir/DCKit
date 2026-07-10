# tracer.gd but refered as logger
# Central log store for the developer console.
# Accessed via preload; no class_name.
extends RefCounted

const LogFileWriter := preload("./log_file_writer.gd")

signal entry_added(entry: LogEntry)
signal cleared


# Level ordering — used by get_at_or_above() and _maybe_print().
# Higher value = more severe.
const _LEVEL_ORDER : Dictionary = {
	"OK"    : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.OK,
	"INFO"  : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.INFO,
	"HELP"  : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.INFO,
	"WARN"  : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.WARN,
	"FAIL"  : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.FAIL,
	"ERROR" : _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.ERROR,
}

const _MEMORY_LIMIT_DEFAULT : int = 200

var print_threshold : String = "WARN"
var memory_limit    : int    = _MEMORY_LIMIT_DEFAULT

var _entries     : Array = []   # Array[LogEntry]
var _file_writer := LogFileWriter.new()

func _init() -> void:
	_read_project_settings()


func _read_project_settings() -> void:
	var file_logging_enabled : bool   = true
	var log_dir              : String = "user://DCKit/logs/"
	var max_files            : int    = 5

	file_logging_enabled = _DCKitNamespace.Setting.get_setting(
		_DCKitNamespace.Setting.SETTING_LOGGING_ENABLED,
		file_logging_enabled
	)
	log_dir = _DCKitNamespace.Setting.get_setting(
		_DCKitNamespace.Setting.SETTING_LOGGING_DIRECTORY,
		log_dir
	)
	max_files = _DCKitNamespace.Setting.get_setting(
		_DCKitNamespace.Setting.SETTING_LOGGING_MAX_SESSION_FILES,
		max_files
	)
	print_threshold = _DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD.keys()[
		_DCKitNamespace.Setting.get_setting(
			_DCKitNamespace.Setting.SETTING_LOGGING_PRINT_THRESHOLD,
			_DCKitNamespace.Setting.LOGGER_PRINT_THRESHOLD[print_threshold]
		)
	]

	_file_writer.configure(log_dir, max_files, file_logging_enabled)


func open_session() -> void:
	_file_writer.open_session()


# Public write API — called by Executor stubs.
# `origin` is accepted to match the executor interface but is not stored.

func log_command(raw: String, stack: Array, _origin: String = "user") -> void:
	_store(_make_entry("COMMAND", "INFO", stack, raw))


func log_system(message: String, stack: Array, _origin: String = "user") -> void:
	_store(_make_entry("SYSTEM", "INFO", stack, message))


func log_result(result: DCResult, stack: Array, _origin: String = "user") -> void:
	_store(_make_entry(
		"RESULT",
		"OK" if result.success else "FAIL",
		stack,
		result.get_log_message()
	))


# Returns a scoped DCLogger bound to one command invocation.
func create_command_logger(stack: Array, _origin: String = "user") -> DCLogger:
	return DCLogger.new(self, _origin, stack)


# Called by DCLogger — origin already resolved by DCLogger, not stored here.
func _write_log(origin: String, stack: Array, level: String, body: String) -> void:
	_store(_make_entry("LOG", level, stack, body))


# Query API — all return Array[LogEntry]

func get_all()                          -> Array: return _entries.duplicate()
func get_by_kind(kind: String)          -> Array: return _entries.filter(func(e): return e.kind  == kind)
func get_by_level(level: String)        -> Array: return _entries.filter(func(e): return e.level == level)
func get_errors()                       -> Array: return _entries.filter(func(e): return e.level == "ERROR")
func get_failures()                     -> Array: return _entries.filter(func(e): return e.level == "FAIL")
func get_entry_count()                  -> int:   return _entries.size()

func get_at_or_above(threshold: String) -> Array:
	var min_order : int = _LEVEL_ORDER.get(threshold, 0)
	return _entries.filter(func(e): return _LEVEL_ORDER.get(e.level, 0) >= min_order)

func clear() -> void:
	_entries.clear()
	cleared.emit()


# Internal

func _make_entry(kind: String, level: String, stack: Array, body: String) -> LogEntry:
	return LogEntry.new(kind, level, stack.duplicate(), body)


func _store(entry: LogEntry) -> void:
	# HELP is contextual output for the user — not a log event, skip the file.
	if entry.level != "HELP":
		_file_writer.append(entry.format_line())

	_maybe_print(entry)

	if _entries.size() >= memory_limit:
		_entries.remove_at(0)

	_entries.append(entry)
	entry_added.emit(entry)


func _maybe_print(entry: LogEntry) -> void:
	if _LEVEL_ORDER.get(entry.level, 0) < _LEVEL_ORDER.get(print_threshold, 0):
		return
	var line := entry.format_line()
	match entry.level:
		"ERROR": push_error(line)
		"WARN":  push_warning(line)
		_:       print(line)


# LOG ENTRY

class LogEntry extends RefCounted:

	const _STACK_DISPLAY_LIMIT : int = 3

	var kind : String   # COMMAND | SYSTEM | RESULT | LOG
	var level : String   # INFO | OK | FAIL | WARN | ERROR | HELP
	var stack : Array    # full snapshot, oldest → newest
	var content : String   # raw input / event message / result text / bbcode string

	func _init(p_kind: String, p_level: String, p_stack: Array, p_content: String) -> void:
		kind  = p_kind
		level = p_level
		stack = p_stack
		content  = p_content


	func format_line() -> String:
		var trimmed : Array = stack.slice(max(0, stack.size() - _STACK_DISPLAY_LIMIT))
		var crumb : String = " > ".join(trimmed) if not trimmed.is_empty() else "·"
		return "%-14s {%s} %s" % [kind + " / " + level, crumb, to_plain_text()]

	func to_plain_text() -> String:
		var regex := RegEx.new()
		regex.compile("\\[/?[a-zA-Z0-9_=# ,.]+\\]")
		return regex.sub(content, "", true)
