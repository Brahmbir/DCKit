extends RefCounted

const Nodes := _DCKitNS.Analyzer.Nodes
const Names := _DCKitNS.Analyzer.Names
const Token := _DCKitNS.Analyzer.Token
const TT := Token.Type
const Role := Token.Role
const Diagnostic := DCAnalysisResult.Diagnostic

# Nodes stay reachable as Parser.<Name> for the executor / analyzer / autocomplete.
const AstNode := Nodes.AstNode
const CommandNode := Nodes.CommandNode
const StringNode := Nodes.StringNode
const TemplateNode := Nodes.TemplateNode
const VariableNode := Nodes.VariableNode
const ConstructorNode := Nodes.ConstructorNode
const ArrayNode := Nodes.ArrayNode
const DictEntry := Nodes.DictEntry
const DictNode := Nodes.DictNode
const ErrorNode := Nodes.ErrorNode

const _VALUE_START := {
	TT.WORD: true,
	TT.NUMBER: true,
	TT.STRING: true,
	TT.QUOTE_OPEN: true,
	TT.DOLLAR: true,
	TT.LPAREN: true,
	TT.LBRACKET: true,
	TT.LCURLY: true,
}

var max_depth := 32
var diagnostics: Array = []

var _t: Array = []
var _p := 0
var _src := ""
var _closers: Array[int] = [] # closing token type of every open bracketed context
var _comma_ok: Array[bool] = [] # does ',' belong to that context
var _closer_count := { }
var _last_err := -1
var _in_key := false
var _unwind_at := -1
var _unwind_text := ""


#region PUBLIC
## Never fails: always returns the commands it could recognise, problems go to `diagnostics`.
## Recovery model: every context knows its own closing token; on trouble the parser reports
## once, skips only what it must, and resumes at the nearest token an enclosing context owns.
func parse_chain(tokens: Array, source := "") -> Array:
	_t = tokens
	_src = source
	_p = 0
	_closers = []
	_comma_ok = []
	_closer_count = { }
	_last_err = -1
	_unwind_at = -1
	_unwind_text = ""
	diagnostics = []

	var out: Array = []
	while _peek().type != TT.END:
		var t := _peek()
		if t.type == TT.SEMI or t.type == TT.COMMENT:
			_next()
		else:
			var cmd := _parse_command(null)
			if _peek().type == TT.SEMI:
				cmd.semi_pos = _peek().start
			out.append(cmd)
	return out
#endregion


#region COMMANDS
func _parse_command(open: Token) -> CommandNode:
	var t := _peek()
	var cmd: CommandNode
	if t.type == TT.WORD or t.type == TT.NUMBER:
		_next()
		cmd = CommandNode.new(t.value, t.start)
		var err := Names.command_name_error(t.value)
		if err.is_empty():
			t.role = Role.COMMAND
		else:
			cmd.bad = true
			t.role = Role.ERROR
			_error(err[1], t.start + err[0], 1).with_hint(Names.COMMAND_HINT)
	else:
		cmd = CommandNode.new("", t.start)
		cmd.bad = true
		cmd.end_pos = t.start
		var stray := _bad_command_start(t, open)
		if stray != null:
			cmd.args.append(stray)

	while true:
		var a := _peek()
		if a.type == TT.END or _is_stop(a.type):
			break
		var before := _p
		if a.type == TT.COMMENT:
			_next()
		elif _starts_value(a.type):
			cmd.args.append(_parse_value())
		else:
			_unexpected(a)
		if _p == before:
			_next()
	if not cmd.args.is_empty():
		cmd.end_pos = maxi(cmd.end_pos, cmd.args.back().end_pos)
	return cmd


func _bad_command_start(t: Token, open: Token) -> AstNode:
	if open != null and (t.type == TT.END or _is_stop(t.type)):
		_error("Expected a command name after '('.", open.start, 1)
		return null
	match t.type:
		TT.DOLLAR:
			_error("Command name cannot be a variable. Use a static name.", t.start, 1)
			return _parse_value()
		TT.STRING, TT.QUOTE_OPEN:
			_error("Command name cannot be a string.", t.start, 1)
			return _parse_value()
		TT.LPAREN, TT.LBRACKET, TT.LCURLY:
			_error("Expected a command name, found '%s'." % _text(t), t.start, 1)
			return _parse_value()
		_:
			_unexpected(t, "Expected a command name, found '%s'.")
			return null
#endregion


