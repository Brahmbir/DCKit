extends RefCounted

enum Mode {
	CODE,
	TEMPLATE,
	BRACE,
	ARRAY,
	DICT,
	PAREN,
}

const Token := _DCKitNS.Analyzer.Token
const TokenType := Token.Type
const Role := Token.Role
const Diagnostic := DCAnalysisResult.Diagnostic

const C_BANG := 33
const C_DQUOTE := 34
const C_HASH := 35
const C_DOLLAR := 36
const C_LPAREN := 40
const C_RPAREN := 41
const C_COMMA := 44
const C_COLON := 58
const C_SEMI := 59
const C_QMARK := 63
const C_LBRACKET := 91
const C_BACKSLASH := 92
const C_RBRACKET := 93
const C_LBRACE := 123
const C_RBRACE := 125

# Per-ASCII-code flags. Non-ASCII has none: it is always plain word / text content.
const F_WS := 1
const F_END := 2 # always terminates a bare word
const F_IDS := 4 # variable-name start
const F_IDC := 8 # variable-name continuation
const F_MAYBE := 16 # terminates a bare word only in some modes (: ] })

const _ROLE := {
	TokenType.NUMBER: Role.NUMBER,
	TokenType.STRING: Role.STRING,
	TokenType.QUOTE_OPEN: Role.STRING,
	TokenType.TEXT: Role.STRING,
	TokenType.QUOTE_CLOSE: Role.STRING,
	TokenType.DOLLAR: Role.VAR_SIGIL,
	TokenType.LBRACE: Role.VAR_SIGIL,
	TokenType.RBRACE: Role.VAR_SIGIL,
	TokenType.BANG: Role.VAR_SIGIL,
	TokenType.QMARK: Role.VAR_SIGIL,
	TokenType.COLON: Role.VAR_SIGIL,
	TokenType.NAME: Role.VAR_NAME,
	TokenType.COMMENT: Role.COMMENT,
	TokenType.LPAREN: Role.PUNCT,
	TokenType.RPAREN: Role.PUNCT,
	TokenType.COMMA: Role.PUNCT,
	TokenType.SEMI: Role.PUNCT,
	TokenType.LBRACKET: Role.PUNCT,
	TokenType.RBRACKET: Role.PUNCT,
	TokenType.LCURLY: Role.PUNCT,
	TokenType.RCURLY: Role.PUNCT,
}

const _CLOSER := {
	Mode.TEMPLATE: "\"",
	Mode.BRACE: "}",
	Mode.ARRAY: "]",
	Mode.DICT: "}",
	Mode.PAREN: ")",
}

static var _cls: PackedByteArray = _build_cls()
static var _role_of: PackedInt32Array = _build_roles()
static var _number: RegEx = _build_number()

var tokens: Array = []
var diagnostics: Array = []

var _s := ""
var _last_end := -1
var _n := 0
var _i := 0
var _modes: Array[int] = []
var _opens: Array[int] = [] # source offset of the construct that pushed each mode


static func _build_cls() -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(128)
	for c in [32, 9, 10, 13]:
		t[c] = F_WS | F_END
	for c in [C_HASH, C_DQUOTE, 39, 96, C_DOLLAR, C_LPAREN, C_RPAREN, C_COMMA, C_SEMI]:
		t[c] |= F_END
	for c in [C_COLON, C_RBRACKET, C_RBRACE]:
		t[c] |= F_MAYBE
	for c in range(65, 91):
		t[c] |= F_IDS | F_IDC
	for c in range(97, 123):
		t[c] |= F_IDS | F_IDC
	t[95] |= F_IDS | F_IDC
	for c in range(48, 58):
		t[c] |= F_IDC
	return t


static func _build_roles() -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(TokenType.size())
	for type in _ROLE:
		t[type] = _ROLE[type]
	return t


static func _build_number() -> RegEx:
	var r := RegEx.new()
	r.compile("^[+-]?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?)$")
	return r


