# t_rect2i.gd
# Built-in Rect2i constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Rect2i()                 → zero rectangle — position and size both (0, 0)
#   Rect2i(Rect2)            → from a Rect2 (widening — always lossless)
#   Rect2i(Vector2, Vector2) → position Vector2i + size Vector2i
#   Rect2i(x, y, w, h)        → four integer: position (x, y) + size (w, h)
#
# DCResult.Value origin rules
#
#   All forms accept any origin (CONSTRUCTOR or COMMAND).

extends "./inbuilt_base.gd"

const DCInt = preload("./t_int.gd")
const DCVector2i = preload("./t_vector2i.gd")


static func create() -> ConstructorDef:

	var handler := func(parts: Array) -> Variant:

		# Zero-arg → zero rectangle
		if parts.is_empty():
			return Rect2i()

		# One arg — Rect2 pass-through or Rect2i widening
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]

			var rect := extract_rect2i(val)
			if rect != null:
				return rect

			return DCResult.fail(
				"Rect2i: single-part form expects a Rect2i or integer-valued Rect2, got %s."
				% val_label(val))

		# Two args — Vector2 position + Vector2 size
		if parts.size() == 2:
			var pos_val : DCResult.Value = parts[0]
			var siz_val : DCResult.Value = parts[1]

			var pos := DCVector2i.extract_vector2i(pos_val)
			if pos == null:
				return DCResult.fail(
					"Rect2i part 'position': expected a Vector2i, got %s." \
					% val_label(pos_val))
			var size := DCVector2i.extract_vector2i(siz_val)
			if size == null:
				return DCResult.fail(
					"Rect2i part 'size': expected a Vector2i, got %s." \
					% val_label(siz_val))

			return Rect2i(pos, size)

		# Four args — flat floats: x y w h
		if parts.size() == 4:
			var labels := ["x", "y", "w", "h"]
			var values : Array = []

			for i in 4:
				var f = DCInt.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Rect2i part '%s': expected a number, got %s." \
						% [labels[i], val_label(parts[i])])
				values.append(f)

			return Rect2i(values[0], values[1], values[2], values[3])

		return DCResult.fail(
			"Rect2i: expected 0, 1, 2, or 4 parts — got %d." % parts.size())

	return ConstructorDef.new(
		"Rect2i",
		handler,
		"A 2D axis-aligned rectangle defined by a [b]position[/b] and [b]size[/b] Vector2i.\n"
		+ "[color=gray]Negative size is valid — call [b].abs()[/b] to normalise.[/color]",
		[
			sig_zero("Zero rectangle — Rect2i(Vector2i.ZERO, Vector2i.ZERO)"),

			ConstructorDef.TypeSignature.new(
				"Convert Rect2/Rect2i",
				[part_hint_rect2i("from","Existing Rect2i or integer-valued Rect2.")]
			),

			ConstructorDef.TypeSignature.new(
				"Position + size as Vector2i",
				[
					DCVector2i.part_hint_vector2i("position", "Top-left corner of the rectangle."),
					DCVector2i.part_hint_vector2i("size", "Width and height of the rectangle."),
				]
			),

			ConstructorDef.TypeSignature.new(
				"Flat integers — position (x, y) + size (w, h)",
				[
					DCInt.part_hint("x", "Position X — left edge."),
					DCInt.part_hint("y", "Position Y — top edge."),
					DCInt.part_hint("w", "Width  (size X)."),
					DCInt.part_hint("h", "Height (size Y)."),
				]
			),
		]
	)


static func extract_rect2i(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Rect2i: return r
	if r is Rect2: return Rect2i(r)
	return null


static func part_hint_rect2i(p_name: String, p_desc: String = "") -> ConstructorDef.PartHint:
	return (ConstructorDef.PartHint
		.new(p_name, "<Rect2i>", p_desc)
		.accepts([TYPE_RECT2, TYPE_RECT2I]))
