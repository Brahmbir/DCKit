extends RefCounted

signal font_changed(value: float)
signal log_font_changed(value: float)
signal space_changed(value: float)

const FONT_SIZE := 24
const LOG_FONT_SIZE := 20
const SPACE_SIZE := 16

var font := _DCKitSetting.get_default_font_scale():
	set = set_font
var log_font := _DCKitSetting.get_default_log_font_scale():
	set = set_log_font
var space := _DCKitSetting.get_default_space_scale():
	set = set_space


func set_font(value: float) -> void:
	value = clampf(value, 0.5, 3.0)
	if is_equal_approx(font, value):
		return
	font = value
	font_changed.emit(value)


func set_log_font(value: float) -> void:
	value = clampf(value, 0.5, 3.0)
	if is_equal_approx(log_font, value):
		return
	log_font = value
	log_font_changed.emit(value)


func set_space(value: float) -> void:
	value = clampf(value, 0.5, 3.0)
	if is_equal_approx(space, value):
		return
	space = value
	space_changed.emit(value)


func em_font(em: float) -> int:
	return int(FONT_SIZE * font * em)


func em_log_font(em: float) -> int:
	return int(LOG_FONT_SIZE * log_font * em)


func em_space(em: float) -> int:
	return int(SPACE_SIZE * space * em)
