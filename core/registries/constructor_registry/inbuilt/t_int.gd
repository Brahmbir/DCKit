# t_int.gd
# Int primitive — resolution logic and constructor type definition.
# Accessed via preload; no class_name.
#
# extract() behaviour by origin
#
#   LITERAL  "3"      → 3
#   LITERAL  "3.9"    → 3
#   LITERAL  "-2.7"   → -2
#   LITERAL  "abc"    → null
#
#   CTOR / CMD float  → truncated toward zero
#
# Usage in other type files
#
#   const DCInt = preload("./t_int.gd")
#
#   var i = DCInt.extract(parts[0])
#   if i == null:
#       return DevConsoleResult.fail("part 'n': expected an integer, got %s." % ...)

extends "./inbuilt_base.gd"


# Core extraction

# Returns an int if the DCResult.Value can be meaningfully interpreted as one.
# Returns null on failure — the caller decides the error message.
static func extract(val: DCResult.Value) -> Variant:
	var r := val.raw

	if r == null:return null
	if r is int: return r
	if r is float: return int(r)
	if r is String:
		var s := (r as String).strip_edges()
		# Direct integer string
		if s.is_valid_int():
			return int(s)
		# float string: "3.0", "2.0"
		if s.is_valid_float():
			return int(float(s))
		return null

	return null


# Part hint factory

# Returns a  _DCKitNamespace.ConstructorDef.PartHint configured for an integer slot.
static func part_hint(p_name: String, p_desc: String = "") ->  _DCKitNamespace.ConstructorDef.PartHint:
	return ( _DCKitNamespace.ConstructorDef.PartHint
		.new(p_name, "<int>", p_desc)
		.validate(_int_validator())
		.accepts([TYPE_INT, TYPE_FLOAT, TYPE_STRING]))


# Constructor type definition

static func create() ->  _DCKitNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:

		# Zero-arg → 0
		if parts.is_empty():
			return 0

		# One arg → coerce to int
		if parts.size() == 1:
			var i = extract(parts[0])
			if i == null:
				return DCResult.fail(
					"Int: cannot convert %s to an integer." % _label(parts[0]))
			return i

		return DCResult.fail(
			"Int: expected 0 or 1 part — got %d." % parts.size())

	return  _DCKitNamespace.ConstructorDef.new(
		"Int",
		handler,
		"Converts a value to an [b]integer[/b].\n"
		+ "[color=gray]Int() → 0[/color]\n"
		+ "[color=gray]Floating-point values are truncated toward zero.[/color]",
		[
			 _DCKitNamespace.ConstructorDef.TypeSignature.new("Zero value", []),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Coerce to integer",
				[( _DCKitNamespace.ConstructorDef.PartHint
					.new("value", "<int>",
						"Any integer, float, or numeric string.")
					.validate(_int_validator())
					.accepts([TYPE_INT, TYPE_FLOAT, TYPE_STRING]))]
			),
		]
	)

# Internal
static func _int_validator() -> Callable:
	return func(value: String) -> String:
		if value.is_empty() or value.begins_with("$"):
			return ""
		if value.is_valid_int() or value.is_valid_float():
			return ""
		return "'%s' is not a number." % value


static func _label(val: DCResult.Value) -> String:
	if val.raw == null: return "null"
	return "%s (%s)" % [var_to_str(val.raw), type_string(typeof(val.raw))]
