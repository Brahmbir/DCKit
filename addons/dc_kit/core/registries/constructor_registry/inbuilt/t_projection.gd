# t_projection.gd
# Built-in Projection constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# Projection() → Projection.IDENTITY
# Projection(name) → named constant
# Projection(Transform3D) → from a Transform3D
# Projection(Vector4, Vector4, Vector4, Vector4) → four column vectors
#
# Note: Static factory methods like create_perspective(), create_orthogonal(), etc.
# are not exposed as constructors. Use them directly in GDScript.

extends "./inbuilt_base.gd"

const DCVector4 = preload("./t_vector4.gd")
const DCTransform3D = preload("./t_transform3d.gd")

static func create() ->  _DCKitNamespace.ConstructorDef:
	const CONSTS := {
		"IDENTITY": Projection.IDENTITY,
		"ZERO": Projection.ZERO,
	}
	
	var const_names : Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → identity
		if parts.is_empty():
			return Projection.IDENTITY

		# One arg — named constant (LITERAL), existing Projection, or Transform3D
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]
			
			# Try extracting existing Projection or Transform3D first
			var proj := extract_projection(val)
			if proj != null:
				return proj
			
			# Named constant (LITERAL only)
			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Projection: '%s' is not a known constant. Expected one of: %s." \
					% [val.raw, ", ".join(const_names)])
			
			return DCResult.fail(
				"Projection: single-part form expects a constant name, Projection, or Transform3D. Got %s." \
				% val_label(val))

		# Four args — four column Vector4s
		if parts.size() == 4:
			var labels := ["x", "y", "z", "w"]
			var vecs : Array[Vector4] = []
			
			for i in 4:
				var v : DCResult.Value = parts[i]
				var vec := DCVector4.extract_vector4(v)
				if vec == null:
					return DCResult.fail(
						"Projection part '%s': expected a Vector4, got %s." \
						% [labels[i], val_label(v)])
				vecs.append(vec)
			
			return Projection(vecs[0], vecs[1], vecs[2], vecs[3])

		return DCResult.fail(
			"Projection: expected 0, 1, or 4 parts — got %d." % parts.size())

	return  _DCKitNamespace.ConstructorDef.new(
		"Projection",
		handler,
		"A 4×4 projection matrix — used for camera perspective and orthogonal projections.\n" +
		"[color=gray]Stores four column vectors: [b]x[/b], [b]y[/b], [b]z[/b], [b]w[/b].[/color]",
		[
			sig_zero("Identity matrix"),
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]
			),
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Existing Projection or Transform3D",
				[ _DCKitNamespace.ConstructorDef.PartHint.new("value", "<Projection | Transform3D>", "Existing projection or transform")]
			),
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"From Transform3D",
				[DCTransform3D.part_hint_transform3d("transform",
					"A Transform3D to convert into a Projection matrix.")]
			),
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Four column vectors",
				[
					DCVector4.part_hint_vector4("x", "First column — maps X basis."),
					DCVector4.part_hint_vector4("y", "Second column — maps Y basis."),
					DCVector4.part_hint_vector4("z", "Third column — maps Z basis."),
					DCVector4.part_hint_vector4("w", "Fourth column — maps translation / projection."),
				]
			),
		]
	)


static func extract_projection(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Projection: return r
	if r is Transform3D: return Projection(r as Transform3D)
	return null


static func part_hint_projection(p_name: String, p_desc: String = "") ->  _DCKitNamespace.ConstructorDef.PartHint:
	return ( _DCKitNamespace.ConstructorDef.PartHint
		.new(p_name, "<Projection>", p_desc)
		.accepts([TYPE_PROJECTION, TYPE_TRANSFORM3D]))
