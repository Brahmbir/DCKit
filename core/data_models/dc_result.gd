## Result of a command execution: success flag, an optional typed Value, and a message.
class_name DCResult
extends RefCounted

## Wraps a raw Variant along with where it came from, and provides typed coercions.
class Value extends RefCounted:
	enum Origin { LITERAL, CONSTRUCTOR, COMMAND }

	## The underlying value, in whatever type it was produced as.
	var raw    : Variant
	## Where this value came from — one of the Origin enum values.
	var origin : int

	func _init(p_raw: Variant, p_origin: int) -> void:
		raw    = p_raw
		origin = p_origin

	## Builds a Value from a literal string (e.g. raw command-line text).
	static func literal(s: String) -> Value:
		return Value.new(s, Origin.LITERAL)

	## Builds a Value produced by a constructor expression.
	static func from_constructor(v: Variant) -> Value:
		return Value.new(v, Origin.CONSTRUCTOR)

	## Builds a Value produced by a command's return.
	static func from_command(v: Variant) -> Value:
		return Value.new(v, Origin.COMMAND)

	## Returns the value as a String, converting non-string raws.
	func as_string() -> String:
		if raw == null: return ""
		if raw is String: return raw
		return var_to_str(raw)

	## Returns the value as a float, or null if it can't be coerced.
	func as_float() -> Variant:
		if raw is float: return raw
		if raw is int:   return float(raw)
		if raw is String:
			var s := (raw as String).strip_edges()
			return float(s) if s.is_valid_float() else null
		return null

	## Returns the value as an int, or null if it can't be coerced.
	func as_int() -> Variant:
		if raw is int: return raw
		if raw is String:
			var s := (raw as String).strip_edges()
			return int(s) if s.is_valid_int() else null
		return null

	## Returns the value as a bool, or null if it can't be coerced.
	func as_bool() -> Variant:
		if raw is bool: return raw
		if raw is int:  return raw != 0
		if raw is String:
			match (raw as String).strip_edges().to_lower():
				"true", "yes", "1":  return true
				"false", "no", "0": return false
		return null

	func _to_string() -> String:
		return "Value[%s](%s)" % [Origin.keys()[origin], var_to_str(raw)]

## Whether the command executed successfully.
var success : bool
## The result payload, if any. Null on failure or when a command returns nothing.
var value   : Value
## Human-readable message: explicit on failure, optional supplementary text on success.
var message : String

func _init(p_success: bool, p_value: Value = null, p_message: String = "") -> void:
	success = p_success
	value   = p_value
	message = p_message

## Returns the message to log: explicit message on success, else the value's
## string form; always the message on failure.
func get_log_message() -> String:
	if success:
		return message if not message.is_empty() else value.as_string() if value != null else ""
	return message

## Builds a successful result. Accepts an existing Value, null, or a raw Variant
## (wrapped as a COMMAND-origin Value).
static func ok(val = null, msg: String = "") -> DCResult:
	if val is Value:
		return DCResult.new(true, val, msg)
	if val == null:
		return DCResult.new(true, null, msg)
	return DCResult.new(true, Value.new(val, Value.Origin.COMMAND), msg)

## Builds a failed result with the given message.
static func fail(msg: String = "") -> DCResult:
	return DCResult.new(false, null, msg)

## Convenience accessor for the underlying raw Variant of value, if any.
var raw: Variant:
	get: return value.raw if value != null else null

func _to_string() -> String:
	if success:
		return "OK | %s" % (str(value) if value else "null")
	return "FAIL | %s" % message