#region VALUES
func _parse_value() -> AstNode:
	var t := _peek()
	var node: AstNode
	match t.type:
		TT.WORD:
			var nx := _peek_next()
			node = _parse_constructor() if nx.type == TT.LPAREN and nx.glued else _literal()
		TT.NUMBER, TT.STRING:
			node = _literal()
		TT.QUOTE_OPEN:
			node = _parse_template()
		TT.DOLLAR:
			node = _parse_variable()
		TT.LPAREN:
			node = _parse_nested()
		TT.LBRACKET:
			node = _parse_array()
		TT.LCURLY:
			node = _parse_dict()
		_:
			return ErrorNode.new(t.start, t.start, true)
	_check_glued(node)
	return node


func _literal() -> StringNode:
	var t := _next()
	return StringNode.new(t.value, t.type == TT.STRING, t.start, t.end)


func _parse_nested() -> AstNode:
	if _too_deep():
		return _skip_too_deep()
	var open := _next()
	_push(TT.RPAREN, false)
	var cmd := _parse_command(open)
	cmd.start_pos = open.start
	var close := _close_or_report(open.start, 1, "'('", TT.RPAREN, ")")
	_pop(TT.RPAREN)
	cmd.open = close == null
	cmd.end_pos = close.end if close != null else _peek().start # open: where the closer would go
	return cmd


func _parse_constructor() -> AstNode:
	if _too_deep():
		return _skip_too_deep()
	var name_t := _next()
	var open := _next()
	var node := ConstructorNode.new(name_t.value, name_t.start)
	var err := Names.type_name_error(name_t.value)
	if err.is_empty():
		name_t.role = Role.CTOR_TYPE
	else:
		node.bad = true
		name_t.role = Role.ERROR
		_error(err[1], name_t.start + err[0], 1)
	var close := _parse_list(
		open.start,
		1,
		"'('",
		TT.RPAREN,
		")",
		func():
			node.parts.append(_parse_value()),
	)
	node.open = close == null
	node.end_pos = close.end if close != null else _peek().start
	return node


func _parse_array() -> AstNode:
	if _too_deep():
		return _skip_too_deep()
	var open := _next()
	var node := ArrayNode.new(open.start)
	var close := _parse_list(
		open.start,
		1,
		"'['",
		TT.RBRACKET,
		"]",
		func():
			node.items.append(_parse_value()),
	)
	node.open = close == null
	node.end_pos = close.end if close != null else _peek().start
	return node


func _parse_template() -> AstNode:
	var open := _next()
	var node := TemplateNode.new(open.start)
	var closed := false
	var interpolates := false
	while true:
		var t := _peek()
		if t.type == TT.TEXT:
			_next()
			node.segments.append(StringNode.new(t.value, true, t.start, t.end))
		elif t.type == TT.DOLLAR:
			interpolates = true
			node.segments.append(_parse_variable())
		elif t.type == TT.QUOTE_CLOSE:
			node.end_pos = _next().end
			closed = true
			break
		else:
			break
	if not closed:
		node.open = true
		var at := _peek()
		node.end_pos = at.start
		var d := _error("Unterminated string. Expected closing '\"'.", open.start, 1) \
				.with_related(at.start, 0, "input ends here")
		if at.type == TT.SEMI:
			d.with_hint(
				"';' always ends the command, even inside ${...}. Quote it (';') to use it as text."
			)
		else:
			d.with_fix("Add closing '\"'", at.start, at.start, "\"")
	if interpolates:
		return node
	var text := ""
	for s in node.segments:
		text += s.value
	var plain := StringNode.new(text, true, node.start_pos, node.end_pos)
	plain.open = node.open
	return plain
#endregion


#region VARIABLES
func _parse_variable() -> AstNode:
	var dollar := _next()
	var node := VariableNode.new("", false, dollar.start)
	node.end_pos = dollar.end
	var t := _peek()
	if t.type == TT.LBRACE and t.glued:
		return _parse_braced(node, dollar)
	if t.type == TT.NAME and t.glued:
		_next()
		node.name = t.value
		node.end_pos = t.end
		_modifier(node, false)
		return node
	dollar.role = Role.ERROR # the lexer already explained why
	return ErrorNode.new(dollar.start, dollar.end)


