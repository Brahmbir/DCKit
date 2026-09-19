extends RefCounted

const TT := _DCKitAnalyzerNamespace.Lexer.TokenType

var _tokens: Array = []
var _pos: int = 0


# PUBLIC
# parse()       — single command, stops at first ';'.
# parse_chain() — all commands split on ';', returns Array of CommandNode.
# parse()
func parse(tokens: Array) -> Dictionary:
	_tokens = tokens
	_pos = 0
	if _at_end():
		return _fail("Empty input.", 0)
	var r := _parse_command()
	if r.ok:
		var last: _DCKitAnalyzerNamespace.Lexer.Token = _tokens[_pos - 1]
		var val_len := last.value.length() + (2 if last.type == TT.STRING else 0)
		r.node.end_pos = last.position + val_len
	return r


# parse_chain()
func parse_chain(tokens: Array) -> Dictionary:
	_tokens = tokens
	_pos = 0
	var commands: Array = []
	while not _at_end():
		if _peek().type == TT.SEMICOLON:
			_advance()
			continue
		var r := _parse_command()
		if not r.ok:
			return r
		var last: _DCKitAnalyzerNamespace.Lexer.Token = _tokens[_pos - 1]
		var val_len := last.value.length() + (2 if last.type == TT.STRING else 0)
		r.node.end_pos = last.position + val_len
		commands.append(r.node)
	return { ok = true, commands = commands }


# INTERNAL
func _parse_command() -> Dictionary:
	var t := _peek()
	if t.type != TT.IDENTIFIER:
		if t.type == TT.VARIABLE:
			return _fail("Command name cannot be a variable. Use a static name.", t.position)
		return _fail("Expected command name, got '%s'." % t.value, t.position)
	var cmd := CommandNode.new(t.value, t.position)
	_advance()
	while not _at_end() and _peek().type != TT.SEMICOLON:
		var r := _parse_arg()
		if not r.ok:
			return r
		cmd.args.append(r.node)
	return { ok = true, node = cmd }


func _parse_arg() -> Dictionary:
	var t := _peek()
	match t.type:
		TT.VARIABLE:
			_advance()
			return { ok = true, node = _make_var_node(t) }
		TT.LPAREN:
			return _parse_nested_command()
		TT.IDENTIFIER:
			if _peek_next().type == TT.LPAREN and _is_adjacent(t, _peek_next()):
				return _parse_constructor()
			if "." in t.value:
				return _fail(
					"'%s': dotted names are only valid as command names." % t.value,
					t.position,
				)
			_advance()
			return { ok = true, node = StringNode.new(t.value, false, t.position) }
		TT.NUMBER:
			_advance()
			return { ok = true, node = StringNode.new(t.value, false, t.position) }
		TT.STRING:
			_advance()
			return { ok = true, node = StringNode.new(t.value, true, t.position) }
		TT.RPAREN:
			return _fail("Unexpected ')'. No matching '('.", t.position)
		TT.COMMA:
			return _fail("Unexpected ','. Commas are only valid inside constructors.", t.position)
		TT.SEMICOLON:
			return _fail("Unexpected ';' inside an argument.", t.position)
		_:
			return _fail("Unexpected token '%s'." % t.value, t.position)


func _parse_constructor() -> Dictionary:
	var name_t := _peek()
	_advance()
	if "." in name_t.value:
		return _fail(
			"Constructor type '%s' cannot be a dotted name." % name_t.value,
			name_t.position,
		)
	var open_t := _peek()
	_advance()
	var ctor := ConstructorNode.new(name_t.value, name_t.position)

	if not _at_end() and _peek().type == TT.RPAREN:
		_advance()
		ctor.end_pos = _tokens[_pos - 1].position + 1
		return { ok = true, node = ctor }

	while not _at_end() and _peek().type != TT.RPAREN:
		if _peek().type == TT.COMMA:
			return _fail("Expected value before ',' in '%s'." % name_t.value, _peek().position)
		var r := _parse_constructor_part(name_t.value)
		if not r.ok:
			return r
		ctor.parts.append(r.node)
		if _peek().type == TT.COMMA:
			_advance()
		elif _peek().type != TT.RPAREN:
			return _fail("Expected ',' or ')' in '%s'." % name_t.value, _peek().position)

	if _at_end() or _peek().type != TT.RPAREN:
		return _fail("Unclosed constructor '%s'. Expected ')'." % name_t.value, open_t.position)
	_advance()
	ctor.end_pos = _tokens[_pos - 1].position + 1
	return { ok = true, node = ctor }


