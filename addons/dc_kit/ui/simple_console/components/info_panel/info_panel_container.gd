extends "./collapsible_info_base.gd"

const Sig = _DCKitNS.UI.Signature

# TEMP: old hardcoded colors, to move into the theme during the styling pass.
const TITLE_COLOR := Color("#e5eefb")
const TEXT_COLOR := Color("#c7d2e1")
const DIM_COLOR := Color("#8b9ab0")
const ACCENT_COLOR := Color("#8be9fd")
const ACTIVE_BG := Color("#172233")
const ACTIVE_BORDER := Color("#3b82f6")
const HINT_COLOR := Color("#50fa7b")
const DIM_BG := Color("#0f1824")
const PANEL_BORDER := Color("#243041")
const WARN_COLOR := Color("#f59e0b")
const ALIAS_COLOR := Color("#bd93f9")


# Handles to the parts that change when only the active slot moves.
class ParamRow:
	var info: Sig.ParamInfo
	var panel: PanelContainer
	var line: RichTextLabel
	var desc: RichTextLabel # null when the param has no description


class SigBlock:
	var info: Sig.TypeSignatureInfo
	var panel: PanelContainer
	var usage: RichTextLabel # null when there is no usage text
	var detail: VBoxContainer # holds the active part's detail


var _param_rows: Array[ParamRow] = []
var _sig_blocks: Array[SigBlock] = []
var _count_label: RichTextLabel = null
var _scroll_tween: Tween = null


# --- hooks from the base ----------------------------------------------------
func _create_view(info: Sig.SignatureInfo) -> Control:
	_param_rows.clear()
	_sig_blocks.clear()
	_count_label = null
	match info.type:
		"command":
			return _build_command(info as Sig.CommandInfo)
		"constructor":
			return _build_constructor(info as Sig.ConstructorInfo)
		_:
			push_warning("InfoPanel: no view for type '%s'" % info.type)
			return null


func _apply_active(index: int) -> void:
	match _info.type:
		"command":
			_apply_command_active(index)
		"constructor":
			_apply_constructor_active(index)


# --- command ----------------------------------------------------------------
func _build_command(info: Sig.CommandInfo) -> Control:
	var root := _vbox(5)

	if info.deprecated:
		root.add_child(_make_deprecated_banner(info.deprecated_message))
	if info.description != "":
		root.add_child(_boxed(_rich(info.description, TEXT_COLOR), 0, 0, 0, 4))
	if not info.aliases.is_empty():
		root.add_child(_make_aliases_row(info.aliases))
	if info.log_mode_name != "NORMAL":
		root.add_child(_make_log_mode_row(info.log_mode_name))

	if info.params.is_empty():
		root.add_child(_make_empty_state("No arguments"))
		return root

	var rows := _vbox(3)
	root.add_child(rows)
	for p in info.params:
		var row := _make_param_row(p)
		_param_rows.append(row)
		rows.add_child(row.panel)
	return root


func _apply_command_active(index: int) -> void:
	var target: Control = null
	for row in _param_rows:
		var active := row.info.index == index
		_style_param_row(row, active)
		if active:
			target = row.panel
	_smooth_scroll_to(target)


func _make_param_row(p: Sig.ParamInfo) -> ParamRow:
	var row := ParamRow.new()
	row.info = p

	var root := _vbox(2)
	row.line = _make_oneliner()
	root.add_child(row.line)
	if p.description != "":
		row.desc = _make_rich_label()
		root.add_child(_boxed(row.desc, 26, 0, 0, 0))

	row.panel = PanelContainer.new()
	row.panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.panel.add_child(_boxed(root, 10, 6, 10, 6))
	_style_param_row(row, false)
	return row


func _style_param_row(row: ParamRow, active: bool) -> void:
	var p := row.info
	var badge := ACCENT_COLOR if active else DIM_COLOR
	var name_col := TITLE_COLOR if active else TEXT_COLOR
	var arrow := "▶ " if active else "   "
	var sug := ("  [color=%s]◈[/color]" % HINT_COLOR.to_html(false)) if p.has_suggestions else ""
	var rest := ("[color=%s]…[/color]" % DIM_COLOR.to_html(false)) if p.is_rest else ""

	# [lb]/[rb] are literal brackets; a bare "[1]" would be parsed as a tag.
	row.line.text = "[color=%s]%s[b][lb]%d%s[rb][/b][/color]  [color=%s]%s[/color]%s" % [
		badge.to_html(false), arrow, p.index + 1, rest,
		name_col.to_html(false), p.name, sug,
	]
	if row.desc:
		row.desc.text = "[color=%s]%s[/color]" % [
			(TEXT_COLOR if active else DIM_COLOR).to_html(false), p.description,
		]

	var style: StyleBox = _flat(ACTIVE_BG, ACTIVE_BORDER, 6) if active else StyleBoxEmpty.new()
	row.panel.add_theme_stylebox_override("panel", style)


# --- constructor ------------------------------------------------------------
func _build_constructor(info: Sig.ConstructorInfo) -> Control:
	var root := _vbox(6)

	if info.description != "":
		root.add_child(_boxed(_rich(info.description, TEXT_COLOR), 0, 0, 0, 4))
	if info.signatures.is_empty():
		root.add_child(_make_empty_state("No signatures"))
		return root

	if info.signatures.size() > 1:
		_count_label = _make_rich_label()
		root.add_child(_count_label)

	for sig in info.signatures:
		var block := _make_sig_block(sig)
		_sig_blocks.append(block)
		root.add_child(block.panel)
	return root


