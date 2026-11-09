# inbuilt_base.gd
extends RefCounted


static func val_label(result: DCResult) -> String:
	if result.value == null:
		return "null"
	var value_str := var_to_str(result.value)

	if result.literal:
		return "%s (literal)" % value_str

	return value_str


# Signature helpers
# Zero-argument signature shared by almost every built-in type.
static func sig_zero(
	desc := "Zero / identity value"
) -> _DCKitNS.Registries.ConstructorDef.TypeSignature:
	return _DCKitNS.Registries.ConstructorDef.TypeSignature.new(desc, [])


# Part hint helpers
# Named-constant slot — suggestor returns const_names, validator rejects unknowns.
# Case-insensitive. Skips variable references ($...).
static func const_part(const_names: Array) -> _DCKitNS.Registries.ConstructorDef.PartHint:
	return (
		_DCKitNS
		.Registries
		.ConstructorDef
		.PartHint
		.new("name", "<const>", "One of: " + ", ".join(const_names))
		.validate(_DCKitNS.Registries.ConstructorDef.PartHint.enum_validator(const_names))
		.suggest(
			func(_prefix: String) -> Array:
				return const_names,
		)
		.accepts([TYPE_STRING])
	)
