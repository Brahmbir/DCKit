extends RefCounted

# Emitted by update() after storing fresh context — consumers (e.g. the
# completion popup) re-call get_completions() to pull the new list.
signal autocomplete_need_update

enum Mode {
	NONE,
	BARE,
	VARIABLE,
	STRING,
	TEMPLATE,
}

const Spec := preload("./registries/spec.gd")
const Nodes := _DCKitNS.Analyzer.Nodes
const TT := _DCKitNS.Analyzer.Token.Type
const ScopeKind := DCAnalysisResult.Scope.Kind

const MAX_ITEMS := 100
const CACHE_LIMIT := 64

var _cmd_reg
var _ctor_reg
var _var_store

# Most recent context — set via update(), consumed by get_completions().
var _result = null # DCAnalysisResult
var _input := ""
var _cursor_pos := 0

# Candidate lists of 0-argument providers. Valid while the cursor stays in one slot:
# moving to another argument / item / key (or back) recomputes them.
var _cache := { }
var _slot_id := ""


func _init(cmd_reg, ctor_reg, var_store) -> void:
	_cmd_reg = cmd_reg
	_ctor_reg = ctor_reg
	_var_store = var_store


## Drops cached candidate lists (a slot change already does).
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
	var slot_id := str(
		[
			scope.kind,
			scope.name,
			scope.type_name,
			scope.arg_index,
			scope.part_index,
			scope.index,
			scope.key,
			scope.path,
		]
	)
	if slot_id != _slot_id:
		_slot_id = slot_id
		_cache.clear()
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
				if not in_text and _slot_spec(scope).is_empty():
					items.append_array(_type_items(loc.prefix))
		ScopeKind.CONSTRUCTOR:
			items = _part_items(scope, loc)
			if not in_text and _slot_spec(scope).is_empty():
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
		out.append(
			CompletionItem.new(
				alias.alias,
				CompletionItem.Kind.COMMAND_ALIAS,
				alias.def.description,
			)
		)
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
	return _spec_items(
		def.params[idx].spec,
		loc,
		"arg",
		scope.arg_index,
		"p:%s:%d" % [def.name, idx],
	)


func _part_items(scope, loc: Dictionary) -> Array:
	var def = scope.get_active()
	if def == null:
		return []
	var out: Array = []
	for n in def.signatures.size():
		var sig = def.signatures[n]
		if scope.part_index < sig.parts.size():
			out.append_array(
				_spec_items(
					sig.parts[scope.part_index].spec,
					loc,
					"arg",
					scope.part_index,
					"c:%s:%d:%d" % [def.name, n, scope.part_index],
				)
			)
	return out


#region PROVIDERS
# What a spec offers for one value: its `suggest`, else what its type implies (bool, constructor types).
func _spec_items(
	spec: Dictionary,
	loc: Dictionary,
	kind: String,
	position,
	slot: String,
	exclude: Array = [],
) -> Array:
	if spec.has("suggest"):
		return _suggested(spec["suggest"], loc, kind, position, slot, exclude)
	if spec.has("choices"): # an enum offers its names
		return _suggested(spec["choices"].keys(), loc, kind, position, slot, exclude)
	return _typed_items(spec.get("type"), loc)


## `suggest` is an Array of strings, a Dictionary { value: description }, or a Callable returning either:
##   func()                 candidates, computed once while the cursor stays in the slot and ranked here
##   func(prefix)           live: called on every change, its order is final
##   func(prefix, context)  live, with suffix / previous arguments / siblings / collection path
func _suggested(
	source,
	loc: Dictionary,
	kind: String,
	position,
	slot: String,
	exclude: Array,
) -> Array:
	if source is Callable:
		if not source.is_valid():
			return []
	elif not (source is Array or source is Dictionary):
		return []

	# Once per slot: a static list is normalised, a main callback is called with (kind, position).
	var key := "%s|%s|%s" % [slot, kind, position]
	if not _cache.has(key) or not is_same(_cache[key][0], source): # a redefined parameter is picked up
		if _cache.size() >= CACHE_LIMIT:
			_cache.clear()
		var made = _call(source, [kind, position]) if source is Callable else source
		_cache[key] = [source, made if made is Callable else _normalize(made)]
	var cached = _cache[key][1]

	var names: Array
	var details: Dictionary
	if cached is Callable: # a live callback: every change, its result is shown as it is
		details = _normalize(_call(cached, [loc.prefix, loc.suffix]))
		names = details.keys()
	else:
		details = cached
		names = _rank(details, loc.prefix)
	var out: Array = []
	for label in names:
		if exclude.has(label):
			continue
		out.append(
			CompletionItem.new(
				label,
				CompletionItem.Kind.VALUE,
				details[label],
				_value_insert(label, loc),
			)
		)
	return out


# Passes only as many arguments as the callback declares.
func _call(fn: Callable, args: Array):
	return fn.callv(args.slice(0, mini(fn.get_argument_count(), args.size())))


func _normalize(raw) -> Dictionary:
	var out := { }
	if raw is Dictionary: # { value: description }
		for k in raw:
			out[str(k)] = raw[k] if raw[k] is String else ""
	elif raw is Array or raw is PackedStringArray: # values, or { value, desc } items
		for v in raw:
			if v is Dictionary:
				if v.has("value"):
					out[str(v["value"])] = str(v.get("desc", ""))
				else:
					push_warning("A suggestion item needs a 'value' key.")
			else:
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
		elif p.length() >= 2 and l.contains(p): # one character would match almost everything
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


