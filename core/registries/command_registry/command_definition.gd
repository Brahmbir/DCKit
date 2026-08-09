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

## Exact case as registered — key in registry.
var name: String
## BBCode; shown in info panel — supports full formatting.
var description: String
## (ctx: DevConsoleCommandContext) -> DevConsoleResult
var handler: Callable
## Ordered, matches handler's expected args.
var params: Array[Param]
## True = unregister denied; changeable via registry.
var locked: bool

var aliases: PackedStringArray:
	get:
		return _aliases
	set(_value):
		printerr("sliases are read-only")
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


func _init(
	p_name: String,
	p_handler: Callable,
	p_description: String = "",
	p_params: Array[Param] = [],
	p_locked: bool = false,
) -> void:
	name = p_name
	handler = p_handler
	description = BbCodeUtils.close_bbcode(p_description)
	params = p_params
	locked = p_locked


## Adds a single alias, if not already present.
func alias(name: String) -> DCDefinition:
	if not _aliases.has(name):
		_aliases.append(name)
	return self


## Adds multiple aliases at once, skipping duplicates.
func alias_many(names: PackedStringArray) -> DCDefinition:
	for name in names:
		if not _aliases.has(name):
			_aliases.append(name)
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
class Param extends RefCounted:
	## Display label shown in the info panel param list.
	var name: String
	## Optional BBCode description shown in the info panel below the param name.
	## Leave empty when the param is self-explanatory from the command description (BBCode).
	var description: String
	## () -> Array[String]  |  null = no suggestions but never Signal.
	## Called live by HintProvider on every keystroke. Keep it fast.
	var suggestor: Callable
	## If true, this parameter consumes all remaining tokens.
	var is_rest := false


	func _init(p_name: String, p_suggestor := Callable()) -> void:
		name = p_name
		suggestor = p_suggestor


	## Sets the param's BBCode description.
	func describe(text: String) -> Param:
		description = BbCodeUtils.close_bbcode(text)
		return self


	## Sets the suggestor from either a Callable or a plain Array of values.
	func suggest(source: Variant) -> Param:
		if source is Callable:
			suggestor = source
		elif source is Array:
			var values: Array[String] = []
			for v in source:
				values.append(str(v))
			suggestor = func() -> Array[String]:
				return values.duplicate()
		else:
			push_error("suggest() expects either Array[String] or Callable.")
		return self


	## Marks this param as consuming all remaining tokens.
	func rest() -> Param:
		is_rest = true
		return self
