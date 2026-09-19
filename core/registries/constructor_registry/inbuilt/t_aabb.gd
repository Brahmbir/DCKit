# t_aabb.gd
# Built-in AABB constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# AABB() → zero AABB
# AABB(Vector3, Vector3) → position + size
# AABB(x, y, z, w, h, d) → six floats (position + size)
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCVector3 = preload("./t_vector3.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	var handler := func(parts: Array) -> Variant:
		# Zero-arg → empty AABB
		if parts.is_empty():
			return AABB()

		# Two parts — position + size (Vector3)
		if parts.size() == 2:
			var pos_val: DCResult.Value = parts[0]
			var siz_val: DCResult.Value = parts[1]

			var position := DCVector3.extract_vector3(pos_val)
			if position == null:
				return DCResult.fail(
					"AABB part 'position': expected a Vector3, got %s." \
							% val_label(pos_val)
				)

			var size := DCVector3.extract_vector3(siz_val)
			if size == null:
				return DCResult.fail(
					"AABB part 'size': expected a Vector3, got %s." \
							% val_label(siz_val)
				)

			return AABB(position, size)

		# Six parts — flat floats: x y z (position) + w h d (size)
		if parts.size() == 6:
			var labels := ["x", "y", "z", "w", "h", "d"]
			var values: Array[float] = []

			for i in 6:
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"AABB part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)

			var position := Vector3(values[0], values[1], values[2])
			var size := Vector3(values[3], values[4], values[5])
			return AABB(position, size)

		return DCResult.fail("AABB: expected 0, 2, or 6 parts — got %d." % parts.size())

	# Part hints
	var vec3_part := func(p_name: String, p_desc: String) -> _DCKitRegistriesNamespace \
			.ConstructorDef \
			.PartHint:
		return (
			_DCKitRegistriesNamespace
			.ConstructorDef
			.PartHint
			.new(p_name, "<Vector3>", p_desc)
			.accepts([TYPE_VECTOR3])
		)

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"AABB",
		handler,
		"An axis-aligned bounding box defined by a [b]position[/b] and [b]size[/b].\n"
		+ "[color=gray]Negative size is allowed. Use [b].abs()[/b] to normalize.[/color]",
		[
			sig_zero("Zero AABB — AABB(Vector3.ZERO, Vector3.ZERO)"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Position + size (Vector3)",
				[
					DCVector3.part_hint_vector3("position", "Origin corner of the box."),
					DCVector3.part_hint_vector3("size", "Extent of the box."),
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Six floats — position (x,y,z) + size (w,h,d)",
				[
					DCFloat.part_hint("x", "Position X"),
					DCFloat.part_hint("y", "Position Y"),
					DCFloat.part_hint("z", "Position Z"),
					DCFloat.part_hint("w", "Size X (width)"),
					DCFloat.part_hint("h", "Size Y (height)"),
					DCFloat.part_hint("d", "Size Z (depth)"),
				],
			),
		],
	)


static func extract_aabb(val: DCResult.Value) -> Variant:
	if val.raw is AABB:
		return val.raw
	return null


static func part_hint_aabb(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(p_name, "<AABB>", p_desc).accepts(
			[TYPE_AABB]
		)
	)
