class_name DCResult
extends RefCounted

class Value extends RefCounted:

	enum Origin { LITERAL, CONSTRUCTOR, COMMAND }

	var raw    : Variant
	var origin : int

	func _init(p_raw: Variant, p_origin: int) -> void:
		raw    = p_raw
		origin = p_origin

	static func literal(s: String) -> Value:
		return Value.new(s, Origin.LITERAL)

	static func from_constructor(v: Variant) -> Value:
		return Value.new(v, Origin.CONSTRUCTOR)

	static func from_command(v: Variant) -> Value:
		return Value.new(v, Origin.COMMAND)

	func as_string() -> String:
		if raw == null: return ""
		if raw is String: return raw
		return var_to_str(raw)

	func as_float() -> Variant:
		if raw is float: return raw
		if raw is int:   return float(raw)
		if raw is String:
			var s := (raw as String).strip_edges()
			return float(s) if s.is_valid_float() else null
		return null

	func as_int() -> Variant:
		if raw is int: return raw
		if raw is String:
			var s := (raw as String).strip_edges()
			return int(s) if s.is_valid_int() else null
		return null

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


var success : bool
var value   : Value
var message : String


func _init(p_success: bool, p_value: Value = null, p_message: String = "") -> void:
	success = p_success
	value   = p_value
	message = p_message

func get_log_message() -> String:
	if success:
		return message if not message.is_empty() else value.as_string() if value != null else ""
	return message

static func ok(val = null, msg: String = "") -> DCResult:
	if val is Value:
		return DCResult.new(true, val, msg)
	if val == null:
		return DCResult.new(true, null, msg)
	return DCResult.new(true, Value.new(val, Value.Origin.COMMAND), msg)


static func fail(msg: String = "") -> DCResult:
	return DCResult.new(false, null, msg)



var raw: Variant:
	get: return value.raw if value != null else null


func _to_string() -> String:
	if success:
		return "OK | %s" % (str(value) if value else "null")
	return "FAIL | %s" % message
