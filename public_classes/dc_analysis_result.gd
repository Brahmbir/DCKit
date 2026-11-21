class_name DCAnalysisResult
extends RefCounted

var tokens: Array = []
var ast: Array = []
var diagnostics: Array = []
var scope: Scope


func _init() -> void:
	scope = Scope.new()


func ok() -> bool:
	for d in diagnostics:
		if d.severity == Diagnostic.Severity.ERROR:
			return false
	return true


func has_warnings() -> bool:
	for d in diagnostics:
		if d.severity == Diagnostic.Severity.WARNING:
			return true
	return false


class Diagnostic:
	enum Severity {
		HINT,
		WARNING,
		ERROR,
	}
	enum Source {
		LEXER,
		PARSER,
		SEMANTIC,
	}

	var message: String
	var position: int
	var length: int = 1
	var severity: int = Severity.ERROR
	var source: int = Source.LEXER

	var hint: String = ""
	var related_pos: int = -1
	var related_len: int = 0
	var related_message: String = ""
	var fixes: Array = [] # Array[Fix]


	func with_hint(text: String) -> Diagnostic:
		hint = text
		return self


	func with_related(pos: int, len: int, text: String) -> Diagnostic:
		related_pos = pos
		related_len = len
		related_message = text
		return self


	func with_fix(title: String, start: int, end: int, text: String) -> Diagnostic:
		fixes.append(Fix.new(title, [{ start = start, end = end, text = text }]))
		return self


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
			"hint": hint,
			"related_pos": related_pos,
			"related_len": related_len,
			"related_message": related_message,
			"has_fix": not fixes.is_empty(),
		}


	func _init(msg: String, pos: int, len := 1, sev := Severity.ERROR, src := Source.LEXER) -> void:
		message = msg
		position = pos
		length = len
		severity = sev
		source = src


	func _to_string() -> String:
		return "[%s/%s pos=%d] %s" % [
			Severity.keys()[severity],
			Source.keys()[source],
			position,
			message,
		]


class Scope:
	enum Kind {
		EMPTY,
		COMMAND,
		CONSTRUCTOR,
		ARRAY_ITEM,
		DICT_KEY,
		DICT_VALUE,
	}

	var kind: int = Kind.EMPTY
	# COMMAND: "" = cursor at name position
	var name: String = ""
	# COMMAND: -1 = at name, 0+ = Nth arg slot
	var arg_index: int = -1
	# CONSTRUCTOR: the type being constructed
	var type_name: String = ""
	# CONSTRUCTOR: 0-based part index
	var part_index: int = 0
	# → DCDefinition |  _DCKitNS.Registries.ConstructorDef | null
	var _active_ref: WeakRef = WeakRef.new()
	
	# ARRAY_ITEM / DICT_KEY / DICT_VALUE: the COMMAND or CONSTRUCTOR scope whose argument slot holds
	# the collection, and the keys (String) / indexes (int) leading from that slot to this collection.
	var owner: Scope = null
	var path: Array = []
	# ARRAY_ITEM / DICT_*: 0-based item / entry slot under the cursor
	var index: int = -1
	# DICT_*: key of the entry under the cursor. used_keys: keys already present elsewhere in the dictionary.
	var key: String = ""
	var used_keys: Array = []
	
	# The AST node this scope is about (CommandNode / ConstructorNode / ArrayNode / DictNode), or null.
	var node = null


	func get_active():
		return _active_ref.get_ref()


	func _to_string() -> String:
		match kind:
			Kind.COMMAND:
				return "COMMAND(name='%s' arg=%d)" % [name, arg_index]
			Kind.CONSTRUCTOR:
				return "CONSTRUCTOR(type='%s' part=%d)" % [type_name, part_index]
			Kind.ARRAY_ITEM:
				return "ARRAY_ITEM(index=%d path=%s in %s)" % [index, path, owner]
			Kind.DICT_KEY:
				return "DICT_KEY(key='%s' index=%d used=%s path=%s in %s)" % [key, index, used_keys, path, owner]
			Kind.DICT_VALUE:
				return "DICT_VALUE(key='%s' index=%d used=%s path=%s in %s)" % [key, index, used_keys, path, owner]
			_:
				return "EMPTY"


## Replace source[start:end] with text for every edit (apply back to front).
class Fix:
	var title: String
	var edits: Array # [{ start: int, end: int, text: String }]


	func _init(p_title: String, p_edits: Array) -> void:
		title = p_title
		edits = p_edits
