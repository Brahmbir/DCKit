# t_plane.gd
# Built-in Plane constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
#   Plane()                          → Plane(0, 1, 0, 0)  — XZ plane (Y-up normal)
#   Plane(name)                      → named constant  e.g. Plane(PLANE_XY)
#   Plane(plane)                     → existing Plane (pass-through)
#   Plane(a, b, c, d)                → four floats: normal components (a, b, c)
#                                      + distance from origin (d)
#   Plane(normal, d)                 → Vector3 normal + float distance
#   Plane(normal, point)             → Vector3 normal + Vector3 point on the plane
#   Plane(v1, v2, v3)                → three Vector3 points (counter-clockwise)
#
# Normal convention
#
#   Godot's Plane stores a normalised normal and a scalar d such that
#   any point P on the plane satisfies  normal · P = d.
#   When the user supplies a non-unit normal in the (a,b,c,d) or (normal,d)
#   forms, Godot normalises it automatically; we surface that in the description.
#
# DCResult.Value origin rules
#
#   Named-constant form: LITERAL only.
#   All numeric / vector forms accept any origin.

extends "./inbuilt_base.gd"


const DCFloat  = preload("./t_float.gd")
const DCVector3 = preload("./t_vector3.gd")


static func create() ->  _DCKitNamespace.ConstructorDef:
	const CONSTS := {
		"PLANE_XY": Plane(Vector3(0, 0, 1), 0),
		"PLANE_XZ": Plane(Vector3(0, 1, 0), 0),
		"PLANE_YZ": Plane(Vector3(1, 0, 0), 0),
	}

	var const_names : Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:

		# Zero-arg → XZ plane (Y-up normal, passes through origin)
		if parts.is_empty():
			return Plane(Vector3(0, 1, 0), 0.0)

		# One arg — existing Plane or named constant (LITERAL string)
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]

			var plane := extract_plane(val)
			if plane != null:
				return plane

			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Plane: '%s' is not a known constant. Expected one of: %s." \
					% [val.raw, ", ".join(const_names)])

			return DCResult.fail(
				"Plane: single-part form expects a constant name or existing Plane, got %s." \
				% val_label(val))

		# Two args — Vector3 normal + float distance, or Vector3 normal + Vector3 point
		if parts.size() == 2:
			var normal_val : DCResult.Value = parts[0]
			var second_val : DCResult.Value = parts[1]

			var normal := DCVector3.extract_vector3(normal_val)
			if normal == null:
				return DCResult.fail(
					"Plane part 'normal': expected a Vector3, got %s." \
					% val_label(normal_val))

			# Second part: float distance
			var d = DCFloat.extract(second_val)
			if d != null:
				return Plane(normal, d)

			# Second part: Vector3 point on plane
			var point := DCVector3.extract_vector3(second_val)
			if point != null:
				return Plane(normal, point)

			return DCResult.fail(
				"Plane part 'd / point': expected a float (distance) "
				+ "or a Vector3 (point on plane), got %s." % val_label(second_val))

		# Three args — three Vector3 points (counter-clockwise winding)
		if parts.size() == 3:
			var labels := ["v1", "v2", "v3"]
			var vecs   : Array[Vector3] = []
			for i in 3:
				var v : DCResult.Value = parts[i]
				var vec := DCVector3.extract_vector3(v)
				if vec == null:
					return DCResult.fail(
						"Plane part '%s': expected a Vector3, got %s." \
						% [labels[i], val_label(v)])
				vecs.append(vec)
			return Plane(vecs[0], vecs[1], vecs[2])

		# Four args — a, b, c, d  (normal components + distance)
		if parts.size() == 4:
			var labels := ["a", "b", "c", "d"]
			var values : Array[float] = []
			for i in 4:
				var f = DCFloat.extract(parts[i])
				if f == null:
					return DCResult.fail(
						"Plane part '%s': expected a number, got %s." \
						% [labels[i], val_label(parts[i])])
				values.append(f)
			return Plane(values[0], values[1], values[2], values[3])

		return DCResult.fail(
			"Plane: expected 0, 1, 2, 3, or 4 parts — got %d." % parts.size())

	return  _DCKitNamespace.ConstructorDef.new(
		"Plane",
		handler,
		"An infinite plane defined by a [b]normal[/b] and a distance [b]d[/b].\n"
		+ "[color=gray]Points on the plane satisfy: "
		+ "[b]normal · P = d[/b]. "
		+ "Normal is automatically normalised.[/color]",
		[
			sig_zero("XZ plane — normal (0, 1, 0), d = 0"),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]
			),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Existing Plane",
				[part_hint_plane("value", "Existing Plane value.")]
			),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Normal + distance",
				[
					DCVector3.part_hint_vector3("normal",
						"Plane normal direction — need not be unit length (auto-normalised)."),
					DCFloat.part_hint("d",
						"Signed distance from the origin along the normal. "
						+ "Positive = plane is shifted in the normal direction."),
				]
			),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Normal + point on plane",
				[
					DCVector3.part_hint_vector3("normal",
						"Plane normal direction — need not be unit length (auto-normalised)."),
					DCVector3.part_hint_vector3("point",
						"Any point known to lie on the plane."),
				]
			),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Three points (counter-clockwise)",
				[
					DCVector3.part_hint_vector3("v1", "First point on the plane."),
					DCVector3.part_hint_vector3("v2", "Second point — counter-clockwise from v1."),
					DCVector3.part_hint_vector3("v3", "Third point — counter-clockwise from v1."),
				]
			),

			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Components — a, b, c (normal) + d (distance)",
				[
					DCFloat.part_hint("a", "Normal X component."),
					DCFloat.part_hint("b", "Normal Y component."),
					DCFloat.part_hint("c", "Normal Z component."),
					DCFloat.part_hint("d",
						"Distance from origin. "
						+ "Normal (a, b, c) is auto-normalised."),
				]
			),
		]
	)


static func extract_plane(val: DCResult.Value) -> Variant:
	if val.raw is Plane: return val.raw
	return null


static func part_hint_plane(p_name: String, p_desc: String = "") ->  _DCKitNamespace.ConstructorDef.PartHint:
	return ( _DCKitNamespace.ConstructorDef.PartHint
		.new(p_name, "<Plane>", p_desc)
		.accepts([TYPE_PLANE]))
