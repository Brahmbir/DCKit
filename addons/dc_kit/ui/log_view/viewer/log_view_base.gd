# log_view_base.gd
# Abstract base class for all log viewer implementations.
#
# Manages connecting to a DevConsoleLogger, replaying history on attach, and
# disconnecting cleanly on tree exit or logger swap.
#
extends Control

const BBCodeHandler := preload("./utils/bb_code_handler.gd")

# STATE
var _logger    : Object = null
var _connected : bool   = false

# PUBLIC API
# Attach to [param logger].  Safe to call multiple times — swaps loggers cleanly.
func setup(logger: Object) -> void:
	if _connected:
		_disconnect_logger()
	_logger = logger
	_connect_logger()
	_replay_all()

func _exit_tree() -> void:
	_disconnect_logger()

# ABSTRACT OVERRIDES — subclasses implement these
# Receive one log entry.  Called both during history replay and for live entries.
# entry.body is pre-parsed; no further parsing is needed in subclasses.
func _append_entry(_entry: _DCKitNamespace.Tracer.LogEntry) -> void:
	pass

# The logger was cleared.  Reset the display.
func _on_cleared() -> void:
	pass

# PRIVATE — LOGGER WIRING
func _connect_logger() -> void:
	if _logger == null:
		return
	_safe_connect(_logger, "entry_added", _append_entry)
	_safe_connect(_logger, "cleared",     _on_cleared)
	_connected = true

func _disconnect_logger() -> void:
	if _logger == null or not _connected:
		return
	_safe_disconnect(_logger, "entry_added", _append_entry)
	_safe_disconnect(_logger, "cleared",     _on_cleared)
	_connected = false

func _replay_all() -> void:
	_on_cleared()
	if _logger == null or not _logger.has_method("get_all"):
		return
	for entry: _DCKitNamespace.Tracer.LogEntry in _logger.get_all():
		_append_entry(entry)

# Signal helpers
func _safe_connect(obj: Object, sig: StringName, callable: Callable) -> void:
	if obj.has_signal(sig) and not obj.is_connected(sig, callable):
		obj.connect(sig, callable)

func _safe_disconnect(obj: Object, sig: StringName, callable: Callable) -> void:
	if obj.has_signal(sig) and obj.is_connected(sig, callable):
		obj.disconnect(sig, callable)
