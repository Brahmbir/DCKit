extends PanelContainer

signal pressed

@export var btn_icon_exe: Texture2D
@export var btn_icon_abo: Texture2D

@export_group("Nodes")
@export var hidden_btn: Button
@export var btn_icon: TextureRect
@export var btn_label: Label

@export_group("Style")
@export var execute_color := Color("1c6629")
@export var abort_color := Color("3a1111")

@export var execute_hover_color := Color("268c39")
@export var abort_hover_color := Color("631d1d")

@export var execute_pressed_color := Color("26bf42")
@export var abort_pressed_color := Color("8b2828")

@export var focus_color := Color("454545")
@export var transition_duration := 0.15

var state: _DCKitUINamespace.State = _DCKitUINamespace.State.EXECUTE

var state_data := {
	_DCKitUINamespace.State.EXECUTE: { "text": "EXECUTE", "icon": null },
	_DCKitUINamespace.State.ABORT: { "text": "ABORT", "icon": null },
}

var color_tween: Tween


func _enter_tree() -> void:
	if not _DCKitUINamespace.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitUINamespace.mobile_layout.changed.connect(_on_mobile_changed)

	hidden_btn.pressed.connect(pressed.emit)

	hidden_btn.mouse_entered.connect(_on_button_hovered)
	hidden_btn.mouse_exited.connect(_on_button_unhovered)
	hidden_btn.button_down.connect(_on_button_down)
	hidden_btn.button_up.connect(_on_button_up)
	hidden_btn.focus_entered.connect(_on_button_focus_entered)
	hidden_btn.focus_exited.connect(_on_button_focus_exited)

	_apply_state(false)


func _ready() -> void:
	state_data[_DCKitUINamespace.State.EXECUTE]["icon"] = btn_icon_exe
	state_data[_DCKitUINamespace.State.ABORT]["icon"] = btn_icon_abo

	_on_mobile_changed(_DCKitUINamespace.mobile_layout.mobile)


func _exit_tree() -> void:
	if _DCKitUINamespace.mobile_layout.changed.is_connected(_on_mobile_changed):
		_DCKitUINamespace.mobile_layout.changed.disconnect(_on_mobile_changed)

	hidden_btn.pressed.disconnect(pressed.emit)

	hidden_btn.mouse_entered.disconnect(_on_button_hovered)
	hidden_btn.mouse_exited.disconnect(_on_button_unhovered)
	hidden_btn.button_down.disconnect(_on_button_down)
	hidden_btn.button_up.disconnect(_on_button_up)
	hidden_btn.focus_entered.disconnect(_on_button_focus_entered)
	hidden_btn.focus_exited.disconnect(_on_button_focus_exited)


func set_state(new_state: _DCKitUINamespace.State, focus := false) -> void:
	if not focus and state == new_state:
		return

	state = new_state
	_apply_state(true)


func _on_mobile_changed(is_mobile: bool) -> void:
	btn_icon.visible = not is_mobile


func _apply_state(animate: bool = true) -> void:
	var data: Dictionary = state_data[state]

	btn_label.text = data["text"]
	btn_icon.texture = data["icon"]

	if animate:
		_transition_color(_get_state_color())
	else:
		_set_color(_get_state_color())


func _get_state_color() -> Color:
	match state:
		_DCKitUINamespace.State.EXECUTE:
			return execute_color
		_DCKitUINamespace.State.ABORT:
			return abort_color

	return Color.WHITE


func _get_hover_color() -> Color:
	match state:
		_DCKitUINamespace.State.EXECUTE:
			return execute_hover_color
		_DCKitUINamespace.State.ABORT:
			return abort_hover_color

	return Color.WHITE


func _get_pressed_color() -> Color:
	match state:
		_DCKitUINamespace.State.EXECUTE:
			return execute_pressed_color
		_DCKitUINamespace.State.ABORT:
			return abort_pressed_color

	return Color.WHITE


func _on_button_hovered() -> void:
	_transition_color(_get_hover_color())


func _on_button_unhovered() -> void:
	_transition_color(_get_state_color())


func _on_button_down() -> void:
	_transition_color(_get_pressed_color())


func _on_button_up() -> void:
	if hidden_btn.is_hovered():
		_transition_color(_get_hover_color())
	else:
		_transition_color(_get_state_color())


func _on_button_focus_entered() -> void:
	_transition_color(focus_color)


func _on_button_focus_exited() -> void:
	_transition_color(_get_state_color())


func _set_color(color: Color) -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = color
	add_theme_stylebox_override("panel", style)


func _transition_color(color: Color) -> void:
	if color_tween:
		color_tween.kill()

	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var from_color := style.bg_color

	color_tween = create_tween()
	color_tween.set_trans(Tween.TRANS_SINE)
	color_tween.set_ease(Tween.EASE_OUT)

	color_tween.tween_method(
		func(value: Color):
			style.bg_color = value
			add_theme_stylebox_override("panel", style),
		from_color,
		color,
		transition_duration,
	)
