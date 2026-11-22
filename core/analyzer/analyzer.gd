extends RefCounted

const Lexer := _DCKitNS.Analyzer.Lexer
const Parser := _DCKitNS.Analyzer.Parser
const Nodes := _DCKitNS.Analyzer.Nodes
const Diagnostic := DCAnalysisResult.Diagnostic
const Scope := DCAnalysisResult.Scope

const MAX_DIAGNOSTICS := 100
const FAR := 1 << 30

# Maximum nested argument / fallback depth allowed for one command tree.
var max_depth: int = _DCKitSetting.get_max_argument_depth()

# Provided at init — all optional; omit to skip that category of semantic check.
var _cmd_reg = null # CommandRegistry     — .has(name), .get_definition(name), .get_all()
var _ctor_reg = null # ConstructorRegistry — .knows(name), .get_def(name), .get_all()
var _var_store = null # variable store      — .has(name), .get_keys()


func _init(cmd_reg = null, ctor_reg = null, var_store = null) -> void:
	_cmd_reg = cmd_reg
	_ctor_reg = ctor_reg
	_var_store = var_store


#region ANALYZE
## lex -> parse -> semantic. Every stage recovers, so the AST and the scope are always usable.
func analyze(input: String, cursor_pos := -1) -> DCAnalysisResult:
	var result := DCAnalysisResult.new()
	if cursor_pos < 0:
		cursor_pos = input.length()

	var lexer := Lexer.new()
	result.tokens = lexer.lex(input)

	var parser := Parser.new()
	parser.max_depth = max_depth
	result.ast = parser.parse_chain(result.tokens, input)

	var found := _merge(lexer.diagnostics, parser.diagnostics)
	for cmd in result.ast:
		_check_node(cmd, found)
	result.diagnostics = _finish(found, input.length())
	result.scope = scope_at(result.ast, cursor_pos)
	return result


#region SCOPE
## Where the cursor sits, derived from the AST. Slots are 0-based everywhere:
## COMMAND arg_index is -1 on the name, CONSTRUCTOR part_index / ARRAY_ITEM index / DICT_* index
## name the slot under the cursor (a finished item moves the cursor to the next slot).
func scope_at(ast: Array, cursor: int) -> Scope:
	for cmd in ast:
		var limit: int = cmd.semi_pos if cmd.semi_pos >= 0 else FAR
		if cursor <= limit:
			return _command_scope(cmd, cursor)
	var s := Scope.new()
	s.kind = Scope.Kind.COMMAND
	return s


# Lexer and parser both report unclosed brackets/strings at the same span; keep the first.
func _merge(lexed: Array, parsed: Array) -> Array:
	var out: Array = lexed.duplicate()
	var seen := { }
	for d in lexed:
		seen[Vector2i(d.position, d.length)] = true
	for d in parsed:
		if not seen.has(Vector2i(d.position, d.length)):
			out.append(d)
	return out


func _finish(found: Array, input_len: int) -> Array:
	var order := { }
	for i in found.size():
		order[found[i]] = i
	found.sort_custom(
		func(a, b) -> bool:
			if a.position != b.position:
				return a.position < b.position
			return order[a] < order[b],
	)
	if found.size() > MAX_DIAGNOSTICS:
		var hidden := found.size() - MAX_DIAGNOSTICS
		found.resize(MAX_DIAGNOSTICS)
		found.append(
			Diagnostic.new(
				"%d more problem(s) not shown." % hidden,
				input_len,
				0,
				Diagnostic.Severity.HINT,
				Diagnostic.Source.SEMANTIC,
			),
		)
	return found
#endregion


#region SEMANTIC
func _check_node(node, out: Array) -> void:
	if node == null:
		return
	if not node.bad:
		if node is Nodes.VariableNode:
			_check_variable(node, out)
		elif node is Nodes.CommandNode:
			_check_command(node, out)
		elif node is Nodes.ConstructorNode:
			_check_constructor(node, out)
	for child in node.children():
		_check_node(child, out)


func _check_variable(node: Nodes.VariableNode, out: Array) -> void:
	if node.is_silent or _var_store == null or _var_store.has(node.name):
		return
	var span := maxi(node.end_pos - node.start_pos, 1)
	var d := _diag(
		"'$%s' is not defined." % node.name,
		node.start_pos,
		span,
		Diagnostic.Severity.WARNING,
	)
	var near := _closest(node.name, _var_store.get_keys())
	if not near.is_empty():
		d.with_hint("Did you mean '$%s'?" % near)
		if not node.braced:
			d.with_fix(
				"Change to '$%s'" % near,
				node.start_pos,
				node.start_pos + node.name.length() + 1,
				"$" + near,
			)
	else:
		d.with_hint("Use $%s? or ${%s:fallback} if it may be missing." % [node.name, node.name])
	out.append(d)


