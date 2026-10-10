@tool
extends "../../../ui_base_class/error_comp_base.gd"

signal expanded_changed(expanded: bool)

@export var expanded: bool = false:
	set(value):
		_pending_expanded = value
		if is_node_ready():
			transition(value)
	get:
		return _expanded

@export var label: RichTextLabel

@export_color_no_alpha var col_error := Color("ff6b6b")
@export_color_no_alpha var col_warn := Color("ffd166")
@export_color_no_alpha var col_hint := Color("4dabf7")

var sub_text_font_size: int = 10:
	set(value):
		sub_text_font_size = value
		_rebuild_text()

var expanded_height: float = 180.0:
	set(new_height):
		expanded_height = new_height
		if _expanded:
			if _tween:
				_tween.kill()
			_apply(true)

var _diags: Array = []

var _pending_expanded := false
var _expanded := false
var _tween: Tween

@onready var margin := $MarginContainer


func _ready() -> void:
	clip_contents = true

	label.bbcode_enabled = true
	label.meta_clicked.connect(_on_meta_clicked)

	_DCKitNS.UI.scales.font_changed.connect(_on_font_changed)

	size_flags_vertical = SIZE_SHRINK_BEGIN
	modulate.a = 0.0
	custom_minimum_size.y = 0.0
	_apply(_pending_expanded)


func show_diagnostic(diags: Array) -> void:
	diags.sort_custom(
		func(a, b) -> bool:
			return a.severity > b.severity,
	)
	_diags = diags
	_rebuild_text()
	transition(not diags.is_empty())


func transition(expanded: bool) -> void:
	if expanded == _expanded:
		return
	_expanded = expanded
	expanded_changed.emit(expanded)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 1.0 if expanded else 0.0, 0.18)
	_tween.tween_property(self, "custom_minimum_size:y", expanded_height if expanded else 0.0, 0.18)
	#_tween.tween_property(
		#self,
		#"custom_maximum_size:y",
		#expanded_height + 4 if expanded else 0.0,
		#0.18,
	#)


func _on_font_changed(_v: float):
	expanded_height = 4.25 * _DCKitNS.UI.scales.em_font(1)
	sub_text_font_size = _DCKitNS.UI.scales.em_font(0.5)
	pass


func _rebuild_text() -> void:
	if label == null or _diags.is_empty():
		return

	var whole_bb := ""

	for i in _diags.size():
		var diag = _diags[i]
		var d: Dictionary = diag.to_ui_dict()
		var color: Color
		match diag.severity:
			diag.Severity.ERROR:
				color = col_error
			diag.Severity.WARNING:
				color = col_warn
			_:
				color = col_hint

		var msg := str(d.get("message", "")).replace("[", "[lb]")
		var src := str(d.get("source_name", "")).replace("[", "[lb]")
		var rng := str(d.get("range_text", "")).replace("[", "[lb]")

		var meta := "nav:%d,%d" % [int(d.get("position", -1)), int(d.get("length", -1))]

		var scr_bb := "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), src]
		var rng_bb := "[font_size=%d][color=gray]%s[/color][/font_size]" % [
			max(1, sub_text_font_size),
			rng,
		]

		var actions_bb := ""
		for j in d.get("actions", []).size():
			var title := str(d.actions[j].get("title", "")).replace("[", "[lb]")
			actions_bb += " [url=act:%d:%d][color=#%s]%s[/color][/url]" % [
				i,
				j,
				col_hint.to_html(false),
				title,
			]

		whole_bb += "%s %s [url=%s]%s[/url]%s\n" % [scr_bb, rng_bb, meta, msg, actions_bb]

	label.text = whole_bb


func _on_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	var sep := s.find(":")
	if sep == -1:
		return
	var kind := s.substr(0, sep)
	var payload := s.substr(sep + 1)
	match kind:
		"nav":
			_handle_nav(payload)
		"act":
			_handle_act(payload)


func _handle_nav(payload: String) -> void:
	var parts := payload.split(",")
	if parts.size() != 2:
		return
	var pos := int(parts[0])
	var len := int(parts[1])
	if pos == -1 or len == -1:
		return
	item_pressed.emit(pos, len)


func _handle_act(payload: String) -> void:
	var parts := payload.split(":") # "diag_index:action_index"
	if parts.size() != 2:
		return
	var di := int(parts[0])
	if di < 0 or di >= _diags.size():
		return
	action_requested.emit(_diags[di], int(parts[1]))


func _apply(expanded: bool) -> void:
	_expanded = expanded
	modulate.a = 1.0 if expanded else 0.0
	custom_minimum_size.y = expanded_height if expanded else 0.0
