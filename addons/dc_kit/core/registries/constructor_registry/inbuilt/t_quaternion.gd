# t_quaternion.gd
# Built-in Quaternion constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Quaternion()               → Quaternion.IDENTITY
#   Quaternion(name)           → named constant  e.g. Quaternion(IDENTITY)
#   Quaternion(quaternion)     → existing Quaternion (pass-through)
#   Quaternion(axis, angle)    → normalised Vector3 axis + float angle (radians)
#   Quaternion(basis)          → from a Basis matrix
#   Quaternion(x, y, z, w)    → four float components (raw)
#
# Component form (x, y, z, w)
#
#   Godot's component order is (x, y, z, w) — w is the scalar part.
#   The handler does NOT re-normalise; if you supply components that do not
#   form a unit quaternion the resulting rotation will be wrong. A warning
#   is issued when the length deviates from 1.0 by more than 1e-3.
#
# Axis-angle form
#
#   The axis must be a unit vector. The handler returns a clear error if it
#   is not normalised (same check as Basis).
#
# DCResult.Value origin rules
#
#   Named-constant form: LITERAL only.
#   All other forms accept any origin (CONSTRUCTOR or COMMAND).
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")
const DCVector3 = preload("./t_vector3.gd")
const DCBasis = preload("./t_basis.gd")


static func create() -> _DCKitRegistriesNamespace.ConstructorDef:
	const CONSTS := { "IDENTITY": Quaternion.IDENTITY }

	var const_names: Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → identity
		if parts.is_empty():
			return Quaternion.IDENTITY

		# One arg — existing Quaternion, Basis pass-through, or named constant (LITERAL)
		if parts.size() == 1:
			var val: DCResult.Value = parts[0]

			var quat := extract_quaternion(val)
			if quat != null:
				return quat

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Quaternion: '%s' is not a known constant. Expected one of: %s." \
							% [val.raw, ", ".join(const_names)]
				)

			return DCResult.fail(
				"Quaternion: single-part form expects a constant name, Quaternion, or Basis, got %s." \
						% val_label(val)
			)

		# Two args — axis (Vector3) + angle (float, radians)
		if parts.size() == 2:
			var axis_val: DCResult.Value = parts[0]
			var angle_val: DCResult.Value = parts[1]

			var axis := DCVector3.extract_vector3(axis_val)
			if axis == null:
				return DCResult.fail(
					"Quaternion part 'axis': expected a Vector3, got %s." \
							% val_label(axis_val)
				)

			var angle = DCFloat.extract(angle_val)
			if angle == null:
				return DCResult.fail(
					"Quaternion part 'angle': expected a float (radians), got %s." \
							% val_label(angle_val)
				)

			if not axis.is_normalized():
				return DCResult.fail(
					"Quaternion part 'axis': vector %s is not normalised — "
					+ "use a unit vector such as Vector3(UP)." % var_to_str(axis)
				)

			return Quaternion(axis, angle)

		# Four args — x, y, z, w components
		if parts.size() == 4:
			var labels := ["x", "y", "z", "w"]
			var values: Array[float] = []
			for i in 4:
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Quaternion part '%s': expected a number, got %s." \
								% [labels[i], val_label(parts[i])]
					)
				values.append(f)

			var q := Quaternion(values[0], values[1], values[2], values[3])

			# Warn (not fail) when the quaternion is not unit-length — a non-unit
			# quaternion is constructable but almost certainly a user mistake.
			var length_sq: float = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w
			if abs(length_sq - 1.0) > 1e-3:
				push_warning(
					"Quaternion: components (%s, %s, %s, %s) do not form a unit quaternion "
					+ "(length² = %.6f). The resulting rotation will be incorrect." \
							% [values[0], values[1], values[2], values[3], length_sq]
				)

			return q

		return DCResult.fail("Quaternion: expected 0, 1, 2, or 4 parts — got %d." % parts.size())

	return _DCKitRegistriesNamespace.ConstructorDef.new(
		"Quaternion",
		handler,
		"A unit quaternion representing a 3D rotation.\n"
		+ "[color=gray]Components must form a unit quaternion: "
		+ "[b]x² + y² + z² + w² = 1[/b].[/color]",
		[
			sig_zero("Identity — no rotation"),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Existing Quaternion or Basis",
				[_DCKitRegistriesNamespace.ConstructorDef.PartHint.new(
						"value",
						"<Quaternion | Basis>",
						"Existing quaternion or basis.",
					)],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Axis + angle (radians)",
				[
					DCVector3.part_hint_vector3(
						"axis",
						"Normalised rotation axis — e.g. [b]Vector3(UP)[/b] or [b]Vector3(0,1,0)[/b].",
					),
					DCFloat.part_hint(
						"angle",
						"Rotation angle in [b]radians[/b]. "
						+ "Use [b]deg_to_rad(degrees)[/b] to convert from degrees.",
					),
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"From Basis",
				[
					DCBasis.part_hint_basis(
						"basis",
						"A rotation matrix to convert into quaternion form.",
					)
				],
			),
			_DCKitRegistriesNamespace.ConstructorDef.TypeSignature.new(
				"Components (x, y, z, w)",
				[
					DCFloat.part_hint("x", "X imaginary component."),
					DCFloat.part_hint("y", "Y imaginary component."),
					DCFloat.part_hint("z", "Z imaginary component."),
					DCFloat.part_hint("w", "Scalar (real) component."),
				],
			),
		],
	)


static func extract_quaternion(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Quaternion:
		return r
	if r is Basis:
		return Quaternion(r as Basis)
	return null


static func part_hint_quaternion(
	p_name: String,
	p_desc: String = "",
) -> _DCKitRegistriesNamespace.ConstructorDef.PartHint:
	return (
		_DCKitRegistriesNamespace
		.ConstructorDef
		.PartHint
		.new(p_name, "<Quaternion>", p_desc)
		.accepts([TYPE_QUATERNION, TYPE_BASIS])
	)