func _parse_constructor_part(owner: String) -> Dictionary:
	var t := _peek()
	match t.type:
		TT.VARIABLE:
			if _peek_next().type == TT.LPAREN and _is_adjacent(t, _peek_next()):
				return _fail(
					"Dynamic constructor type '$%s(...)' is not allowed." % t.value,
					t.position,
				)
			_advance()
			return { ok = true, node = _make_var_node(t) }
		TT.IDENTIFIER:
			if _peek_next().type == TT.LPAREN and _is_adjacent(t, _peek_next()):
				return _parse_constructor()
			if "." in t.value:
				return _fail(
					"'%s': dotted names are not valid inside constructors." % t.value,
					t.position,
				)
			_advance()
			return { ok = true, node = StringNode.new(t.value, false, t.position) }
		TT.NUMBER, TT.STRING:
			_advance()
			return { ok = true, node = StringNode.new(t.value, t.type == TT.STRING, t.position) }
		TT.LPAREN:
			return _parse_nested_command()
		TT.RPAREN:
			return _fail("Missing value before ')' in '%s'." % owner, t.position)
		TT.COMMA:
			return _fail("Missing value before ',' in '%s'." % owner, t.position)
		_:
			return _fail("Unexpected token inside '%s'." % owner, t.position)


func _parse_nested_command() -> Dictionary:
	var open_t := _peek()
	_advance()
	if _at_end():
		return _fail("Empty nested command after '('.", open_t.position)
	var name_t := _peek()
	if name_t.type != TT.IDENTIFIER:
		return _fail(
			"Expected command name inside '(...)', got '%s'." % name_t.value,
			name_t.position,
		)
	var cmd := CommandNode.new(name_t.value, name_t.position)
	_advance()
	while not _at_end() and _peek().type != TT.RPAREN:
		var r := _parse_arg()
		if not r.ok:
			return r
		cmd.args.append(r.node)
	if _at_end() or _peek().type != TT.RPAREN:
		return _fail("Unclosed nested command '%s'. Expected ')'." % cmd.name, open_t.position)
	_advance()
	cmd.end_pos = _tokens[_pos - 1].position + 1
	return { ok = true, node = cmd }


# HELPERS
func _make_var_node(t) -> VariableNode:
	var node := VariableNode.new(t.value, t.is_silent, t.position)
	if t.fallback != null and not t.fallback.nested_tokens.is_empty():
		node.fallback = _parse_cmd_from_tokens(t.fallback.nested_tokens)
	else:
		node.fallback = _token_to_node(t.fallback)
	return node


## Parses `tokens` as a command by temporarily substituting them for the
## parser's live token stream, then restoring — no new Parser object needed.
func _parse_cmd_from_tokens(tokens: Array) -> Object:
	var saved_tokens := _tokens
	var saved_pos := _pos
	_tokens = tokens
	_pos = 0
	var r := _parse_command()
	_tokens = saved_tokens
	_pos = saved_pos
	return r.node if r.ok else null


func _token_to_node(token) -> Object:
	if token == null:
		return null
	match token.type:
		TT.VARIABLE:
			return _make_var_node(token)
		TT.STRING:
			return StringNode.new(token.value, true, token.position)
		_:
			return StringNode.new(token.value, false, token.position)


func _is_adjacent(a, b) -> bool:
	return a.position + a.value.length() == b.position


func _peek() -> _DCKitAnalyzerNamespace.Lexer.Token:
	return _tokens[_pos]


func _peek_next() -> _DCKitAnalyzerNamespace.Lexer.Token:
	return _tokens[_pos + 1] if _pos + 1 < _tokens.size() else _tokens.back()


func _advance() -> void:
	if _pos < _tokens.size() - 1:
		_pos += 1


func _at_end() -> bool:
	return _tokens[_pos].type == TT.END


func _fail(msg: String, pos: int) -> Dictionary:
	return { ok = false, error = ParseError.new(msg, pos) }


#region TYPES
class ParseError:
	var message: String
	var position: int


	func _init(msg: String, pos: int) -> void:
		position = pos
		message = "[pos %d] %s" % [pos, msg]


	func _to_string() -> String:
		return message


class CommandNode:
	var name: String
	var args: Array = [] # StringNode | VariableNode | ConstructorNode | CommandNode
	var start_pos: int = -1
	var end_pos: int = -1


	func _init(p_name: String, p_start: int) -> void:
		name = p_name
		start_pos = p_start


	func _to_string() -> String:
		return "Command(%s)[%d args]" % [name, args.size()]


class StringNode:
	var value: String
	var quoted: bool
	var start_pos: int = -1
	var end_pos: int = -1


	func _init(p_value: String, p_quoted := false, p_start: int = -1, p_end: int = -1) -> void:
		value = p_value
		quoted = p_quoted
		start_pos = p_start
		end_pos = p_end if p_end != -1 else p_start + p_value.length()


class ConstructorNode:
	var type_name: String
	var parts: Array = [] # StringNode | VariableNode | ConstructorNode | CommandNode
	var start_pos: int = -1
	var end_pos: int = -1


	func _init(p_type: String, p_start: int) -> void:
		type_name = p_type
		start_pos = p_start


class VariableNode:
	var name: String
	var is_silent: bool = false
	var fallback = null # StringNode | VariableNode | CommandNode | null (recursive chain)
	var start_pos: int = -1
	var end_pos: int = -1


	func _init(p_name: String, p_silent := false, p_start: int = -1) -> void:
		name = p_name
		is_silent = p_silent
		start_pos = p_start
		end_pos = p_start + p_name.length() + 1
#endregion