# Literal values of the arguments / parts before the slot (null for anything resolved at run time).
#region COLLECTIONS
# The spec of the collection under the cursor is found by walking the parameter's spec along scope.path.
# A suggestion on an array spec applies to its items; `unique` hides values the array already holds.
func _collection_items(scope, loc: Dictionary, cur: int) -> Array:
	var spec := _collection_spec(scope)
	match scope.kind:
		ScopeKind.ARRAY_ITEM:
			var item: Dictionary = spec.get("items", { })
			if spec.has("suggest") and not item.has("suggest"):
				item = Spec.merge(item, { "suggest": spec["suggest"] }) # a suggestion on an array is per item
			var exclude: Array = _siblings(scope) if spec.get("unique", false) else []
			return _value_items(item, loc, "item", scope.index, "i:%s" % [scope.path], exclude)
		ScopeKind.DICT_VALUE:
			return _value_items(
				_field_spec(spec, scope.key),
				loc,
				"value",
				scope.key,
				"f:%s:%s" % [scope.path, scope.key],
				[],
			)
		_:
			var keys := _key_items(spec.get("fields", { }), scope, loc, cur)
			if spec.has("suggest"): # on a dictionary, suggest is the keys (for open maps)
				keys.append_array(_open_keys(spec["suggest"], scope, loc, cur))
			return keys


func _value_items(
	spec: Dictionary,
	loc: Dictionary,
	kind: String,
	position,
	slot: String,
	exclude: Array,
) -> Array:
	var items := _spec_items(spec, loc, kind, position, slot, exclude)
	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	var concrete: bool = spec.get("type", TYPE_NIL) != TYPE_NIL
	if (
			items.is_empty() and not spec.has("suggest") and not concrete and not in_text \
				and not spec.has("items")
		and not spec.has("fields")
	):
		return _type_items(loc.prefix) # nothing known about the value: offer constructor types
	return items


func _key_items(fields: Dictionary, scope, loc: Dictionary, cur: int) -> Array:
	var cands := { }
	var optional := { }
	for k in fields:
		var key: String = str(k)
		if key == "*":
			continue
		var is_req := key.ends_with("!") # "hp!" required; "name" and "name?" optional
		var name := key.trim_suffix("!").trim_suffix("?")
		if scope.used_keys.has(name):
			continue
		var f: Dictionary = fields[k]
		var parts: Array = ["required" if is_req else "optional"]
		var t = f.get("type")
		if t is int and t != TYPE_NIL:
			parts.append(type_string(t))
		if f.has("desc"):
			parts.append(f["desc"])
		(cands if is_req else optional)[name] = " · ".join(parts)
	cands.merge(optional) # required keys first
	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	var out: Array = []
	for name in _rank(cands, loc.prefix):
		var insert: String = _value_insert(name, loc)
		if not in_text and not _colon_follows(cur):
			insert += ": "
		out.append(CompletionItem.new(name, CompletionItem.Kind.KEY, cands[name], insert))
	return out


func _open_keys(source, scope, loc: Dictionary, cur: int) -> Array:
	var in_text: bool = loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE
	var out: Array = []
	for i in _suggested(source, loc, "key", scope.index, "k:%s" % [scope.path], scope.used_keys):
		var insert: String = i.insert if in_text or _colon_follows(cur) else i.insert + ": "
		out.append(CompletionItem.new(i.label, CompletionItem.Kind.KEY, i.detail, insert))
	return out


func _colon_follows(cur: int) -> bool:
	var j := cur
	while j < _input.length() and (_input[j] == " " or _input[j] == "\t"):
		j += 1
	return j < _input.length() and _input[j] == ":"


# What a type alone implies: true / false for bool, the constructor for a constructor type.
func _typed_items(type, loc: Dictionary) -> Array:
	if not type is int:
		return []
	if type == TYPE_BOOL:
		var out: Array = []
		for label in _rank({ "true": "", "false": "" }, loc.prefix):
			out.append(
				CompletionItem.new(label, CompletionItem.Kind.VALUE, "", _value_insert(label, loc))
			)
		return out
	if loc.mode == Mode.STRING or loc.mode == Mode.TEMPLATE or type == TYPE_NIL:
		return []
	var wanted := type_string(type)
	return _type_items(loc.prefix).filter(
		func(i):
			return i.label == wanted,
	)


func _siblings(scope) -> Array:
	var out: Array = []
	var n = scope.node
	if n == null:
		return out
	for i in n.items.size():
		if i != scope.index and n.items[i] is Nodes.StringNode:
			out.append(n.items[i].value)
	return out


func _collection_spec(scope) -> Dictionary:
	var spec := _slot_spec(scope.owner)
	for step in scope.path:
		spec = spec.get("items", { }) if step is int else _field_spec(spec, step)
	return spec


func _slot_spec(owner) -> Dictionary:
	if owner == null:
		return { }
	var def = owner.get_active()
	if def == null:
		return { }
	if owner.kind == ScopeKind.COMMAND:
		if def.params.is_empty():
			return { }
		return def.params[mini(owner.arg_index, def.params.size() - 1)].spec
	for sig in def.signatures:
		if owner.part_index < sig.parts.size() and not sig.parts[owner.part_index].spec.is_empty():
			return sig.parts[owner.part_index].spec
	return { }


func _field_spec(spec: Dictionary, key: String) -> Dictionary:
	var fields: Dictionary = spec.get("fields", { })
	if fields.has(key):
		return fields[key]
	if fields.has(key + "?"):
		return fields[key + "?"]
	if fields.has(key + "!"):
		return fields[key + "!"]
	return fields.get("*", { })
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
	return text if _is_bare(text, loc.in_dict) else "'" + text.replace("\\", "\\\\").replace(
		"'",
		"\\'",
	) + "'"


func _is_bare(text: String, in_dict: bool) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		if (
			c <= 32 or c in [34, 35, 36, 39, 40, 41, 44, 59, 91, 93, 96, 123, 125]
			or (in_dict and c == 58)
		):
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
