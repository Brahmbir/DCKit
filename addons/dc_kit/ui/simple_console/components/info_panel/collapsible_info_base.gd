@tool
extends "../../../ui_base_class/info_panel_base.gd"

@export var opacity_duration: float = 0.15
@export var fold_unfold_duration: float = 0.13

@export_group("Header Nodes")
@export var header_label: Label
@export var header_texture_rect: TextureRect
@export var header_button: Button
@export_group("Content Nodes")
@export var content_root: MarginContainer
@export var content_container: MarginContainer
## Optional. Subclasses use it for scrolling to the active row.
@export var scroll_container: ScrollContainer

@export_group("Layout")
@export var max_content_height: float = 0.0

var _info: _DCKitNS.UI.Signature.SignatureInfo = null
var _collapsed: bool = true
var _open_h: float = 0.0 # body height currently applied while expanded
var _fold_signal_pending: bool = false
var _fold_tween: Tween = null
var _fade_tween: Tween = null


func _ready() -> void:
	print_tree()
	_build()
	modulate.a = 0.0
	visible = false
	_set_interactable(false)

	# Keep the expanded height correct when the parent is resized.
	var p := get_parent() as Control
	if p:
		p.resized.connect(_refresh_height)


# --- public API -------------------------------------------------------------
func show_info(info: _DCKitNS.UI.Signature.SignatureInfo) -> void:
	var had_info := _info != null
	_info = info

	if info == null:
		_hide_panel()
		return

	_update_header()
	_clear_body()
	var view := _create_view(info)
	if view != null and content_container:
		content_container.add_child(view)

	# Wait for layout so sizes are accurate before measuring.
	if is_inside_tree():
		await get_tree().process_frame
	if _info != info:
		return # replaced or cleared while waiting

	_refresh_height()
	if not had_info:
		_show_panel()


func set_active(index: int) -> void:
	if _info == null:
		return
	_apply_active(index)


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
	_open_h = _target_height()
	_fold_signal_pending = true
	_tween_clip(_open_h, Tween.EASE_OUT)


func collapse() -> void:
	if _collapsed:
		return
	_collapsed = true
	_update_header()
	_fold_signal_pending = true
	_tween_clip(0.0, Tween.EASE_IN)


func is_collapsed() -> bool:
	return _collapsed


func is_showing() -> bool:
	return visible


# --- subclass hooks ---------------------------------------------------------
## Build the body for a new definition. The panel owns the result and frees it
## when the definition changes or the panel finishes hiding.
func _create_view(_info_data: _DCKitNS.UI.Signature.SignatureInfo) -> Control:
	_DCKitNS.UI.not_implemented("_create_view")
	return null


## The active slot moved within the current definition. Restyle, don't rebuild.
func _apply_active(_index: int) -> void:
	_DCKitNS.UI.not_implemented("_apply_active")
	pass


# --- construction -----------------------------------------------------------
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
		header_label.text = _info.title if _info else ""

	if header_texture_rect:
		header_texture_rect.flip_h = true if _collapsed else false
		header_texture_rect.flip_v = true if _collapsed else false

	if header_button:
		header_button.text = "enabled" if _info else "disabled"


func _clear_body() -> void:
	if not content_container:
		return
	for child in content_container.get_children():
		# Detach first so the old size stops counting right now;
		# queue_free alone only takes effect at the end of the frame.
		content_container.remove_child(child)
		child.queue_free()


# --- height -----------------------------------------------------------------
func _target_height() -> float:
	if not content_container:
		return 0.0
	return minf(content_container.get_combined_minimum_size().y, _available_height())


func _available_height() -> float:
	var cap := INF
	var p := get_parent() as Control
	if p and p.size.y > 0.0:
		var header_h := header_button.get_combined_minimum_size().y if header_button else 0.0
		cap = maxf(p.size.y - header_h, 0.0)
	if max_content_height > 0.0:
		cap = minf(cap, max_content_height)
	return cap


## Re-measures and animates to the new height, only while expanded.
func _refresh_height() -> void:
	if _collapsed or _info == null:
		return
	var h := _target_height()
	if is_equal_approx(h, _open_h):
		return
	_open_h = h
	_tween_clip(h, Tween.EASE_OUT)


# --- animation --------------------------------------------------------------
func _restart(old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	return create_tween()


func _tween_clip(to: float, ease_type: Tween.EaseType) -> void:
	if not content_root:
		return
	_fold_tween = _restart(_fold_tween)
	_fold_tween.set_ease(ease_type).set_trans(Tween.TRANS_CUBIC)
	_fold_tween.tween_property(
		content_root,
		"custom_minimum_size:y",
		to,
		fold_unfold_duration,
	)
	_fold_tween.tween_callback(_on_fold_finished)


# Emits only for a real expand/collapse, not for height refreshes. A refresh
# during an expand re-tweens, and the pending flag still emits at the end.
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
