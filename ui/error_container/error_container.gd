@tool
extends MarginContainer

signal expanded_changed(expanded: bool)
signal item_pressed( pos:int, len:int)

@export_color_no_alpha var col_error := Color("ff6b6b") 
@export_color_no_alpha var col_warn := Color("ffd166") 
@export_color_no_alpha var col_hint := Color("4dabf7") 

@export var expanded: bool = false:
	set(value):
		_pending_expanded = value
		if is_node_ready():
			transition(value)
	get:
		return _expanded

@export var expanded_height: float = 180.0

var _pending_expanded := false
var _expanded := false
var _tween: Tween


const DiagnosticItemScene := preload("./error_item.tscn")

@onready var list: VBoxContainer = %ErrorVbox

@onready var error_btn: Button = %ErrorBtn
@onready var warn_btn: Button = %WarnBtn
@onready var hint_btn: Button = %HintBtn

func show_diagnostic(diags: Array) -> void:
	for child in list.get_children():
		child.queue_free()

	diags.sort_custom(func(a, b) -> bool: return a.severity > b.severity)

	var error_count := 0
	var warn_count := 0
	var hint_count := 0

	for diag in diags:
		match diag.severity:
			diag.Severity.HINT : hint_count += 1
			diag.Severity.WARNING : warn_count += 1
			diag.Severity.ERROR : error_count += 1

		var item = DiagnosticItemScene.instantiate()
		item.set_color(col_error, col_warn, col_hint)
		item.set_diagnostic_data(diag.to_ui_dict())
		item.pressed.connect(_on_item_pressed)
		list.add_child(item)

	error_btn.text = "%d %s" % [error_count, "Error" if error_count == 1 else "Errors"]
	warn_btn.text = "%d %s" % [warn_count, "Warning" if warn_count == 1 else "Warnings"]
	hint_btn.text = "%d %s" % [hint_count, "Hint" if hint_count == 1 else "Hints"]

	error_btn.visible = error_count > 0
	warn_btn.visible = warn_count > 0
	hint_btn.visible = hint_count > 0
	
	transition(not diags.is_empty())

func transition(expanded: bool) -> void:
	if expanded == _expanded:
		return

	var previous := _expanded
	_expanded = expanded

	expanded_changed.emit(expanded)

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	var duration := 0.18

	_tween.tween_property(
		self,
		"modulate:a",
		1.0 if expanded else 0.0,
		duration
	)

	_tween.tween_property(
		self,
		"custom_minimum_size:y",
		expanded_height if expanded else 0.0,
		duration
	)

func _on_item_pressed( pos:int, len:int): item_pressed.emit(pos, len)

func _apply(expanded: bool) -> void:
	_expanded = expanded
	modulate.a = 1.0 if expanded else 0.0
	custom_minimum_size.y = expanded_height if expanded else 0.0

func _ready() -> void:
	clip_contents = true
	
	error_btn.modulate = col_error
	warn_btn.modulate = col_warn
	hint_btn.modulate = col_hint
	error_btn.visible = false
	warn_btn.visible = false
	hint_btn.visible = false
	
	size_flags_vertical = SIZE_SHRINK_BEGIN

	modulate.a = 0.0
	custom_minimum_size.y = 0.0

	_apply(_pending_expanded)