func _parse_braced(node: VariableNode, dollar: Token) -> AstNode:
	if _too_deep():
		dollar.role = Role.ERROR
		return _skip_too_deep(dollar.start)
	_next() # '{'
	node.braced = true
	_push(TT.RBRACE, false)

	var name_t := _peek()
	if name_t.type == TT.NAME:
		_next()
		node.name = name_t.value
		node.end_pos = name_t.end
		node.bad = name_t.role == Role.ERROR
	else:
		node.bad = true # empty name: reported by the lexer
	_modifier(node, true)

	var close: Token = null
	var r := _peek()
	if r.type == TT.RBRACE:
		close = _next()
	else:
		if r.type != TT.END and not _is_stop(r.type):
			_error("Expected '}' to close '${'.", r.start, maxi(r.end - r.start, 1)) \
					.with_hint(
				"A variable takes one modifier: ${name!}, ${name?} or ${name:fallback}."
			)
			close = _recover_to(TT.RBRACE)
		if close == null:
			close = _close_or_report(dollar.start, 2, "'${'", TT.RBRACE, "}")
	_pop(TT.RBRACE)
	node.open = close == null
	node.end_pos = close.end if close != null else _peek().start
	return node


func _modifier(node: VariableNode, braced: bool) -> void:
	var t := _peek()
	match t.type:
		TT.BANG:
			_next()
			node.modifier = "!"
			node.end_pos = t.end
		TT.QMARK:
			_next()
			node.modifier = "?"
			node.is_silent = true
			node.end_pos = t.end
			if braced and _starts_value(_peek().type):
				var v := _peek()
				var has_colon: bool = (
					v.type == TT.WORD and v.glued and String(v.value).begins_with(":")
				)
				_error("'?' takes no value.", t.start, 1) \
						.with_hint("Did you mean ${%s:...} for a fallback?" % node.name) \
						.with_fix(
					"Use ':' for a fallback",
					t.start,
					v.start + 1 if has_colon else t.end,
					":",
				)
				node.fallback = _parse_value()
				node.end_pos = node.fallback.end_pos
		TT.COLON:
			_next()
			node.modifier = ":"
			node.is_silent = true
			node.end_pos = t.end
			var n := _peek()
			if _starts_value(n.type) and (braced or n.glued):
				if _too_deep():
					node.fallback = _skip_too_deep()
				else:
					_push(-1, not _comma_ok.is_empty() and _comma_ok.back())
					node.fallback = _parse_value()
					_pop(-1)
				node.end_pos = node.fallback.end_pos
			elif not _in_key:
				_error("Expected a fallback value after ':'.", t.start, 1) \
						.with_hint("Write ${name:value}, or remove the ':'.")
#endregion


#region COLLECTIONS
func _parse_dict() -> AstNode:
	if _too_deep():
		return _skip_too_deep()
	var open := _next()
	var node := DictNode.new(open.start)
	var seen := { }
	var close := _parse_list(
		open.start,
		1,
		"'{'",
		TT.RCURLY,
		"}",
		func():
			var e := _parse_entry()
			node.entries.append(e)
			if e.key is StringNode and not e.key.bad:
				var k: String = e.key.value
				if seen.has(k):
					var first: DictEntry = seen[k]
					_warn(
						"Duplicate key '%s'." % k,
						e.key.start_pos,
						maxi(e.key.end_pos - e.key.start_pos, 1),
					) \
							.with_related(
						first.key.start_pos,
						maxi(first.key.end_pos - first.key.start_pos, 1),
						"first defined here",
					)
				else:
					seen[k] = e,
	)
	node.open = close == null
	node.end_pos = close.end if close != null else _peek().start
	return node


func _parse_entry() -> DictEntry:
	var e := DictEntry.new(_peek().start)
	e.key = _parse_key()
	e.end_pos = e.key.end_pos

	var t := _peek()
	if e.key is VariableNode and e.key.modifier == ":" and e.key.fallback == null:
		e.colon_pos = e.key.end_pos - 1 # the variable swallowed the entry's ':'
		var after := _peek()
		if _starts_value(after.type):
			e.value = _parse_value()
		else:
			_error("Expected a value after ':'.", e.colon_pos, 1)
			e.value = ErrorNode.new(e.key.end_pos, e.key.end_pos, true)
			e.end_pos = _peek().start # the entry stays open until the next ',' or closer
	elif t.type == TT.COLON:
		_next()
		e.colon_pos = t.start
		if _starts_value(_peek().type):
			e.value = _parse_value()
		else:
			_error("Expected a value after ':'.", t.start, 1)
			e.value = ErrorNode.new(t.end, t.end, true)
			e.end_pos = _peek().start # the entry stays open until the next ',' or closer
	else:
		var k_len := maxi(e.key.end_pos - e.key.start_pos, 1)
		_error("Expected ':' after the key.", e.key.start_pos, k_len) \
				.with_hint("Write {key: value}.") \
				.with_fix("Add ':'", e.key.end_pos, e.key.end_pos, ":")
		e.value = (
			_parse_value()
			if _starts_value(t.type)
			else ErrorNode.new(e.key.end_pos, e.key.end_pos, true)
		)
	e.end_pos = maxi(e.end_pos, e.value.end_pos)
	return e


