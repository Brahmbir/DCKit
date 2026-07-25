extends RefCounted

#region TYPES

enum TokenType {
	IDENTIFIER, NUMBER, STRING, VARIABLE,
	LPAREN, RPAREN, COMMA, SEMICOLON, END,
}

class Token:
	var type          : int
	var value         : String
	var position      : int
	var is_silent     : bool = false
	var fallback             = null   # Token | null — set for $?... variables; may itself have a fallback
	var prefix_len    : int  = 0
	## Set only on a fallback-sentinel LPAREN token produced by _read_nested_cmd_fallback().
	## Holds the inner token stream (IDENTIFIER … END) of the nested command.
	var nested_tokens : Array = []

	func _init(t: int, v: String, p: int, silent := false) -> void:
		type = t; value = v; position = p; is_silent = silent

	func _to_string() -> String:
		return "[%d] %s:'%s'%s%s%s" % [position, TokenType.keys()[type], value,
				" (silent)"     if is_silent                  else "",
				" (fallback)"   if fallback != null            else "",
				" (nested_cmd)" if not nested_tokens.is_empty() else ""]


class LexError:
	var message  : String
	var position : int

	func _init(msg: String, pos: int) -> void:
		position = pos; message = "[pos %d] %s" % [pos, msg]

	func _to_string() -> String: return message

#endregion


var _input := ""
var _pos   := 0


# Returns { ok=true, tokens=Array } or { ok=false, error=LexError }
func lex(input: String) -> Dictionary:
	_input = input if input else ""
	_pos   = 0
	var tokens : Array = []

	while not _at_end():
		_skip_whitespace()
		if _at_end(): break
		var c := _peek()

		if c == "#":
			break
		if c == ";":
			#return _with_tokens(_err("; is not supported",_pos), tokens)
			tokens.append(Token.new(TokenType.SEMICOLON, c, _pos)); _pos += 1; continue
		if c == "(":
			tokens.append(Token.new(TokenType.LPAREN, c, _pos)); _pos += 1; continue
		if c == ")":
			tokens.append(Token.new(TokenType.RPAREN, c, _pos)); _pos += 1; continue
		if c == ",":
			tokens.append(Token.new(TokenType.COMMA, c, _pos)); _pos += 1; continue
		if _is_quote(c):
			var r := _read_string()
			if not r.ok: return _with_tokens(r, tokens)
			tokens.append(r.token); continue
		if c == "$":
			var r := _read_variable()
			if not r.ok: return _with_tokens(r, tokens)
			tokens.append(r.token); continue
		if _is_atom_start(c):
			var r := _read_atom()
			if not r.ok: return _with_tokens(r, tokens)
			tokens.append(r.token); continue

		return _with_tokens(_err("Unexpected character '%s'." % c, _pos), tokens)

	tokens.append(Token.new(TokenType.END, "", _pos))
	return { ok = true, tokens = tokens }


# READERS

func _read_string() -> Dictionary:
	var start := _pos
	var quote := _eat()
	var sb    := ""
	while not _at_end():
		var c := _eat()
		if c == "\\":
			if not _at_end(): sb += _unescape(_eat())
			continue
		if c == quote:
			return { ok = true, token = Token.new(TokenType.STRING, sb, start) }
		sb += c
	return _err("Unterminated string.", start)


# Supports:
#   $name          → missing = FAIL
#   $name!         → missing = FAIL (explicit)
#   $name?         → missing = ""
#   $name:fallback → missing = resolve fallback recursively
#   ${name}, ${name!}, ${name?}, ${name:fallback}
# Braces allow whitespace around the inner syntax.
func _read_variable() -> Dictionary:
	var start := _pos
	_eat()  # '$'
	if _at_end():
		return _err("Expected variable name after '$'.", start)

	if _peek() == "{":
		return _read_braced_variable(start)

	return _read_compact_variable(start)


func _read_braced_variable(start: int) -> Dictionary:
	_eat()  # '{'
	_skip_whitespace()

	var inner := _pos
	var sb := ""
	while not _at_end() and _peek() not in ["}", ":", "?", "!"]:
		sb += _eat()

	var name := sb.strip_edges()
	if name.is_empty():
		return _err("Empty variable name in '${...}'.", inner)
	if not _is_valid_var(name):
		return _err("Invalid variable name '%s'." % name, inner)

	_skip_whitespace()
	var r := _read_var_modifier(name, start, true)
	if not r.ok: return r
	var tok : Token = r.token

	_skip_whitespace()
	if _at_end() or _peek() != "}":
		return _unclosed_brace_error(tok, name, start)
	_eat()

	return { ok = true, token = tok }


