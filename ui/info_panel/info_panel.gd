extends "./collapsible_info_base.gd"

const PANEL_BG       := Color("#111827")
const PANEL_BORDER   := Color("#243041")
const TITLE_COLOR    := Color("#e5eefb")
const TEXT_COLOR     := Color("#c7d2e1")
const DIM_COLOR      := Color("#8b9ab0")
const ACCENT_COLOR   := Color("#8be9fd")
const ACTIVE_BG      := Color("#172233")
const ACTIVE_BORDER  := Color("#3b82f6")
const HINT_COLOR     := Color("#50fa7b")
const DIM_BG         := Color("#0f1824")
const WARN_COLOR     := Color("#f59e0b")
const ALIAS_COLOR    := Color("#bd93f9")

var _cmd_container:  VBoxContainer
var _ctor_container: VBoxContainer
var _active_arg_row:  Control = null
var _active_sig_row:  Control = null
var _scroll_tween:   Tween    = null


func _ready() -> void:
	super()
	_cmd_container = VBoxContainer.new()
	_cmd_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_container.add_theme_constant_override("separation", 5)

	_ctor_container = VBoxContainer.new()
	_ctor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ctor_container.add_theme_constant_override("separation", 6)


func show_info(current_dict: Dictionary) -> void:
	_active_arg_row = null
	_active_sig_row = null

	if current_dict.is_empty():
		set_content(null)
		return

	var kind := str(current_dict.get("kind", ""))
	match kind:
		"command":
			_rebuild_command(current_dict)
			await set_content(PanelContent.new(str(current_dict.get("title", "Command")), _cmd_container))
			_smooth_scroll_to_active()
		"constructor":
			_rebuild_constructor(current_dict)
			await set_content(PanelContent.new(str(current_dict.get("title", "Constructor")), _ctor_container))
			_smooth_scroll_to_active()
		_:
			set_content(null)


# COMMAND
func _rebuild_command(data: Dictionary) -> void:
	for c in _cmd_container.get_children():
		c.queue_free()

	var desc          := str(data.get("description", ""))
	var params: Array  = data.get("params", [])
	var active_idx    := int(data.get("active_index", -1))
	var aliases: Array = data.get("aliases", [])
	var deprecated    := bool(data.get("deprecated", false))
	var dep_msg       := str(data.get("deprecated_message", ""))
	var log_mode_name := str(data.get("log_mode_name", "NORMAL"))

	# 1. Deprecated warning banner (most prominent — always first).
	if deprecated:
		_cmd_container.add_child(_make_deprecated_banner(dep_msg))

	# 2. Description.
	if desc != "":
		var lbl := _make_rich_label()
		lbl.text = "[color=%s]%s[/color]" % [TEXT_COLOR.to_html(false), desc]
		_cmd_container.add_child(_boxed(lbl, 0, 0, 0, 4))

	# 3. Aliases row (shown only when present).
	if not aliases.is_empty():
		_cmd_container.add_child(_make_aliases_row(aliases))

	# 4. Log-mode badge (shown only when non-default).
	if log_mode_name != "NORMAL":
		_cmd_container.add_child(_make_log_mode_row(log_mode_name))

	# 5. Parameter list.
	if params.is_empty():
		_cmd_container.add_child(_make_empty_state("No arguments"))
		return

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	_cmd_container.add_child(rows)

	for i in params.size():
		var row := _make_command_row(i, params[i], i == active_idx)
		rows.add_child(row)
		if i == active_idx:
			_active_arg_row = row


func _make_deprecated_banner(msg: String) -> Control:
	var lbl  := _make_rich_label()
	var warn := WARN_COLOR.to_html(false)
	var text := "[color=%s][b]⚠  deprecated[/b][/color]" % warn
	if msg != "":
		text += "\n[color=%s]%s[/color]" % [TEXT_COLOR.to_html(false), msg]
	lbl.text = text

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color         = Color(WARN_COLOR, 0.08)
	s.border_color     = Color(WARN_COLOR, 0.45)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)
	panel.add_child(_boxed(lbl, 10, 5, 10, 5))
	return _boxed(panel, 0, 0, 0, 2)


