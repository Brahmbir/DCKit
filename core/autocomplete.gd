extends RefCounted

# Emitted by update() after storing fresh context — consumers (e.g. the
# completion popup) re-call get_completions() to pull the new list.
signal autocomplete_need_update

const Nodes := _DCKitNS.Analyzer.Nodes
const TT := _DCKitNS.Analyzer.Token.Type
const ScopeKind := DCAnalysisResult.Scope.Kind

const MAX_ITEMS := 100
const CACHE_LIMIT := 64

enum Mode { NONE, BARE, VARIABLE, STRING, TEMPLATE }

var _cmd_reg
var _ctor_reg
var _var_store

# Most recent context — set via update(), consumed by get_completions().
var _result = null # DCAnalysisResult
var _input := ""
var _cursor_pos := 0

# Candidate lists of 0-argument providers, per slot.
var _cache := { }


func _init(cmd_reg, ctor_reg, var_store) -> void:
	_cmd_reg = cmd_reg
	_ctor_reg = ctor_reg
	_var_store = var_store


## (a variable set, a command run, the console opened).
func invalidate() -> void:
	_cache.clear()


# Called by the view controller on every analysis/scope update.
# Stores context only — computation happens lazily in get_completions().
func update(result, input: String, cursor_pos: int) -> void:
	if result == _result and input == _input and cursor_pos == _cursor_pos:
		return
	_result = result
	_input = input
	_cursor_pos = cursor_pos
	autocomplete_need_update.emit()


# Returns { start: int, items: Array[CompletionItem] } for the most recently
# stored context. `start` is where the chosen item should be spliced in —
# replace input[start:cursor_pos] with item.insert.
func get_completions() -> Dictionary:
	var cur := clampi(_cursor_pos, 0, _input.length())
	if _result == null:
		return { start = cur, items = [] }

	var scope: DCAnalysisResult.Scope = _result.scope
	var loc := _locate(_result.tokens, cur)
	loc.in_dict = scope.kind == ScopeKind.DICT_KEY or scope.kind == ScopeKind.DICT_VALUE

	# Variables can appear in any slot — decided by what is typed, not by the scope.
	if loc.mode == Mode.VARIABLE:
		return { start = loc.start, items = _variable_items(loc, cur) }

	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	var items: Array = []
	match scope.kind:
		ScopeKind.COMMAND:
			if scope.arg_index == -1:
				if not in_text:
					items = _command_items(loc.prefix)
			else:
				items = _param_items(scope, loc)
				if not in_text:
					items.append_array(_type_items(loc.prefix))
		ScopeKind.CONSTRUCTOR:
			items = _part_items(scope, loc)
			if not in_text:
				items.append_array(_type_items(loc.prefix))
		ScopeKind.ARRAY_ITEM, ScopeKind.DICT_KEY, ScopeKind.DICT_VALUE:
			items = _collection_items(scope, loc, cur)
	return { start = loc.start, items = _unique(items) }


#region WHAT IS UNDER THE CURSOR
# { start, prefix, suffix, mode }: the text typed before the cursor in the token it touches.
# Everything comes from the token list, so strings, paths and variables need no character scanning.
func _locate(tokens: Array, cur: int) -> Dictionary:
	var out := { start = cur, prefix = "", suffix = "", mode = Mode.NONE, in_dict = false }
	var i := -1
	for k in tokens.size():
		if tokens[k].start < cur:
			i = k
		else:
			break
	if i < 0:
		return out
	var t = tokens[i]
	if cur > t.end:
		return out

	var limit: int = t.end
	match t.type:
		TT.WORD, TT.NUMBER:
			out.start = t.start
			out.mode = Mode.BARE
		TT.NAME:
			var s: int = t.start
			if i >= 2 and tokens[i - 1].type == TT.LBRACE and tokens[i - 2].type == TT.DOLLAR:
				s = tokens[i - 2].start
			elif i >= 1 and tokens[i - 1].type == TT.DOLLAR:
				s = tokens[i - 1].start
			out.start = s
			out.mode = Mode.VARIABLE
		TT.DOLLAR:
			out.start = t.start
			out.mode = Mode.VARIABLE
		TT.LBRACE:
			if i >= 1 and tokens[i - 1].type == TT.DOLLAR:
				out.start = tokens[i - 1].start
				out.mode = Mode.VARIABLE
		TT.TEXT:
			out.start = t.start
			out.mode = Mode.TEMPLATE
		TT.QUOTE_OPEN:
			out.mode = Mode.TEMPLATE
		TT.STRING:
			var closed: bool = t.end - t.start >= 2 and _input[t.end - 1] == _input[t.start]
			if cur > t.start and not (closed and cur == t.end):
				out.start = t.start + 1
				out.mode = Mode.STRING
				limit = t.end - 1 if closed else t.end
	out.prefix = _input.substr(out.start, cur - out.start)
	if out.mode != Mode.NONE and limit > cur:
		out.suffix = _input.substr(cur, limit - cur)
	return out
