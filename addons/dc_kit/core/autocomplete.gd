extends RefCounted

# Emitted by update() after storing fresh context — consumers (e.g. the
# completion popup) re-call get_completions() to pull the new list.
signal autocomplete_need_update

class CompletionItem:
	enum Kind { COMMAND, COMMAND_ALIAS, TYPE, VARIABLE, VALUE }

	var label  : String  # text to insert
	var kind   : int
	var detail : String = ""  # description, shown in the completion list

	func _init(p_label: String, p_kind: int, p_detail: String = "") -> void:
		label = p_label; kind = p_kind; detail = p_detail


var _cmd_reg
var _ctor_reg
var _var_store

# Most recent context — set via update(), consumed by get_completions().
var _result     = null  # DCAnalysisResult
var _input      := ""
var _cursor_pos := 0


func _init(cmd_reg, ctor_reg, var_store) -> void:
	_cmd_reg   = cmd_reg
	_ctor_reg  = ctor_reg
	_var_store = var_store


# Called by the view controller on every analysis/scope update.
# Stores context only — computation happens lazily in get_completions().
func update(result, input: String, cursor_pos: int) -> void:
	_result     = result
	_input      = input
	_cursor_pos = cursor_pos
	autocomplete_need_update.emit()


# Returns { start: int, items: Array[CompletionItem] } for the most recently
# stored context. `start` is where the chosen item's label should be spliced
# in — replace input[start:cursor_pos] with item.label.
func get_completions() -> Dictionary:
	if _result == null:
		return { start = _cursor_pos, items = [] }

	var scope: _DCKitNamespace.Analyzer.DCScope = _result.scope
	var prefix := _scan_prefix(_input, _cursor_pos)
	var start  := _cursor_pos - prefix.length()

	# Variables can appear in any arg/part slot — checked first, universally.
	if prefix.begins_with("$"):
		return { start = start, items = _variable_items(prefix) }

	var items : Array = []
	match scope.kind:
		_DCKitNamespace.Analyzer.DCScope.Kind.COMMAND:
			if scope.arg_index == -1:
				items = _command_items(prefix)
			else:
				items = _param_items(scope, prefix)
				items.append_array(_type_items(prefix))
		_DCKitNamespace.Analyzer.DCScope.Kind.CONSTRUCTOR:
			items = _part_items(scope, prefix)
			items.append_array(_type_items(prefix))

	return { start = start, items = items }


# SOURCES

func _command_items(prefix: String) -> Array:
	var out : Array = []
	for def in _cmd_reg.get_matching(prefix):
		out.append(CompletionItem.new(def.name, CompletionItem.Kind.COMMAND, def.description))
	# for alias
	for alias in _cmd_reg.get_alias_matches(prefix):
		out.append(CompletionItem.new(alias.alias, CompletionItem.Kind.COMMAND_ALIAS, alias.def.description))
	return out


func _type_items(prefix: String) -> Array:
	var out : Array = []
	for def in _ctor_reg.get_all():
		if def.name.begins_with(prefix):
			out.append(CompletionItem.new(def.name, CompletionItem.Kind.TYPE, def.description))
	return out


func _variable_items(prefix: String) -> Array:
	var rest  := prefix
	var sigil := ""
	if rest.begins_with("${"): sigil = "${"; rest = rest.substr(2)
	elif rest.begins_with("$"): sigil = "$";  rest = rest.substr(1)

	var silent := rest.begins_with("?")
	if silent: rest = rest.substr(1)

	var insert_prefix := sigil + ("?" if silent else "")
	var closing       := "}" if sigil == "${" else ""

	var out : Array = []
	for key in _var_store.get_keys():
		if key.begins_with(rest):
			out.append(CompletionItem.new(insert_prefix + key + closing, CompletionItem.Kind.VARIABLE))
	return out


