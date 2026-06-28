# t_vector4i.gd
# Built-in Vector4 constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Vector4i()            → Vector4i.ZERO
#   Vector4i(x, y, z, w)  → float components — any DCResult.Value origin
#
# Note: Vector4i has no named constants beyond ZERO and ONE in Godot,
# so there is no named-constant form.

extends "./inbuilt_base.gd"

const DCInt = preload("./t_int.gd")


static func create() -> ConstructorDef:
	const CONSTS := {
		"ZERO": Vector4i.ZERO,
		"ONE":  Vector4i.ONE,
		#"INF":  Vector4i.INF,
	}

	var const_names : Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:

		# Zero-arg
		if parts.is_empty():
			return Vector4i.ZERO

		# One arg — named constant only
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]
			var vec := extract_vector4i(val)
			if vec != null:
				return vec
			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
			return DCResult.fail(
				"Vector4i: expected a constant name (%s), got %s." \
				% [", ".join(const_names), val_label(val)])

		# Four args — XYZW components
		if parts.size() == 4:
			var labels := ["x", "y", "z", "w"]
			var values : Array = []
			for i in 4:
				var f = DCInt.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Vector4i part '%s': expected a number, got %s." \
						% [labels[i], val_label(parts[i])])
				values.append(f)
			return Vector4i(values[0], values[1], values[2], values[3])

		return DCResult.fail(
			"Vector4i: expected 0, 1, or 4 parts — got %d." % parts.size())

	return ConstructorDef.new(
		"Vector4i",
		handler,
		"A 4D vector with [b]x[/b], [b]y[/b], [b]z[/b], and [b]w[/b] int components.",
		[
			sig_zero("Zero vector — Vector4i(0, 0, 0, 0)"),

			ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]
			),

			ConstructorDef.TypeSignature.new(
				"Convert Vector4/Vector4i",
				[part_hint_vector4i(
						"value",
						"Existing Vector4i or integer-valued Vector4")]
			),

			ConstructorDef.TypeSignature.new(
				"XYZW components",
				[
					DCInt.part_hint("x", "X component"),
					DCInt.part_hint("y", "Y component"),
					DCInt.part_hint("z", "Z component"),
					DCInt.part_hint("w", "W component"),
				]
			),
		]
	)

static func extract_vector4i(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector4i: return r
	if r is Vector4: return Vector4i(r)
	return null
 
static func part_hint_vector4i(p_name: String, p_desc: String = "") -> ConstructorDef.PartHint:
	return (ConstructorDef.PartHint
		.new(p_name, "<Vector4i>", p_desc)
		.accepts([TYPE_VECTOR4I, TYPE_VECTOR4]))