func _apply_constructor_active(index: int) -> void:
	if _sig_blocks.is_empty():
		return
	var best := _best_signature(index)

	for i in _sig_blocks.size():
		var block := _sig_blocks[i]
		var is_best := i == best
		_style_sig_block(block, is_best)
		_fill_detail(block, index if is_best else -1)

	if _count_label:
		_count_label.text = "[color=%s]signature %d / %d[/color]" % [
			DIM_COLOR.to_html(false), best + 1, _sig_blocks.size(),
		]
	_smooth_scroll_to(_sig_blocks[best].panel)


# The signature matching the most parts typed so far; ties go to the first.
func _best_signature(index: int) -> int:
	var best := 0
	var best_score := -1
	for i in _sig_blocks.size():
		var m := _sig_blocks[i].info.matches_count(index)
		if m > best_score:
			best_score = m
			best = i
	return best


func _make_sig_block(sig: Sig.TypeSignatureInfo) -> SigBlock:
	var block := SigBlock.new()
	block.info = sig

	var root := _vbox(5)
	if sig.usage != "":
		block.usage = _make_oneliner()
		root.add_child(block.usage)
	if sig.description != "":
		root.add_child(_rich(sig.description, DIM_COLOR))
	block.detail = _vbox(0)
	root.add_child(block.detail)

	block.panel = PanelContainer.new()
	block.panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.panel.add_child(_boxed(root, 10, 7, 10, 7))
	_style_sig_block(block, false)
	return block


func _style_sig_block(block: SigBlock, is_best: bool) -> void:
	if block.usage:
		block.usage.text = "[color=%s][code]%s[/code][/color]" % [
			(ACCENT_COLOR if is_best else DIM_COLOR).to_html(false), block.info.usage,
		]
	var style := _flat(ACTIVE_BG, ACTIVE_BORDER, 6) if is_best else _flat(DIM_BG, PANEL_BORDER, 5)
	block.panel.add_theme_stylebox_override("panel", style)


# part_index < 0 clears the detail.
func _fill_detail(block: SigBlock, part_index: int) -> void:
	for c in block.detail.get_children():
		block.detail.remove_child(c)
		c.queue_free()
	if part_index >= 0 and part_index < block.info.parts.size():
		block.detail.add_child(_make_part_detail(block.info.parts[part_index]))


func _make_part_detail(part: Sig.PartInfo) -> Control:
	var root := _vbox(3)

	var tag := ("  [color=%s]%s[/color]" % [DIM_COLOR.to_html(false), part.type_hint]) \
		if part.type_hint != "" else ""
	var name_line := _make_oneliner()
	name_line.text = "[b][color=%s]%s[/color][/b]%s" % [ACCENT_COLOR.to_html(false), part.name, tag]
	root.add_child(name_line)

	if part.description != "":
		root.add_child(_rich(part.description, TEXT_COLOR))
	if part.accepted_types != "" and part.accepted_types != part.type_hint:
		root.add_child(_rich("accepts  " + part.accepted_types, DIM_COLOR))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _flat(Color("#0d1829"), ACTIVE_BORDER, 4)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(_boxed(root, 10, 6, 10, 6))
	return _boxed(panel, 0, 5, 0, 0)


# --- command extras ---------------------------------------------------------
func _make_deprecated_banner(msg: String) -> Control:
	var text := "[color=%s][b]⚠  deprecated[/b][/color]" % WARN_COLOR.to_html(false)
	if msg != "":
		text += "\n[color=%s]%s[/color]" % [TEXT_COLOR.to_html(false), msg]
	var lbl := _make_rich_label()
	lbl.text = text

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _flat(Color(WARN_COLOR, 0.08), Color(WARN_COLOR, 0.45), 4)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(_boxed(lbl, 10, 5, 10, 5))
	return _boxed(panel, 0, 0, 0, 2)


func _make_aliases_row(aliases: PackedStringArray) -> Control:
	var parts: PackedStringArray = []
	for a in aliases:
		parts.append("[b][color=%s]%s[/color][/b]" % [ALIAS_COLOR.to_html(false), a])
	var lbl := _make_oneliner()
	lbl.text = "[color=%s]also  [/color]%s" % [DIM_COLOR.to_html(false), ", ".join(parts)]
	return _boxed(lbl, 0, 0, 0, 2)


func _make_log_mode_row(mode_name: String) -> Control:
	var lbl := _make_oneliner()
	lbl.text = "[color=%s]log  %s[/color]" % [
		DIM_COLOR.to_html(false), mode_name.to_lower().replace("_", " "),
	]
	return _boxed(lbl, 0, 0, 0, 2)


# --- scrolling --------------------------------------------------------------
func _smooth_scroll_to(target: Control) -> void:
	if target == null or scroll_container == null:
		return

	# Let layout settle after the restyle, and after a fresh build.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(target) or not target.is_inside_tree():
		return

	var row_top := target.get_global_rect().position.y
	var scroll_top := scroll_container.get_global_rect().position.y
	var dest := int(row_top - scroll_top) + scroll_container.scroll_vertical
	dest = clampi(dest, 0, int(scroll_container.get_v_scroll_bar().max_value))

	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.tween_property(scroll_container, "scroll_vertical", dest, 0.2)


# --- small helpers ----------------------------------------------------------
func _vbox(separation: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", separation)
	return v


func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s


func _rich(text: String, color: Color) -> RichTextLabel:
	var lbl := _make_rich_label()
	lbl.text = "[color=%s]%s[/color]" % [color.to_html(false), text]
	return lbl


func _make_empty_state(msg: String) -> Control:
	var lbl := _make_rich_label()
	lbl.text = "[color=%s][i]%s[/i][/color]" % [DIM_COLOR.to_html(false), msg]
	return _boxed(lbl, 8, 4, 8, 4)


func _make_oneliner() -> RichTextLabel:
	var lbl := _make_rich_label()
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl


func _make_rich_label() -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
