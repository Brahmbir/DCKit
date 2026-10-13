@tool
extends Container
## Holds the state a panel needs from its host: where to size against,
## what data to show, and which row is active.

var sizing_parent: Control = null:
	set(v):
		if v == sizing_parent:
			return
		if sizing_parent and sizing_parent.resized.is_connected(_refresh_height):
			sizing_parent.resized.disconnect(_refresh_height)
		sizing_parent = v
		if sizing_parent and not Engine.is_editor_hint():
			sizing_parent.resized.connect(_refresh_height)
		_refresh_height()

var info: _DCKitNS.UI.Signature.SignatureInfo = null:
	set(v):
		if v == info:
			return
		var had_info := info != null
		info = v
		_info_changed(had_info)

var active_index: int = -1:
	set(v):
		active_index = v
		if info != null:
			_apply_active(v)


func toggle() -> void:
	pass


func expand() -> void:
	pass


func collapse() -> void:
	pass


# Virtual hooks, overridden by subclasses.
func _refresh_height() -> void:
	pass


func _info_changed(_had_info: bool) -> void:
	pass


func _apply_active(_index: int) -> void:
	pass
