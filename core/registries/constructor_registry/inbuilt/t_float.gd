# t_float.gd
# Float primitive — resolution logic and constructor type definition.
# Accessed via preload; no class_name.
#
# Two responsibilities
#
#   1. extract(val)  — static helper imported by other type files.
#                      Pulls a float out of any DCResult.Value regardless of origin.
#                      Returns float or null — never crashes.
#
#   2. create()      — registers Float(...) as a console constructor type.
#                      Useful for explicit coercion: Float(3) → 3.0
#
# extract() behaviour by origin
#
#   LITERAL  "1.0"  "1"  "-3.14"  → parsed as float
#   LITERAL  "abc"                 → null
#   CTOR / CMD  float              → returned directly
#   CTOR / CMD  int                → cast to float
#   CTOR / CMD  String             → parsed, same as LITERAL
#   CTOR / CMD  anything else      → null
#
# Usage in other type files
#
#   const DCFloat = preload("./t_float.gd")
#
#   var f = DCFloat.extract(parts[0])
#   if f == null:
#       return DevConsoleResult.fail("part 'x': expected a number, got %s." % ...)
extends "./inbuilt_base.gd"


# Core extraction
# Returns a float if the DCResult.Value can be meaningfully interpreted as one.
# Returns null on failure — the caller decides the error message.
static func extract(val: DCResult.Value) -> Variant:
	var r := val.raw

	if r == null:
		return null

	if r is float:
		return r

	if r is int:
		return float(r)

	if r is String:
		var s := (r as String).strip_edges()
		if s.is_valid_float():
			return float(s)
		return null

	return null


# Part hint factory
# Returns a  _DCKitNamespace.ConstructorDef.PartHint configured for a float slot.
# Used by other type files when building their signatures.
#
#   var parts = [DCFloat.part_hint("x", "Horizontal axis")]
static func part_hint(
	p_name: String,
	p_desc: String = "",
) -> _DCKitNamespace.ConstructorDef.PartHint:
	return (
		_DCKitNamespace
		.ConstructorDef
		.PartHint
		.new(p_name, "<float>", p_desc)
		.validate(_DCKitNamespace.ConstructorDef.PartHint.float_validator())
		.accepts([TYPE_FLOAT, TYPE_INT, TYPE_STRING])
	)


# Constructor type definition
static func create() -> _DCKitNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:
		# Zero-arg → 0.0
		if parts.is_empty():
			return 0.0

		# One arg → coerce to float
		if parts.size() == 1:
			var f = extract(parts[0])
			if f == null:
				return DCResult.fail("Float: cannot convert %s to a float." % _label(parts[0]))
			return f

		return DCResult.fail("Float: expected 0 or 1 part — got %d." % parts.size())

	return _DCKitNamespace.ConstructorDef.new(
		"Float",
		handler,
		"Converts a value to a [b]float[/b].\n" + "[color=gray]Float()  →  0.0[/color]",
		[
			_DCKitNamespace.ConstructorDef.TypeSignature.new("Zero value", []),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Coerce to float",
				[
					(
						_DCKitNamespace
						.ConstructorDef
						.PartHint
						.new("value", "<float>", "Any numeric or string value to convert.")
						.validate(_DCKitNamespace.ConstructorDef.PartHint.float_validator())
						.accepts([TYPE_FLOAT, TYPE_INT, TYPE_STRING])
					)
				],
			),
		],
	)


# Internal
static func _label(val: DCResult.Value) -> String:
	if val.raw == null:
		return "null"
	return "%s (%s)" % [var_to_str(val.raw), type_string(typeof(val.raw))]
