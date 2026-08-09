extends RefCounted

signal update_posted(data)

var current_data: Dictionary = { }


func update(scope) -> void:
	current_data.clear()
	if scope == null or not scope.has_method("get_active"):
		update_posted.emit(current_data)
		return
	var def = scope.get_active()
	if def == null:
		update_posted.emit(current_data)
		return
	match scope.kind:
		scope.Kind.COMMAND:
			current_data = _build_command_data(def, scope.arg_index)
		scope.Kind.CONSTRUCTOR:
			current_data = _build_constructor_data(def, scope.part_index)
	update_posted.emit(current_data)


func _build_command_data(def: DCDefinition, arg_index: int) -> Dictionary:
	var params := []
	for i in def.params.size():
		var p: DCDefinition.Param = def.params[i]
		params.append(
			{
				"index": i,
				"name": p.name,
				"description": p.description,
				"active": i == arg_index,
				"has_suggestions": p.suggestor.is_valid(),
				"is_rest": p.is_rest,
			}
		)

	return {
		"kind": "command",
		"title": def.name,
		"description": def.description,
		"active_index": arg_index,
		"params": params,
		"aliases": Array(def.aliases),
		"deprecated": def.deprecated,
		"deprecated_message": def.deprecated_message,
		"log_mode": def.log_mode,
		"log_mode_name": DCDefinition.LogMode.keys()[def.log_mode],
	}


func _build_constructor_data(def: _DCKitNamespace.ConstructorDef, part_index: int) -> Dictionary:
	var signatures := []
	for sig: _DCKitNamespace.ConstructorDef.TypeSignature in def.signatures:
		var parts := []
		for i in sig.parts.size():
			var p: _DCKitNamespace.ConstructorDef.PartHint = sig.parts[i]
			parts.append(
				{
					"name": p.name,
					"type_hint": p.type_hint,
					"description": p.description,
					"accepted_types": p.accepted_types_label(),
					"active": i == part_index,
				}
			)
		signatures.append(
			{
				"description": sig.description,
				"usage": sig.usage(def.name),
				"matches": sig.matches_count(part_index),
				"parts": parts,
			}
		)
	return {
		"kind": "constructor",
		"title": def.name,
		"description": def.description,
		"active_index": part_index,
		"signatures": signatures,
	}
