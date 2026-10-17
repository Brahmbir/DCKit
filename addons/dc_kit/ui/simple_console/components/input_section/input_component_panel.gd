extends "../../../ui_base_class/input_comp_base.gd"

const DIVIDER_TEXT := " :~$"
const _DEBOUNCE_SEC: float = 0.1

const _TEXT_EDIT_INTERFACE := preload("./text_edit_interface.gd")
const _AUTO_COMPLETE_BASE := preload("./auto_suggestion/auto_complete_base.gd")
const _EXECUTE_BASE := preload("./execute_btn/base.gd")

@export var label_perfix: String

@export_group("nodes")
@export var button: PanelContainer # has signal `pressed`
@export var text_edit: TextEdit
@export var auto_complete_comp: Control

@export var label: Label

var executor_ref: WeakRef = weakref(null)
var _hist_obj_ref: WeakRef = weakref(null)
var _state: _DCKitNS.UI.State = _DCKitNS.UI.State.EXECUTE
var _last_submit: float = 0.0


func _enter_tree() -> void:
	_connect_edit_signals()

	if not _DCKitNS.UI.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitNS.UI.mobile_layout.changed.connect(_on_mobile_changed)

	if is_instance_valid(button) and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

	var auto_complete := auto_complete_comp as _AUTO_COMPLETE_BASE
	if is_instance_valid(auto_complete):
		auto_complete.item_accepted.connect(_on_completion_accepted)

		auto_complete.opened.connect(_toggle_history)
		auto_complete.closed.connect(_toggle_history)


func _ready() -> void:
	set_state(_DCKitNS.UI.State.EXECUTE, true)

	var auto_complete := auto_complete_comp as _AUTO_COMPLETE_BASE
	var my_text_edit = text_edit as _TEXT_EDIT_INTERFACE

	if is_instance_valid(auto_complete) and is_instance_valid(my_text_edit):
		my_text_edit.set_auto_complete_ref(auto_complete)

	_on_mobile_changed(_DCKitNS.UI.mobile_layout.mobile) # catch up if spawned late


func _exit_tree() -> void:
	_disconnect_edit_signals()

	if _DCKitNS.UI.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitNS.UI.mobile_layout.changed.disconnect(_on_mobile_changed)

	if is_instance_valid(button) and button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)

	var auto_complete := auto_complete_comp as _AUTO_COMPLETE_BASE
	if is_instance_valid(auto_complete):
		auto_complete.item_accepted.disconnect(_on_completion_accepted)

		auto_complete.opened.disconnect(_toggle_history)
		auto_complete.closed.disconnect(_toggle_history)


func set_state(s: _DCKitNS.UI.State, focus := false) -> void:
	_state = s

	if is_instance_valid(text_edit):
		text_edit.editable = (s == _DCKitNS.UI.State.EXECUTE)

	var exe_btn := button as _EXECUTE_BASE
	if exe_btn:
		exe_btn.set_state(_state, focus)


func get_input_node() -> TextEdit:
	return text_edit


func connect_history_obj(hist_obj: _DCKitNS.UI.CommandHistory) -> void:
	_hist_obj_ref = weakref(hist_obj)
	_apply_history_to_input()


func connect_autocomplete_obj(autocomplete_obj: _DCKitNS.Core.AutoComplete) -> void:
	if not auto_complete_comp:
		push_warning("auto_complete_comp is null")
		return

	var auto_complete := auto_complete_comp as _AUTO_COMPLETE_BASE
	if not auto_complete:
		push_warning("auto_complete_comp is not _AUTO_COMPLETE_BASE type")
		return

	auto_complete.setup(autocomplete_obj)


func connect_executor(executor) -> void:
	_disconnect_executor()
	if executor == null:
		return

	executor_ref = weakref(executor)
	executor.state_changed.connect(_on_executor_state_changed)
	_on_executor_state_changed() # sync right away, so hooking in mid-run is correct


func _toggle_history():
	var auto_complete := auto_complete_comp as _AUTO_COMPLETE_BASE
	if not is_instance_valid(auto_complete):
		return


func _on_completion_accepted(start: int, label: String):
	var caret := text_edit.get_caret_column()
	if start < caret:
		text_edit.remove_text(0, start, 0, caret)
	text_edit.set_caret_column(start)
	text_edit.insert_text_at_caret(label)


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

	var my_text_edit = text_edit as _TEXT_EDIT_INTERFACE
	if my_text_edit:
		my_text_edit.set_history_obj(hist_obj)


func _connect_edit_signals() -> void:
	var my_text_edit = text_edit as _TEXT_EDIT_INTERFACE
	if not is_instance_valid(my_text_edit):
		return

	if not my_text_edit.text_submitted.is_connected(_on_submit):
		my_text_edit.text_submitted.connect(_on_submit)

	if not my_text_edit.text_set.is_connected(_on_text_edit_changed):
		my_text_edit.text_set.connect(_on_text_edit_changed)
	if not my_text_edit.text_changed.is_connected(_on_text_edit_changed):
		my_text_edit.text_changed.connect(_on_text_edit_changed)

	if not my_text_edit.caret_changed.is_connected(_on_text_edit_caret_changed):
		my_text_edit.caret_changed.connect(_on_text_edit_caret_changed)
	if not my_text_edit.focus_entered.is_connected(_on_focus_entered):
		my_text_edit.focus_entered.connect(_on_focus_entered)
	if not my_text_edit.focus_exited.is_connected(_on_focus_exited):
		my_text_edit.focus_exited.connect(_on_focus_exited)


func _disconnect_edit_signals() -> void:
	var my_text_edit = text_edit as _TEXT_EDIT_INTERFACE
	if not is_instance_valid(my_text_edit):
		return

	if my_text_edit.text_submitted.is_connected(_on_submit):
		my_text_edit.text_submitted.disconnect(_on_submit)

	if my_text_edit.text_set.is_connected(_on_text_edit_changed):
		my_text_edit.text_set.disconnect(_on_text_edit_changed)
	if my_text_edit.text_changed.is_connected(_on_text_edit_changed):
		my_text_edit.text_changed.disconnect(_on_text_edit_changed)

	if my_text_edit.caret_changed.is_connected(_on_text_edit_caret_changed):
		my_text_edit.caret_changed.disconnect(_on_text_edit_caret_changed)
	if my_text_edit.focus_entered.is_connected(_on_focus_entered):
		my_text_edit.focus_entered.disconnect(_on_focus_entered)
	if my_text_edit.focus_exited.is_connected(_on_focus_exited):
		my_text_edit.focus_exited.disconnect(_on_focus_exited)


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
	set_state(_DCKitNS.UI.State.ABORT if ex and ex.is_running() else _DCKitNS.UI.State.EXECUTE)
