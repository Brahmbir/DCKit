extends RefCounted

const Lexer  := preload("./lexer.gd")
const Parser := preload("./parser.gd")
const TT     := Lexer.TokenType

const ConstructorDef := preload("../registries/constructor_registry/constructor_def.gd")

# Provided at init — all optional; omit to skip that category of semantic check.
var _cmd_reg   = null  # CommandRegistry     — .has(name), .get_definition(name)
var _ctor_reg  = null  # ConstructorRegistry — .knows(name), .get_def(name)
var _var_store = null  # variable store      — .has(name)



# Maximum nested argument / fallback depth allowed for one command tree.
const MAX_ARGUMENT_DEPTH : int = 32

func _init(cmd_reg = null, ctor_reg = null, var_store = null) -> void:
	_cmd_reg   = cmd_reg
	_ctor_reg  = ctor_reg
	_var_store = var_store


func analyze(input: String, cursor_pos := -1) -> DCAnalysisResult:
	var result := DCAnalysisResult.new()
	if cursor_pos < 0: cursor_pos = input.length()

	var lex_r := Lexer.new().lex(input)
	if not lex_r.ok:
		result.diagnostics.append(_diag(lex_r.error.message, lex_r.error.position,
				1, DCDiagnostic.Severity.ERROR, DCDiagnostic.Source.LEXER))
		result.tokens = lex_r.get("tokens", [])
		result.scope  = compute_scope(result.tokens, cursor_pos)
		return result
	result.tokens = lex_r.tokens

	var parse_r := Parser.new().parse_chain(result.tokens)
	if not parse_r.ok:
		result.diagnostics.append(_diag(parse_r.error.message, parse_r.error.position,
				1, DCDiagnostic.Severity.ERROR, DCDiagnostic.Source.PARSER))
	else:
		result.ast = parse_r.commands
		for cmd in result.ast:
			_check_node(cmd, result.diagnostics)
			_check_argument_stack(cmd, 1, result.diagnostics)

	result.scope = compute_scope(result.tokens, cursor_pos)
	return result


# SCOPE
func compute_scope(tokens: Array, cursor_pos: int) -> DCScope:
	var stack : Array = [_cmd_frame()]
	var prev          = null

	for i in tokens.size():
		var tok = tokens[i]
		if tok.type == TT.END: break

		var tok_end : int = tok.position + _tok_span(tok)

		if cursor_pos < tok.position: return _to_scope(stack.back(), null)

		var structural :bool= tok.type == TT.LPAREN \
				or tok.type == TT.RPAREN \
				or tok.type == TT.SEMICOLON

		# Closing tokens: cursor at or before them means still inside the current scope
		if (tok.type == TT.RPAREN or tok.type == TT.SEMICOLON) \
				and cursor_pos <= tok.position:
			return _to_scope(stack.back(), null)

		if not structural and cursor_pos <= tok_end:
			return _to_scope(stack.back(), tok)

		# Cursor is past this token's own span.  If it is a variable whose fallback
		# chain contains a nested-command sentinel, check whether the cursor lands
		# inside that sentinel's text range and, if so, recurse into it.
		if tok.type == TT.VARIABLE and tok.fallback != null:
			var inner = _find_nested_cmd_at(tok.fallback, cursor_pos)
			if inner != null:
				return compute_scope(inner, cursor_pos)

		var f   = stack.back()
		var nxt = tokens[i + 1] if i + 1 < tokens.size() else null

		match tok.type:
			TT.IDENTIFIER:
				var is_ctor : bool = nxt != null and nxt.type == TT.LPAREN and tok.position + tok.value.length() == nxt.position
				if f.k == DCScope.Kind.COMMAND:
					if f.arg == -1: f.name = tok.value; f.arg = 0
					elif not is_ctor: f.arg += 1
				elif f.k == DCScope.Kind.CONSTRUCTOR:
					if not is_ctor: f.part += 1
			TT.LPAREN:
				var is_ctor : bool = prev != null and prev.type == TT.IDENTIFIER and prev.position + prev.value.length() == tok.position
				stack.push_back(_ctor_frame(prev.value) if is_ctor else _cmd_frame())
			TT.RPAREN:
				if stack.size() > 1:
					stack.pop_back()
					var p = stack.back()
					if   p.k == DCScope.Kind.COMMAND:     p.arg  += 1
					elif p.k == DCScope.Kind.CONSTRUCTOR: p.part += 1
			TT.VARIABLE, TT.NUMBER, TT.STRING:
				if   f.k == DCScope.Kind.COMMAND:     f.arg  += 1
				elif f.k == DCScope.Kind.CONSTRUCTOR: f.part += 1
			TT.SEMICOLON:
				stack = [_cmd_frame()]

		prev = tok

	return _to_scope(stack.back(), null)