func _make_aliases_row(aliases: Array) -> Control:
	var lbl := _make_oneliner()
	var formatted := ", ".join(aliases.map(
			func(a: String) -> String:
				return "[b][color=%s]%s[/color][/b]" % [ALIAS_COLOR.to_html(false), a]))
	lbl.text = "[color=%s]also  [/color]%s" % [DIM_COLOR.to_html(false), formatted]
	return _boxed(lbl, 0, 0, 0, 2)


func _make_log_mode_row(mode_name: String) -> Control:
	var lbl  := _make_oneliner()
	var label := mode_name.to_lower().replace("_", " ")
	lbl.text = "[color=%s]log  [/color][color=%s]%s[/color]" % [
		DIM_COLOR.to_html(false), DIM_COLOR.to_html(false), label
	]
	return _boxed(lbl, 0, 0, 0, 2)


func _make_command_row(idx: int, param, is_active: bool) -> Control:
	var p_name: String = _get_val(param, "name", "param_%d" % (idx + 1))
	var p_desc: String = _get_val(param, "description", "")
	var has_sug: bool  = bool(_get_val(param, "has_suggestions", false))
	var is_rest: bool  = bool(_get_val(param, "is_rest", false))

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 2)

	# index badge + name
	var line      := _make_oneliner()
	var badge_col := ACCENT_COLOR.to_html(false) if is_active else DIM_COLOR.to_html(false)
	var name_col  := TITLE_COLOR.to_html(false)  if is_active else TEXT_COLOR.to_html(false)
	var arrow     := "▶ " if is_active else "   "
	var sug_tag   := ("  [color=%s]◈[/color]" % HINT_COLOR.to_html(false)) if has_sug else ""
	var rest_tag  := ("[color=%s]…_[/color]" % DIM_COLOR.to_html(false)) if is_rest else ""

	line.text = (
		"[color=%s]%s[b][%d %s][/b][/color]  [color=%s]%s[/color] %s"
		% [badge_col, arrow, idx + 1, rest_tag, name_col, p_name, sug_tag]
	)
	root.add_child(line)

	if p_desc != "":
		var dl := _make_rich_label()
		dl.text = "[color=%s]%s[/color]" % [
			TEXT_COLOR.to_html(false) if is_active else DIM_COLOR.to_html(false),
			p_desc
		]
		root.add_child(_boxed(dl, 26, 0, 0, 0))

	return _param_panel(root, is_active)


# CONSTRUCTOR

func _rebuild_constructor(data: Dictionary) -> void:
	for c in _ctor_container.get_children():
		c.queue_free()

	var desc        := str(data.get("description", ""))
	var sigs: Array  = data.get("signatures", [])
	var active_part := int(data.get("active_index", -1))

	if desc != "":
		var lbl := _make_rich_label()
		lbl.text = "[color=%s]%s[/color]" % [TEXT_COLOR.to_html(false), desc]
		_ctor_container.add_child(_boxed(lbl, 0, 0, 0, 4))

	if sigs.is_empty():
		_ctor_container.add_child(_make_empty_state("No signatures"))
		return

	# pick best-matching signature automatically
	var best_idx   := 0
	var best_score := -1
	for i in sigs.size():
		var m := int(sigs[i].get("matches", 0))
		if m > best_score:
			best_score = m
			best_idx   = i

	if sigs.size() > 1:
		var count_lbl := _make_rich_label()
		count_lbl.text = "[color=%s]signature %d / %d[/color]" % [
			DIM_COLOR.to_html(false), best_idx + 1, sigs.size()
		]
		_ctor_container.add_child(_boxed(count_lbl, 0, 0, 0, 0))

	for i in sigs.size():
		var block := _make_sig_block(sigs[i], active_part, i == best_idx)
		_ctor_container.add_child(block)
		if i == best_idx:
			_active_sig_row = block


