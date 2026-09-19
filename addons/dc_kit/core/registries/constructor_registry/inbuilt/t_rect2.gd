# t_rect2.gd
# Built-in Rect2 constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Rect2()                 → zero rectangle — position and size both (0, 0)
#   Rect2(Rect2i)           → from a Rect2i (widening — always lossless)
#   Rect2(Vector2, Vector2) → position Vector2 + size Vector2
#   Rect2(x, y, w, h)       → four floats: position (x, y) + size (w, h)
#
# Rect2i pass-through
#
#   Rect2(some_rect2i) accepts a Rect2i from any origin and widens it to a
#   Rect2. This mirrors the float/int sibling pattern used by Vector2/Vector2i
#   throughout the codebase — widening is always lossless so no check needed.
#
# No named constants
#
#   Godot 4 does not expose named constants on Rect2 (no ZERO, ONE, etc.),
#   so there is no named-constant form and no LITERAL-only restriction.
#
# DCResult.Value origin rules
#
#   All forms accept any origin (CONSTRUCTOR or COMMAND).
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCVector2 = preload("./t_vector2.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:
		# Zero-arg → zero rectangle
		if parts.is_empty():
			return Rect2()

		# One arg — Rect2 pass-through or Rect2i widening
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]
			var rect := extract_rect2(val)
			if rect != null:
				return rect

			return DCResult.fail(
				"Rect2: single-part form expects a Rect2 or Rect2i, got %s." % val_label(val)
			)

		# Two args — Vector2 position + Vector2 size
		if parts.size() == 2:
			var pos_val: DCResult.Value = parts[0]
			var siz_val: DCResult.Value = parts[1]

			var pos := DCVector2.extract_vector2(pos_val)
			if pos == null:
				return DCResult.fail(
					"Rect2 part 'position': expected a Vector2, got %s." \
							% val_label(pos_val)
				)
			var size := DCVector2.extract_vector2(siz_val)
			if size == null:
				return DCResult.fail(
					"Rect2 part 'size': expected a Vector2, got %s." \
							% val_label(siz_val)
				)

			return Rect2(pos, size)

		# Four args — flat floats: x y w h
		if parts.size() == 4:
			var labels := ["x", "y", "w", "h"]
			var values: Array = []

			for i in 4:
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Rect2 part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)

			return Rect2(values[0], values[1], values[2], values[3])

		return DCResult.fail("Rect2: expected 0, 1, 2, or 4 parts — got %d." % parts.size())

	# Part hints
	var vec2_part := func(p_name: String, p_desc: String) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
		return (_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(p_name, "<Vector2>", p_desc).accepts(
				[TYPE_VECTOR2]
			))

	var rect2i_part := (
		_DCKitRegistriesNamespace
		.ConstructorDef
		.PartHint
		.new("from", "<Rect2i>", "A Rect2i to widen into a Rect2 — integer components become floats.")
		.accepts([TYPE_RECT2I, TYPE_RECT2])
	)

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Rect2",
		handler,
		"A 2D axis-aligned rectangle defined by a [b]position[/b] and [b]size[/b] Vector2.\n"
		+ "[color=gray]Negative size is valid — call [b].abs()[/b] to normalise.[/color]",
		[
			sig_zero("Zero rectangle — Rect2(Vector2.ZERO, Vector2.ZERO)"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"From Rect2i",
				[part_hint_rect2("from", "A Rect2 or Rect2i to use directly.")],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Position + size as Vector2",
				[
					vec2_part.call("position", "Top-left corner of the rectangle."),
					vec2_part.call("size", "Width and height of the rectangle."),
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Flat floats — position (x, y) + size (w, h)",
				[
					DCFloat.part_hint("x", "Position X — left edge."),
					DCFloat.part_hint("y", "Position Y — top edge."),
					DCFloat.part_hint("w", "Width  (size X)."),
					DCFloat.part_hint("h", "Height (size Y)."),
				],
			),
		],
	)


static func extract_rect2(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Rect2:
		return r
	if r is Rect2i:
		return Rect2(r) # widening — always lossless
	return null


static func part_hint_rect2(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(p_name, "<Rect2>", p_desc).accepts(
			[TYPE_RECT2, TYPE_RECT2I]
		))
