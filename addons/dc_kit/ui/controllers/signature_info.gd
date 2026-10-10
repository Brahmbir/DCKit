extends RefCounted

class SignatureInfo:
	var type := ""
	var title := ""
	var description := ""


class ParamInfo:
	var index := 0
	var name := ""
	var description := ""
	var has_suggestions := false
	var is_rest := false


class CommandInfo extends SignatureInfo:
	var params: Array[ParamInfo] = []
	var aliases: PackedStringArray = []
	var deprecated := false
	var deprecated_message := ""
	var log_mode_name := "NORMAL"

	func _init() -> void:
		type = "command"


class PartInfo:
	var name := ""
	var type_hint := ""
	var description := ""
	var accepted_types := ""


class TypeSignatureInfo:
	var description := ""
	var usage := ""
	var parts: Array[PartInfo] = []
	var _sig # the definition's TypeSignature, kept for matches_count

	func matches_count(index: int) -> int:
		return _sig.matches_count(index)


class ConstructorInfo extends SignatureInfo:
	var signatures: Array[TypeSignatureInfo] = []

	func _init() -> void:
		type = "constructor"