func _check_command(node: Nodes.CommandNode, out: Array) -> void:
	if _cmd_reg == null:
		return
	var span := node.name.length()
	if not _cmd_reg.has(node.name):
		var d := _diag(
			"Unknown command '%s'." % node.name,
			node.name_pos,
			span,
			Diagnostic.Severity.ERROR,
		)
		var near := _closest(
			node.name,
			_cmd_reg.get_all().map(
				func(x):
					return x.name,
			),
		)
		if not near.is_empty():
			d.with_hint("Did you mean '%s'?" % near) \
					.with_fix("Change to '%s'" % near, node.name_pos, node.name_pos + span, near)
		out.append(d)
		return
	# Argument count is intentionally not validated — handlers are variadic by design.
	var def: DCDefinition = _cmd_reg.get_definition(node.name)
	if def != null and def.deprecated:
		var msg := "'%s' is deprecated." % def.name
		if not (def.name == node.name):
			msg = "Command '%s' (invoked as '%s') is deprecated." % [def.name, node.name]
		if not def.deprecated_message.is_empty():
			msg += " " + def.deprecated_message
		out.append(_diag(msg, node.name_pos, span, Diagnostic.Severity.WARNING))
	if def == null:
		return
	for i in node.args.size():
		var p = null
		if i < def.params.size():
			p = def.params[i]
		elif not def.params.is_empty() and def.params.back().is_rest:
			p = def.params.back()
		if p != null:
			_check_spec(node.args[i], p.spec, out)


func _check_constructor(node: Nodes.ConstructorNode, out: Array) -> void:
	if _ctor_reg == null:
		return
	var span := node.type_name.length()
	if not _ctor_reg.knows(node.type_name):
		var d := _diag(
			"Unknown constructor type '%s'." % node.type_name,
			node.type_pos,
			span,
			Diagnostic.Severity.ERROR,
		)
		var near := _closest(
			node.type_name,
			_ctor_reg.get_all().map(
				func(x):
					return x.name,
			),
		)
		if not near.is_empty():
			d.with_hint("Did you mean '%s'?" % near) \
					.with_fix("Change to '%s'" % near, node.type_pos, node.type_pos + span, near)
		out.append(d)
		return
	var def = _ctor_reg.get_def(node.type_name)
	var count: int = node.parts.size()
	if def.signatures.is_empty():
		return
	var accepted: Array = []
	for sig in def.signatures:
		var n: int = sig.parts.size()
		if n == count:
			return
		if not accepted.has(n):
			accepted.append(n)
	accepted.sort()
	out.append(
		_diag(
			"'%s' has no signature for %d part(s)." % [node.type_name, count],
			node.type_pos,
			span,
			Diagnostic.Severity.WARNING,
		) \
				.with_hint("Accepted part counts: %s." % ", ".join(accepted.map(str))),
	)


