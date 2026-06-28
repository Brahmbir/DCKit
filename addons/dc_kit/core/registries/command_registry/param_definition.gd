# param_definition.gd
# One parameter slot on a command. Purely descriptive — validation is the handler's job.
class_name DCParam
extends RefCounted

const BbCodeUtils = preload("../bb_code_utils.gd")

# Display label shown in the info panel param list.
var name        : String

# Optional BBCode description shown in the info panel below the param name.
# Leave empty when the param is self-explanatory from the command description (BBcode).
var description : String

# () -> Array[String]  |  null = no suggestions but never Signal.
# Called live by HintProvider on every keystroke. Keep it fast.
var suggestor : Callable

# If true, this parameter consumes all remaining tokens.
var is_rest := false

func _init(p_name: String, p_suggestor := Callable()) -> void:
	name      = p_name
	suggestor = p_suggestor


# Fluent setters — allow chaining in registration calls:
#   DCParam.new("zone").describe("Target zone name.").suggest(fn)

func describe(text: String) -> DCParam:
	description = BbCodeUtils.close_bbcode(text)
	return self

func suggest(source: Variant) -> DCParam:
	if source is Callable:
		suggestor = source
	elif source is Array:
		var values : Array[String] = []
		for v in source:
			values.append(str(v))

		suggestor = func() -> Array[String]:
			return values.duplicate()
	else:
		push_error("suggest() expects either Array[String] or Callable.")
	return self

func rest() -> DCParam:
	is_rest = true
	return self
