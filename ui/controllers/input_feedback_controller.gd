extends RefCounted
## Runs the analyzer on the console input line and fans the result out to the
## diagnostics view, the signature-help view, and the completion provider.

signal analysis_changed(analysis) # DCAnalysisResult
signal scope_changed(scope)       # DCScope

const DiagnosticsView = preload("./diagnostics_view.gd")
const SignatureHelpView = preload("./signature_help_view.gd")

## Most recent analysis. The executor reads this on submit.
var latest_analysis = null # DCAnalysisResult

var diagnostics_view: DiagnosticsView
var signature_help_view: SignatureHelpView
var completion_provider: _DCKitNS.Core.AutoComplete = null

var _analyzer_ref: WeakRef
var _current_text := ""
var _current_cursor := -1
var _last_scope_key: Array = []


func _init(analyzer) -> void:
	_analyzer_ref = weakref(analyzer)
	diagnostics_view = DiagnosticsView.new()
	signature_help_view = SignatureHelpView.new()


func set_completion_provider(provider: _DCKitNS.Core.AutoComplete) -> void:
	completion_provider = provider


#region Input events
func handle_text_changed(text: String, cursor_pos: int) -> void:
	var analyzer = _analyzer_ref.get_ref()
	if analyzer == null or not analyzer.has_method("analyze"):
		return

	_current_text = text
	_current_cursor = cursor_pos
	latest_analysis = analyzer.analyze(text, cursor_pos)

	_refresh_diagnostics()
	_refresh_signature_help(true)
	_refresh_completions()

	analysis_changed.emit(latest_analysis)
	scope_changed.emit(latest_analysis.scope)


func handle_cursor_moved(cursor_pos: int) -> void:
	if latest_analysis == null:
		return
	# A caret event right after a text change reports the same position
	# and was already handled.
	if cursor_pos == _current_cursor:
		return

	var analyzer = _analyzer_ref.get_ref()
	if analyzer == null or not analyzer.has_method("compute_scope"):
		return

	_current_cursor = cursor_pos
	latest_analysis.scope = analyzer.compute_scope(latest_analysis.tokens, cursor_pos)

	_refresh_signature_help()
	_refresh_completions()

	scope_changed.emit(latest_analysis.scope)
#endregion


#region Refresh helpers
func _refresh_diagnostics() -> void:
	diagnostics_view.update(latest_analysis.diagnostics)


## Skips the rebuild when the scope points at the same definition and the same
## argument/part slot as last time, unless `force` is set.
func _refresh_signature_help(force := false) -> void:
	var scope = latest_analysis.scope
	var key := _scope_key(scope)
	if not force and key == _last_scope_key:
		return
	_last_scope_key = key
	signature_help_view.update(scope)


func _refresh_completions() -> void:
	if completion_provider != null:
		completion_provider.update(latest_analysis, _current_text, _current_cursor)


func _scope_key(scope) -> Array:
	if scope == null:
		return []
	return [scope.kind, scope.get_active(), scope.arg_index, scope.part_index]
#endregion
