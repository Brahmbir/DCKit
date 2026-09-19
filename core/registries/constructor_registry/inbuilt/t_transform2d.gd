# t_transform2d.gd
# Built-in Transform2D constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# Transform2D() → Transform2D.IDENTITY
# Transform2D(name) → named constant
# Transform2D(rotation, position) → float (radians) + Vector2
# Transform2D(rotation, scale, skew, position) → full decomposed form
# Transform2D(x, y, origin) → three Vector2 columns
#
# Disambiguation — two-part form
# Both parts of Transform2D(rotation, position) are unambiguous.
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCVector2 = preload("./t_vector2.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	const CONSTS := {
		"IDENTITY": Transform2D.IDENTITY,
		"FLIP_X": Transform2D.FLIP_X,
		"FLIP_Y": Transform2D.FLIP_Y,
	}

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → identity
		if parts.is_empty():
			return Transform2D.IDENTITY

		# One arg — named constant (LITERAL only) or existing Transform2D
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			# Try extracting existing Transform2D first
			var xform := extract_transform2d(val)
			if xform != null:
				return xform

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Transform2D: '%s' is not a known constant. Expected one of: %s." \
							% [val.raw, ", ".join(const_names)]
				)

			return DCResult.fail(
				"Transform2D: single-part form expects a constant name or Transform2D. Got %s." \
						% val_label(val)
			)

		# Two args — rotation (float) + position (Vector2)
		if parts.size() == 2:
			var rot_val: DCResult.Value = parts[0]
			var pos_val: DCResult.Value = parts[1]

			var rotation = DCFloat.extract(rot_val)
			if rotation == null:
				return DCResult.fail(
					"Transform2D part 'rotation': expected a float (radians), got %s." \
							% val_label(rot_val)
				)

			var pos := DCVector2.extract_vector2(pos_val)
			if pos == null:
				return DCResult.fail(
					"Transform2D part 'position': expected a Vector2, got %s." \
							% val_label(pos_val)
				)

			return Transform2D(rotation, pos)

		# Three args — x column, y column, origin (all Vector2)
		if parts.size() == 3:
			var labels := ["x", "y", "origin"]
			var vecs: Array[Vector2] = []

			for i in 3:
				var v: DCResult.Value = parts[i]
				var vec := DCVector2.extract_vector2(v)
				if vec == null:
					return DCResult.fail(
						"Transform2D part '%s': expected a Vector2, got %s." \
								% [labels[i], val_label(v)]
					)
				vecs.append(vec)

			return Transform2D(vecs[0], vecs[1], vecs[2])

		# Four args — rotation, scale, skew, position
		if parts.size() == 4:
			var rot_val: DCResult.Value = parts[0]
			var scale_val: DCResult.Value = parts[1]
			var skew_val: DCResult.Value = parts[2]
			var pos_val: DCResult.Value = parts[3]

			var rotation = DCFloat.extract(rot_val)
			if rotation == null:
				return DCResult.fail(
					"Transform2D part 'rotation': expected a float (radians), got %s." \
							% val_label(rot_val)
				)

			var scale := DCVector2.extract_vector2(scale_val)
			if scale == null:
				return DCResult.fail(
					"Transform2D part 'scale': expected a Vector2, got %s." \
							% val_label(scale_val)
				)

			var skew = DCFloat.extract(skew_val)
			if skew == null:
				return DCResult.fail(
					"Transform2D part 'skew': expected a float (radians), got %s." \
							% val_label(skew_val)
				)

			var pos := DCVector2.extract_vector2(pos_val)
			if pos == null:
				return DCResult.fail(
					"Transform2D part 'position': expected a Vector2, got %s." \
							% val_label(pos_val)
				)

			return Transform2D(rotation, scale, skew, pos)

		return DCResult.fail(
			"Transform2D: expected 0, 1, 2, 3, or 4 parts — got %d." % parts.size()
		)

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Transform2D",
		handler,
		"A 2D transformation matrix with rotation, scale, skew, and translation.\n"
		+ "[color=gray]Stores three Vector2 columns: [b]x[/b] (right), [b]y[/b] (down), [b]origin[/b] (position).[/color]",
		[
			sig_zero("Identity — no transformation"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Existing Transform2D",
				[part_hint_transform2d("value", "Existing Transform2D")],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Rotation + position",
				[
					DCFloat.part_hint(
						"rotation",
						"Rotation in [b]radians[/b] — counter-clockwise positive. "
						+ "Use [b]deg_to_rad(degrees)[/b] to convert.",
					),
					DCVector2.part_hint_vector2("position", "Translation in world space."),
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Rotation, scale, skew, position",
				[
					DCFloat.part_hint(
						"rotation",
						"Rotation in [b]radians[/b] — counter-clockwise positive. "
						+ "Use [b]deg_to_rad(degrees)[/b] to convert.",
					),
					DCVector2.part_hint_vector2(
						"scale",
						"Non-uniform scale — [b]Vector2(1, 1)[/b] is no scale.",
					),
					DCFloat.part_hint(
						"skew",
						"Shear angle in [b]radians[/b] applied after rotation.",
					),
					DCVector2.part_hint_vector2("position", "Translation in world space."),
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Three column vectors",
				[
					DCVector2.part_hint_vector2("x", "Right-axis column."),
					DCVector2.part_hint_vector2("y", "Down-axis column."),
					DCVector2.part_hint_vector2("origin", "Translation column."),
				],
			),
		],
	)


static func extract_transform2d(val: DCResult.Value) -> Variant:
	if val.raw is Transform2D:
		return val.raw
	return null


static func part_hint_transform2d(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace
		.ConstructorDef
		.PartHint
		.new(p_name, "<Transform2D>", p_desc)
		.accepts([TYPE_TRANSFORM2D])
	)
