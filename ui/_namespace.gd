extends RefCounted

enum State {
	EXECUTE = 0,
	ABORT = 1,
}

const CommandHistory := preload("./utills/command_history.gd")

const ConsoleBase := preload("./ui_base_class/console_base.gd")
const InputComponentBase := preload("./ui_base_class/input_comp_base.gd")
const LoggerComponentBase := preload("./ui_base_class/logger_comp_base.gd")
const ErrorComponentBase := preload("./ui_base_class/error_comp_base.gd")

const InfoComponentBase := preload("./ui_base_class/info_panel_base.gd")

const InputFeedbackController := preload("./controllers/input_feedback_controller.gd")
const Signature = preload("./controllers/signature_info.gd")

const MobileLayout := preload("./utills/mobile_layout.gd")

static var mobile_layout: MobileLayout = null:
	get ():
		if mobile_layout == null:
			mobile_layout = MobileLayout.new()
		return mobile_layout


static func shortcut_pressed(event: InputEvent, shortcut: Shortcut) -> bool:
	return (event is InputEventKey and event.pressed
	and shortcut.matches_event(event) and not event.echo)


static func make_shortcut(key: Key, ctrl := false, shift := false, alt := false) -> Shortcut:
	var key_event := InputEventKey.new()

	key_event.keycode = key
	key_event.ctrl_pressed = ctrl
	key_event.shift_pressed = shift
	key_event.alt_pressed = alt
	key_event.command_or_control_autoremap = true

	var shortcut := Shortcut.new()
	shortcut.events = [key_event]

	return shortcut