func _parse_key() -> AstNode:
	var t := _peek()
	match t.type:
		TT.WORD, TT.NUMBER, TT.STRING:
			t.role = Role.KEY
			return _literal()
		TT.QUOTE_OPEN:
			var k := _parse_template()
			if k is TemplateNode:
				k.bad = true
				_error(
					"Dictionary keys must be literal text.",
					k.start_pos,
					maxi(k.end_pos - k.start_pos, 1),
				) \
						.with_hint("Variables can be values: {name: ${x}}.")
			return k
		TT.COLON:
			_error("Expected a key before ':'.", t.start, 1)
			return ErrorNode.new(t.start, t.start, true)
		_:
			_in_key = true
			var v := _parse_value()
			_in_key = false
			v.bad = true
			_error(
				"Dictionary keys must be a word, number or string.",
				v.start_pos,
				maxi(v.end_pos - v.start_pos, 1),
			)
			return v


# Shared by constructors, arrays and dictionaries. Returns the closing token, or null.
func _parse_list(
	open_at: int,
	open_len: int,
	open_text: String,
	closer: int,
	close_text: String,
	item: Callable,
) -> Token:
	_push(closer, true)
	var expect_value := true
	while true:
		var t := _peek()
		if t.type == closer or t.type == TT.END:
			break
		if t.type == TT.COMMA:
			if expect_value:
				_error("Expected a value before ','.", t.start, 1)
			_next()
			expect_value = true
			continue
		if _is_stop(t.type):
			break
		var before := _p
		if _starts_value(t.type) or (closer == TT.RCURLY and t.type == TT.COLON):
			item.call()
			expect_value = false
			var n := _peek()
			if n.type == TT.COLON:
				_error("Unexpected ':' after the value.", n.start, 1) \
						.with_hint("Quote values that contain ':', e.g. \"res://x\".")
				_skip_glued_run()
			elif (
				n.type != TT.COMMA and n.type != closer
				and n.type != TT.END and not _is_stop(n.type)
			):
				_error(
					"Expected ',' or '%s' after the item." % close_text,
					n.start,
					maxi(n.end - n.start, 1),
				) \
						.with_hint("Separate items with commas.")
		else:
			_unexpected(t)
		if _p == before:
			_next()
	var close := _close_or_report(open_at, open_len, open_text, closer, close_text)
	_pop(closer)
	return close
#endregion


#region RECOVERY
func _push(closer: int, comma: bool) -> void:
	_closers.append(closer)
	_comma_ok.append(comma)
	_closer_count[closer] = _closer_count.get(closer, 0) + 1


func _pop(closer: int) -> void:
	_closers.pop_back()
	_comma_ok.pop_back()
	_closer_count[closer] -= 1


# A token some open context is waiting for: inner contexts must stop and leave it alone.
func _is_stop(type: int) -> bool:
	if type == TT.SEMI or _closer_count.get(type, 0) > 0:
		return true
	return type == TT.COMMA and not _comma_ok.is_empty() and _comma_ok.back()


# Insertion recovery: pretend the closer was there, report once at the opener.
func _close_or_report(
	open_at: int,
	open_len: int,
	open_text: String,
	closer: int,
	close_text: String,
) -> Token:
	var t := _peek()
	if t.type == closer:
		_unwind_at = -1
		return _next()
	if _unwind_at != t.start:
		_unwind_at = t.start
		_unwind_text = ""
	_unwind_text += close_text
	var found := "input ends here" if t.type == TT.END else "found '%s' here" % _text(t)
	var d := _error("Unclosed %s. Expected '%s'." % [open_text, close_text], open_at, open_len) \
			.with_related(t.start, 0 if t.type == TT.END else t.end - t.start, found) \
			.with_fix("Add closing '%s'" % _unwind_text, t.start, t.start, _unwind_text)
	if t.type == TT.SEMI:
		d.with_hint(
			"';' always ends the command, even inside brackets. Quote it (';') to use it as text."
		)
	return null


