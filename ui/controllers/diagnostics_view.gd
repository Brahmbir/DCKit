extends RefCounted
## Holds the current diagnostics and notifies listeners only when they change.

signal diagnostics_changed(diagnostics)

var diagnostics: Array = []


func update(new_diagnostics: Array) -> void:
	if _same_diagnostics(diagnostics, new_diagnostics):
		return
	diagnostics = new_diagnostics
	diagnostics_changed.emit(diagnostics)


func _same_diagnostics(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x = a[i]
		var y = b[i]
		if x.message != y.message or x.position != y.position \
				or x.length != y.length or x.severity != y.severity:
			return false
	return true
