# t_string.gd
# String primitive — resolution logic and constructor type definition.
# Accessed via preload; no class_name.
#
# extract() behaviour
#
#   Always succeeds — every Variant has a string representation.
#   Uses var_to_str() for non-string types so the result is always meaningful.
#
#   LITERAL  "hello"          → "hello"   (quotes already stripped by tokeniser)
#   LITERAL  "42"             → "42"
#   CTOR / CMD  String        → returned directly
#   CTOR / CMD  int / float   → var_to_str  e.g. "3"  "1.5"
#   CTOR / CMD  Vector2       → "Vector2(1, 2)"
#   CTOR / CMD  null          → ""
#   CTOR / CMD  anything else → var_to_str result
#
# Why extract always succeeds
#
#   String is the universal fallback type. Any value can be represented as
#   a string. Returning null would only be useful if we wanted to distinguish
#   "this value has no string form" — which never happens in Godot.
#
#   Handlers that want strict string-only input (no numeric coercion) should
#   check val.raw is String themselves rather than using extract().
#
# Usage in other type files
#
#   const DCString = preload("./t_string.gd")
#
#   var s : String = DCString.extract(parts[0])  # always a String, never null

extends "./inbuilt_base.gd"


# Core extraction

# Always returns a String. Never returns null.
static func extract(val: DCResult.Value) -> String:
	return val.as_string()


# Part hint factory

# Returns a  _DCKitNamespace. _DCKitNamespace.ConstructorDef.PartHint configured for a string slot.
# p_suggest — optional callable (prefix: String) -> Array[String] for suggestions.
static func part_hint(
		p_name    : String,
		p_desc    : String   = "",
		p_suggest : Callable = Callable()) ->  _DCKitNamespace.ConstructorDef.PartHint:

	var hint := ( _DCKitNamespace.ConstructorDef.PartHint
		.new(p_name, "<string>", p_desc)
		.accepts([TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]))

	if p_suggest.is_valid():
		hint.suggest(p_suggest)

	return hint


# Constructor type definition

static func create() ->  _DCKitNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:

		# Zero-arg → empty string
		if parts.is_empty():
			return ""

		# One arg → convert to string
		if parts.size() == 1:
			return extract(parts[0])

		# Multiple args → join with space
		# Str(hello world) would be two tokens, joining them is natural
		var joined := ""
		for i in parts.size():
			if i > 0:
				joined += " "
			joined += extract(parts[i])
		return joined

	return  _DCKitNamespace.ConstructorDef.new(
		"Str",
		handler,
		"Converts a value to a [b]string[/b], or joins multiple values with spaces.\n"
		+ "[color=gray]Str()           →  \"\"[/color]\n"
		+ "[color=gray]Str(hello)      →  \"hello\"[/color]\n"
		+ "[color=gray]Str(hello world)  →  \"hello world\"[/color]",
		[
			 _DCKitNamespace.ConstructorDef.TypeSignature.new("Empty string", []),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Convert to string",
				[( _DCKitNamespace.ConstructorDef.PartHint
					.new("value", "<any>",
						"Any value — converted to its string representation.")
					.accepts([TYPE_STRING, TYPE_INT, TYPE_FLOAT,
							  TYPE_BOOL, TYPE_VECTOR2, TYPE_VECTOR3,
							  TYPE_COLOR, TYPE_RECT2]))]
			),
		]
	)