#region SPEC RULES
# The spec rules on what is already known while typing: literals. Variables and nested commands are
# skipped here and checked at run time.
func _check_spec(n, spec: Dictionary, out: Array) -> void:
	if spec.is_empty() or n == null or n.bad:
		return
	var span := maxi(n.end_pos - n.start_pos, 1)
	if n is Nodes.ArrayNode:
		var count: int = n.items.size()
		if spec.has("min") and count < spec["min"]:
			out.append(
				_diag(
					"Needs at least %d item(s) (found %d)." % [spec["min"], count],
					n.start_pos,
					span,
					Diagnostic.Severity.ERROR,
				)
			)
		if spec.has("max") and count > spec["max"]:
			out.append(
				_diag(
					"Takes at most %d item(s) (found %d)." % [spec["max"], count],
					n.start_pos,
					span,
					Diagnostic.Severity.ERROR,
				)
			)
		var seen := { }
		for item in n.items:
			if spec.get("unique", false) and item is Nodes.StringNode:
				var key := [item.quoted, item.value]
				if seen.has(key):
					out.append(
						_diag(
							"Duplicate item '%s'." % item.value,
							item.start_pos,
							maxi(item.end_pos - item.start_pos, 1),
							Diagnostic.Severity.ERROR,
						) \
								.with_related(
							seen[key].start_pos,
							maxi(seen[key].end_pos - seen[key].start_pos, 1),
							"first used here",
						),
					)
				else:
					seen[key] = item
			_check_spec(item, spec.get("items", { }), out)
	elif n is Nodes.DictNode:
		var fields: Dictionary = spec.get("fields", { })
		var present := { }
		for e in n.entries:
			if not (e.key is Nodes.StringNode) or e.key.bad:
				continue
			var key: String = e.key.value
			present[key] = true
			var field = DCSpec.field_of(fields, key)
			if field == null:
				if not fields.is_empty():
					var names: Array = fields.keys().map(
						func(k):
							return k.trim_suffix("!").trim_suffix("?"),
					)
					var near := _closest(key, names)
					var d := _diag(
						"Unknown key '%s'." % key,
						e.key.start_pos,
						maxi(e.key.end_pos - e.key.start_pos, 1),
						Diagnostic.Severity.ERROR,
					)
					if not near.is_empty():
						d.with_hint("Did you mean '%s'?" % near).with_fix(
							"Change to '%s'" % near,
							e.key.start_pos,
							e.key.end_pos,
							near,
						)
					out.append(d)
			else:
				_check_spec(e.value, field, out)
		for f in fields:
			var name: String = f.trim_suffix("!")
			if f.ends_with("!") and not present.has(name):
				var at: int = n.end_pos - 1 if not n.open else n.end_pos
				var text := ("" if n.entries.is_empty() else ", ") + name + ": "
				out.append(
					_diag(
						"Missing required key '%s'." % name,
						n.start_pos,
						1,
						Diagnostic.Severity.ERROR,
					) \
							.with_fix("Add '%s'" % name, at, at, text),
				)
		if spec.has("max") and n.entries.size() > spec["max"]:
			out.append(
				_diag(
					"Takes at most %d key(s) (found %d)." % [spec["max"], n.entries.size()],
					n.start_pos,
					span,
					Diagnostic.Severity.ERROR,
				)
			)
	elif n is Nodes.StringNode:
		if spec.has("choices"):
			var names: Array = spec["choices"].keys().map(str)
			var typed := DCSpec._typed(n.value, spec)
			if not DCSpec._in_choices(typed, spec["choices"]):
				var d := _diag(
					"Expected one of: %s." % ", ".join(PackedStringArray(names)),
					n.start_pos,
					span,
					Diagnostic.Severity.ERROR,
				)
				var near := _closest(n.value, names)
				if not near.is_empty():
					d.with_hint("Did you mean '%s'?" % near).with_fix(
						"Change to '%s'" % near,
						n.start_pos,
						n.end_pos,
						near,
					)
				out.append(d)
				return
		var rules := { }
		for k in ["type", "min", "max"]: #INFO "validate" is runtime only
			if spec.has(k):
				rules[k] = spec[k]
		var err := DCSpec.check(n.value, rules)
		if not err.is_empty():
			out.append(
				_diag(
					err[0].to_upper() + err.substr(1),
					n.start_pos,
					span,
					Diagnostic.Severity.ERROR,
				)
			)
#endregion


# Nearest candidate by edit distance, or "" when nothing is close enough.
func _closest(word: String, candidates: Array) -> String:
	var best := ""
	var best_d := maxi(2, word.length() / 3) + 1
	for c in candidates:
		var s := str(c)
		if s == word or absi(s.length() - word.length()) >= best_d:
			continue
		var d := _distance(word, s)
		if d < best_d:
			best_d = d
			best = s
	return best


func _distance(a: String, b: String) -> int:
	var prev := PackedInt32Array()
	prev.resize(b.length() + 1)
	for j in prev.size():
		prev[j] = j
	for i in a.length():
		var cur := PackedInt32Array()
		cur.resize(b.length() + 1)
		cur[0] = i + 1
		for j in b.length():
			var cost := 0 if a.unicode_at(i) == b.unicode_at(j) else 1
			cur[j + 1] = mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + cost)
		prev = cur
	return prev[b.length()]


func _diag(msg: String, pos: int, len: int, sev: int) -> Diagnostic:
	return Diagnostic.new(msg, pos, len, sev, Diagnostic.Source.SEMANTIC)
#endregion


func _command_scope(cmd: Nodes.CommandNode, c: int) -> Scope:
	var s := Scope.new()
	s.kind = Scope.Kind.COMMAND
	s.node = cmd
	if c <= cmd.name_pos + cmd.name.length():
		s.name = "" if c < cmd.name_pos else cmd.name
		s.arg_index = -1
	else:
		s.name = cmd.name
		s.arg_index = _slot(cmd.args, c)
		_bind_command(s)
		var inner := _dive(cmd.args, c, s, [])
		if inner != null:
			return inner
	_bind_command(s)
	return s


