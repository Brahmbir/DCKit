extends SyntaxHighlighter

enum ColorScheme {
	TOKYO_NIGHT,
	CUBER,
	NORD,
	CATPPUCCIN_MOCHA,
}

const TT := _DCKitAnalyzerNamespace.Lexer.TokenType

@export var palette := ColorScheme.TOKYO_NIGHT

var color_dict := {
	ColorScheme.TOKYO_NIGHT: {
		"color_command": Color("7DCFFF"),
		"color_ctor_type": Color("E0AF68"),
		"color_string": Color("9ECE6A"),
		"color_number": Color("FF9E64"),
		"color_variable": Color("BB9AF7"),
		"color_var_sigil": Color("D8C8FF"),
		"color_default": Color("D8DFF9"),
		"color_comment": Color("565F89"),
	},
	ColorScheme.CUBER: {
		"color_command": Color("4FC3F7"),
		"color_ctor_type": Color("FFD54F"),
		"color_string": Color("69F0AE"),
		"color_number": Color("FFAB40"),
		"color_variable": Color("B388FF"),
		"color_var_sigil": Color("D1C4E9"),
		"color_default": Color("ECEFF1"),
		"color_comment": Color("78909C"),
	},
	ColorScheme.NORD: {
		"color_command": Color("88C0D0"),
		"color_ctor_type": Color("EBCB8B"),
		"color_string": Color("A3BE8C"),
		"color_number": Color("D08770"),
		"color_variable": Color("B48EAD"),
		"color_var_sigil": Color("D8B4E2"),
		"color_default": Color("ECEFF4"),
		"color_comment": Color("616E88"),
	},
	ColorScheme.CATPPUCCIN_MOCHA: {
		"color_command": Color("89B4FA"),
		"color_ctor_type": Color("F9E2AF"),
		"color_string": Color("A6E3A1"),
		"color_number": Color("FAB387"),
		"color_variable": Color("CBA6F7"),
		"color_var_sigil": Color("E5C8FF"),
		"color_default": Color("CDD6F4"),
		"color_comment": Color("7F849C"),
	},
}


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text := get_text_edit().get_line(line)
	if text.is_empty():
		return { 0: { "color": color_dict[palette].color_default } }

	var spans: Dictionary = { 0: { "color": color_dict[palette].color_default } }

	var lex_r := _DCKitAnalyzerNamespace.Lexer.new().lex(text)
	var tokens: Array = lex_r.get("tokens", [])

	var last_end := _add_token_spans(spans, text, tokens)

	if not lex_r.ok:
		var err_pos: int = lex_r.error.position
		if err_pos < text.length() and text[err_pos] in ["-", "+"]:
			spans[err_pos] = { "color": color_dict[palette].color_number }
			if err_pos + 1 <= text.length():
				spans[err_pos + 1] = { "color": color_dict[palette].color_default }

	var hash_pos := text.find("#")
	if hash_pos != -1 and hash_pos >= last_end:
		spans[hash_pos] = { "color": color_dict[palette].color_comment }

	return spans


func _add_var_spans(spans: Dictionary, text: String, tok) -> void:
	var p: int = tok.position
	var i: int = p + 1

	if i >= text.length():
		spans[p] = { "color": color_dict[palette].color_var_sigil }
		return

	var is_braced := text[i] == "{"

	if is_braced:
		spans[p] = { "color": color_dict[palette].color_var_sigil } # ${
		i += 1
		i = _skip_ws(text, i)

		var name_start := i
		var name_end: int = name_start + tok.value.length()

		spans[name_start] = { "color": color_dict[palette].color_variable }

		var mod_pos := _write_modifier_or_default(spans, text, _skip_ws(text, name_end), name_end)

		if tok.fallback != null:
			_add_fallback_spans(spans, text, tok.fallback)

			var close_pos := _find_matching_brace(text, tok.fallback.position)
			if close_pos >= 0:
				spans[close_pos] = { "color": color_dict[palette].color_var_sigil }
				spans[close_pos + 1] = { "color": color_dict[palette].color_default }
		else:
			var close_pos := _find_matching_brace(text, mod_pos)
			if close_pos >= 0:
				spans[close_pos] = { "color": color_dict[palette].color_var_sigil }
				spans[close_pos + 1] = { "color": color_dict[palette].color_default }

		return

	# compact form: $name, $name!, $name?, $name:fallback
	spans[p] = { "color": color_dict[palette].color_var_sigil }

	var name_start := i
	var name_end: int = name_start + tok.value.length()

	spans[name_start] = { "color": color_dict[palette].color_variable }

	_write_modifier_or_default(spans, text, name_end, name_end)

	if tok.fallback != null:
		_add_fallback_spans(spans, text, tok.fallback)


