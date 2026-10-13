@tool
extends "./info_comp_base.gd"

signal panel_shown
signal panel_hidden
signal panel_expanded
signal panel_collapsed

## Editor only: expands the panel in the scene view.
@export var editor_expanded: bool = false:
	set(v):
		editor_expanded = v
		if Engine.is_editor_hint() and is_node_ready():
			if v:
				expand()
			else:
				collapse()

@export var opacity_duration: float = 0.15
@export var fold_unfold_duration: float = 0.2

@export_group("Header Nodes")
@export var header_label: Label
@export var header_texture_rect: TextureRect
@export var header_button: Button
@export_group("Content Nodes")
@export var content_root: Control
@export var content_container: MarginContainer
# Optional. Subclasses use it for scrolling to the active row.
@export var scroll_container: ScrollContainer

@export_group("Layout")
@export var max_content_height: float = 0.0

## Ascending breakpoints in em. The tier is how many the width has passed.
@export var width_breakpoints_em: PackedFloat32Array = [25.0, 50.0, 60.0, 70.0]

var _editor_view: Control = null

#30.0,
var _fold_progress: float = 0.0 # 0 = collapsed, 1 = fully open
#var _info: _DCKitNS.UI.Signature.SignatureInfo = null
var _collapsed: bool = true
var _open_h: float = 0.0 # body height currently applied while expanded
var _fold_signal_pending: bool = false
var _fold_tween: Tween = null
var _fade_tween: Tween = null
var _width_tier: int = -1


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		_build_editor_preview()
		if editor_expanded:
			expand()
		return # skip the hidden/transparent/non-interactive runtime setup

	modulate.a = 0.0
	visible = false
	_set_interactable(false)


func toggle() -> void:
	if _collapsed:
		expand()
	else:
		collapse()


func expand() -> void:
	if not _collapsed:
		return
	_collapsed = false
	_update_header()
	_fold_signal_pending = true
	_tween_fold(1.0, Tween.EASE_OUT)


func collapse() -> void:
	if _collapsed:
		return
	_collapsed = true
	_update_header()
	_fold_signal_pending = true
	_tween_fold(0.0, Tween.EASE_IN)


func is_collapsed() -> bool:
	return _collapsed


func is_showing() -> bool:
	return visible


func _info_changed(had_info: bool) -> void:
	var current := info
	if current == null:
		_hide_panel()
		return

	_update_header()
	_clear_body()
	var view := _create_view(current)
	if view != null and content_container:
		content_container.add_child(view)

	# Wait for layout so sizes are accurate before measuring.
	if is_inside_tree():
		await get_tree().process_frame
	if info != current:
		return # replaced or cleared while waiting

	_refresh_height()
	if not had_info:
		_show_panel()


func _tween_fold(to: float, ease_type: Tween.EaseType) -> void:
	if not content_root:
		return
	_fold_tween = _restart(_fold_tween)

	# in _tween_fold, snap in the editor so there are no tweens running there
	if not sizing_parent or Engine.is_editor_hint():
		_fold_tween.kill()
		_set_fold_progress(to)
		_on_fold_finished()
		return

	_fold_tween.set_ease(ease_type).set_trans(Tween.TRANS_CUBIC)
	_fold_tween.tween_method(_set_fold_progress, _fold_progress, to, fold_unfold_duration)
	_fold_tween.tween_callback(_on_fold_finished)


func _create_view(_info_data: _DCKitNS.UI.Signature.SignatureInfo) -> Control:
	_DCKitNS.not_implemented("_create_view")
	return null


## Editor only. Subclasses return sample content so the fold can be seen
## without a SignatureInfo. Return null for an empty body.
func _create_editor_view() -> Control:
	return null


func _build_editor_preview() -> void:
	if is_instance_valid(_editor_view):
		_editor_view.queue_free()
	_editor_view = _create_editor_view()
	if _editor_view and content_container:
		content_container.add_child(_editor_view) # no owner set, so it is never saved


func _apply_active(_index: int) -> void:
	_DCKitNS.not_implemented("_apply_active")
	pass


func _build() -> void:
	if header_button:
		header_button.pressed.connect(toggle)

	if content_root:
		content_root.clip_contents = true # needed for the fold to clip
		content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_root.custom_minimum_size.y = 0.0

	if content_container:
		content_container.minimum_size_changed.connect(_refresh_height)

	_update_header()


func _update_header() -> void:
	if header_label:
		if Engine.is_editor_hint():
			header_label.text = "Sample command"
		else:
			header_label.text = info.title if info else ""

	if header_texture_rect:
		header_texture_rect.flip_h = true if _collapsed else false
		header_texture_rect.flip_v = true if _collapsed else false


func _clear_body() -> void:
	if not content_container:
		return
	for child in content_container.get_children():
		# Detach first so the old size stops counting right now;
		# queue_free alone only takes effect at the end of the frame.
		content_container.remove_child(child)
		child.queue_free()


func _target_height() -> float:
	if not content_container:
		return 0.0
	return minf(content_container.get_combined_minimum_size().y, _available_height())


func _available_height() -> float:
	var cap := INF
	if sizing_parent and sizing_parent.size.y > 0.0:
		var header_h := header_button.get_combined_minimum_size().y if header_button else 0.0
		cap = maxf(sizing_parent.size.y - header_h, 0.0)
	if max_content_height > 0.0:
		cap = minf(cap, max_content_height)
	return cap


func _restart(old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	return create_tween()


func _on_fold_finished() -> void:
	if not _fold_signal_pending:
		return
	_fold_signal_pending = false
	if _collapsed:
		panel_collapsed.emit()
	else:
		panel_expanded.emit()


func _show_panel() -> void:
	visible = true
	_set_interactable(true)
	_fade_tween = _restart(_fade_tween)
	_fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(self, "modulate:a", 1.0, opacity_duration)
	_fade_tween.tween_callback(panel_shown.emit)


func _hide_panel() -> void:
	# Stop blocking input immediately so clicks pass through during the fade.
	_set_interactable(false)
	_fade_tween = _restart(_fade_tween)
	_fade_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(self, "modulate:a", 0.0, opacity_duration)
	_fade_tween.tween_callback(_on_hidden)


func _on_hidden() -> void:
	visible = false
	_clear_body() # safe: a re-show during the fade kills this tween first
	panel_hidden.emit()


func _set_interactable(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mouse_filter = filter
	if header_button:
		header_button.mouse_filter = filter


func _apply_height() -> void:
	if not content_root:
		return
	content_root.custom_minimum_size.y = _target_height() * _fold_progress


func _set_fold_progress(p: float) -> void:
	_fold_progress = p
	_apply_height()


func _refresh_height() -> void:
	if info == null and not Engine.is_editor_hint():
		return
	_apply_height()