#endregion


#region SOURCES
func _command_items(prefix: String) -> Array:
	var out: Array = []
	for def in _cmd_reg.get_matching(prefix):
		out.append(CompletionItem.new(def.name, CompletionItem.Kind.COMMAND, def.description))
	for alias in _cmd_reg.get_alias_matches(prefix):
		out.append(CompletionItem.new(alias.alias, CompletionItem.Kind.COMMAND_ALIAS, alias.def.description))
	return out


func _type_items(prefix: String) -> Array:
	var out: Array = []
	var p := prefix.to_lower()
	for def in _ctor_reg.get_all():
		if def.name.to_lower().begins_with(p):
			out.append(CompletionItem.new(def.name, CompletionItem.Kind.TYPE, def.description))
	return out


# $name  ${name}  — the closing brace is only added when none follows the cursor.
func _variable_items(loc: Dictionary, cur: int) -> Array:
	var braced: bool = loc.prefix.begins_with("${")
	var rest: String = loc.prefix.substr(2 if braced else 1).lstrip(" \t")
	var close := "}" if braced and _input.substr(cur, 1) != "}" else ""
	var sigil := "${" if braced else "$"
	var names := { }
	for key in _var_store.get_keys():
		names[str(key)] = ""
	var out: Array = []
	for key in _rank(names, rest):
		var text: String = sigil + key + close
		out.append(CompletionItem.new(text, CompletionItem.Kind.VARIABLE))
	return out


func _param_items(scope, loc: Dictionary) -> Array:
	var def = scope.get_active()
	if def == null or def.params.is_empty():
		return []
	var idx: int = scope.arg_index
	if idx >= def.params.size():
		if not def.params.back().is_rest:
			return []
		idx = def.params.size() - 1 # a rest parameter owns every later argument
	var param = def.params[idx]
	return _provided(param.suggestor, loc, _context(scope, loc), "p:%s:%d" % [def.name, idx], CompletionItem.Kind.VALUE)


func _part_items(scope, loc: Dictionary) -> Array:
	var def = scope.get_active()
	if def == null:
		return []
	var out: Array = []
	var ctx := _context(scope, loc)
	for n in def.signatures.size():
		var sig = def.signatures[n]
		if scope.part_index >= sig.parts.size():
			continue
		var part = sig.parts[scope.part_index]
		out.append_array(
			_provided(part.suggestor, loc, ctx, "c:%s:%d:%d" % [def.name, n, scope.part_index], CompletionItem.Kind.VALUE),
		)
	return out
#endregion


#region PROVIDERS
## A suggestion provider is a Callable that returns an Array of strings or a Dictionary { value: description }.
##   func()                 candidates, computed once per slot and ranked here
##   func(prefix)           live: called on every change, its order is final
##   func(prefix, context)  live, with suffix / previous arguments / collection path
func _provided(provider: Callable, loc: Dictionary, ctx: SuggestContext, slot: String, kind: int) -> Array:
	if not provider.is_valid():
		return []
	var arity := provider.get_argument_count()
	var names: Array
	var details: Dictionary
	if arity == 0:
		var key := "%s|%s|%s" % [slot, ctx.args, ctx.path]
		if not _cache.has(key):
			if _cache.size() >= CACHE_LIMIT:
				_cache.clear()
			_cache[key] = _normalize(provider.call())
		details = _cache[key]
		names = _rank(details, loc.prefix)
	else:
		details = _normalize(provider.call(loc.prefix) if arity == 1 else provider.call(loc.prefix, ctx))
		names = details.keys()
	var out: Array = []
	for label in names:
		out.append(CompletionItem.new(label, kind, details[label], _value_insert(label, loc)))
	return out