#region PUBLIC
## Never fails. Returns the token list (always ends with END); problems land in `diagnostics`.
func lex(text: String) -> Array:
	_s = text
	_n = text.length()
	_i = 0
	tokens = []
	diagnostics = []
	_last_end = -1
	_modes = [Mode.CODE]
	_opens = [0]

	while _i < _n:
		if _modes.back() == Mode.TEMPLATE:
			_step_template()
		else:
			_step_code()

	for k in range(1, _modes.size()):
		if _modes[k] != Mode.PAREN: # the parser owns unclosed '('
			_unclosed(k, _n, 0, "input ends here")
	_push(TokenType.END, _n, _n)
	return tokens
#endregion


#region CODE / BRACE / ARRAY / DICT / PAREN MODES
func _step_code() -> void:
	_skip_ws()
	if _i >= _n:
		return

	var c := _s.unicode_at(_i)
	match c:
		C_HASH:
			_push(TokenType.COMMENT, _i, _n, _s.substr(_i + 1))
			_i = _n
		C_LPAREN:
			_open(TokenType.LPAREN, Mode.PAREN)
		C_RPAREN:
			if not _close(c):
				_punct(TokenType.RPAREN)
		C_COMMA:
			_punct(TokenType.COMMA)
		C_SEMI:
			_punct(TokenType.SEMI)
		C_LBRACKET:
			_open(TokenType.LBRACKET, Mode.ARRAY)
		C_LBRACE:
			_open(TokenType.LCURLY, Mode.DICT)
		C_RBRACKET, C_RBRACE:
			if not _close(c):
				_lex_word()
		C_COLON:
			if _modes.back() == Mode.DICT:
				_punct(TokenType.COLON)
				tokens.back().role = Role.PUNCT
			else:
				_lex_word()
		C_DQUOTE:
			_push(TokenType.QUOTE_OPEN, _i, _i + 1)
			_modes.push_back(Mode.TEMPLATE)
			_opens.push_back(_i)
			_i += 1
		39, 96:
			_lex_string(c)
		C_DOLLAR:
			_lex_variable()
		_:
			_lex_word()


func _lex_word() -> void:
	var start := _i
	_i += 1 # callers guarantee the first char belongs to the word; this also guarantees progress
	while _i < _n:
		var c := _s.unicode_at(_i)
		if c < 128:
			var f := _cls[c]
			if (f & F_END) != 0 or ((f & F_MAYBE) != 0 and _stops(c)):
				break
		_i += 1
	var raw := _s.substr(start, _i - start)
	_push(TokenType.NUMBER if _is_number(raw) else TokenType.WORD, start, _i, raw)


func _stops(c: int) -> bool:
	match c:
		C_COLON:
			return _modes.back() == Mode.DICT
		C_RBRACKET:
			return _modes.has(Mode.ARRAY)
		_:
			return _modes.has(Mode.DICT) or _modes.has(Mode.BRACE)


func _is_number(raw: String) -> bool:
	var c := raw.unicode_at(0)
	if not ((c >= 48 and c <= 57) or c == 43 or c == 45 or c == 46):
		return false
	return _number.search(raw) != null


func _lex_string(quote: int) -> void:
	var start := _i
	_i += 1
	var body := ""
	var run := _i
	while _i < _n:
		var c := _s.unicode_at(_i)
		if c == C_BACKSLASH and _i + 1 < _n:
			body += _s.substr(run, _i - run) + _unescape(_s[_i + 1])
			_i += 2
			run = _i
		elif c == quote:
			body += _s.substr(run, _i - run)
			_i += 1
			_push(TokenType.STRING, start, _i, body)
			return
		else:
			_i += 1
	body += _s.substr(run, _i - run)
	_push(TokenType.STRING, start, _n, body)
	var q := char(quote)
	_diag("Unterminated string. Expected closing quote (%s)." % q, start, 1) \
			.with_related(_n, 0, "input ends here") \
			.with_fix("Add closing %s" % q, _n, _n, q)
#endregion


#region NESTING
func _open(type: int, mode: int) -> void:
	_modes.push_back(mode)
	_opens.push_back(_i)
	_punct(type)


