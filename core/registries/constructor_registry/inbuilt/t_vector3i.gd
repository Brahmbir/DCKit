# t_vector3i.gd
# Built-in Vector3i constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Vector3i()            → Vector3i.ZERO
#   Vector3i(name)        → named constant  e.g. Vector3i(UP)
#   Vector3i(x, y, z)     → int components — any DCResult.Value origin
extends "./inbuilt_base.gd"

const DCInt = preload("./t_int.gd")


static func create() -> _DCKitNamespace.ConstructorDef:
	const CONSTS := {
		"ZERO": Vector3i.ZERO,
		"ONE": Vector3i.ONE,
		"LEFT": Vector3i.LEFT,
		"RIGHT": Vector3i.RIGHT,
		"UP": Vector3i.UP,
		"DOWN": Vector3i.DOWN,
		"FORWARD": Vector3i.FORWARD,
		"BACK": Vector3i.BACK,
	}

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg
		if parts.is_empty():
			return Vector3i.ZERO

		# One arg — named constant only
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			var vec := extract_vector3i(val)
			if vec != null:
				return vec

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]

			return DCResult.fail(
				"Vector3i: expected a Vector3i, integer Vector3, or constant name (%s), got %s."
				% [", ".join(const_names), val_label(val)]
			)

		# Three args — XYZ components
		if parts.size() == 3:
			var labels := ["x", "y", "z"]
			var values: Array = []
			for i in 3:
				var f = DCInt.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Vector3i part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)
			return Vector3i(values[0], values[1], values[2])

		return DCResult.fail("Vector3i: expected 0, 1, or 3 parts — got %d." % parts.size())

	return _DCKitNamespace.ConstructorDef.new(
		"Vector3i",
		handler,
		"A 3D vector with [b]x[/b], [b]y[/b], and [b]z[/b] int components.",
		[
			sig_zero("Zero vector — Vector3i(0, 0, 0)"),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Convert Vector3/Vector3i",
				[part_hint_vector3i("value", "Existing Vector3i or integer-valued Vector3")],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"XYZ components",
				[
					DCInt.part_hint("x", "Right (+), left (−)"),
					DCInt.part_hint("y", "Up (+), down (−)"),
					DCInt.part_hint("z", "Back (+), forward (−)"),
				],
			),
		],
	)


static func extract_vector3i(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector3i:
		return r
	if r is Vector3:
		return Vector3i(r)
	return null


static func part_hint_vector3i(
	p_name: String,
	p_desc: String = "",
) -> _DCKitNamespace.ConstructorDef.PartHint:
	return (_DCKitNamespace.ConstructorDef.PartHint.new(p_name, "<Vector3i>", p_desc).accepts(
			[TYPE_VECTOR3I, TYPE_VECTOR3]
		))