func _ctor_scope(node: Nodes.ConstructorNode, c: int) -> Scope:
	var s := Scope.new()
	s.kind = Scope.Kind.CONSTRUCTOR
	s.node = node
	s.type_name = node.type_name
	s.part_index = _slot(node.parts, c)
	_bind_ctor(s)
	var inner := _dive(node.parts, c, s, [])
	return inner if inner != null else s


func _array_scope(node: Nodes.ArrayNode, c: int, owner: Scope, path: Array) -> Scope:
	var idx := _slot(node.items, c)
	var inner := _dive(node.items, c, owner, path + [idx])
	if inner != null:
		return inner
	var s := Scope.new()
	s.kind = Scope.Kind.ARRAY_ITEM
	s.node = node
	s.owner = owner
	s.path = path
	s.index = idx
	s._active_ref = owner._active_ref
	return s


func _dict_scope(node: Nodes.DictNode, c: int, owner: Scope, path: Array) -> Scope:
	var idx := _slot(node.entries, c)
	var s := Scope.new()
	s.node = node
	s.owner = owner
	s.path = path
	s.index = idx
	s._active_ref = owner._active_ref
	s.kind = Scope.Kind.DICT_KEY
	for i in node.entries.size():
		var e: Nodes.DictEntry = node.entries[i]
		if i != idx and e.key is Nodes.StringNode and not e.key.bad:
			s.used_keys.append(e.key.value)
	if idx < node.entries.size():
		var e: Nodes.DictEntry = node.entries[idx]
		s.key = e.key.value if e.key is Nodes.StringNode else ""
		if e.colon_pos >= 0 and c > e.colon_pos:
			var inner := _dive([e.value], c, owner, path + [s.key])
			if inner != null:
				return inner
			s.kind = Scope.Kind.DICT_VALUE
		else:
			s.kind = Scope.Kind.DICT_KEY
	else:
		s.key = ""
	return s


# The deepest scope among `children` that contains the cursor, or null.
func _dive(children: Array, c: int, owner: Scope, path: Array) -> Scope:
	for ch in children:
		var s := _enter(ch, c, owner, path)
		if s != null:
			return s
	return null


func _enter(node, c: int, owner: Scope, path: Array) -> Scope:
	if node is Nodes.CommandNode: # nested command
		return _command_scope(node, c) if c > node.start_pos and _before_end(node, c) else null
	if node is Nodes.ConstructorNode:
		var after_paren: bool = c > node.type_pos + node.type_name.length()
		return _ctor_scope(node, c) if after_paren and _before_end(node, c) else null
	if node is Nodes.ArrayNode:
		return _array_scope(node, c, owner, path) if c > node.start_pos and _before_end(node, c) else null
	if node is Nodes.DictNode:
		return _dict_scope(node, c, owner, path) if c > node.start_pos and _before_end(node, c) else null
	if node is Nodes.VariableNode or node is Nodes.TemplateNode:
		return _dive(node.children(), c, owner, path) # fallback commands, ${...} inside strings
	return null


# Closed nodes end with their closer, so the cursor must be before it; open ones extend to the stop token.
func _before_end(node, c: int) -> bool:
	return c <= node.end_pos if node.open else c < node.end_pos


# Number of finished children before the cursor = the slot it is in.
func _slot(children: Array, c: int) -> int:
	var i := 0
	for ch in children:
		if c > ch.end_pos or (c == ch.end_pos and _is_finished(ch)):
			i += 1
		else:
			break
	return i


func _is_finished(n) -> bool:
	if n.open:
		return false
	return (
		n is Nodes.CommandNode or n is Nodes.ConstructorNode or n is Nodes.ArrayNode \
				or n is Nodes.DictNode
		or n is Nodes.TemplateNode or (n is Nodes.VariableNode and n.braced)
	)


func _bind_command(s: Scope) -> void:
	if _cmd_reg != null and not s.name.is_empty():
		var def = _cmd_reg.get_definition(s.name)
		if def != null:
			s._active_ref = weakref(def)


func _bind_ctor(s: Scope) -> void:
	if _ctor_reg != null and not s.type_name.is_empty():
		var def = _ctor_reg.get_def(s.type_name)
		if def != null:
			s._active_ref = weakref(def)
#endregion
