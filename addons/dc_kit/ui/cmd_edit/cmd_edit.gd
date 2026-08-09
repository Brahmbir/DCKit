extends HBoxContainer

signal focus_changed(has_focus: bool)
signal command_submitted(raw: String)
signal abort_requested

signal input_text_changed(text: String, caret_pos: int)
signal caret_changed(caret_pos: int)

#  STATE
enum State {
	IDLE,
	BUSY,
}

const TextCmdEdit = preload("./text_edit_to_cmd_edit.gd")
const AutoCompletePopup = preload("./completion_popup.gd")

const _DEBOUNCE_SEC: float = 0.1

var _state: State = State.IDLE
var _last_submit: float = 0.0

var _tween: Tween
var _highlighted_colour := Color.BLACK
var _normal_colour := Color.BLACK

var _sct_toggle_popup: Shortcut = _make_shortcut(KEY_SPACE, true)

@onready var button: Button = %Button
@onready var masked_icon_panel: MaskedIconPanel = %MaskedIconPanel
@onready var text_edit: TextCmdEdit = %TextEdit

@onready var label: Label = %Label
@onready var autocomplete_popup: AutoCompletePopup = %PopupPanel


func _ready() -> void:
	theme_changed.connect(set_colors)
	resized.connect(set_btn_min_size)

	set_colors()

	text_edit.text_changed.connect(_on_text_changed)
	text_edit.caret_changed.connect(_on_caret_changed)

	text_edit.text_submitted.connect(_on_submit)
	text_edit.focus_entered.connect(_on_focus_entered)
	text_edit.focus_exited.connect(_on_focus_exited)

	button.pressed.connect(_on_button_pressed)
	masked_icon_panel.accent_color = _highlighted_colour
	_set_state(State.IDLE)

	autocomplete_popup.item_accepted.connect(_on_completion_accepted)


func _input(event: InputEvent) -> void:
	if not text_edit.has_focus():
		return
	if not (event is InputEventKey) or not event.pressed:
		return

	if _shortcut_pressed(event, _sct_toggle_popup) and not event.echo:
		if autocomplete_popup.is_open():
			autocomplete_popup.hide_popup()
		elif autocomplete_popup.show_popup():
			_forus_update_popup_position()
		accept_event()
		return

	if not autocomplete_popup.is_open():
		return

	match event.keycode:
		KEY_UP:
			autocomplete_popup.navigate(-1)
			accept_event()
		KEY_DOWN:
			autocomplete_popup.navigate(1)
			accept_event()
		KEY_TAB:
			if not event.echo:
				if event.shift_pressed:
					autocomplete_popup.navigate(-1)
				else:
					autocomplete_popup.accept()
			accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				autocomplete_popup.accept()
			accept_event()
		KEY_ESCAPE:
			if not event.echo:
				autocomplete_popup.hide_popup()
			accept_event()


func set_btn_min_size():
	button.get_parent().custom_minimum_size.x = size.y


func set_colors():
	_highlighted_colour = get_theme_color("highlighted_colour", "Consts")
	_normal_colour = get_theme_color("normal_colour", "Consts")

	masked_icon_panel.accent_color = _highlighted_colour


func move_caret_to(col: int) -> void:
	var line := text_edit.get_caret_line()
	text_edit.set_caret_line(line)
	text_edit.set_caret_column(col)
	text_edit.grab_focus(true)


func set_busy(is_busy: bool) -> void:
	_set_state(State.BUSY if is_busy else State.IDLE)


func focus() -> void:
	text_edit.grab_focus()


func _on_submit(raw: String) -> void:
	if _state == State.BUSY:
		return
	var now: float = Time.get_unix_time_from_system()
	if now - _last_submit < _DEBOUNCE_SEC:
		return

	var text: String = raw.strip_edges()
	if text.is_empty():
		return
	_last_submit = now

	command_submitted.emit(text)


#region SIGNAL HANDLERS
func _on_focus_entered() -> void:
	_tween_label_color(_highlighted_colour)
	focus_entered.emit()
	focus_changed.emit(true)


func _on_focus_exited() -> void:
	_tween_label_color(_normal_colour)
	autocomplete_popup.hide_popup()
	focus_exited.emit()
	focus_changed.emit(false)


func _on_button_pressed() -> void:
	if _state == State.BUSY:
		abort_requested.emit()
	elif text_edit != null:
		text_edit.on_submit()
		#on_submit(text_edit.text)


func _on_text_changed() -> void:
	var caret := text_edit.get_caret_column()
	input_text_changed.emit(text_edit.text, caret)
	_refresh_popup()


func _on_caret_changed() -> void:
	var caret := text_edit.get_caret_column()
	caret_changed.emit(caret)
	if autocomplete_popup.is_open():
		_refresh_popup()


func _on_completion_accepted(start: int, label: String) -> void:
	var caret := text_edit.get_caret_column()
	if start < caret:
		text_edit.remove_text(0, start, 0, caret)
	text_edit.set_caret_column(start)
	text_edit.insert_text_at_caret(label)
#endregion


func _refresh_popup() -> void:
	if not autocomplete_popup.is_open():
		return
	if autocomplete_popup.has_items():
		_forus_update_popup_position()
	else:
		autocomplete_popup.hide_popup()


func _update_popup_position() -> void:
	if not autocomplete_popup.is_open():
		return
	_forus_update_popup_position()


func _forus_update_popup_position() -> void:
	var caret_pos := text_edit.global_position + text_edit.get_caret_draw_pos()

	var popup_w := maxf(autocomplete_popup.size.x, autocomplete_popup.get_combined_minimum_size().x)
	var min_x := text_edit.global_position.x
	var max_x := maxf(text_edit.global_position.x + text_edit.size.x - popup_w, min_x)

	autocomplete_popup.global_position = Vector2(
		clampf(caret_pos.x + 10, min_x, max_x),
		caret_pos.y - autocomplete_popup.expected_height() - text_edit.get_line_height(),
	)


func _tween_label_color(to_color: Color, duration := 0.1) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	var from_color := label.get_theme_color("font_color")
	_tween = create_tween()

	_tween.tween_method(
		func(c: Color):
			label.add_theme_color_override("font_color", c),
		from_color,
		to_color,
		duration,
	)


func _set_state(s: State) -> void:
	_state = s
	masked_icon_panel.is_off = (s != State.BUSY)
	text_edit.editable = s == State.IDLE


#region  helpers
func _shortcut_pressed(event: InputEvent, shortcut: Shortcut) -> bool:
	return (event is InputEventKey and event.pressed and shortcut.matches_event(event))


func _make_shortcut(key: Key, ctrl := false, shift := false, alt := false) -> Shortcut:
	var key_event := InputEventKey.new()

	key_event.keycode = key
	key_event.ctrl_pressed = ctrl
	key_event.shift_pressed = shift
	key_event.alt_pressed = alt
	key_event.command_or_control_autoremap = true

	var shortcut := Shortcut.new()
	shortcut.events = [key_event]

	return shortcut
#endregion
