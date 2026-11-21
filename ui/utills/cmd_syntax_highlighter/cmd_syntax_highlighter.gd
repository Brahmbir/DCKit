extends "../../ui_base_class/highlighter_base.gd"

var _pos := PackedInt32Array() # offset where each span starts, ascending
var _roles := PackedInt32Array() # role in effect from that offset
var _version := -1 # TextEdit version the spans belong to
var _lexer := _DCKitNS.Analyzer.Lexer.new()
var _parser := _DCKitNS.Analyzer.Parser.new()


#region PUBLIC
## Hand over an analysis of the current text (DCAnalysisResult). Ignored when it does not match it.
func set_analysis(result: DCAnalysisResult) -> void:
	var te := get_text_edit()
	if te == null or result == null or result.tokens.is_empty():
		return
	var tokens: Array = result.tokens
	if tokens.back().start != te.text.length():
		return
	_build(tokens)
	_version = te.get_version()
	clear_highlighting_cache()


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var te := get_text_edit()
	if _colors.is_empty():
		_rebuild_colors()
	if te.get_version() != _version:
		_build(_analyze(te.text))
		_version = te.get_version()

	var base := 0
	for i in line:
		base += te.get_line(i).length() + 1
	var end := base + te.get_line(line).length()

	var out := { 0: { "color": _colors[Role.NONE] } }
	var k := _pos.bsearch(base, false) # first span starting after the line start
	if k > 0:
		out[0] = { "color": _colors[_roles[k - 1]] }
	while k < _pos.size() and _pos[k] < end:
		out[_pos[k] - base] = { "color": _colors[_roles[k]] }
		k += 1
	return out
#endregion


#region INTERNALS
func _analyze(text: String) -> Array:
	var tokens := _lexer.lex(text)
	_parser.parse_chain(tokens, text) # assigns the roles the lexer cannot know
	return tokens


# Spans are role changes along the text; equal neighbours are merged.
func _build(tokens: Array) -> void:
	_pos.clear()
	_roles.clear()
	var last_end := 0
	for t in tokens:
		if t.type == TT.END:
			break
		if t.start > last_end:
			_add(last_end, Role.NONE)
		_add(t.start, t.role)
		last_end = t.end
	if last_end < tokens.back().start:
		_add(last_end, Role.NONE)


func _add(pos: int, role: int) -> void:
	if not _roles.is_empty() and _roles[_roles.size() - 1] == role:
		return
	_pos.append(pos)
	_roles.append(role)
#endregion