## At `scan_pos`, checks for a trailing '!' / '?' / ':' modifier. If found,
## writes sigil-colored span at its position followed by a default span
## right after it, and returns the position past it. If not found, writes a
## single default span at `name_end` (the end of the variable name) instead.
## Each key is written exactly once — never overwritten — to keep spans in
## strict ascending order for the TextEdit highlighter.
func _write_modifier_or_default(
	spans: Dictionary,
	text: String,
	scan_pos: int,
	name_end: int,
) -> int:
	if scan_pos < text.length() and text[scan_pos] in ["!", "?", ":"]:
		spans[scan_pos] = { "color": color_dict[palette].color_var_sigil }
		if scan_pos + 1 < text.length():
			spans[scan_pos + 1] = { "color": color_dict[palette].color_default }
		return scan_pos + 1
	spans[name_end] = { "color": color_dict[palette].color_default }
	return scan_pos


func _add_token_spans(spans: Dictionary, text: String, tokens: Array) -> int:
	var expect_command := true
	var last_end := 0

	for i in tokens.size():
		var tok = tokens[i]

		if tok.type == TT.END:
			last_end = tok.position
			break

		var nxt = tokens[i + 1] if i + 1 < tokens.size() else null
		var prev = tokens[i - 1] if i > 0 else null

		var is_ctor_open: bool = (
			nxt != null and nxt.type == TT.LPAREN
			and tok.position + tok.value.length() == nxt.position
		)
		var is_ctor_paren: bool = (
			tok.type == TT.LPAREN and prev != null and prev.type == TT.IDENTIFIER
			and prev.position + prev.value.length() == tok.position
		)

		if tok.type == TT.VARIABLE:
			_add_var_spans(spans, text, tok)
		else:
			var color: Color = color_dict[palette].color_default
			var extra_len := 0
			match tok.type:
				TT.IDENTIFIER:
					if is_ctor_open:
						color = color_dict[palette].color_ctor_type
					elif expect_command:
						color = color_dict[palette].color_command
						expect_command = false
				TT.STRING:
					color = color_dict[palette].color_string
					extra_len = 2
				TT.NUMBER:
					color = color_dict[palette].color_number
				TT.LPAREN:
					if not is_ctor_paren:
						expect_command = true
				TT.SEMICOLON:
					expect_command = true
				_:
					pass

			spans[tok.position] = { "color": color }
			spans[tok.position + tok.value.length() + extra_len] = {
				"color": color_dict[palette].color_default
			}

		last_end = max(last_end, tok.position + tok.value.length())

	return last_end


func _add_fallback_spans(spans: Dictionary, text: String, tok) -> void:
	match tok.type:
		TT.VARIABLE:
			_add_var_spans(spans, text, tok)
		TT.STRING:
			spans[tok.position] = { "color": color_dict[palette].color_string }
			spans[tok.position + tok.value.length() + 2] = {
				"color": color_dict[palette].color_default
			}
		TT.NUMBER:
			spans[tok.position] = { "color": color_dict[palette].color_number }
			spans[tok.position + tok.value.length()] = {
				"color": color_dict[palette].color_default
			}
		TT.LPAREN:
			spans[tok.position] = { "color": color_dict[palette].color_default }
			spans[tok.position + 1] = { "color": color_dict[palette].color_default }
			if tok.nested_tokens != null and not tok.nested_tokens.is_empty():
				_add_token_spans(spans, text, tok.nested_tokens)
				var close_pos := _find_matching_paren(text, tok.position)
				if close_pos >= 0:
					spans[close_pos] = { "color": color_dict[palette].color_default }
					spans[close_pos + 1] = { "color": color_dict[palette].color_default }
		TT.IDENTIFIER, _:
			spans[tok.position] = { "color": color_dict[palette].color_default }


func _skip_ws(text: String, i: int) -> int:
	while i < text.length() and text[i] in [" ", "\t"]:
		i += 1
	return i


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
