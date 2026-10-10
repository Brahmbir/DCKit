extends "../../../ui_base_class/input_comp_base.gd"

const DIVIDER_TEXT := " :~$"
const _DEBOUNCE_SEC: float = 0.1

@export var label_perfix: String

@export_group("nodes")
@export var button: PanelContainer # has signal `pressed`
@export var text_edit: TextEdit

var executor_ref: WeakRef = weakref(null)
var _hist_obj_ref: WeakRef = weakref(null)
var _state: _DCKitNS.UI.State = _DCKitNS.UI.State.EXECUTE
var _last_submit: float = 0.0

@onready var label: Label = $MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Label


func _enter_tree() -> void:
	_connect_edit_signals()

	if not _DCKitNS.UI.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitNS.UI.mobile_layout.changed.connect(_on_mobile_changed)

	if is_instance_valid(button) and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _ready() -> void:
	set_state(_DCKitNS.UI.State.EXECUTE, true)
	_apply_history_to_input()
	_on_mobile_changed(_DCKitNS.UI.mobile_layout.mobile) # catch up if spawned late


func _exit_tree() -> void:
	_disconnect_edit_signals()

	if _DCKitNS.UI.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitNS.UI.mobile_layout.changed.disconnect(_on_mobile_changed)

	if is_instance_valid(button) and button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)


func set_state(s: _DCKitNS.UI.State, focus := false) -> void:
	_state = s

	if is_instance_valid(text_edit):
		text_edit.editable = (s == _DCKitNS.UI.State.EXECUTE)

	if button and button.has_method("set_state"):
		button.call("set_state", _state, focus)


func get_input_node() -> Control:
	return text_edit


func connect_history_obj(hist_obj: _DCKitNS.UI.CommandHistory) -> void:
	_hist_obj_ref = weakref(hist_obj)
	_apply_history_to_input()


func connect_executor(executor) -> void:
	_disconnect_executor()
	if executor == null:
		return

	executor_ref = weakref(executor)
	executor.state_changed.connect(_on_executor_state_changed)
	_on_executor_state_changed() # sync right away, so hooking in mid-run is correct


func _on_mobile_changed(is_mobile: bool) -> void:
	label.text = _get_label_text(is_mobile)


func _get_label_text(is_mobile: bool) -> String:
	if is_mobile:
		return DIVIDER_TEXT
	return label_perfix + DIVIDER_TEXT


func _apply_history_to_input() -> void:
	var hist_obj := _hist_obj_ref.get_ref() as _DCKitNS.UI.CommandHistory
	if hist_obj == null or not is_instance_valid(text_edit):
		return

	if "history" in text_edit:
		text_edit.history = hist_obj


# --- signals ---
func _connect_edit_signals() -> void:
	if not is_instance_valid(text_edit):
		return

	if (
		text_edit.has_signal(&"text_submitted")
		and not text_edit.is_connected(&"text_submitted", _on_submit)
	):
		text_edit.connect(&"text_submitted", _on_submit)

	if not text_edit.text_set.is_connected(_on_text_edit_changed):
		text_edit.text_set.connect(_on_text_edit_changed)
	if not text_edit.text_changed.is_connected(_on_text_edit_changed):
		text_edit.text_changed.connect(_on_text_edit_changed)

	if not text_edit.caret_changed.is_connected(_on_text_edit_caret_changed):
		text_edit.caret_changed.connect(_on_text_edit_caret_changed)
	if not text_edit.focus_entered.is_connected(_on_focus_entered):
		text_edit.focus_entered.connect(_on_focus_entered)
	if not text_edit.focus_exited.is_connected(_on_focus_exited):
		text_edit.focus_exited.connect(_on_focus_exited)


func _disconnect_edit_signals() -> void:
	if not is_instance_valid(text_edit):
		return

	if (
		text_edit.has_signal(&"text_submitted")
		and text_edit.is_connected(&"text_submitted", _on_submit)
	):
		text_edit.disconnect(&"text_submitted", _on_submit)

	if text_edit.text_set.is_connected(_on_text_edit_changed):
		text_edit.text_set.disconnect(_on_text_edit_changed)
	if text_edit.text_changed.is_connected(_on_text_edit_changed):
		text_edit.text_changed.disconnect(_on_text_edit_changed)

	if text_edit.caret_changed.is_connected(_on_text_edit_caret_changed):
		text_edit.caret_changed.disconnect(_on_text_edit_caret_changed)
	if text_edit.focus_entered.is_connected(_on_focus_entered):
		text_edit.focus_entered.disconnect(_on_focus_entered)
	if text_edit.focus_exited.is_connected(_on_focus_exited):
		text_edit.focus_exited.disconnect(_on_focus_exited)


func _on_text_edit_changed() -> void:
	cmd_text_changed.emit(text_edit.text, text_edit.get_caret_column())


func _on_text_edit_caret_changed() -> void:
	cmd_caret_location_changed.emit(text_edit.get_caret_column())


func _on_abort() -> void:
	var executor := executor_ref.get_ref() as _DCKitNS.Executor.Executor
	if executor and executor.is_running():
		executor.abort()
		abort_requested.emit()


func _on_submit(raw: String) -> void:
	if _state == _DCKitNS.UI.State.ABORT:
		return

	var now := Time.get_unix_time_from_system()
	if now - _last_submit < _DEBOUNCE_SEC:
		return

	var text := raw.strip_edges()
	if text.is_empty():
		return

	_last_submit = now

	var executor := executor_ref.get_ref() as _DCKitNS.Executor.Executor
	if executor:
		text_edit.clear()
		executor.run(text)
		command_submitted.emit(text)


func _on_button_pressed() -> void:
	if _state == _DCKitNS.UI.State.ABORT:
		_on_abort()
	else:
		_on_submit(text_edit.text)


func _on_focus_entered() -> void:
	focus_changed.emit(true)


func _on_focus_exited() -> void:
	focus_changed.emit(false)


func _disconnect_executor() -> void:
	var old = executor_ref.get_ref()
	if old and old.state_changed.is_connected(_on_executor_state_changed):
		old.state_changed.disconnect(_on_executor_state_changed)
	executor_ref = weakref(null)


func _on_executor_state_changed(_s = null) -> void:
	var ex = executor_ref.get_ref()
	set_state(
		_DCKitNS.UI.State.ABORT if ex and ex.is_running() else _DCKitNS.UI.State.EXECUTE
	)
