extends PanelContainer

signal panel_shown
signal panel_hidden
signal panel_expanded
signal panel_collapsed

@export_group("Animation")
@export var opacity_duration:     float = 0.15
@export var fold_unfold_duration: float = 0.30

@export_group("Layout")
# Hard ceiling in px. 0 = use all available space from the parent container.
@export var max_content_height: float = 0.0

var _is_collapsed: bool         = true
var _full_h:       float        = 0.0
var _tween:        Tween        = null
var _content:      PanelContent = null

@onready var _label:   Label = $RootVBox/Header/MarginContainer/HBoxContainer/Label
@onready var _icon:    TextureRect = $RootVBox/Header/MarginContainer/HBoxContainer/AspectRatioContainer/MarginContainer/TextureRect
@onready var _btn:     Button = $RootVBox/Header/Button
@onready var _header:  Control = $RootVBox/Header
@onready var _clip:    Control = $RootVBox/ContentClip
@onready var _scroll:  ScrollContainer = $RootVBox/ContentClip/MarginContainer/ScrollContainer
@onready var _body:    Control   = %ContentBody
func _ready() -> void:
	modulate.a = 0.0
	visible = false
	_set_interactable(false)
	_clip.custom_minimum_size.y = 0.0

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_icon.pivot_offset = _icon.size * 0.5

	_btn.pressed.connect(_on_header_pressed)
	
	_panel_style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _panel_style)
	_set_colors()
	

var highlight_color: Color
var border_color: Color
var _panel_style := StyleBoxFlat.new()

func _set_colors():
	highlight_color = get_theme_color("highlighted_colour", "Consts")
	border_color = get_theme_color("normal_colour", "Consts")

	_panel_style.border_color = border_color.darkened(0.5)
	#_panel_style.bg_color = get_theme_color("panel_bg", "Consts")

	_label.add_theme_color_override("font_color", highlight_color)
	_icon.modulate = highlight_color

# CollapsibleInfo takes ownership of PanelContent.node — do not free it externally.
func set_content(c: PanelContent) -> void:
	var had_content := _content != null
	_content = c

	if c == null:
		_animate_out()
		return

	await _populate()

	if not had_content:
		_fade_in()


func get_content() -> PanelContent:
	return _content

func toggle()   -> void: 
	if _is_collapsed: _expand()
	else: _collapse()
	
func collapse() -> void: _collapse()
func expand()   -> void: _expand()

func is_collapsed() -> bool: return _is_collapsed
func is_showing() -> bool: return visible

func _populate() -> void:
	if _content == null:
		return

	_label.text = _content.title
	_clear_body()

	if _content.node != null:
		_body.add_child(_content.node)

	# Wait for layout so sizes are accurate before we measure.
	await get_tree().process_frame

	var natural_h := _body.get_combined_minimum_size().y
	var new_full_h := minf(natural_h, _available_height())

	if not _is_collapsed and not is_equal_approx(new_full_h, _full_h):
		# Panel is visible and the height changed — animate to the new size.
		_kill_tween()
		_tween = (create_tween()
			.set_ease(Tween.EASE_OUT)
			.set_trans(Tween.TRANS_CUBIC))
		_tween.tween_property(_clip, "custom_minimum_size:y", new_full_h, fold_unfold_duration)

	_full_h = new_full_h

func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)

# Falls back to max_content_height if set, or 9999 (uncapped) if zero.
func _available_height() -> float:
	var parent_h : float = get_parent().size.y if get_parent() is Control else 0.0
	var header_h := _header.size.y

	# Room left after the header sits at the top of the panel.
	var from_parent := maxf(parent_h - header_h, 0.0)

	if max_content_height > 0.0:
		return minf(from_parent, max_content_height)

	return from_parent if from_parent > 0.0 else 9999.0

func _on_header_pressed() -> void:
	toggle()


func _expand() -> void:
	if not _is_collapsed:
		return
	_is_collapsed = false
	_icon.pivot_offset = _icon.size * 0.5

	_kill_tween()
	_tween = (create_tween()
		.set_ease(Tween.EASE_OUT)
		.set_trans(Tween.TRANS_CUBIC)
		.set_parallel(true))
	_tween.tween_property(_clip, "custom_minimum_size:y", _full_h, fold_unfold_duration)
	_tween.tween_property(_icon, "rotation_degrees",      180.0,   fold_unfold_duration)
	_tween.set_parallel(false)
	_tween.tween_callback(panel_expanded.emit)


func _collapse() -> void:
	if _is_collapsed:
		return
	_is_collapsed = true
	_icon.pivot_offset = _icon.size * 0.5

	_kill_tween()
	_tween = (create_tween()
		.set_ease(Tween.EASE_IN)
		.set_trans(Tween.TRANS_CUBIC)
		.set_parallel(true))
	_tween.tween_property(_clip, "custom_minimum_size:y", 0.0,  fold_unfold_duration)
	_tween.tween_property(_icon, "rotation_degrees",      0.0,  fold_unfold_duration)
	
	_tween.set_parallel(false)
	_tween.tween_callback(panel_collapsed.emit)

func _set_interactable(enabled: bool) -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)

	# Optional: stop children too
	_header.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)

	_clip.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)

func _fade_in() -> void:
	_kill_tween()

	# Make interactive before animation starts
	visible = true
	_set_interactable(true)

	modulate.a = 0.0

	_tween = (
		create_tween()
		.set_ease(Tween.EASE_OUT)
		.set_trans(Tween.TRANS_SINE)
	)

	_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		opacity_duration
	)

	_tween.tween_callback(panel_shown.emit)

func _animate_out() -> void:
	_kill_tween()

	# Disable interaction immediately so clicks pass through
	_set_interactable(false)

	_tween = (
		create_tween()
		.set_ease(Tween.EASE_IN)
		.set_trans(Tween.TRANS_SINE)
	)

	_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		opacity_duration
	)

	_tween.tween_callback(func():
		visible = false
		panel_hidden.emit()
	)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

# Wrap your custom Control layout and a header title.
# CollapsibleInfo.set_content() will parent node into the scroll body.
#
#  info_panel.set_content(
#     CollapsibleInfo.PanelContent.new("Enemy", MyEnemyInfoLayout.new())
#  )
#
class PanelContent:
	var title: String  = ""
	var node:  Control = null

	func _init(t: String = "", n: Control = null) -> void:
		title = t
		node  = n
