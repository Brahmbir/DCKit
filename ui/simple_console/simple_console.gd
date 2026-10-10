@tool
extends "../ui_base_class/console_base.gd"

@export var LOGGER_COLOR_MAP := {
	"OK": Color("4EC9B0"),
	"FAIL": Color("F28B82"),
	"WARN": Color("FFD166"),
	"ERROR": Color("FF6B6B"),
	"INFO": Color("89B4FA"),
	"CMD": Color("89DCEB"),
	"HELP": Color("858aa0"),
	"SYS": Color("858aa0"),
	"muted": Color("858aa0"),
	"plain": Color("CDD6F4"),
}


func _enter_tree() -> void:
	var s := _DCKitNS.UI.scales
	s.font_changed.connect(_on_scale_changed)
	s.log_font_changed.connect(_on_scale_changed)
	s.space_changed.connect(_on_scale_changed)

	resized.connect(
		func():
			_DCKitNS.UI.mobile_layout.set_screen_width(size.x),
	)
	_DCKitNS.UI.mobile_layout.set_screen_width(size.x)


func _ready() -> void:
	_queue_theme_rebuild()

	if error_component and input_component:
		var move_caret_func := (input_component.get_input_node() as TextEdit).set_caret_column
		error_component.item_pressed.connect(
			func(pos, _l):
				move_caret_func.call(pos, true),
		)
		pass


func _exit_tree() -> void:
	var s := _DCKitNS.UI.scales
	s.font_changed.disconnect(_on_scale_changed)
	s.log_font_changed.disconnect(_on_scale_changed)
	s.space_changed.disconnect(_on_scale_changed)


func grab_focus_on_input():
	var node := _get_input_node("grab_focus_on_input")
	if node:
		node.grab_focus()


func release_focus_on_input():
	var node := _get_input_node("release_focus_on_input")
	if node:
		node.release_focus()


func connect_cmd_history(history: _DCKitNS.UI.CommandHistory):
	var node := _get_input_node("connect_cmd_history")
	if node:
		_DCKitNS.UI.call_from_comp(node, "set_history_obj", [history])


func connect_executor(executor: _DCKitNS.Executor.Executor):
	if not input_component or not log_component:
		push_warning(
			"SimpleConsole.connect_executor: input_component and log_component must both be assigned."
		)
		return

	input_component.connect_executor(executor)

	log_component.connect_logger(executor.logger)
	_DCKitNS.UI.set_var_comp(log_component, "COLOR_MAP", LOGGER_COLOR_MAP)


func connect_feedback_controller(controller: _DCKitNS.UI.InputFeedbackController):
	if not input_component:
		push_warning("SimpleConsole.connect_feedback_controller: input_component must be assigned.")
		return
		
	if not controller:
		push_warning("SimpleConsole.connect_feedback_controller: variable `controller` is null.")
		return
	
	controller.diagnostics_view.diagnostics_changed.connect(_on_diagnostics_changed)
	controller.signature_help_view.definition_changed.connect(_on_definition_changed)
	controller.signature_help_view.active_changed.connect(_on_active_changed)

	input_component.cmd_text_changed.connect(controller.handle_text_changed)
	input_component.cmd_caret_location_changed.connect(controller.handle_cursor_moved)


func _on_definition_changed(info: _DCKitNS.UI.Signature.SignatureInfo) -> void:
	if not info_component:
		push_warning("SimpleConsole.connect_feedback_controller: info_component must be assigned.")
		return
	info_component.show_info(info)


func _on_active_changed(index: int) -> void:
	if not info_component:
		push_warning("SimpleConsole.connect_feedback_controller: info_component must be assigned.")
		return
	info_component.set_active(index)


func _on_scale_changed(_v) -> void:
	_queue_theme_rebuild()


func _on_diagnostics_changed(diagnostics):
	if not error_component:
		push_warning("SimpleConsole.connect_feedback_controller: error_component must be assigned.")
		return
	error_component.show_diagnostic(diagnostics)


func _get_input_node(caller: String) -> Control:
	if not input_component:
		push_warning("SimpleConsole.%s: input_component is not assigned." % caller)
		return null
	var node: Control = input_component.get_input_node()
	if not node:
		push_warning("SimpleConsole.%s: input_component returned no input node." % caller)
	return node


#region UI Response
func _default_theme_changed():
	var new_theme: Theme = default_theme.duplicate()

	var scales = _DCKitNS.UI.scales

	new_theme.default_font_size = scales.em_font(1)

	new_theme.set_font_size("font_size", "Header_Label", scales.em_font(0.8))
	for property in new_theme.get_font_size_list("Looger_RichTextLabel"):
		new_theme.set_font_size(property, "Looger_RichTextLabel", scales.em_log_font(1))

	for property in new_theme.get_font_size_list("RichTextLabel"):
		new_theme.set_font_size(property, "RichTextLabel", scales.em_font(.75))

	new_theme.set_constant("caret_width", "TextEdit", scales.em_font(0.5))

	new_theme.set_constant("icon_max_width", "Button", scales.em_font(0.9))

	for property in ["margin_bottom", "margin_left", "margin_right", "margin_top"]:
		new_theme.set_constant(property, "MarginContainer", scales.em_space(1))
		#new_theme.set_constant(property, "MarginContainer", scales.em_space(1))
	
	new_theme.set_constant("margin_bottom", "ToolNInfo_MarginContainer", scales.em_space(0.5))
	new_theme.set_constant("margin_top", "ToolNInfo_MarginContainer", scales.em_space(4))

	new_theme.set_constant("separation", "HBoxContainer", scales.em_space(.9))
	new_theme.set_constant("separation", "HBoxContainer_LineEdit", scales.em_font(.5))

	var new_scroll_VScrollBar := new_theme.get_stylebox("scroll", "VScrollBar").duplicate()
	for property in ["content_margin_left", "content_margin_right"]:
		new_scroll_VScrollBar.set(property, scales.em_space(.275))
	new_theme.set_stylebox("scroll", "VScrollBar", new_scroll_VScrollBar)
	new_theme.set_constant("margin_right", "LoggerComponentPanel_Margin", scales.em_space(.5))

	set_theme(new_theme)
#endregion