## Produces a targeted message for content trailing a variable's modifier
## inside '${...}' instead of the closing brace, based on which modifier
## (if any) was already consumed.
func _unclosed_brace_error(tok: Token, name: String, start: int) -> Dictionary:
	if tok.fallback != null:
		return _err("Unexpected content after fallback in '${%s:...}'. Expected '}'." % name, _pos)
	if tok.is_silent:
		return _err("'?' takes no value — did you mean '${%s:...}' for a fallback? Expected '}' after '?'." % name, _pos)
	if not _at_end() and _peek() in ["?", "!", ":"]:
		return _err("Only one modifier ('!', '?', or ':fallback') is allowed per variable.", _pos)
	return _err("Unclosed '${...}'. Expected '}'.", start)


func _read_compact_variable(start: int) -> Dictionary:
	if not _is_ident_start(_peek()):
		return _err("Invalid char after '$'.", start)

	var name := ""
	while not _at_end() and _is_var_char(_peek()):
		name += _eat()

	if not _is_valid_var(name):
		return _err("Invalid variable name '%s'." % name, start)

	return _read_var_modifier(name, start)


## Reads the optional trailing modifier after a variable name:
##   (nothing) / '!' → required, missing = FAIL
##   '?'             → optional, missing = ""
##   ':fallback'     → optional, missing = resolved fallback node
func _read_var_modifier(name: String, start: int, allow_whitespace := false) -> Dictionary:
	var tok := Token.new(TokenType.VARIABLE, name, start, false)

	if allow_whitespace: _skip_whitespace()
	if _at_end(): return { ok = true, token = tok }

	match _peek():
		"!":
			_eat()
		"?":
			_eat()
			tok.is_silent = true
		":":
			_eat()
			tok.is_silent = true
			var fb := _read_fallback(allow_whitespace)
			if not fb.ok: return fb
			tok.fallback = fb.token
		_:
			pass

	return { ok = true, token = tok }


func _read_fallback(allow_whitespace := false) -> Dictionary:
	if allow_whitespace:
		_skip_whitespace()

	if _at_end():
		return _err("Expected fallback value after ':'.", _pos)

	if _peek() == "$":
		return _read_variable()

	if _is_quote(_peek()):
		var r := _read_string()
		if not r.ok: return r
		return { ok = true, token = r.token }

	if _peek() == "(":
		return _read_nested_cmd_fallback()

	var start := _pos
	var raw := ""
	while not _at_end() and not _is_atom_delim(_peek()):
		raw += _eat()

	if raw.is_empty():
		return _err("Empty fallback value.", _pos)

	return _classify_raw_atom(raw, start)


func _read_nested_cmd_fallback() -> Dictionary:
	var start := _pos
	_eat()  # consume '('
	var inner : Array = []
	var depth := 1

	while not _at_end() and depth > 0:
		_skip_whitespace()
		if _at_end(): break
		var c := _peek()
		if c == "(":
			inner.append(Token.new(TokenType.LPAREN, c, _pos)); _eat()
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0: _eat(); break
			inner.append(Token.new(TokenType.RPAREN, c, _pos)); _eat()
		elif c == ";":
			return _err("Command chains (';') are not allowed in a fallback command.", _pos)
		elif c == ",":
			inner.append(Token.new(TokenType.COMMA, c, _pos)); _eat()
		elif _is_quote(c):
			var r := _read_string()
			if not r.ok: return r
			inner.append(r.token)
		elif c == "$":
			var r := _read_variable()
			if not r.ok: return r
			inner.append(r.token)
		elif _is_atom_start(c):
			var r := _read_atom()
			if not r.ok: return r
			inner.append(r.token)
		else:
			return _err("Unexpected character '%s' in nested command fallback." % c, _pos)

	if depth > 0:
		return _err("Unclosed '(' in variable fallback.", start)

	inner.append(Token.new(TokenType.END, "", _pos))
	var sentinel := Token.new(TokenType.LPAREN, "", start)
	sentinel.nested_tokens = inner
	return { ok = true, token = sentinel }


func _read_atom() -> Dictionary:
	var start := _pos
	var raw := ""
	while not _at_end() and not _is_atom_delim(_peek()):
		raw += _eat()

	if raw.is_empty():
		return _err("Unexpected character '%s'." % _peek(), _pos)

	return _classify_raw_atom(raw, start)


