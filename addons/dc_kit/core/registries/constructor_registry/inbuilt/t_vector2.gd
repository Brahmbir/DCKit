# t_vector2.gd
# Built-in Vector2 constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Vector2()            → Vector2.ZERO
#   Vector2(name)        → named constant  e.g. Vector2(UP)
#   Vector2(x, y)        → float components — any DCResult.Value origin
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	const CONSTS := {
		"ZERO": Vector2.ZERO,
		"ONE": Vector2.ONE,
		"INF": Vector2.INF,
		"LEFT": Vector2.LEFT,
		"RIGHT": Vector2.RIGHT,
		"UP": Vector2.UP,
		"DOWN": Vector2.DOWN,
	}

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg
		if parts.is_empty():
			return Vector2.ZERO

		# One arg — named constant only
		# We only accept a LITERAL string here — a Vector2 constant name
		# must be typed by the user, not produced by another node.
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			var vec := extract_vector2(val)
			if vec != null:
				return vec

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]

			return DCResult.fail(
				"Vector2: expected a Vector2, integer Vector2, or constant name (%s), got %s."
				% [", ".join(const_names), val_label(val)]
			)

		# Two args — XY components
		if parts.size() == 2:
			var x = DCFloat.extract(parts[0])
			if x == null:
				return DCResult.fail(
					"Vector2 part 'x': expected a number, got %s." \
							% val_label(parts[0])
				)
			var y = DCFloat.extract(parts[1])
			if y == null:
				return DCResult.fail(
					"Vector2 part 'y': expected a number, got %s." \
							% val_label(parts[1])
				)
			return Vector2(x, y)

		return DCResult.fail("Vector2: expected 0, 1, or 2 parts — got %d." % parts.size())

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Vector2",
		handler,
		"A 2D vector with [b]x[/b] and [b]y[/b] float components.",
		[
			sig_zero("Zero vector — Vector2(0, 0)"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Convert Vector2/Vector2i",
				[part_hint_vector2("value", "Existing Vector2 or Vector2i")],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"XY components",
				[
					DCFloat.part_hint("x", "Horizontal axis — right (+), left (−)"),
					DCFloat.part_hint("y", "Vertical axis — down (+), up (−)"),
				],
			),
		],
	)


static func extract_vector2(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector2:
		return r
	if r is Vector2i:
		return Vector2(r)
	return null


static func part_hint_vector2(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(p_name, "<Vector2>", p_desc).accepts(
			[TYPE_VECTOR2, TYPE_VECTOR2I]
		)
	)
