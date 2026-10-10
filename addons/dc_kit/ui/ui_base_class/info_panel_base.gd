extends Container

signal panel_shown
signal panel_hidden
signal panel_expanded
signal panel_collapsed


func show_info(info: _DCKitNS.UI.Signature.SignatureInfo) -> void:
	_DCKitNS.UI.not_implemented("show_info")


func set_active(index: int) -> void:
	_DCKitNS.UI.not_implemented("set_active")


func toggle() -> void:
	_DCKitNS.UI.not_implemented("toggle")


func expand() -> void:
	_DCKitNS.UI.not_implemented("expand")


func collapse() -> void:
	_DCKitNS.UI.not_implemented("collapse")


func is_collapsed() -> bool:
	_DCKitNS.UI.not_implemented("is_collapsed")
	return false


func is_showing() -> bool:
	_DCKitNS.UI.not_implemented("is_showing")
	return false
