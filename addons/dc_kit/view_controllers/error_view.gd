extends RefCounted

signal update_posted(diags)

var diagnostics: Array = []


func update(diags: Array) -> void:
	diagnostics = diags
	update_posted.emit(diagnostics)
