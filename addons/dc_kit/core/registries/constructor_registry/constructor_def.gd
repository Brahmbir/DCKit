# dc_constructor_def.gd
# Immutable record for one registered constructor type.
# Analogous to DCDefinition for commands.
#
# The executor reads only `handler`.
# The hint provider reads `description`, `signatures`, and `is_builtin`.
# Neither field is writable after construction.
extends RefCounted

const BbCodeUtils = preload("../bb_code_utils.gd")

var name        : String    # Exact type name as registered   e.g. "Vector3"
var description : String    # BBCode — shown in info panel header
var signatures  : Array     # Array[DCTypeSignature] — all valid calling forms
var handler     : Callable  # (parts: Array) -> Variant | DevConsoleResult
							# Must return DevConsoleResult.fail() on error, not null
var is_builtin  : bool      # True = sealed by the registry; cannot be replaced


func _init(
		p_name        : String,
		p_handler     : Callable,
		p_description : String = "",
		p_signatures  : Array  = [],
		p_is_builtin  : bool   = false) -> void:
	name        = p_name
	handler     = p_handler
	description = BbCodeUtils.close_bbcode(p_description)
	signatures  = p_signatures
	is_builtin  = p_is_builtin


func _to_string() -> String:
	return "ConstructorDef(%s)[%d sigs, builtin=%s]" \
		% [name, signatures.size(), is_builtin]

#region TypeSignature inner class
# One valid calling convention for a constructor type.
# A type can have multiple signatures — e.g. Vector3 has three:
#   Vector3()          zero-argument form
#   Vector3(name)      named constant
#   Vector3(x, y, z)  component form
#
# Analogous to an Overload on a command definition.

class TypeSignature extends RefCounted:

	var description : String          # Short label  e.g. "XYZ components"
	var parts       : Array           # Array[DCPartHint]


	func _init(p_desc: String, p_parts: Array = []) -> void:
		description = BbCodeUtils.close_bbcode(p_desc)
		parts       = p_parts


	# Builds the usage string shown in the info panel.
	# e.g.  "Vector3(x, y, z)"   "Color()"   "Vector3(name)"
	func usage(type_name: String) -> String:
		if parts.is_empty():
			return "%s()" % type_name
		var labels := parts.map(func(p: PartHint): return p.name)
		return "%s(%s)" % [type_name, ", ".join(labels)]


	# True when this signature could match the given committed part count.
	# Used by HintProvider to decide which signatures remain viable.
	func matches_count(count: int) -> bool:
		return count <= parts.size()


	func _to_string() -> String:
		return "Signature(%s)[%d parts]" % [description, parts.size()]

#endregion



#region Part inner class
# Describes one slot inside a constructor signature.
# Analogous to DCParam, but for constructor parts instead of command arguments.
#
# accepted_types
#
#   An optional Array[int] of Godot TYPE_* constants (see @GlobalScope).
#   Used ONLY by the hint provider to warn the user while they are typing.
#   The executor never reads this field — the constructor handler is always
#   responsible for validating what it receives at runtime.
#
#   Empty array (default) = accept anything — hint system shows no type warning.
#
#   Example:
#     PartHint.new("x", "<float>").accepts([TYPE_INT, TYPE_FLOAT, TYPE_STRING])
#
#   Common constants:
#     TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
#     TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_RECT2, …
#     (full list in Godot docs: @GlobalScope.Variant.Type)
#
# validator vs accepted_types
#
#   validator      — called when the user is typing a LITERAL string value.
#                    Receives the raw string, returns "" (ok) or error message.
#                    Used for range checks, enum membership, format checks.
#
#   accepted_types — checked when the slot receives a non-literal value
#                    (from a nested constructor or command).
#                    Purely advisory for the hint UI — not enforced at runtime.
#
# Usage:
#   PartHint.new("x", "<float>", "World-space X component")
#   PartHint.new("name", "<const>", "Named constant").suggest(fn).validate(fn)
#   PartHint.new("pos", "<Vector2>").accepts([TYPE_VECTOR2, TYPE_STRING])

class PartHint extends RefCounted:


	var name           : String    # Slot label shown in the info panel   e.g. "x"
	var type_hint      : String    # Type label                           e.g. "<float>"
	var description    : String    # BBCode — shown below the slot label
	var validator      : Callable  # (value: String) -> String   empty string = valid
	var suggestor      : Callable  # (prefix: String) -> Array[String]
	var accepted_types : Array     # Array[int] TYPE_* constants — hint system only, never enforced


	func _init(
			p_name      : String,
			p_type_hint : String = "",
			p_desc      : String = "") -> void:
		name        = p_name
		type_hint   = p_type_hint
		description = BbCodeUtils.close_bbcode(p_desc)


	# Fluent builders

	func describe(text: String) -> PartHint:
		description = BbCodeUtils.close_bbcode(text)
		return self

	func validate(fn: Callable) -> PartHint:
		validator = fn
		return self

	func suggest(fn: Callable) -> PartHint:
		suggestor = fn
		return self

	# Sets the accepted Godot TYPE_* constants for the hint system.
	# Has NO effect on executor behaviour — purely advisory.
	# Pass multiple types when the slot can meaningfully receive more than one:
	#   .accepts([TYPE_FLOAT, TYPE_STRING])
	func accepts(types: Array) -> PartHint:
		accepted_types = types
		return self

	#region Hint helpers

	# Returns true when the given Godot type constant is in accepted_types.
	# Always returns true when accepted_types is empty (= accept anything).
	# Used by the hint provider — not the executor.
	func hints_accepts_type(godot_type: int) -> bool:
		if accepted_types.is_empty():
			return true
		return godot_type in accepted_types

	# Human-readable label for the accepted types — shown in the info panel
	# when the user passes a non-literal value into this slot.
	# Returns "" when accepted_types is empty.
	func accepted_types_label() -> String:
		if accepted_types.is_empty():
			return ""
		var names : Array = accepted_types.map(func(t: int) -> String:
			return type_string(t))
		return ", ".join(names)


	# Built-in validators (static helpers for convenience)
	#
	# These are for LITERAL string validation only (user typing).
	# They skip variable references ($...) because those are resolved later.

	# Accepts any valid float string.
	static func float_validator() -> Callable:
		return func(value: String) -> String:
			if value.is_empty() or value.begins_with("$"):
				return ""
			if value.is_valid_float():
				return ""
			return "'%s' is not a number." % value


	# Accepts only values present in `options` (case-insensitive).
	static func enum_validator(options: Array) -> Callable:
		var upper := options.map(func(s): return (s as String).to_upper())
		return func(value: String) -> String:
			if value.is_empty() or value.begins_with("$"):
				return ""
			if value.to_upper() in upper:
				return ""
			return "'%s' is not valid. Expected one of: %s." % [
				value, ", ".join(options)]


	# Accepts floats in the 0.0–1.0 range.
	static func unit_float_validator() -> Callable:
		return func(value: String) -> String:
			if value.is_empty() or value.begins_with("$"):
				return ""
			if not value.is_valid_float():
				return "'%s' is not a number." % value
			var f := float(value)
			if f < 0.0 or f > 1.0:
				return "%s is out of range — must be 0.0 to 1.0." % value
			return ""
	#endregion
#endregion
