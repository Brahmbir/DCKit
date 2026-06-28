# command_definition.gd
# Immutable-ish record for one registered command.
# Executor reads handler only. HintProvider reads everything except handler.
#
# Arg resolution
#
#   All commands are lazy by default. The executor never pre-resolves arguments.
#   Every handler pulls arguments on demand via ctx.arg(n) or ctx.get_all_args().
#   This means control flow commands (if, try, loop) work the same way as any
#   other command — there is no special declaration needed.

class_name DCDefinition
extends RefCounted

const BbCodeUtils = preload("../bb_code_utils.gd")

var name        : String         # exact case as registered — key in registry
var description : String         # BBCode; shown in info panel — supports full formatting
var handler     : Callable       # (ctx: DevConsoleCommandContext) -> DevConsoleResult
var params      : Array[DCParam] # ordered, matches handler's expected args
var locked      : bool           # true = unregister denied; changeable via registry


func _init(
		p_name        : String,
		p_handler     : Callable,
		p_description : String         = "",
		p_params      : Array[DCParam] = [],
		p_locked      : bool           = false) -> void:
	name        = p_name
	handler     = p_handler
	description = BbCodeUtils.close_bbcode(p_description)
	params      = p_params
	locked      = p_locked

var aliases: PackedStringArray = []

var deprecated := false
var deprecated_message := ""

enum LogMode {
	NORMAL,
	HIDDEN_SUCCESS,
	HIDDEN_ALL
}

var log_mode := LogMode.NORMAL ## while not log ok result only

func alias(name: String) -> DCDefinition:
	if not aliases.has(name):
		aliases.append(name)
	return self


func alias_many(names: PackedStringArray) -> DCDefinition:
	for name in names:
		if not aliases.has(name):
			aliases.append(name)
	return self


func deprecate(message: String = "") -> DCDefinition:
	deprecated = true
	deprecated_message = message
	return self


func as_utility() -> DCDefinition:
	log_mode = LogMode.HIDDEN_SUCCESS
	return self