# SEMANTIC
func _check_node(node, out: Array) -> void:
	if node == null: return

	if node is Parser.VariableNode:
		if not node.is_silent and _var_store != null \
				and not _var_store.has(node.name):
			out.append(_diag("'$%s' is not defined." % node.name,
					node.start_pos, node.name.length() + 1,
					DCDiagnostic.Severity.WARNING, DCDiagnostic.Source.SEMANTIC))
		_check_node(node.fallback, out)

	elif node is Parser.CommandNode:
		if _cmd_reg != null:
			if not _cmd_reg.has(node.name):
				out.append(_diag("Unknown command '%s'." % node.name,
						node.start_pos, node.name.length(),
						DCDiagnostic.Severity.ERROR, DCDiagnostic.Source.SEMANTIC))
			else:
				# Deprecated — static analysis warning, fires before any execution.
				var cmd_def : DCDefinition = _cmd_reg.get_definition(node.name)
				if cmd_def != null and cmd_def.deprecated:
					
					var msg := (
						"'%s' is deprecated."
						% cmd_def.name
					) if cmd_def.name == node.name else (
						"Command '%s' (invoked as '%s') is deprecated."
						% [cmd_def.name, node.name]
					)
					
					if not cmd_def.deprecated_message.is_empty():
						msg += " " + cmd_def.deprecated_message
					out.append(_diag(msg, node.start_pos, node.name.length(),
							DCDiagnostic.Severity.WARNING, DCDiagnostic.Source.SEMANTIC))
		# Argument count is intentionally not validated — handlers are variadic by design.
		for child in node.args: _check_node(child, out)

	elif node is Parser.ConstructorNode:
		if _ctor_reg != null:
			if not _ctor_reg.knows(node.type_name):
				out.append(_diag("Unknown constructor type '%s'." % node.type_name,
						node.start_pos, node.type_name.length(),
						DCDiagnostic.Severity.ERROR, DCDiagnostic.Source.SEMANTIC))
			else:
				var def : ConstructorDef = _ctor_reg.get_def(node.type_name)
				var count : int = node.parts.size()
				if not def.signatures.is_empty():
					var matched : bool = def.signatures.any(
							func(sig) -> bool: return sig.parts.size() == count)
					if not matched:
						out.append(_diag(
								"'%s' has no signature for %d part(s)." % [node.type_name, count],
								node.start_pos, node.type_name.length(),
								DCDiagnostic.Severity.WARNING, DCDiagnostic.Source.SEMANTIC))
		for child in node.parts: _check_node(child, out)


# HELPERS
func _cmd_frame() -> Dictionary:
	return { k = DCScope.Kind.COMMAND, name = "", arg = -1, ctor = "", part = 0 }

func _ctor_frame(type_name: String) -> Dictionary:
	return { k = DCScope.Kind.CONSTRUCTOR, name = "", arg = -1, ctor = type_name, part = 0 }

func _to_scope(f: Dictionary, tok) -> DCScope:
	var s := DCScope.new()
	s.kind = f.k
	if f.k == DCScope.Kind.COMMAND:
		s.name      = tok.value if (tok != null and tok.type == TT.IDENTIFIER and f.arg == -1) \
				else f.name
		s.arg_index = f.arg
		if _cmd_reg != null and not s.name.is_empty():
			var def = _cmd_reg.get_definition(s.name)
			if def != null: s._active_ref = weakref(def)
	elif f.k == DCScope.Kind.CONSTRUCTOR:
		s.type_name  = f.ctor
		s.part_index = f.part + (1 if tok != null else 0)  # tok != null = cursor is on a part
		if _ctor_reg != null and not s.type_name.is_empty():
			var def = _ctor_reg.get_def(s.type_name)
			if def != null: s._active_ref = weakref(def)
	return s