func _normalize(raw) -> Dictionary:
	var out := { }
	if raw is Dictionary:
		for k in raw:
			out[str(k)] = raw[k] if raw[k] is String else ""
	elif raw is Array or raw is PackedStringArray:
		for v in raw:
			out[str(v)] = ""
	return out


# Prefix first (exact case, then any case), then substring, then subsequence. Provider order is the tie-break.
func _rank(cands: Dictionary, prefix: String) -> Array:
	if prefix.is_empty():
		return cands.keys()
	var p := prefix.to_lower()
	var b0: Array = []
	var b1: Array = []
	var b2: Array = []
	var b3: Array = []
	for label in cands:
		var l: String = label.to_lower()
		if label.begins_with(prefix):
			b0.append(label)
		elif l.begins_with(p):
			b1.append(label)
		elif l.contains(p):
			b2.append(label)
		elif p.length() >= 3 and _subsequence(p, l): # fuzzy only once the prefix is long enough not to match everything
			b3.append(label)
	return b0 + b1 + b2 + b3


func _subsequence(needle: String, hay: String) -> bool:
	var j := 0
	for i in hay.length():
		if j < needle.length() and hay[i] == needle[j]:
			j += 1
	return j == needle.length()


func _context(scope, loc: Dictionary) -> SuggestContext:
	var ctx := SuggestContext.new()
	ctx.suffix = loc.suffix
	var owner = scope if scope.owner == null else scope.owner
	ctx.args = _prev_values(owner)
	ctx.path = scope.path
	ctx.key = scope.key
	return ctx


# Literal values of the arguments / parts before the slot (null for anything resolved at run time).
func _prev_values(scope) -> Array:
	var n = scope.node
	if n == null:
		return []
	var nodes: Array = []
	var limit := 0
	if scope.kind == ScopeKind.COMMAND:
		nodes = n.args
		limit = scope.arg_index
	elif scope.kind == ScopeKind.CONSTRUCTOR:
		nodes = n.parts
		limit = scope.part_index
	var out: Array = []
	for i in mini(limit, nodes.size()):
		out.append(nodes[i].value if nodes[i] is Nodes.StringNode else null)
	return out
#endregion


#region COLLECTIONS
# Shapes are plain data on a parameter / part hint (an optional `shape` property):
#   [T] array of T   { key: T, "opt?": T, "*": T } dictionary   TYPE_* constant   TYPE_NIL any
func _collection_items(scope, loc: Dictionary, cur: int) -> Array:
	var shape = _shape_of(scope)
	match scope.kind:
		ScopeKind.ARRAY_ITEM:
			return _value_items(shape[0] if shape is Array and shape.size() == 1 else null, loc)
		ScopeKind.DICT_VALUE:
			return _value_items(_field_shape(shape, scope.key), loc)
		_:
			return _key_items(shape, scope, loc, cur)


func _key_items(shape, scope, loc: Dictionary, cur: int) -> Array:
	if not shape is Dictionary:
		return []
	var cands := { }
	var optional := { }
	for k in shape:
		var key: String = str(k)
		if key == "*":
			continue
		var is_opt := key.ends_with("?")
		var name := key.trim_suffix("?")
		if scope.used_keys.has(name):
			continue
		var t = shape[k]
		var type_text: String = type_string(t) if t is int and t != TYPE_NIL else ""
		var detail := "%s%s" % ["optional" if is_opt else "required", (" · " + type_text) if not type_text.is_empty() else ""]
		(optional if is_opt else cands)[name] = detail
	cands.merge(optional) # required keys first
	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	var out: Array = []
	for name in _rank(cands, loc.prefix):
		var insert: String = _value_insert(name, loc)
		if not in_text and not _colon_follows(cur):
			insert += ": "
		out.append(CompletionItem.new(name, CompletionItem.Kind.KEY, cands[name], insert))
	return out


