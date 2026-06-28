extends SyntaxHighlighter

const _Lexer := preload("../../core/analyzer/lexer.gd")
const TT    := _Lexer.TokenType

@export var color_command    := Color("BD93F9") # classic dracula purple
@export var color_ctor_type  := Color("8BE9FD") # cyan
@export var color_string     := Color("50FA7B") # bright green
@export var color_number     := Color("FFB86C") # orange
@export var color_variable   := Color("FF79C6") # pink
@export var color_silent_var := Color("8BE9FD") # cyan
@export var color_var_sigil  := Color("6272A4") # muted blue-gray
@export var color_default    := Color("F8F8F2")
@export var color_comment    := Color("6272A4")


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text := get_text_edit().get_line(line)
	if text.is_empty():
		return { 0: { "color": color_default } } 	
	
	var spans: Dictionary = { 0: { "color": color_default } }

	var lex_r := _Lexer.new().lex(text)
	var tokens: Array = lex_r.get("tokens", [])

	var last_end := _add_token_spans(spans, text, tokens)

	if not lex_r.ok:
		var err_pos: int = lex_r.error.position
		if err_pos < text.length() and text[err_pos] in ["-", "+"]:
			spans[err_pos] = { "color": color_number }
			if err_pos + 1 <= text.length():
				spans[err_pos + 1] = { "color": color_default }

	var hash_pos := text.find("#")
	if hash_pos != -1 and hash_pos >= last_end:
		spans[hash_pos] = { "color": color_comment }

	return spans
	
	
func _add_var_spans(spans: Dictionary, text: String, tok) -> void:
	var p: int = tok.position
	var i: int = p + 1

	if i >= text.length():
		spans[p] = { "color": color_var_sigil }
		return

	var is_braced := text[i] == "{"

	if is_braced:
		spans[p] = { "color": color_var_sigil } # ${
		i += 1
		i = _skip_ws(text, i)

		var has_silent := i < text.length() and text[i] == "?"
		if has_silent:
			spans[i] = { "color": color_var_sigil }
			i += 1
			i = _skip_ws(text, i)

		var name_start := i
		var name_end :int= name_start + tok.value.length()

		spans[name_start] = { "color": color_silent_var if has_silent else color_variable }
		spans[name_end] = { "color": color_default }

		if tok.fallback != null:
			var colon_pos := _find_colon(text, name_end, tok.fallback.position)
			if colon_pos >= 0:
				spans[colon_pos] = { "color": color_var_sigil }

			_add_fallback_spans(spans, text, tok.fallback)

			var close_pos := _find_matching_brace(text, tok.fallback.position)
			if close_pos >= 0:
				spans[close_pos] = { "color": color_var_sigil }
				spans[close_pos + 1] = { "color": color_default }
		else:
			var close_pos := _find_matching_brace(text, name_end)
			if close_pos >= 0:
				spans[close_pos] = { "color": color_var_sigil }
				spans[close_pos + 1] = { "color": color_default }

		return

	# compact form: $name, $?name, $?name:fallback
	spans[p] = { "color": color_var_sigil }

	var has_silent := i < text.length() and text[i] == "?"
	if has_silent:
		spans[i] = { "color": color_var_sigil }
		i += 1

	var name_start := i
	var name_end :int= name_start + tok.value.length()

	spans[name_start] = { "color": color_silent_var if has_silent else color_variable }
	spans[name_end] = { "color": color_default }

	if tok.fallback != null:
		var colon_pos := _find_colon(text, name_end, tok.fallback.position)
		if colon_pos >= 0:
			spans[colon_pos] = { "color": color_var_sigil }
		_add_fallback_spans(spans, text, tok.fallback)

func _add_token_spans(spans: Dictionary, text: String, tokens: Array) -> int:
	var expect_command := true
	var last_end := 0

	for i in tokens.size():
		var tok = tokens[i]

		if tok.type == TT.END:
			last_end = tok.position
			break

		var nxt  = tokens[i + 1] if i + 1 < tokens.size() else null
		var prev = tokens[i - 1] if i > 0 else null

		var is_ctor_open: bool = nxt != null and nxt.type == TT.LPAREN and tok.position + tok.value.length() == nxt.position
		var is_ctor_paren: bool = tok.type == TT.LPAREN and prev != null and prev.type == TT.IDENTIFIER and prev.position + prev.value.length() == tok.position

		if tok.type == TT.VARIABLE:
			_add_var_spans(spans, text, tok)
		else:
			var color := color_default
			var extra_len := 0
			match tok.type:
				TT.IDENTIFIER:
					if is_ctor_open:
						color = color_ctor_type
					elif expect_command:
						color = color_command
						expect_command = false
				TT.STRING:
					color = color_string
					extra_len = 2
				TT.NUMBER:
					color = color_number
				TT.LPAREN:
					if not is_ctor_paren:
						expect_command = true
				TT.SEMICOLON:
					expect_command = true
				_:
					pass

			spans[tok.position] = { "color": color }
			spans[tok.position + tok.value.length() + extra_len] = { "color": color_default }

		last_end = max(last_end, tok.position + tok.value.length())

	return last_end


func _add_fallback_spans(spans: Dictionary, text: String, tok) -> void:
	match tok.type:
		TT.VARIABLE:
			_add_var_spans(spans, text, tok)
		TT.STRING:
			spans[tok.position] = { "color": color_string }
			spans[tok.position + tok.value.length() + 2] = { "color": color_default } 
		TT.NUMBER:
			spans[tok.position] = { "color": color_number }
			spans[tok.position + tok.value.length()] = { "color": color_default }
		TT.LPAREN:
			spans[tok.position] = { "color": color_default }
			spans[tok.position + 1] = { "color": color_default }
			if tok.nested_tokens != null and not tok.nested_tokens.is_empty():
				_add_token_spans(spans, text, tok.nested_tokens)
				var close_pos := _find_matching_paren(text, tok.position)
				if close_pos >= 0:
					spans[close_pos] = { "color": color_default }
					spans[close_pos + 1] = { "color": color_default }
		TT.IDENTIFIER, _:
			spans[tok.position] = { "color": color_default }

func _skip_ws(text: String, i: int) -> int:
	while i < text.length() and text[i] in [" ", "\t"]:
		i += 1
	return i


func _find_colon(text: String, from_pos: int, to_pos: int) -> int:
	var i := from_pos
	while i < to_pos and i < text.length():
		if text[i] == ":":
			return i
		i += 1
	return -1

func _find_matching_paren(text: String, start_pos: int) -> int:
	var i := start_pos
	var depth := 0

	while i < text.length():
		var c := text[i]

		if c == "(":
			depth += 1
		elif c == ")":
			if depth == 0:
				return i
			depth -= 1
		elif c in ['"', "'", "`"]:
			var q := c
			i += 1
			while i < text.length() and text[i] != q:
				if text[i] == "\\":
					i += 1
				i += 1

		i += 1

	return -1

func _find_matching_brace(text: String, start_pos: int) -> int:
	var i := start_pos
	var depth := 0

	while i < text.length():
		var c := text[i]

		if c == "{":
			depth += 1
		elif c == "}":
			if depth == 0:
				return i
			depth -= 1
		elif c in ['"', "'", "`"]:
			var q := c
			i += 1
			while i < text.length() and text[i] != q:
				if text[i] == "\\":
					i += 1
				i += 1

		i += 1

	return -1
