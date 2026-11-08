# tracer.gd but refered as logger
# Central log store for the developer console.
# Accessed via preload; no class_name.
extends RefCounted

signal entry_added(entry: LogEntry)
signal cleared

const LogFileWriter := preload("./log_file_writer.gd")

# Level ordering — used by get_at_or_above() and _maybe_print().
# Higher value = more severe.
const _LEVEL_ORDER: Dictionary = {
	"OK": _DCKitSetting.LoggerPrintThershold.OK,
	"INFO": _DCKitSetting.LoggerPrintThershold.INFO,
	"HELP": _DCKitSetting.LoggerPrintThershold.INFO,
	"WARN": _DCKitSetting.LoggerPrintThershold.WARN,
	"FAIL": _DCKitSetting.LoggerPrintThershold.FAIL,
	"ERROR": _DCKitSetting.LoggerPrintThershold.ERROR,
}
const _LEVEL_NAME: Dictionary = {
	_DCKitSetting.LoggerPrintThershold.OK: "OK",
	_DCKitSetting.LoggerPrintThershold.INFO: "INFO",
	_DCKitSetting.LoggerPrintThershold.WARN: "WARN",
	_DCKitSetting.LoggerPrintThershold.FAIL: "FAIL",
	_DCKitSetting.LoggerPrintThershold.ERROR: "ERROR",
}

const _MEMORY_LIMIT_DEFAULT: int = 200

var print_threshold: String = _LEVEL_NAME[_DCKitSetting.get_logging_print_threshold()]

var memory_limit: int = _MEMORY_LIMIT_DEFAULT

var _entries: Array = [] # Array[LogEntry]
var _file_writer := LogFileWriter.new()


func _init() -> void:
	var file_logging_enabled: bool = _DCKitSetting.get_logging_enabled()
	var log_dir: String = _DCKitSetting.get_logging_directory()
	var max_files: int = _DCKitSetting.get_logging_max_session_files()

	_file_writer.configure(log_dir, max_files, file_logging_enabled)


func open_session() -> void:
	_file_writer.open_session()


# Quick one-off log with no details.
func simple_print(text: String) -> void:
	_store(_make_entry("LOG", "", text), true)


# Executor write API. `details` is the executor's breadcrumb string.
func log_command(raw: String, details: String = "") -> void:
	_store(_make_entry("COMMAND", "INFO", raw, details))


func log_system(message: String, details: String = "") -> void:
	_store(_make_entry("SYSTEM", "INFO", message, details))


func log_result(result: DCResult, details: String = "") -> void:
	_store(
		_make_entry("RESULT", "OK" if result.success else "FAIL", result.get_log_message(), details)
	)


# General write API — reached through the DCKit autoload and the backend.
# `details` is optional extra context shown as a tooltip and written to the
# log file; it is cut to LogEntry.DETAILS_LIMIT characters.
func info(msg: String, details: String = "") -> void:
	_store(_make_entry("LOG", "INFO", msg, details))


func warn(msg: String, details: String = "") -> void:
	_store(_make_entry("LOG", "WARN", msg, details))


func error(msg: String, details: String = "") -> void:
	_store(_make_entry("LOG", "ERROR", msg, details))


func help(msg: String, details: String = "") -> void:
	_store(_make_entry("LOG", "HELP", msg, details))


# Query API — all return Array[LogEntry]
func get_all() -> Array:
	return _entries.duplicate()


func get_by_kind(kind: String) -> Array:
	return _entries.filter(
		func(e):
			return e.kind == kind,
	)


func get_by_level(level: String) -> Array:
	return _entries.filter(
		func(e):
			return e.level == level,
	)


func get_errors() -> Array:
	return _entries.filter(
		func(e):
			return e.level == "ERROR",
	)


func get_failures() -> Array:
	return _entries.filter(
		func(e):
			return e.level == "FAIL",
	)


func get_entry_count() -> int:
	return _entries.size()


func get_at_or_above(threshold: String) -> Array:
	var min_order: int = _LEVEL_ORDER.get(threshold, 0)
	return _entries.filter(
		func(e):
			return _LEVEL_ORDER.get(e.level, 0) >= min_order,
	)


func clear() -> void:
	_entries.clear()
	cleared.emit()


# Internal
func _make_entry(kind: String, level: String, body: String, details: String = "") -> LogEntry:
	return LogEntry.new(kind, level, body, details)


func _store(entry: LogEntry, ignore: bool = false) -> void:
	# HELP is contextual output for the user — not a log event, skip the file.
	if ignore or entry.level != "HELP":
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
		"ERROR":
			push_error(line)
		"WARN":
			push_warning(line)
		_:
			print(line)


# LOG ENTRY
class LogEntry extends RefCounted:
	const DETAILS_LIMIT: int = 100
	const _TAG_WIDTH: int = 5 # longest tag: ERROR

	static var _bbcode: RegEx

	var kind: String # COMMAND | SYSTEM | RESULT | LOG
	var level: String # INFO | OK | FAIL | WARN | ERROR | HELP
	var content: String # raw input / event message / result text / bbcode string
	var details: String # short extra context (breadcrumb, caller note), ≤ DETAILS_LIMIT


	func _init(p_kind: String, p_level: String, p_content: String, p_details: String = "") -> void:
		kind = p_kind
		level = p_level
		content = p_content
		details = p_details
		if details.length() > DETAILS_LIMIT:
			details = details.left(DETAILS_LIMIT - 1) + "…"


	# One readable line for the log file and the Godot console:
	#   TAG   text  [details]
	# Extra lines of multi-line text are indented under the text.
	func format_line() -> String:
		var text := to_plain_text().strip_edges(false, true).replace("\t", "  ")
		text = text.replace("\n", "\n" + " ".repeat(_TAG_WIDTH + 1))
		var line := "%-5s %s" % [_tag(), text]
		if not details.is_empty():
			line += ("  " if not text.is_empty() else "") + "[%s]" % details
		return line.strip_edges(false, true)


	func to_plain_text() -> String:
		if _bbcode == null:
			_bbcode = RegEx.create_from_string("\\[/?[a-z_]+(?:[= ][^\\]]*)?\\]")
		return _bbcode.sub(content, "", true)


	func _tag() -> String:
		match kind:
			"COMMAND":
				return "CMD"
			"SYSTEM":
				return "SYS"
		return level if not level.is_empty() else "LOG"
