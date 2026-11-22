## Immutable-ish record for one registered command.
## Executor reads handler only. HintProvider reads everything except handler.
##
## [b]Arg resolution[/b]
##
## All commands are lazy by default. The executor never pre-resolves arguments.
## Every handler pulls arguments on demand via ctx.arg(n) or ctx.get_all_args().
## This means control flow commands (if, try, loop) work the same way as any
## other command — there is no special declaration needed.
class_name DCDefinition
extends RefCounted

enum LogMode {
	NORMAL,
	HIDDEN_SUCCESS,
	HIDDEN_ALL,
}

const BbCodeUtils = preload("../bb_code_utils.gd")
const PlainCommand = preload("./plain_command.gd")

## Exact case as registered — key in registry.
var name: String
## BBCode; shown in info panel — supports full formatting.
var description: String
## (ctx: DCContext) -> DCResult
var handler: Callable
## Ordered, matches handler's expected args.
var params: Array[Param]
## True = unregister denied; changeable via registry.
var locked: bool

var aliases: PackedStringArray:
	get:
		return _aliases
	set(_value):
		printerr("aliases are read-only")
var deprecated: bool:
	get:
		return _deprecated
	set(_value):
		printerr("deprecated is read-only")
var deprecated_message: String:
	get:
		return _deprecated_message
	set(_value):
		printerr("deprecated_message is read-only")

## While not log ok result only.
var log_mode := LogMode.NORMAL
var _aliases: PackedStringArray = []
var _deprecated := false
var _deprecated_message := ""


## Builds a definition from a plain function. See PlainCommand.
static func from_function(p_name: String, fn: Callable, p_description: String = "") -> DCDefinition:
	return PlainCommand.build(p_name, fn, p_description)


func _init(
	p_name: String,
	p_handler: Callable,
	p_description := "",
	p_params: Array = [],
	p_locked := false,
) -> void:
	name = p_name
	handler = p_handler
	description = BbCodeUtils.close_bbcode(p_description)
	for p in p_params:
		params.append(p if p is Param else Param.new(str(p)))
	locked = p_locked


## Adds a single alias, if not already present.
func alias(new_alias: String) -> DCDefinition:
	if not _aliases.has(new_alias):
		_aliases.append(new_alias)
	return self


## Adds multiple aliases at once, skipping duplicates.
func alias_many(new_alias_array: PackedStringArray) -> DCDefinition:
	for new_alias in new_alias_array:
		if not _aliases.has(new_alias):
			_aliases.append(new_alias)
	return self


func unalias(_alias: String) -> DCDefinition:
	var i := _aliases.find(_alias)
	if i >= 0:
		_aliases.remove_at(i)
	return self


func clear_aliases() -> DCDefinition:
	_aliases.clear()
	return self


## Marks this command as deprecated, with an optional message shown to users.
func deprecate(message: String = "") -> DCDefinition:
	_deprecated = true
	_deprecated_message = message
	return self


## Marks this command as a utility: only failures get logged.
func as_utility() -> DCDefinition:
	log_mode = LogMode.HIDDEN_SUCCESS
	return self


## One parameter slot on a command. Purely descriptive — validation is the handler's job.
const Spec := preload("../spec.gd")


class Param extends RefCounted:
	## Display label shown in the info panel param list.
	var name: String
	## Optional BBCode description shown in the info panel below the param name.
	## Leave empty when the param is self-explanatory from the command description (BBCode).
	var description: String
	## What this parameter is and what to offer for it — see Spec. Assign any shorthand
	## (Array, Callable, TYPE_*, Dictionary) to replace it; suggest() adds to it.
	var spec: Variant:
		get:
			return _spec
		set(value):
			_spec = Spec.normalize(value)
	var _spec: Dictionary = { }
	## If true, this parameter consumes all remaining tokens.
	var is_rest := false


	func _init(p_name: String, p_spec: Variant = null) -> void:
		name = p_name
		_spec = Spec.normalize(p_spec)

	## name → value. Input matching a key resolves to its value before type coercion.
	var choices: Dictionary = { }


	## Marks this param as an enum and suggests its keys.
	func enum_of(source: Dictionary) -> Param:
		choices = source
		return suggest(source.keys())


	## Sets the param's BBCode description.
	func describe(text: String) -> Param:
		description = BbCodeUtils.close_bbcode(text)
		return self


	## Adds to the spec. Array / Callable → suggestions, TYPE_* → type, Dictionary → a full spec.
	func suggest(source: Variant) -> Param:
		_spec = Spec.merge(_spec, Spec.normalize(source))
		return self


	## Marks this param as consuming all remaining tokens.
	func rest() -> Param:
		is_rest = true
		return self