func _classify_raw_atom(raw: String, start: int) -> Dictionary:
	if raw == "+" or raw == "-":
		return _err("Expected number after '%s'." % raw, start)

	if _is_number_literal(raw):
		return { ok = true, token = Token.new(TokenType.NUMBER, raw, start) }

	if _is_bare_identifier(raw):
		return { ok = true, token = Token.new(TokenType.IDENTIFIER, raw, start) }

	return _err("Unexpected token '%s'." % raw, start)


func _is_number_literal(raw: String) -> bool:
	var s := raw
	if s.is_empty():
		return false

	if s[0] == "+" or s[0] == "-":
		if s.length() == 1:
			return false
		s = s.substr(1)

	if s.begins_with("0x") or s.begins_with("0X"):
		if s.length() <= 2:
			return false
		for i in range(2, s.length()):
			if not _is_hex_digit(s[i]):
				return false
		return true

	if s.begins_with("0b") or s.begins_with("0B"):
		if s.length() <= 2:
			return false
		for i in range(2, s.length()):
			if s[i] not in ["0", "1"]:
				return false
		return true

	var dot_count := 0
	var digit_count := 0
	for i in range(s.length()):
		var c := s[i]
		if _is_digit(c):
			digit_count += 1
		elif c == "." and dot_count == 0:
			dot_count += 1
		else:
			return false

	return digit_count > 0


func _is_bare_identifier(raw: String) -> bool:
	if raw.is_empty():
		return false
	var start := 0
	if raw[0] == "+" or raw[0] == "-":
		if raw.length() == 1:
			return false
		start = 1
	if raw[0] == ".":
		return false
	for i in range(start, raw.length()):
		if not _is_bare_ident_char(raw[i]):
			return false
	return true


# HELPERS

func _is_ident_char(c: String) -> bool:
	if c.length() != 1: return false
	var n := c.unicode_at(0)
	return (n >= 65 and n <= 90) or (n >= 97 and n <= 122) or (n >= 48 and n <= 57) or c == "_" or c == "."

func _is_ident_start(c: String) -> bool:
	if c.length() != 1: return false
	var n := c.unicode_at(0)
	return (n >= 65 and n <= 90) or (n >= 97 and n <= 122) or c == "_"

func _is_var_char(c: String) -> bool:
	if c.length() != 1: return false
	var n := c.unicode_at(0)
	return (n >= 65 and n <= 90) or (n >= 97 and n <= 122) or (n >= 48 and n <= 57) or c == "_"

func _is_bare_ident_char(c: String) -> bool:
	if c.length() != 1: return false
	var n := c.unicode_at(0)
	return (n >= 65 and n <= 90) or (n >= 97 and n <= 122) or (n >= 48 and n <= 57) or c == "_" or c == "." or c == "-"

func _is_atom_start(c: String) -> bool:
	if c.length() != 1: return false
	return not _is_atom_delim(c)

func _is_atom_delim(c: String) -> bool:
	return c == "" or c in [" ", "\t", "\r", "\n", "#", ";", "(", ")", ",", "{", "}", "$", ":", '"', "'", "`"]

func _is_digit(c: String) -> bool:
	if c.length() != 1: return false
	return c.unicode_at(0) >= 48 and c.unicode_at(0) <= 57

func _is_hex_digit(c: String) -> bool:
	if c.length() != 1: return false
	var n := c.unicode_at(0)
	return (n >= 48 and n <= 57) or (n >= 65 and n <= 70) or (n >= 97 and n <= 102)

func _is_quote(c: String) -> bool: return c in ['"', "'", "`"]

func _is_valid_var(name: String) -> bool:
	if name.is_empty():
		return false
	if not _is_ident_start(name[0]):
		return false
	for i in range(1, name.length()):
		if not _is_var_char(name[i]):
			return false
	return true

func _peek()  -> String: return _input[_pos] if _pos < _input.length() else ""
func _eat()   -> String: var c := _input[_pos]; _pos += 1; return c
func _at_end() -> bool:  return _pos >= _input.length()

func _skip_whitespace() -> void:
	while not _at_end() and _peek() in [" ", "\t", "\r", "\n"]: _pos += 1

func _unescape(c: String) -> String:
	match c:
		"n":  return "\n"
		"t":  return "\t"
		"r":  return "\r"
		"\\": return "\\"
		'"':  return '"'
		"'":  return "'"
		_:    return c

func _err(msg: String, pos: int) -> Dictionary:
	return { ok = false, error = LexError.new(msg, pos) }

# Attaches whatever tokens were successfully read before a lex failure —
# lets the highlighter render up to the error point instead of going blank.
func _with_tokens(result: Dictionary, tokens: Array) -> Dictionary:
	result["tokens"] = tokens
	return result
