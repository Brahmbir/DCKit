# t_vector3.gd
# Built-in Vector3 constructor definition.
# Accessed via ConstructorRegistry; no class_name.
# 
# Supported forms:
# Vector3() → Vector3.ZERO
# Vector3(name) → named constant e.g. Vector3(UP)
# Vector3(x, y, z) → float components — any DCResult.Value origin
extends "./inbuilt_base.gd"

const DCFloat = preload("./t_float.gd")


static func create() ->  _DCKitNamespace.ConstructorDef:
	const CONSTS := {
	"ZERO": Vector3.ZERO,
	"ONE": Vector3.ONE,
	"INF": Vector3.INF,
	"LEFT": Vector3.LEFT,
	"RIGHT": Vector3.RIGHT,
	"UP": Vector3.UP,
	"DOWN": Vector3.DOWN,
	"FORWARD": Vector3.FORWARD,
	"BACK": Vector3.BACK,
	"MODEL_LEFT": Vector3.MODEL_LEFT,
	"MODEL_RIGHT": Vector3.MODEL_RIGHT,
	"MODEL_TOP": Vector3.MODEL_TOP,
	"MODEL_BOTTOM": Vector3.MODEL_BOTTOM,
	"MODEL_FRONT": Vector3.MODEL_FRONT,
	"MODEL_REAR": Vector3.MODEL_REAR,
	}
	var const_names : Array = CONSTS.keys()
	const_names.sort()
	
	var handler := func(parts: Array) -> Variant:
		# Zero-arg
		if parts.is_empty():
			return Vector3.ZERO
			
		# One arg — named constant only
		if parts.size() == 1:
			var val : DCResult.Value = parts[0]
			var vec := extract_vector3(val)
			if vec != null:
				return vec
				
			if val.origin == DCResult.Value.Origin.LITERAL:
				var key := (val.raw as String).to_upper().strip_edges()
				if key in CONSTS:
					return CONSTS[key]
					
			return DCResult.fail(
			"Vector3: expected a Vector3, Vector3i, or constant name (%s), got %s."
			% [", ".join(const_names), val_label(val)]
			)
			
		# Three args — XYZ components
		if parts.size() == 3:
			var labels := ["x", "y", "z"]
			var values : Array = []
			for i in 3:
				var f = DCFloat.extract(parts[i])
				
				if f == null:
					return DCResult.fail(
					"Vector3 part '%s': expected a number, got %s." 
					% [labels[i], val_label(parts[i])])
				
				values.append(f)
			return Vector3(values[0], values[1], values[2])
		
		return DCResult.fail(
			"Vector3: expected 0, 1, or 3 parts — got %d." % parts.size())
			
	return  _DCKitNamespace.ConstructorDef.new(
		"Vector3",
		handler,
		"A 3D vector with [b]x[/b], [b]y[/b], and [b]z[/b] float components.",
		[
			sig_zero("Zero vector — Vector3(0, 0, 0)"),
			
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Named constant",
				[const_part(const_names)]),
				
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"Convert Vector3/Vector3i",
				[part_hint_vector3("value","Existing Vector3 or Vector3i")]),
			
			 _DCKitNamespace.ConstructorDef.TypeSignature.new(
				"XYZ components",
				[
					DCFloat.part_hint("x", "Right (+), left (−)"),
					DCFloat.part_hint("y", "Up (+), down (−)"),
					DCFloat.part_hint("z", "Back (+), forward (−)"),
				]
			),
		]
	)


static func extract_vector3(val: DCResult.Value) -> Variant:
	var r := val.raw
	if r is Vector3: return r
	if r is Vector3i: return Vector3(r)
	return null


static func part_hint_vector3(p_name: String, p_desc: String = "") ->  _DCKitNamespace.ConstructorDef.PartHint:
	return ( _DCKitNamespace.ConstructorDef.PartHint
	.new(p_name, "<Vector3>", p_desc)
	.accepts([TYPE_VECTOR3, TYPE_VECTOR3I]))