func _colon_follows(cur: int) -> bool:
	var j := cur
	while j < _input.length() and (_input[j] == " " or _input[j] == "\t"):
		j += 1
	return j < _input.length() and _input[j] == ":"


func _value_items(shape, loc: Dictionary) -> Array:
	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	if shape is int and shape == TYPE_BOOL:
		var out: Array = []
		for label in _rank({ "true": "", "false": "" }, loc.prefix):
			out.append(CompletionItem.new(label, CompletionItem.Kind.VALUE, "", _value_insert(label, loc)))
		return out
	if in_text or shape is Array or shape is Dictionary:
		return []
	if shape is int and shape != TYPE_NIL:
		var wanted := type_string(shape)
		return _type_items(loc.prefix).filter(func(i): return i.label == wanted)
	return _type_items(loc.prefix)


func _shape_of(scope):
	var shape = _slot_shape(scope.owner)
	for step in scope.path:
		if shape == null:
			return null
		if step is int:
			shape = shape[0] if shape is Array and shape.size() == 1 else null
		else:
			shape = _field_shape(shape, step)
	return shape


func _slot_shape(owner):
	if owner == null:
		return null
	var def = owner.get_active()
	if def == null:
		return null
	if owner.kind == ScopeKind.COMMAND:
		if def.params.is_empty():
			return null
		var idx: int = mini(owner.arg_index, def.params.size() - 1)
		return def.params[idx].get("shape")
	for sig in def.signatures:
		if owner.part_index < sig.parts.size():
			var s = sig.parts[owner.part_index].get("shape")
			if s != null:
				return s
	return null


func _field_shape(shape, key: String):
	if not shape is Dictionary:
		return null
	if shape.has(key):
		return shape[key]
	if shape.has(key + "?"):
		return shape[key + "?"]
	return shape.get("*")
#endregion


#region INSERT TEXT
# What gets spliced in for a value: quoted when a bare word would split or change meaning,
# escaped when the cursor is already inside a string.
func _value_insert(text: String, loc: Dictionary) -> String:
	match loc.mode:
		Mode.STRING:
			return text.replace("\\", "\\\\").replace("'", "\\'")
		Mode.TEMPLATE:
			return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("${", "\\${")
	return text if _is_bare(text, loc.in_dict) else "'" + text.replace("\\", "\\\\").replace("'", "\\'") + "'"


func _is_bare(text: String, in_dict: bool) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		if c <= 32 or c in [34, 35, 36, 39, 40, 41, 44, 59, 91, 93, 96, 123, 125] or (in_dict and c == 58):
			return false
	return true


func _unique(items: Array) -> Array:
	var seen := { }
	var out: Array = []
	for item in items:
		if seen.has(item.label):
			continue
		seen[item.label] = true
		out.append(item)
		if out.size() >= MAX_ITEMS:
			break
	return out
#endregion


## Passed as the second argument of a live provider.
class SuggestContext:
	var suffix := "" # text of the token after the cursor
	var args: Array = [] # literal values of the previous arguments / parts (null = not a literal)
	var path: Array = [] # inside [] / {}: indexes and keys leading to the collection
	var key := "" # inside {}: the key of the entry being edited


class CompletionItem:
	enum Kind {
		COMMAND,
		COMMAND_ALIAS,
		TYPE,
		VARIABLE,
		VALUE,
		KEY,
	}

	var label: String # shown in the list
	var kind: int
	var detail: String = "" # description, shown in the completion list
	var insert: String # spliced in place of input[start:cursor]


	func _init(p_label: String, p_kind: int, p_detail: String = "", p_insert: String = "") -> void:
		label = p_label
		kind = p_kind
		detail = p_detail
		insert = p_insert if not p_insert.is_empty() else p_label