# Closes the nearest matching construct. Anything still open above it is reported and
# discarded, so one stray bracket does not swallow the rest of the line.
func _close(c: int) -> bool:
	var k := -1
	for j in range(_modes.size() - 1, 0, -1):
		var m := _modes[j]
		if m == Mode.TEMPLATE:
			break # never close across a string boundary
		if (c == C_RBRACKET and m == Mode.ARRAY) \
				or (c == C_RPAREN and m == Mode.PAREN) \
				or (c == C_RBRACE and (m == Mode.DICT or m == Mode.BRACE)):
			k = j
			break
	if k < 0:
		return false

	for j in range(k + 1, _modes.size()):
		if _modes[j] != Mode.PAREN:
			_unclosed(j, _i, 1, "found '%s' here" % char(c))

	var type: int
	match _modes[k]:
		Mode.ARRAY:
			type = TokenType.RBRACKET
		Mode.PAREN:
			type = TokenType.RPAREN
		Mode.DICT:
			type = TokenType.RCURLY
		_:
			type = TokenType.RBRACE
	_modes.resize(k)
	_opens.resize(k)
	_punct(type)
	return true


func _unclosed(k: int, at: int, rel_len: int, rel_msg: String) -> void:
	if diagnostics.size() >= 100:
		return
	var open_at := _opens[k]
	var closers := _closers_from(k)
	var d: Diagnostic
	match _modes[k]:
		Mode.TEMPLATE:
			d = _diag("Unterminated string. Expected closing '\"'.", open_at, 1)
		Mode.BRACE:
			d = _diag("Unclosed '${'. Expected '}'.", open_at, 2)
		Mode.ARRAY:
			d = _diag("Unclosed '['. Expected ']'.", open_at, 1)
		_:
			d = _diag("Unclosed '{'. Expected '}'.", open_at, 1)
	d.with_related(at, rel_len, rel_msg).with_fix("Add closing '%s'" % closers, at, at, closers)


# Closing text, innermost first, for every open construct from `k` up to the top.
func _closers_from(k: int) -> String:
	var out := ""
	for j in range(_modes.size() - 1, k - 1, -1):
		out += _CLOSER[_modes[j]]
	return out
#endregion


#region VARIABLES
func _lex_variable() -> void:
	var start := _i
	_punct(TokenType.DOLLAR)
	if _i < _n and _s.unicode_at(_i) == C_LBRACE:
		_lex_braced(start)
	else:
		_lex_compact(start)


# $name  $name!  $name?  $name:fallback
func _lex_compact(start: int) -> void:
	var c := _s.unicode_at(_i) if _i < _n else -1
	if not _has(c, F_IDS):
		if c >= 48 and c <= 57:
			var end := _i
			while end < _n and _has(_s.unicode_at(end), F_IDC):
				end += 1
			_diag("Variable names cannot start with a digit.", start, end - start)
			_i = end
			return
		_diag("Expected a variable name after '$'.", start, 1) \
				.with_hint("To write a literal '$', put it in quotes: '$'.") \
				.with_fix("Quote the '$'", start, start + 1, "'$'")
		return
	var name_start := _i
	while _i < _n and _has(_s.unicode_at(_i), F_IDC):
		_i += 1
	_push(TokenType.NAME, name_start, _i, _s.substr(name_start, _i - name_start))
	_modifier()