func _param_items(scope, prefix: String) -> Array:
	var def = scope.get_active()
	if def == null or scope.arg_index >= def.params.size():
		return []
	var param : DCDefinition.Param = def.params[scope.arg_index]
	if not param.suggestor.is_valid():
		return []
	var out : Array = []
	
	var suggestions = _call_suggestor(param.suggestor, _prev_arg_values(scope), prefix)
	if suggestions is not Array:
		return out
	for s in suggestions:
		out.append(CompletionItem.new(s, CompletionItem.Kind.VALUE))
	return out


func _part_items(scope, prefix: String) -> Array:
	var def = scope.get_active()
	if def == null:
		return []

	var out  : Array      = []
	var seen : Dictionary = {}
	var prev : Array      = _prev_arg_values(scope)

	for sig : _DCKitNamespace.ConstructorDef.TypeSignature in def.signatures:
		if scope.part_index >= sig.parts.size():
			continue
		var part : _DCKitNamespace.ConstructorDef.PartHint = sig.parts[scope.part_index]
		if not part.suggestor.is_valid():
			continue
		#var suggestions = _call_suggestor(part.suggestor, prev, prefix)
		var suggestions = _call_suggestor(part.suggestor)
		
		if suggestions is not Array:
			continue
		for s in suggestions:
			if seen.has(s): continue
			seen[s] = true
			out.append(CompletionItem.new(str(s), CompletionItem.Kind.VALUE))

	return out

# HELPERS

func _prev_arg_values(scope: _DCKitNamespace.Analyzer.DCScope) -> Array:
	if _result == null or _result.ast.is_empty():
		return []
	match scope.kind:
		_DCKitNamespace.Analyzer.DCScope.Kind.COMMAND:
			for node in _result.ast:
				if "args" in node and "name" in node and node.name == scope.name:
					return _literal_values(node.args, scope.arg_index)
		# INFO it crash , so dont uncomment (i dont want to to it) 
		#_DCKitNamespace.Analyzer.DCScope.Kind.CONSTRUCTOR:
			#var ctor :_DCKitNamespace.ConstructorDef= _find_ctor(_result.ast, scope.type_name)
			#if ctor != null:
				#return _literal_values(ctor.parts, scope.part_index)
	return []


# Returns array of size `limit`: each entry is the string value of a literal
# node, or null for anything that requires runtime resolution.
func _literal_values(nodes: Array, limit: int) -> Array:
	var out: Array = []
	for i in min(limit, nodes.size()):
		var n = nodes[i]
		# CommandNode → has "args"; ConstructorNode → has "parts";
		# VariableNode → has "is_silent".  Anything else is a plain literal.
		if "args" in n or "parts" in n or "is_silent" in n:
			out.append(null)
		else:
			out.append(str(n.value) if "value" in n else null)
	return out


func _find_ctor(nodes: Array, type_name: String):
	for node in nodes:
		if "parts" in node and "type_name" in node and node.type_name == type_name:
			return node
		if "args"  in node:
			var r = _find_ctor(node.args,  type_name); if r != null: return r
		if "parts" in node:
			var r = _find_ctor(node.parts, type_name); if r != null: return r
	return null

# Scans backward from the cursor over identifier/variable-ish characters.
# Correct even when the cursor sits mid-word — only what's typed BEFORE
# the cursor is ever completed.
func _scan_prefix(input: String, cursor_pos: int) -> String:
	var start := cursor_pos
	while start > 0:
		if _is_prefix_char(input[start - 1]): start -= 1
		else: break
	return input.substr(start, cursor_pos - start)


func _is_prefix_char(c: String) -> bool:
	var n := c.unicode_at(0)
	return (n >= 65 and n <= 90) or (n >= 97 and n <= 122) or (n >= 48 and n <= 57) \
			or c in ["_", ".", "$", "?", "{"]

func _call_suggestor(suggestor: Callable, prev: Array=[], prefix: String=""):
	match suggestor.get_argument_count():
		0: return suggestor.call()
		1: return suggestor.call(prev)
		_: return suggestor.call(prev, prefix)