## Walks the fallback chain rooted at `fb_tok` and returns the nested_tokens
## of the first nested-command sentinel whose text span contains `cursor_pos`.
## Handles arbitrary chain depth: $?a:$?b:(cmd) → walks past VARIABLE(b) to
## the LPAREN sentinel.  Returns null if the cursor is not inside any nested cmd.
func _find_nested_cmd_at(fb_tok, cursor_pos: int):
	while fb_tok != null:
		if not fb_tok.nested_tokens.is_empty():
			# This token IS the nested-command sentinel.
			var inner : Array = fb_tok.nested_tokens
			if inner.size() >= 2:
				var last    = inner[inner.size() - 2]  # last real token before END
				var fb_end  : int = last.position + _tok_span(last)
				if cursor_pos > fb_tok.position and cursor_pos <= fb_end:
					return inner
			return null  # sentinel found but cursor is outside it — stop walking
		fb_tok = fb_tok.fallback
	return null

func _tok_span(tok) -> int:
	match tok.type:
		TT.STRING:   return tok.value.length() + 2
		TT.VARIABLE: return tok.value.length() + (2 if tok.is_silent else 1)
		_:           return tok.value.length()

func _diag(msg: String, pos: int, len: int, sev: int, src: int) -> DCDiagnostic:
	return DCDiagnostic.new(msg, pos, len, sev, src)

# Depth check for nested command / constructor / fallback trees.
# `depth` counts the current node; children are checked with depth + 1.
func _check_argument_stack(node, depth: int, out: Array) -> void:
	if node == null:
		return

	if depth > MAX_ARGUMENT_DEPTH:
		out.append(_diag(
			"Argument stack depth exceeds the limit (%d)." % MAX_ARGUMENT_DEPTH,
			node.start_pos,
			1,
			DCDiagnostic.Severity.ERROR,
			DCDiagnostic.Source.SEMANTIC))
		return

	if node is Parser.VariableNode:
		_check_argument_stack(node.fallback, depth + 1, out)

	elif node is Parser.CommandNode:
		for child in node.args:
			_check_argument_stack(child, depth + 1, out)

	elif node is Parser.ConstructorNode:
		for child in node.parts:
			_check_argument_stack(child, depth + 1, out)

#region TYPES

class DCDiagnostic:
	enum Severity { HINT, WARNING, ERROR }
	enum Source   { LEXER, PARSER, SEMANTIC }

	var message  : String
	var position : int
	var length   : int = 1
	var severity : int = Severity.ERROR
	var source   : int = Source.LEXER
	
	func to_ui_dict() -> Dictionary:
		return {
			"message": message,
			"position": position,
			"length": length,
			"severity": severity,
			"source": source,
			"severity_name": Severity.keys()[severity],
			"source_name": Source.keys()[source],
			"range_text": "Pos %d • Len %d" % [position, length],
		}
	
	func _init(msg: String, pos: int, len := 1,
			sev := Severity.ERROR, src := Source.LEXER) -> void:
		message = msg; position = pos; length = len; severity = sev; source = src

	func _to_string() -> String:
		return "[%s/%s pos=%d] %s" % [
			Severity.keys()[severity], Source.keys()[source], position, message]


class DCScope:
	enum Kind { EMPTY, COMMAND, CONSTRUCTOR }

	var kind       : int    = Kind.EMPTY
	var name       : String = ""  # COMMAND: "" = cursor at name position
	var arg_index  : int    = -1  # COMMAND: -1 = at name, 0+ = Nth arg slot
	var type_name  : String = ""  # CONSTRUCTOR: the type being constructed
	var part_index : int    = 0   # CONSTRUCTOR: 0-based part index
	var _active_ref : WeakRef = WeakRef.new()  # → DCDefinition | DCConstructorDef | null

	func get_active():
		return _active_ref.get_ref()

	func _to_string() -> String:
		match kind:
			Kind.COMMAND:     return "COMMAND(name='%s' arg=%d)" % [name, arg_index]
			Kind.CONSTRUCTOR: return "CONSTRUCTOR(type='%s' part=%d)" % [type_name, part_index]
			_:                return "EMPTY"


class DCAnalysisResult:
	var tokens      : Array = []
	var ast         : Array = []
	var diagnostics : Array = []
	var scope       : DCScope

	func _init() -> void: scope = DCScope.new()

	func ok() -> bool:
		for d in diagnostics:
			if d.severity == DCDiagnostic.Severity.ERROR: return false
		return true

	func has_warnings() -> bool:
		for d in diagnostics:
			if d.severity == DCDiagnostic.Severity.WARNING: return true
		return false
