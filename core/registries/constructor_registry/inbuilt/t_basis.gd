# t_basis.gd
# Built-in Basis constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# Basis() → Basis.IDENTITY
# Basis(name) → named constant
# Basis(Vector3, Vector3, Vector3) → three column vectors (x, y, z)
# Basis(Vector3, float) → axis + angle (radians)
# Basis(Quaternion) → from a quaternion
#
# Note: Godot's Basis(x, y, z) constructor uses column vectors.
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCVector3 = preload("./t_vector3.gd")
const DCQuaternion = preload("./t_quaternion.gd")


static func create() -> _DCKitNamespace.ConstructorDef:
	const CONSTS := {
		"IDENTITY": Basis.IDENTITY,
		"FLIP_X": Basis.FLIP_X,
		"FLIP_Y": Basis.FLIP_Y,
		"FLIP_Z": Basis.FLIP_Z,
	}

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → identity
		if parts.is_empty():
			return Basis.IDENTITY

		# One arg — named constant, existing Basis, or Quaternion
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			# Try extracting existing Basis or Quaternion first
			var basis := extract_basis(val)
			if basis != null:
				return basis

			# Named constant (LITERAL only)
			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Basis: '%s' is not a known constant. Expected one of: %s." \
							% [val.raw, ", ".join(const_names)]
				)

			return DCResult.fail(
				"Basis: single-part form expects a constant name, Basis, or Quaternion. Got %s." \
						% val_label(val)
			)

		# Two args — axis (Vector3) + angle (float, radians)
		if parts.size() == 2:
			var axis_val: DCResult.Value = parts[0]
			var angle_val: DCResult.Value = parts[1]

			var axis := DCVector3.extract_vector3(axis_val)
			if axis == null:
				return DCResult.fail(
					"Basis part 'axis': expected a Vector3, got %s." \
							% val_label(axis_val)
				)

			var angle = DCFloat.extract(angle_val)
			if angle == null:
				return DCResult.fail(
					"Basis part 'angle': expected a float (radians), got %s." \
							% val_label(angle_val)
				)

			if not axis.is_normalized():
				return DCResult.fail(
					"Basis part 'axis': vector %s is not normalised. "
					+ "Use a unit vector (e.g. Vector3.UP)." % var_to_str(axis)
				)

			return Basis(axis, angle)

		# Three args — three column vectors (x, y, z)
		if parts.size() == 3:
			var labels := ["x", "y", "z"]
			var vecs: Array[Vector3] = []

			for i in 3:
				var v: DCResult.Value = parts[i]
				var vec := DCVector3.extract_vector3(v)
				if vec == null:
					return DCResult.fail(
						"Basis part '%s': expected a Vector3, got %s." \
								% [labels[i], val_label(v)]
					)
				vecs.append(vec)

			return Basis(vecs[0], vecs[1], vecs[2])

		return DCResult.fail("Basis: expected 0, 1, 2, or 3 parts — got %d." % parts.size())

	return _DCKitNamespace.ConstructorDef.new(
		"Basis",
		handler,
		"A 3×3 rotation and scale matrix.\n"
		+ "[color=gray]Stores three column vectors: [b]x[/b] (right), [b]y[/b] (up), [b]z[/b] (back).[/color]",
		[
			sig_zero("Identity — no rotation or scale"),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Existing Basis or Quaternion",
				[_DCKitNamespace.ConstructorDef.PartHint.new(
						"value",
						"<Basis | Quaternion>",
						"Existing basis or quaternion",
					)],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Axis + angle (radians)",
				[
					DCVector3.part_hint_vector3(
						"axis",
						"Normalised rotation axis — e.g. [b]Vector3.UP[/b].",
					),
					DCFloat.part_hint(
						"angle",
						"Rotation angle in [b]radians[/b]. Use [b]deg_to_rad(degrees)[/b] to convert.",
					),
				],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Three column vectors",
				[
					DCVector3.part_hint_vector3("x", "X column — local right direction."),
					DCVector3.part_hint_vector3("y", "Y column — local up direction."),
					DCVector3.part_hint_vector3("z", "Z column — local back direction."),
				],
			),
			_DCKitNamespace.ConstructorDef.TypeSignature.new(
				"From Quaternion",
				[
					DCQuaternion.part_hint_quaternion(
						"quaternion",
						"A unit quaternion representing the desired rotation.",
					)
				],
			),
		],
	)


static func extract_basis(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Basis:
		return r
	if r is Quaternion:
		return Basis(r as Quaternion)
	return null


static func part_hint_basis(
	p_name: String,
	p_desc: String = "",
) -> _DCKitNamespace.ConstructorDef.PartHint:
	return (_DCKitNamespace.ConstructorDef.PartHint.new(p_name, "<Basis>", p_desc).accepts(
			[TYPE_BASIS]
		))
