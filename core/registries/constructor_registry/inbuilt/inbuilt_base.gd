# inbuilt_base.gd
extends RefCounted


static func val_label(val: DCResult.Value) -> String:
	if val.raw == null:
		return "null"
	var value_str := var_to_str(val.raw)

	match val.origin:
		DCResult.Value.Origin.LITERAL:
			return "%s (literal)" % value_str
		DCResult.Value.Origin.CONSTRUCTOR:
			return "%s (from constructor)" % value_str
		DCResult.Value.Origin.COMMAND:
			return "%s (from command)" % value_str

	return value_str


# Signature helpers
# Zero-argument signature shared by almost every built-in type.
static func sig_zero(
	desc := "Zero / identity value"
) -> _DCKitNamespace.ConstructorDef.TypeSignature:
	return _DCKitNamespace.ConstructorDef.TypeSignature.new(desc, [])


# Part hint helpers
# Named-constant slot — suggestor returns const_names, validator rejects unknowns.
# Case-insensitive. Skips variable references ($...).
static func const_part(const_names: Array) -> _DCKitNamespace.ConstructorDef.PartHint:
	return (
		_DCKitNamespace
		.ConstructorDef
		.PartHint
		.new("name", "<const>", "One of: " + ", ".join(const_names))
		.validate(_DCKitNamespace.ConstructorDef.PartHint.enum_validator(const_names))
		.suggest(
			func(_prefix: String) -> Array:
				return const_names,
		)
		.accepts([TYPE_STRING])
	)
