extends RefCounted

signal entry_added(entry: LogEntry)
signal cleared

const LogFileWriter := preload("./log_file_writer.gd")

# Higher = more severe. HELP counts as INFO.
const _SEVERITY: Dictionary = {
	"OK": _DCKitSetting.LoggerPrintThershold.OK,
	"INFO": _DCKitSetting.LoggerPrintThershold.INFO,
	"HELP": _DCKitSetting.LoggerPrintThershold.INFO,
	"WARN": _DCKitSetting.LoggerPrintThershold.WARN,
	"FAIL": _DCKitSetting.LoggerPrintThershold.FAIL,
	"ERROR": _DCKitSetting.LoggerPrintThershold.ERROR,
}

var print_threshold: String = _DCKitSetting.LoggerPrintThershold.find_key(
	_DCKitSetting.get_logging_print_threshold()
)

var _file_writer := LogFileWriter.new()


func _init() -> void:
	_file_writer.configure(
		_DCKitSetting.get_logging_directory(),
		_DCKitSetting.get_logging_max_session_files(),
		_DCKitSetting.get_logging_enabled(),
	)


func open_session() -> void:
	_file_writer.open_session()


# Write API. `details` is optional short context (tooltip + log file, cut to
# LogEntry.DETAILS_LIMIT). The executor passes its breadcrumb here.
func simple_print(text: String) -> void:
	_add("LOG", "", text)


func log_command(raw: String, details: String = "") -> void:
	_add("COMMAND", "INFO", raw, details)


func log_system(message: String, details: String = "") -> void:
	_add("SYSTEM", "INFO", message, details)


func log_result(result: DCResult, details: String = "") -> void:
	_add("RESULT", "OK" if result.success else "FAIL", result.get_log_message(), details)


func info(msg: String, details: String = "") -> void:
	_add("LOG", "INFO", msg, details)


func warn(msg: String, details: String = "") -> void:
	_add("LOG", "WARN", msg, details)


func error(msg: String, details: String = "") -> void:
	_add("LOG", "ERROR", msg, details)


func help(msg: String, details: String = "") -> void:
	_add("LOG", "HELP", msg, details)


func clear() -> void:
	cleared.emit()


func _add(kind: String, level: String, body: String, details: String = "") -> void:
	var entry := LogEntry.new(kind, level, body, details)
	var line := entry.format_line()

	# HELP is contextual output for the user, not a log event: skip the file.
	if level != "HELP":
		_file_writer.append(line)
	_maybe_print(level, line)
	entry_added.emit(entry)


func _maybe_print(level: String, line: String) -> void:
	if _SEVERITY.get(level, 0) < _SEVERITY.get(print_threshold, 0):
		return
	match level:
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
		match kind:
			"COMMAND":
				tag = "CMD"
			"SYSTEM":
				tag = "SYS"
			_:
				tag = level


	# One readable line for the log file and the Godot console:
	#   TAG   text  [details]
	# Extra lines of multi-line text are indented under the text.
	func format_line() -> String:
		var text := to_plain_text().strip_edges(false, true).replace("\t", "  ")
		text = text.replace("\n", "\n" + " ".repeat(_TAG_WIDTH + 1))
		var line := "%-5s %s" % [tag if not tag.is_empty() else "LOG", text]
		if not details.is_empty():
			line += ("  " if not text.is_empty() else "") + "[%s]" % details
		return line.strip_edges(false, true)


	func to_plain_text() -> String:
		if _bbcode == null:
			_bbcode = RegEx.create_from_string("\\[/?[a-z_]+(?:[= ][^\\]]*)?\\]")
		return _bbcode.sub(content, "", true)


	var tag: String # badge text: CMD | SYS | the level. "" for plain prints.
