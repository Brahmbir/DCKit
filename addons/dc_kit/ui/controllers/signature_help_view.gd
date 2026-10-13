extends RefCounted
## Builds the signature-help data for the active scope and notifies listeners
## only when the definition or the active slot changes.

signal definition_changed(info: _DCKitNS.UI.Signature.SignatureInfo) # null = nothing active
signal active_changed(index: int)

var current_info: _DCKitNS.UI.Signature.SignatureInfo = null
var current_index: int = -1

# Single-entry cache: the cursor stays on one definition for many keystrokes.
var _cached_def = null
var _cached_info: _DCKitNS.UI.Signature.SignatureInfo = null


func update(scope: DCAnalysisResult.Scope) -> void:
	var def = null
	if scope != null and scope.has_method("get_active"):
		def = scope.get_active()
	if def == null:
		_clear()
		return

	var index: int
	match scope.kind:
		DCAnalysisResult.Scope.Kind.COMMAND:
			index = scope.arg_index
		DCAnalysisResult.Scope.Kind.CONSTRUCTOR:
			index = scope.part_index
		_:
			_clear()
			return

	if def != _cached_def:
		_cached_def = def
		_cached_info = _build_info(def, scope.kind)
	if _cached_info == null:
		_clear()
		return

	if current_info != _cached_info:
		current_info = _cached_info
		current_index = index
		definition_changed.emit(current_info)
		active_changed.emit(index)
	elif index != current_index:
		current_index = index
		active_changed.emit(index)


func _build_info(def, kind: DCAnalysisResult.Scope.Kind) -> _DCKitNS.UI.Signature.SignatureInfo:
	match kind:
		DCAnalysisResult.Scope.Kind.COMMAND:
			var c := _DCKitNS.UI.Signature.CommandInfo.new()
			c.title = def.name
			c.description = def.description
			c.aliases = PackedStringArray(def.aliases)
			c.deprecated = def.deprecated
			c.deprecated_message = def.deprecated_message
			c.log_mode_name = DCDefinition.LogMode.keys()[def.log_mode]
			for i in def.params.size():
				var p: DCDefinition.Param = def.params[i]
				var pi := _DCKitNS.UI.Signature.ParamInfo.new()
				pi.index = i
				pi.name = p.name
				pi.description = p.description
				pi.has_suggestions = p.suggestor.is_valid()
				pi.is_rest = p.is_rest
				c.params.append(pi)
			return c
		DCAnalysisResult.Scope.Kind.CONSTRUCTOR:
			var k := _DCKitNS.UI.Signature.ConstructorInfo.new()
			k.title = def.name
			k.description = def.description
			for sig in def.signatures:
				var si := _DCKitNS.UI.Signature.TypeSignatureInfo.new()
				si.description = sig.description
				si.usage = sig.usage(def.name)
				si._sig = sig
				for p in sig.parts:
					var pt := _DCKitNS.UI.Signature.PartInfo.new()
					pt.name = p.name
					pt.type_hint = p.type_hint
					pt.description = p.description
					pt.accepted_types = p.accepted_types_label()
					si.parts.append(pt)
				k.signatures.append(si)
			return k
		_:
			push_warning(kind, " not implemented")
			return null


func _clear() -> void:
	if current_info == null:
		return
	current_info = null
	current_index = -1
	definition_changed.emit(null)
