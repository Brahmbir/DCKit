extends RefCounted
## Builds the signature-help data for the active scope and notifies listeners
## only when the definition or the active slot changes.

signal update_posted(data)

var current_data: Dictionary = { }

# Single-entry cache: the cursor stays on one definition for many keystrokes.
var _cached_def = null
var _cached_static: Dictionary = { }
var _last_key: Array = []


func update(scope) -> void:
	var def = null
	if scope != null and scope.has_method("get_active"):
		def = scope.get_active()
	if def == null:
		_publish({ }, [])
		return

	var index: int
	match scope.kind:
		scope.Kind.COMMAND:
			index = scope.arg_index
		scope.Kind.CONSTRUCTOR:
			index = scope.part_index
		_:
			_publish({ }, [])
			return

	var key := [scope.kind, def, index]
	if key == _last_key:
		return

	if def != _cached_def:
		_cached_def = def
		_cached_static = _build_static(def, scope.kind == scope.Kind.COMMAND)

	_publish(_apply_active(_cached_static, index), key)


func _publish(data: Dictionary, key: Array) -> void:
	_last_key = key
	current_data = data
	update_posted.emit(current_data)


# Everything that depends only on the definition.
func _build_static(def, is_command: bool) -> Dictionary:
	if is_command:
		var params := []
		for i in def.params.size():
			var p: DCDefinition.Param = def.params[i]
			params.append(
				{
					"index": i,
					"name": p.name,
					"description": p.description,
					"has_suggestions": p.suggestor.is_valid(),
					"is_rest": p.is_rest,
				}
			)
		return {
			"kind": "command",
			"title": def.name,
			"description": def.description,
			"params": params,
			"aliases": Array(def.aliases),
			"deprecated": def.deprecated,
			"deprecated_message": def.deprecated_message,
			"log_mode": def.log_mode,
			"log_mode_name": DCDefinition.LogMode.keys()[def.log_mode],
		}

	var signatures := []
	for sig: _DCKitRegistriesNamespace.ConstructorDef.TypeSignature in def.signatures:
		var parts := []
		for p: _DCKitRegistriesNamespace.ConstructorDef.PartHint in sig.parts:
			parts.append(
				{
					"name": p.name,
					"type_hint": p.type_hint,
					"description": p.description,
					"accepted_types": p.accepted_types_label(),
				}
			)
		signatures.append(
			{
				"description": sig.description,
				"usage": sig.usage(def.name),
				"parts": parts,
				"_sig": sig, # kept so matches can be recomputed per index
			}
		)
	return {
		"kind": "constructor",
		"title": def.name,
		"description": def.description,
		"signatures": signatures,
	}


# Everything that depends on the cursor. Returns a fresh dictionary so
# listeners holding an earlier emission are never mutated.
func _apply_active(static_data: Dictionary, index: int) -> Dictionary:
	var out := static_data.duplicate()
	out["active_index"] = index

	if static_data.kind == "command":
		var params := []
		for p in static_data.params:
			var q: Dictionary = p.duplicate()
			q["active"] = p.index == index
			params.append(q)
		out["params"] = params
	else:
		var signatures := []
		for s in static_data.signatures:
			var parts := []
			for i in s.parts.size():
				var part: Dictionary = s.parts[i].duplicate()
				part["active"] = i == index
				parts.append(part)
			signatures.append(
				{
					"description": s.description,
					"usage": s.usage,
					"matches": s._sig.matches_count(index),
					"parts": parts,
				}
			)
		out["signatures"] = signatures
	return out
