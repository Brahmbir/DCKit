## Scoped logger handed to each command handler via ctx.log.
## Writes through to the central logger, stamping every entry with the
## origin and call-stack snapshot captured at command construction time.
class_name DCLogger
extends RefCounted

var _logger_ref: WeakRef
var _origin: String
var _stack: Array


func _init(logger, origin: String, stack: Array) -> void:
	_logger_ref = weakref(logger)
	_origin = origin
	_stack = stack.duplicate()


## Logs an informational message.
func info(msg: String) -> void:
	_write("INFO", msg)


## Logs a warning message.
func warn(msg: String) -> void:
	_write("WARN", msg)


## Logs an error message.
func error(msg: String) -> void:
	_write("ERROR", msg)


## Logs a help message.
func help(msg: String) -> void:
	_write("HELP", msg)


## Forwards a stamped entry to the backing logger, if it still exists.
func _write(level: String, msg: String) -> void:
	var logger = _logger_ref.get_ref()
	if logger == null or not logger.has_method("_write_log"):
		printerr("DCLogger: backing logger is gone or missing _write_log")
		return
	logger._write_log(_origin, _stack, level, msg)