# Skips junk up to `target` (consumed, returned) or until an enclosing context takes over.
func _recover_to(target: int) -> Token:
	while true:
		var t := _peek()
		if t.type == target:
			return _next()
		if t.type == TT.END or _is_stop(t.type):
			return null
		t.role = Role.ERROR
		_next()
	return null


func _skip_glued_run() -> void:
	var t := _peek()
	t.role = Role.ERROR
	_next()
	while _peek().glued and _peek().type != TT.END and not _is_stop(_peek().type):
		_peek().role = Role.ERROR
		_next()


func _too_deep() -> bool:
	return _closers.size() >= max_depth


func _skip_too_deep(from := -1) -> AstNode:
	var start := _peek().start if from < 0 else from
	_error("Nesting is too deep (the limit is %d levels)." % max_depth, start, 1 if from < 0 else 2)
	var depth := 0
	while _peek().type != TT.END and _peek().type != TT.SEMI:
		var ty := _peek().type
		if ty == TT.LPAREN or ty == TT.LBRACKET or ty == TT.LCURLY or ty == TT.LBRACE:
			depth += 1
		elif ty == TT.RPAREN or ty == TT.RBRACKET or ty == TT.RCURLY or ty == TT.RBRACE:
			depth -= 1
		_peek().role = Role.ERROR
		_next()
		if (
			depth <= 0
			and (ty == TT.RPAREN or ty == TT.RBRACKET or ty == TT.RCURLY or ty == TT.RBRACE)
		):
			break # the construct's own closer
	return ErrorNode.new(start, _prev_end())


func _unexpected(t: Token, template := "Unexpected '%s'.") -> void:
	var text := _text(t)
	match t.type:
		TT.COMMA:
			_error("Unexpected ','. Commas only separate items inside (), [] and {}.", t.start, 1) \
					.with_hint("Remove it, or quote the text: 'a,b'.")
		TT.RPAREN, TT.RBRACKET, TT.RCURLY, TT.RBRACE:
			_error("Unmatched '%s'." % text, t.start, 1)
		_:
			_error(template % text, t.start, maxi(t.end - t.start, 1))
	t.role = Role.ERROR
	_next()


func _check_glued(node: AstNode) -> void:
	var n := _peek()
	if not n.glued or not _starts_value(n.type):
		return
	if node.bad and node is ErrorNode:
		return
	var span := maxi(n.end - n.start, 1)
	if node is VariableNode and node.fallback != null and not node.braced:
		return # the fallback value already checked what follows it
	if node is VariableNode and node.modifier.is_empty():
		var d := _error("Text directly after '$%s'." % node.name, n.start, span) \
				.with_hint("Join text with a string: \"${%s}...\"." % node.name)
		if (n.type == TT.WORD or n.type == TT.NUMBER) and not _src.is_empty():
			var joined := "\"${%s}%s\"" % [node.name, n.value.replace("\\", "\\\\")]
			d.with_fix("Join into one string", node.start_pos, n.end, joined)
	elif node is VariableNode and not node.braced:
		_error("Expected a space after '%s'." % node.modifier, n.start, span)
	else:
		_error("Expected a space before '%s'." % _text(n), n.start, span) \
				.with_hint(
			"Separate arguments with spaces. To join text, use a double-quoted string."
		)
#endregion


#region HELPERS
func _peek() -> Token:
	return _t[_p]


func _peek_next() -> Token:
	return _t[_p + 1] if _p + 1 < _t.size() else _t.back()


func _next() -> Token:
	var t: Token = _t[_p]
	if _p < _t.size() - 1:
		_p += 1
	return t


func _prev_end() -> int:
	return _t[_p - 1].end if _p > 0 else 0


func _starts_value(type: int) -> bool:
	return _VALUE_START.has(type)


func _text(t: Token) -> String:
	return _src.substr(t.start, t.end - t.start) if not _src.is_empty() else t.value


# Cascade guard: one report per source position.
func _error(msg: String, pos: int, len: int) -> Diagnostic:
	var d := Diagnostic.new(msg, pos, len, Diagnostic.Severity.ERROR, Diagnostic.Source.PARSER)
	if pos != _last_err:
		diagnostics.append(d)
		_last_err = pos
	return d


func _warn(msg: String, pos: int, len: int) -> Diagnostic:
	var d := Diagnostic.new(msg, pos, len, Diagnostic.Severity.WARNING, Diagnostic.Source.PARSER)
	diagnostics.append(d)
	return d
#endregion
