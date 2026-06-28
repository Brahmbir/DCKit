# t_transform3d.gd
# Built-in Transform3D constructor definition.
# Accessed via ConstructorRegistry; no class_name.
#
# Supported forms:
# Transform3D() → Transform3D.IDENTITY
# Transform3D(name) → named constant
# Transform3D(basis, origin) → Basis + Vector3
# Transform3D(x, y, z, origin) → four Vector3 columns
# Transform3D(projection) → from Projection matrix
#
# Note: One-argument form properly supports existing Transform3D values
# and Projection matrices.

extends "./inbuilt_base.gd"

const DCVector3 = preload("./t_vector3.gd")
const DCBasis = preload("./t_basis.gd")
const DCProjection = preload("./t_projection.gd")

static func create() -> ConstructorDef:
	const CONSTS := {
		"IDENTITY": Transform3D.IDENTITY,
		"FLIP_X": Transform3D.FLIP_X,
		"FLIP_Y": Transform3D.FLIP_Y,
		"FLIP_Z": Transform3D.FLIP_Z,
	}
	
	var const_names : Array = CONSTS.keys()
	const_names.sort()

	var handler := func(parts: Array) -> Variant:
		# Zero-arg → identity
		if parts.is_empty():
			return Transform3D.IDENTITY

		# One arg — named constant, existing Transform3D, or Projection
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]
			
			# Try extracting existing Transform3D or Projection first
			var xform := extract_transform3d(val)
			if xform != null:
				return xform
			
			# Named constant (LITERAL only)
			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
				return DCResult.fail(
					"Transform3D: '%s' is not a known constant. Expected one of: %s." \
					% [val.raw, ", ".join(const_names)])
			
			return DCResult.fail(
				"Transform3D: single-part form expects a constant name, Transform3D, or Projection. Got %s." \
				% val_label(val))

		# Two args — Basis + Vector3 origin
		if parts.size() == 2:
			var basis_val : DCResult.Value = parts[0]
			var origin_val : DCResult.Value = parts[1]
			
			var basis := DCBasis.extract_basis(basis_val)
			if basis == null:
				return DCResult.fail(
					"Transform3D part 'basis': expected a Basis, got %s." \
					% val_label(basis_val))
			
			var origin := DCVector3.extract_vector3(origin_val)
			if origin == null:
				return DCResult.fail(
					"Transform3D part 'origin': expected a Vector3, got %s." \
					% val_label(origin_val))
			
			return Transform3D(basis, origin)

		# Four args — x, y, z columns + origin (all Vector3)
		if parts.size() == 4:
			var labels := ["x", "y", "z", "origin"]
			var vecs : Array[Vector3] = []
			
			for i in 4:
				var v : DCResult.Value = parts[i]
				var vec := DCVector3.extract_vector3(v)
				if vec == null:
					return DCResult.fail(
						"Transform3D part '%s': expected a Vector3, got %s." \
						% [labels[i], val_label(v)])
				vecs.append(vec)
			
			return Transform3D(vecs[0], vecs[1], vecs[2], vecs[3])

		return DCResult.fail(
			"Transform3D: expected 0, 1, 2, or 4 parts — got %d." % parts.size())

	return ConstructorDef.new(
		"Transform3D",
		handler,
		"A 3D transformation matrix with rotation, scale, and translation.\n" +
		"[color=gray]Stores a [b]Basis[/b] (3×3) and a [b]Vector3 origin[/b].[/color]",
		[
			sig_zero("Identity — no transformation"),
			ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]
			),
			ConstructorDef.TypeSignature.new(
				"Existing Transform3D or Projection",
				[ConstructorDef.PartHint.new("value", "<Transform3D | Projection>", "Existing transform or projection")]
			),
			ConstructorDef.TypeSignature.new(
				"Basis + origin",
				[
					DCBasis.part_hint_basis("basis", "Rotation and scale matrix — e.g. from [b]Basis(axis, angle)[/b]."),
					DCVector3.part_hint_vector3("origin", "Translation in world space."),
				]
			),
			ConstructorDef.TypeSignature.new(
				"Three column vectors + origin",
				[
					DCVector3.part_hint_vector3("x", "X column — local right direction."),
					DCVector3.part_hint_vector3("y", "Y column — local up direction."),
					DCVector3.part_hint_vector3("z", "Z column — local back direction."),
					DCVector3.part_hint_vector3("origin", "Translation in world space."),
				]
			),
			ConstructorDef.TypeSignature.new(
				"From Projection",
				[DCProjection.part_hint_projection("projection", "A Projection matrix to extract the affine 3D transform from.")]
			),
		]
	)


static func extract_transform3d(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Transform3D: return r
	if r is Projection: return Transform3D(r as Projection)
	return null


static func part_hint_transform3d(p_name: String, p_desc: String = "") -> ConstructorDef.PartHint:
	return (ConstructorDef.PartHint
		.new(p_name, "<Transform3D>", p_desc)
		.accepts([TYPE_TRANSFORM3D, TYPE_PROJECTION]))