func _make_sig_block(sig: Dictionary, active_part: int, is_best: bool) -> Control:
	var parts: Array = sig.get("parts", [])
	var usage    := str(sig.get("usage", ""))
	var sig_desc := str(sig.get("description", ""))

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 5)

	if usage != "":
		var ul := _make_oneliner()
		ul.text = "[color=%s][code]%s[/code][/color]" % [
			ACCENT_COLOR.to_html(false) if is_best else DIM_COLOR.to_html(false),
			usage
		]
		root.add_child(ul)

	if sig_desc != "":
		var sdl := _make_rich_label()
		sdl.text = "[color=%s]%s[/color]" % [DIM_COLOR.to_html(false), sig_desc]
		root.add_child(sdl)

	if is_best and active_part >= 0 and active_part < parts.size():
		root.add_child(_make_part_detail(parts[active_part]))

	var wrapped := _boxed(root, 10, 7, 10, 7)

	if not is_best:
		var dim := PanelContainer.new()
		dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ds := StyleBoxFlat.new()
		ds.bg_color     = DIM_BG
		ds.border_color = PANEL_BORDER
		ds.set_border_width_all(1)
		ds.set_corner_radius_all(5)
		dim.add_theme_stylebox_override("panel", ds)
		dim.add_child(wrapped)
		return dim

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color     = ACTIVE_BG
	ps.border_color = ACTIVE_BORDER
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ps)
	panel.add_child(wrapped)
	return panel


func _make_part_detail(part: Dictionary) -> Control:
	var p_name    := str(part.get("name", ""))
	var type_hint := str(part.get("type_hint", ""))
	var p_desc    := str(part.get("description", ""))
	var accepted  := str(part.get("accepted_types", ""))

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 3)

	var name_line := _make_oneliner()
	var type_tag  := ("  [color=%s]%s[/color]" % [DIM_COLOR.to_html(false), type_hint]) if type_hint != "" else ""
	name_line.text = "[b][color=%s]%s[/color][/b]%s" % [ACCENT_COLOR.to_html(false), p_name, type_tag]
	root.add_child(name_line)

	if p_desc != "":
		var dl := _make_rich_label()
		dl.text = "[color=%s]%s[/color]" % [TEXT_COLOR.to_html(false), p_desc]
		root.add_child(dl)

	if accepted != "" and accepted != type_hint:
		var al := _make_rich_label()
		al.text = "[color=%s]accepts  %s[/color]" % [DIM_COLOR.to_html(false), accepted]
		root.add_child(al)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color         = Color("#0d1829")
	s.border_color     = ACTIVE_BORDER
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)
	panel.add_child(_boxed(root, 10, 6, 10, 6))
	return panel


# SHARED HELPERS
func _smooth_scroll_to_active() -> void:
	var target: Control = _active_arg_row if _active_arg_row != null else _active_sig_row
	if target == null:
		return

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(target):
		return

	var row_top    := target.get_global_rect().position.y
	var scroll_top := _scroll.get_global_rect().position.y
	var dest       := int(row_top - scroll_top) + _scroll.scroll_vertical
	dest = clampi(dest, 0, _scroll.get_v_scroll_bar().max_value)

	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()

	_scroll_tween = create_tween()
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.tween_property(_scroll, "scroll_vertical", dest, 0.2)


func _param_panel(inner: Control, is_active: bool) -> Control:
	var wrapped := _boxed(inner, 10, 6, 10, 6)
	if not is_active:
		return wrapped

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color     = ACTIVE_BG
	s.border_color = ACTIVE_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", s)
	panel.add_child(wrapped)
	return panel


func _make_empty_state(msg: String) -> Control:
	var lbl := _make_rich_label()
	lbl.text = "[color=%s][i]%s[/i][/color]" % [DIM_COLOR.to_html(false), msg]
	return _boxed(lbl, 8, 4, 8, 4)


func _make_oneliner() -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled  = true
	lbl.fit_content     = true
	lbl.scroll_active   = false
	lbl.autowrap_mode   = TextServer.AUTOWRAP_OFF
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_rich_label() -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled  = true
	lbl.fit_content     = true
	lbl.scroll_active   = false
	lbl.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _boxed(node: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(node)
	return m


func _get_val(item, key: String, default = null):
	if item == null:      return default
	if item is Dictionary: return item.get(key, default)
	if item is Object:     return item.get(key)
	return default
