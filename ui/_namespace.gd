class_name _DCKitUINamespace

enum State {
	EXECUTE = 0,
	ABORT = 1,
}

const CommandHistory := preload("./utills/command_history.gd")

const ConsoleBase := preload("./ui_base_class/console_base.gd")
const InputComponentBase := preload("./ui_base_class/input_comp_base.gd")
const LoggerComponentBase := preload("./ui_base_class/logger_comp_base.gd")
const ErrorComponentBase := preload("./ui_base_class/error_comp_base.gd")

const InputFeedbackController := preload("./controllers/input_feedback_controller.gd")

static var mobile_layout: MobileLayout = null:
	get ():
		if mobile_layout == null:
			mobile_layout = MobileLayout.new()
		return mobile_layout

static var scales: Scales = null:
	get ():
		if scales == null:
			scales = Scales.new()
		return scales


static func call_from_comp(obj: Object, method_name: String, args: Array = []) -> Variant:
	if is_instance_valid(obj) and obj.has_method(method_name):
		return obj.callv(method_name, args)

	if OS.has_feature("Editor"):
		push_error("Component '%s' does not have method '%s()'." % [obj, method_name])

	return null


static func set_var_comp(obj: Object, param_name: String, value: Variant) -> bool:
	if is_instance_valid(obj) and param_name in obj:
		obj.set(param_name, value)
		return true

	if OS.has_feature("Editor"):
		push_error("Component '%s' does not have property '%s'." % [obj, param_name])

	return false


static func not_implemented(function_name: String) -> void:
	push_warning("'%s' is not implemented." % function_name)


class Scales extends RefCounted:
	signal font_changed(value: float)
	signal log_font_changed(value: float)
	signal space_changed(value: float)

	const FONT_SIZE := 24
	const LOG_FONT_SIZE := 20
	const SPACE_SIZE := 16

	var font := 1.0:
		set = set_font
	var log_font := 1.0:
		set = set_log_font
	var space := 1.0:
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


class MobileLayout extends RefCounted:
	signal manual_changed(value: bool)
	signal screen_changed(value: bool)
	signal changed(value: bool)

	var breakpoint_width: float = 600.0

	var manual := false
	var screen := false
	var mobile := false


	func set_manual(value: bool) -> void:
		if manual == value:
			return
		manual = value
		manual_changed.emit(value)
		_update()


	func set_screen_width(width: float) -> void:
		var value := width < breakpoint_width
		if screen == value:
			return
		screen = value
		screen_changed.emit(value)
		_update()


	func _update() -> void:
		var value := manual or screen
		if mobile == value:
			return
		mobile = value
		changed.emit(value)
