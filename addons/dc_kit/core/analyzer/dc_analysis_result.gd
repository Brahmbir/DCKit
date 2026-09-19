class_name DCAnalysisResult
extends RefCounted

var tokens: Array = []
var ast: Array = []
var diagnostics: Array = []
var scope: DCScope


func _init() -> void:
	scope = DCScope.new()


func ok() -> bool:
	for d in diagnostics:
		if d.severity == DCDiagnostic.Severity.ERROR:
			return false
	return true


func has_warnings() -> bool:
	for d in diagnostics:
		if d.severity == DCDiagnostic.Severity.WARNING:
			return true
	return false


class DCDiagnostic:
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


class DCScope:
	enum Kind {
		EMPTY,
		COMMAND,
		CONSTRUCTOR,
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
	# → DCDefinition |  _DCKitRegistriesNamespace.ConstructorDef | null
	var _active_ref: WeakRef = WeakRef.new()


	func get_active():
		return _active_ref.get_ref()


	func _to_string() -> String:
		match kind:
			Kind.COMMAND:
				return "COMMAND(name='%s' arg=%d)" % [name, arg_index]
			Kind.CONSTRUCTOR:
				return "CONSTRUCTOR(type='%s' part=%d)" % [type_name, part_index]
			_:
				return "EMPTY"
