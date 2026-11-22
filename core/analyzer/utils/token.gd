extends RefCounted

enum Type {
	WORD,
	NUMBER,
	STRING, # '...' and `...` (literal, decoded)
	QUOTE_OPEN, # " — starts a template
	TEXT, # literal run inside a template (decoded)
	QUOTE_CLOSE,
	DOLLAR,
	LBRACE,
	NAME, # variable name
	QMARK,
	COLON,
	RBRACE,
	LBRACKET,
	RBRACKET,
	LCURLY, # '{' opening a dictionary
	RCURLY,
	LPAREN,
	RPAREN,
	COMMA,
	SEMI,
	COMMENT,
	END,
}

## What the highlighter paints. Lexer presets what it knows; the parser overrides WORD roles.
enum Role {
	NONE,
	COMMAND,
	CTOR_TYPE,
	STRING,
	NUMBER,
	VAR_SIGIL,
	VAR_NAME,
	COMMENT,
	PUNCT,
	KEY, # dictionary key (set by the parser)
	ERROR,
}

var type: int
var start: int
var end: int # exclusive, source offset
var value: String # decoded content (string body, variable name, word text)
var glued: bool # no whitespace between the previous token and this one
var role: int = Role.NONE


func _init(p_type: int, p_start: int, p_end: int, p_value := "", p_glued := false) -> void:
	type = p_type
	start = p_start
	end = p_end
	value = p_value
	glued = p_glued


func _to_string() -> String:
	return "%s%s[%d,%d)%s" % [
		"~" if glued else "",
		Type.keys()[type],
		start,
		end,
		(" '%s'" % value) if not value.is_empty() else "",
	]
