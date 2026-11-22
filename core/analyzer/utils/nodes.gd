extends RefCounted


## Every node: exact source span [start_pos, end_pos) and two recovery flags.
class AstNode:
	var start_pos := -1
	var end_pos := -1
	var open := false # closing token missing in the source
	var bad := false # already has an error; later passes should not pile on


	func children() -> Array:
		return []


class CommandNode extends AstNode:
	var name: String
	var name_pos: int
	var args: Array = []
	var semi_pos := -1 # top-level only: offset of the ';' that ended this command


	func _init(p_name: String, p_start: int) -> void:
		name = p_name
		start_pos = p_start
		name_pos = p_start
		end_pos = p_start + p_name.length()


	func children() -> Array:
		return args


class StringNode extends AstNode:
	var value: String
	var quoted: bool


	func _init(p_value: String, p_quoted := false, p_start := -1, p_end := -1) -> void:
		value = p_value
		quoted = p_quoted
		start_pos = p_start
		end_pos = p_end if p_end != -1 else p_start + p_value.length()


## "text ${var} text" — only when it interpolates; plain "text" collapses to StringNode.
class TemplateNode extends AstNode:
	var segments: Array = [] # StringNode | VariableNode


	func _init(p_start: int) -> void:
		start_pos = p_start


	func children() -> Array:
		return segments


class VariableNode extends AstNode:
	var name: String
	var is_silent: bool # '?' or ':fallback' — a missing variable is not an error
	var fallback = null # AstNode | null
	var modifier := "" # "", "!", "?" or ":"
	var braced := false


	func _init(p_name: String, p_silent := false, p_start := -1) -> void:
		name = p_name
		is_silent = p_silent
		start_pos = p_start
		end_pos = p_start + p_name.length() + 1


	func children() -> Array:
		return [] if fallback == null else [fallback]


class ConstructorNode extends AstNode:
	var type_name: String
	var type_pos: int
	var parts: Array = []


	func _init(p_type: String, p_start: int) -> void:
		type_name = p_type
		type_pos = p_start
		start_pos = p_start


	func children() -> Array:
		return parts


class ArrayNode extends AstNode:
	var items: Array = []


	func _init(p_start: int) -> void:
		start_pos = p_start


	func children() -> Array:
		return items


class DictEntry extends AstNode:
	var key: AstNode
	var value: AstNode
	var colon_pos := -1


	func _init(p_start: int) -> void:
		start_pos = p_start


	func children() -> Array:
		return [key, value]


class DictNode extends AstNode:
	var entries: Array = [] # DictEntry


	func _init(p_start: int) -> void:
		start_pos = p_start


	func children() -> Array:
		return entries


## Placeholder so the tree stays whole: `missing` = zero-width (a value that is absent),
## otherwise it covers source that could not be understood.
class ErrorNode extends AstNode:
	var missing := false


	func _init(p_start: int, p_end: int, p_missing := false) -> void:
		start_pos = p_start
		end_pos = p_end
		missing = p_missing
		bad = true
