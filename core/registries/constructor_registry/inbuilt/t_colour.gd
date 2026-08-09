# t_colour.gd
# Built-in Color constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# Color() → opaque black
# Color(name) → CSS named color (e.g. "red")
# Color("#ff4400") → HTML hex (#RGB, #RGBA, #RRGGBB, #RRGGBBAA)
# Color(r, g, b) → float RGB (0.0–1.0)
# Color(r, g, b, a) → float RGBA (0.0–1.0)
# Color(r8, g8, b8) → 8-bit RGB (0–255)
# Color(r8, g8, b8, a8) → 8-bit RGBA (0–255)
#
# Auto-detection: If all values are whole numbers and any > 1.0 → treated as 8-bit.
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCInt = preload("./t_int.gd")


static func create() -> _DCKitNamespace.ConstructorDef:
	const NAMED_COLORS := {
		"black": Color.BLACK,
		"white": Color.WHITE,
		"red": Color.RED,
		"green": Color.GREEN,
		"blue": Color.BLUE,
		"yellow": Color.YELLOW,
		"cyan": Color.CYAN,
		"magenta": Color.MAGENTA,
		"gray": Color.GRAY,
		"orange": Color.ORANGE,
		"purple": Color.PURPLE,
		"pink": Color.PINK,
		"lime": Color.LIME,
		"teal": Color.TEAL,
		"brown": Color.BROWN,
		"olive": Color(0.5, 0.5, 0.0),
		"navy": Color(0.0, 0.0, 0.5),
		"maroon": Color(0.5, 0.0, 0.0),
		"silver": Color(0.75, 0.75, 0.75),
		"gold": Color(1.0, 0.84, 0.0),
		"transparent": Color.TRANSPARENT,
	}

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → opaque black
		if parts.is_empty():
			return Color.BLACK

		# One part — existing Color, named color, or HTML hex
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			# Already a Color
			if val.raw is Color:
				return val.raw

			# Must be string (name or hex)
			if val.raw is not String:
				return DCResult.fail(
					"Color: single-part form expects a color name, hex string, "
					+ "or existing Color — got %s." % val_label(val)
				)

			var s: String = (val.raw as String).strip_edges()
			if Color.html_is_valid(s):
				return Color.html(s)

			var key := s.to_lower()
			if NAMED_COLORS.has(key):
				return NAMED_COLORS[key]

			return DCResult.fail(
				"Color: '%s' is not a valid color name or HTML hex.\n" % s
				+ "Available names: red, green, blue, yellow, cyan, magenta, "
				+ "orange, purple, pink, black, white, gray, ..."
			)

		# Three or four parts — RGB(A) float or 8-bit
		if parts.size() in [3, 4]:
			var labels := ["r", "g", "b", "a"]
			var values: Array[float] = []

			for i in parts.size():
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Color part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)

			# Auto-detect 8-bit mode
			var all_whole: bool = values.all(
				func(v: float) -> bool:
					return is_equal_approx(v, floorf(v)),
			)
			var any_gt1: bool = values.any(
				func(v: float) -> bool:
					return v > 1.0,
			)

			if all_whole and any_gt1:
				# 8-bit mode
				for i in values.size():
					if values[i] < 0.0 or values[i] > 255.0:
						return DCResult.fail(
							"Color part '%s': 8-bit value %s is out of range (0–255)." \
									% [labels[i], values[i]]
						)

				var r := values[0] / 255.0
				var g := values[1] / 255.0
				var b := values[2] / 255.0
				var a := values[3] / 255.0 if values.size() == 4 else 1.0
				return Color(r, g, b, a)

			# Float mode (0.0–1.0)
			for i in values.size():
				if values[i] < 0.0 or values[i] > 1.0:
					return DCResult.fail(
						"Color part '%s': float value %s is out of range (0.0–1.0).\n" \
								% [labels[i], values[i]]
						+ "Tip: Use integers 0–255 for 8-bit mode, e.g. Color(255, 128, 0)."
					)

			var r := values[0]
			var g := values[1]
			var b := values[2]
			var a := values[3] if values.size() == 4 else 1.0
			return Color(r, g, b, a)

		return DCResult.fail("Color: expected 0, 1, 3, or 4 parts — got %d." % parts.size())

	# ── Part Hints ─────────────────────────────────────────────────────
	var name_part := (
		_DCKitNamespace
		.ConstructorDef
		.PartHint
		.new("name", "<string>", "CSS color name (e.g. [b]red[/b]) or HTML hex (e.g. [b]#ff4400[/b], [b]#f40[/b])")
		.accepts([TYPE_STRING, TYPE_COLOR])
	)

	var channel_part := func(ch: String, label: String) -> _DCKitNamespace.ConstructorDef.PartHint:
		return (
			_DCKitNamespace
			.ConstructorDef
			.PartHint
			.new(ch, "<float>", "%s channel — 0.0–1.0 (float) or 0–255 (integer). Auto-detected."
			% label)
			.validate(_DCKitNamespace.ConstructorDef.PartHint.float_validator())
			.accepts([TYPE_FLOAT, TYPE_INT, TYPE_STRING])
		)

	var rf := channel_part.call("r", "Red")
	var gf := channel_part.call("g", "Green")
	var bf := channel_part.call("b", "Blue")
	var af := channel_part.call("a", "Alpha")

	return _DCKitNamespace.ConstructorDef.new(
		"Color",
		handler,
		"An RGBA color. Supports named colors, hex codes, float (0.0–1.0), "
		+ "and 8-bit (0–255) components.\n"
		+ "[color=gray]Auto-detection: values > 1.0 → treated as 8-bit.[/color]",
		[
			sig_zero("Opaque black — Color(0, 0, 0, 1)"),
			_DCKitNamespace.ConstructorDef.TypeSignature.new("Named color or HTML hex", [name_part]),
			_DCKitNamespace.ConstructorDef.TypeSignature.new("RGB — float 0.0–1.0", [rf, gf, bf]),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"RGBA — float 0.0–1.0",
				[rf, gf, bf, af],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new("RGB — 8-bit 0–255", [rf, gf, bf]),
			_DCKitNamespace.ConstructorDef.TypeSignature.new("RGBA — 8-bit 0–255", [rf, gf, bf, af]),
		],
	)


static func extract_color(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Color:
		return r
	if r is String:
		var s := (r as String).strip_edges()
		if Color.html_is_valid(s):
			return Color.html(s)
	return null


static func part_hint_color(
	p_name: String,
	p_desc: String = "",
) -> _DCKitNamespace.ConstructorDef.PartHint:
	return (_DCKitNamespace.ConstructorDef.PartHint.new(p_name, "<Color>", p_desc).accepts(
			[TYPE_COLOR, TYPE_STRING]
		))
