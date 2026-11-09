class_name DCResult
extends RefCounted

var success: bool
var value: Variant
var message: String
var literal: bool

static func ok(v: Variant = null, msg := "") -> DCResult:
	return _make(true, v, msg)


static func fail(msg := "") -> DCResult:
	return _make(false, null, msg)


static func from_literal(s: String) -> DCResult:
	var r := _make(true, s, "")
	r.literal = true
	return r

func text() -> String:
	if value == null:
		return ""
	if value is String:
		return value
	return var_to_str(value)


func truthy() -> bool:
	if not success:
		return false
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING:
			return not (value.strip_edges().to_lower() in ["", "false", "0"])
	return true

func log_text() -> String:
	if not success or not message.is_empty():
		return message
	return text()


func _to_string() -> String:
	return "OK | %s" % var_to_str(value) if success else "FAIL | %s" % message


static func _make(p_success: bool, v: Variant, msg: String) -> DCResult:
	var r := DCResult.new()
	r.success = p_success
	r.value = v
	r.message = msg
	return r
