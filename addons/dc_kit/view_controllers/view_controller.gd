extends RefCounted

signal analysis_updated(result) # DCAnalysisResult
signal scope_updated(scope) # DCScope

const ErrorView = preload("./error_view.gd")
const InfoView = preload("./info_view.gd")

var last_result = null # DCAnalysisResult — read by executor on submit
var error_view_ctl: ErrorView
var info_view_ctl: InfoView

var autocomplete: _DCKitCoreNamespace.AutoComplete = null
var _analyzer := WeakRef.new()
var _last_input := "" # most recent text — reused by on_cursor_moved for autocomplete context


func _init(analyzer) -> void:
	_analyzer = weakref(analyzer)
	error_view_ctl = ErrorView.new()
	info_view_ctl = InfoView.new()


func set_autocomplete(_autocomplete: _DCKitCoreNamespace.AutoComplete) -> void:
	autocomplete = _autocomplete


func on_text_changed(text: String, cursor_pos: int) -> void:
	var a := _analyzer.get_ref()
	if a == null or not a.has_method("analyze"):
		return
	_last_input = text
	last_result = a.analyze(text, cursor_pos)

	_internal_on_analysis_update()
	_internal_on_scope_update()
	_internal_on_autocomplete_update(cursor_pos)

	analysis_updated.emit(last_result)
	scope_updated.emit(last_result.scope)


func on_cursor_moved(cursor_pos: int) -> void:
	if last_result == null:
		return

	var a := _analyzer.get_ref()
	if a == null or not a.has_method("compute_scope"):
		return

	var scope = a.compute_scope(last_result.tokens, cursor_pos)
	last_result.scope = scope

	_internal_on_scope_update()
	_internal_on_autocomplete_update(cursor_pos)

	scope_updated.emit(scope)


func _internal_on_scope_update() -> void:
	if info_view_ctl != null:
		info_view_ctl.update(last_result.scope)


func _internal_on_analysis_update() -> void:
	if error_view_ctl != null:
		error_view_ctl.update(last_result.diagnostics)


func _internal_on_autocomplete_update(cursor_pos: int) -> void:
	if autocomplete != null:
		autocomplete.update(last_result, _last_input, cursor_pos)