# ${name}  ${name!}  ${name?}  ${name:fallback}   (whitespace allowed inside)
func _lex_braced(start: int) -> void:
	_push(TokenType.LBRACE, _i, _i + 1)
	_i += 1
	_modes.push_back(Mode.BRACE)
	_opens.push_back(start)
	_skip_ws()

	var name_start := _i
	while _i < _n:
		var c := _s.unicode_at(_i)
		if _has(c, F_END) or c == C_RBRACE or c == C_COLON or c == C_QMARK or c == C_BANG:
			break
		_i += 1
	var name := _s.substr(name_start, _i - name_start)

	if name.is_empty():
		_diag("Empty variable name in '${...}'.", start, maxi(_i - start, 2)) \
				.with_hint("Write a name between the braces, e.g. ${name}.")
	else:
		_push(TokenType.NAME, name_start, _i, name)
		var bad := _first_invalid_name_char(name)
		if bad >= 0:
			tokens.back().role = Role.ERROR
			var ch := name[bad]
			var msg := "Variable names cannot start with a digit."
			if not (bad == 0 and ch.is_valid_int()):
				msg =  "Invalid character '%s' in variable name '%s'." % [ch, name]
			_diag(msg, name_start + bad, 1) \
					.with_hint("Names use letters, digits and '_', and cannot start with a digit.")
	_skip_ws()
	_modifier()


func _modifier() -> void:
	if _i >= _n:
		return
	match _s.unicode_at(_i):
		C_BANG:
			_punct(TokenType.BANG)
		C_QMARK:
			_punct(TokenType.QMARK)
		C_COLON:
			_punct(TokenType.COLON)


func _first_invalid_name_char(name: String) -> int:
	for i in name.length():
		var c := name.unicode_at(i)
		var ok := _has(c, F_IDS if i == 0 else F_IDC)
		if not ok:
			return i
	return -1
#endregion


#region TEMPLATE MODE
# Text until '"' or '${'. Only the braced form interpolates; '\$' escapes a dollar.
func _step_template() -> void:
	var start := _i
	var body := ""
	var run := _i
	var stop := 0 # 0 = end of input, 1 = closing quote, 2 = '${'
	while _i < _n:
		var c := _s.unicode_at(_i)
		if c == C_DQUOTE:
			stop = 1
			break
		if c == C_BACKSLASH and _i + 1 < _n:
			body += _s.substr(run, _i - run) + _unescape(_s[_i + 1])
			_i += 2
			run = _i
		elif c == C_DOLLAR:
			var nxt := _s.unicode_at(_i + 1) if _i + 1 < _n else -1
			if nxt == C_LBRACE:
				stop = 2
				break
			if _has(nxt, F_IDS):
				_hint_bare_dollar(_i)
			_i += 1
		else:
			_i += 1
	body += _s.substr(run, _i - run)

	if _i > start:
		_push(TokenType.TEXT, start, _i, body)

	match stop:
		1:
			_modes.pop_back()
			_opens.pop_back()
			_punct(TokenType.QUOTE_CLOSE)
		2:
			_lex_variable()


func _hint_bare_dollar(at: int) -> void:
	var e := at + 1
	while e < _n and _has(_s.unicode_at(e), F_IDC):
		e += 1
	var name := _s.substr(at + 1, e - at - 1)
	_diag("'$%s' is not interpolated inside a string." % name, at, e - at, Diagnostic.Severity.HINT) \
			.with_hint("Use ${%s} to insert the variable, or '\\$' for a literal dollar." % name) \
			.with_fix("Change to ${%s}" % name, at, e, "${%s}" % name)
#endregion


#region HELPERS
func _push(type: int, start: int, end: int, value := "") -> void:
	var t := Token.new(type, start, end, value, start == _last_end)
	t.role = _role_of[type]
	tokens.append(t)
	_last_end = end


func _punct(type: int) -> void:
	_push(type, _i, _i + 1)
	_i += 1


func _skip_ws() -> void:
	while _i < _n and _has(_s.unicode_at(_i), F_WS):
		_i += 1


func _has(c: int, flag: int) -> bool:
	return c >= 0 and c < 128 and (_cls[c] & flag) != 0


func _unescape(c: String) -> String:
	match c:
		"n":
			return "\n"
		"t":
			return "\t"
		"r":
			return "\r"
		_:
			return c # \\ \" \' \` \$ and anything else: the character itself


func _diag(msg: String, pos: int, len: int, sev := Diagnostic.Severity.ERROR) -> Diagnostic:
	var d := Diagnostic.new(msg, pos, len, sev, Diagnostic.Source.LEXER)
	diagnostics.append(d)
	return d
#endregion
