# t_vector4.gd
# Built-in Vector4 constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Vector4()            → Vector4.ZERO
#   Vector4(x, y, z, w)  → float components — any DCResult.Value origin
#
# Note: Vector4 has no named constants beyond ZERO and ONE in Godot,
# so there is no named-constant form.
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	const CONSTS := { "ZERO": Vector4.ZERO, "ONE": Vector4.ONE, "INF": Vector4.INF }

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg
		if parts.is_empty():
			return Vector4.ZERO

		# One arg — named constant only
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			var vec := extract_vector4(val)
			if vec != null:
				return vec

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]

			return DCResult.fail(
				"Vector4: expected a Vector4, Vector4i, or constant name (%s), got %s."
				% [", ".join(const_names), val_label(val)]
			)

		# Four args — XYZW components
		if parts.size() == 4:
			var labels := ["x", "y", "z", "w"]
			var values: Array = []
			for i in 4:
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Vector4 part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)
			return Vector4(values[0], values[1], values[2], values[3])

		return DCResult.fail("Vector4: expected 0, 1, or 4 parts — got %d." % parts.size())

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Vector4",
		handler,
		"A 4D vector with [b]x[/b], [b]y[/b], [b]z[/b], and [b]w[/b] float components.",
		[
			sig_zero("Zero vector — Vector4(0, 0, 0, 0)"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Convert Vector4/Vector4i",
				[part_hint_vector4("value", "Existing Vector4 or Vector4i")],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"XYZW components",
				[
					DCFloat.part_hint("x", "X component"),
					DCFloat.part_hint("y", "Y component"),
					DCFloat.part_hint("z", "Z component"),
					DCFloat.part_hint("w", "W component"),
				],
			),
		],
	)


static func extract_vector4(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector4:
		return r
	if r is Vector4i:
		return Vector4(r)
	return null


static func part_hint_vector4(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(p_name, "<Vector4>", p_desc).accepts(
			[TYPE_VECTOR4, TYPE_VECTOR4I]
		)
	)
