# t_bool.gd
# Bool primitive — resolution logic and constructor type definition.
# Accessed via preload; no class_name.
#
# extract() behaviour by origin
#
#   LITERAL  "true"  "yes"  "1"   (case-insensitive) → true
#   LITERAL  "false" "no"   "0"   (case-insensitive) → false
#   LITERAL  anything else                            → null
#   CTOR / CMD  bool                                  → returned directly
#   CTOR / CMD  int     0                             → false
#   CTOR / CMD  int     nonzero                       → true
#   CTOR / CMD  String                                → same rules as LITERAL
#   CTOR / CMD  anything else                         → null
#
# Accepted literal strings
#
#   truthy  — "true"  "True"  "TRUE"  "yes"  "1"
#   falsy   — "false" "False" "FALSE" "no"   "0"
#
#   "yes" and "no" are included because they appear naturally in console usage.
#   Anything outside this set is null — no silent coercion from arbitrary strings.
#
# Usage in other type files
#
#   const DCBool = preload("./t_bool.gd")
#
#   var b = DCBool.extract(parts[0])
#   if b == null:
#       return DevConsoleResult.fail("part 'flag': expected true/false, got %s." % ...)
extends "./inbuilt_base.gd"

const _TRUTHY := ["true", "yes", "1", "on"]
const _FALSY := ["false", "no", "0", "off"]


# Core extraction
# Returns true, false, or null.
# null means the value cannot be interpreted as a boolean.
static func extract(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r == null:
		return null
	if r is bool:
		return r
	if r is int:
		return r != 0
	if r is String:
		return _parse_string(r as String)
	return null


# Part hint factory
# Returns a  _DCKitRegistriesNamespace.ConstructorDef.PartHint configured for a boolean slot.
static func part_hint(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace
		.ConstructorDef
		.PartHint
		.new(p_name, "<bool>", p_desc)
		.validate(_bool_validator())
		.suggest(
			func(_p):
				return ["true", "false"],
		)
		.accepts([TYPE_BOOL, TYPE_INT, TYPE_STRING])
	)


# Constructor type definition
static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:
		# Zero-arg → false
		if parts.is_empty():
			return false

		# One arg → coerce to bool
		if parts.size() == 1:
			var b = extract(parts[0])
			if b == null:
				return DCResult.fail(
					"Bool: cannot convert %s to a boolean. " % _label(parts[0])
					+ "Use true/false, yes/no, or 1/0."
				)
			return b

		return DCResult.fail("Bool: expected 0 or 1 part — got %d." % parts.size())

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Bool",
		handler,
		"Converts a value to a [b]boolean[/b].\n" + "[color=gray]Bool()  →  false[/color]\n"
		+ "Accepted: [b]true[/b] / [b]false[/b], [b]yes[/b] / [b]no[/b], [b]1[/b] / [b]0[/b]",
		[
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new("Zero value — false", []),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Coerce to boolean",
				[
					(
						_DCKitRegistriesNamespace
						.ConstructorDef
						.PartHint
						.new("value", "<bool>", "[b]true[/b] / [b]yes[/b] / [b]1[/b]  or  "
						+ "[b]false[/b] / [b]no[/b] / [b]0[/b]")
						.validate(_bool_validator())
						.suggest(
							func(_p):
								return ["true", "false", "yes", "no", "1", "0"],
						)
						.accepts([TYPE_BOOL, TYPE_INT, TYPE_STRING])
					)
				],
			),
		],
	)


# Internal
static func _parse_string(s: String) -> Variant:
	var lower := s.strip_edges().to_lower()
	if lower in _TRUTHY:
		return true
	if lower in _FALSY:
		return false
	return null


static func _bool_validator() -> Callable:
	return func(value: String) -> String:
		if value.is_empty() or value.begins_with("$"):
			return ""
		if _parse_string(value) != null:
			return ""
		return "'%s' is not a boolean. Use true/false, yes/no, or 1/0." % value


static func _label(val: DCResult.Value) -> String:
	if val.raw == null:
		return "null"
	return "%s (%s)" % [var_to_str(val.raw), type_string(typeof(val.raw))]
