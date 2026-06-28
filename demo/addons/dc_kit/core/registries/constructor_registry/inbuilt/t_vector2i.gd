# t_vector2i.gd
# Built-in Vector2i constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Vector2i()            → Vector2i.ZERO
#   Vector2i(name)        → named constant  e.g. Vector2i(UP)
#   Vector2i(x, y)        → int components — any DCResult.Value origin

extends "./inbuilt_base.gd"

const DCInt = preload("./t_int.gd")


static func create() -> ConstructorDef:
	const CONSTS := {
		"ZERO":  Vector2i.ZERO,
		"ONE":   Vector2i.ONE,
		#"INF":   Vector2i.INF,
		"LEFT":  Vector2i.LEFT,
		"RIGHT": Vector2i.RIGHT,
		"UP":    Vector2i.UP,
		"DOWN":  Vector2i.DOWN,
	}

	var const_names : Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:

		# Zero-arg
		if parts.is_empty():
			return Vector2i.ZERO

		# One arg — named constant only
		# We only accept a LITERAL string here — a Vector2i constant name
		# must be typed by the user, not produced by another node.
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]

			var vec := extract_vector2i(val)
			if vec != null:
				return vec

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]

			return DCResult.fail(
				"Vector2i: expected a Vector2i, integer Vector2, or constant name (%s), got %s."
				% [", ".join(const_names), val_label(val)])

		# Two args — XY components
		if parts.size() == 2:
			var x = DCInt.extract(parts[0])
			if x == null:
				return DCResult.fail(
					"Vector2i part 'x': expected a number, got %s." \
					% val_label(parts[0]))
			var y = DCInt.extract(parts[1])
			if y == null:
				return DCResult.fail(
					"Vector2i part 'y': expected a number, got %s." \
					% val_label(parts[1]))
			return Vector2i(x, y)

		return DCResult.fail(
			"Vector2i: expected 0, 1, or 2 parts — got %d." % parts.size())

	return ConstructorDef.new(
		"Vector2i",
		handler,
		"A 2D vector with [b]x[/b] and [b]y[/b] int components.",
		[
			sig_zero("Zero vector — Vector2i(0, 0)"),

			ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]
			),

			ConstructorDef.TypeSignature.new(
				"Convert Vector2/Vector2i",
				[part_hint_vector2i(
						"value",
						"Existing Vector2i or Vector2")]
			),

			ConstructorDef.TypeSignature.new(
				"XY components",
				[
					DCInt.part_hint("x", "Horizontal axis — right (+), left (−)"),
					DCInt.part_hint("y", "Vertical axis — down (+), up (−)"),
				]
			),
		]
	)

 
static func extract_vector2i(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector2i: return r
	if r is Vector2: return Vector2i(r)
	return null
 
static func part_hint_vector2i(p_name: String, p_desc: String = "") -> ConstructorDef.PartHint:
	return (ConstructorDef.PartHint
		.new(p_name, "<Vector2i>", p_desc)
		.accepts([TYPE_VECTOR2I, TYPE_VECTOR2]))
 
