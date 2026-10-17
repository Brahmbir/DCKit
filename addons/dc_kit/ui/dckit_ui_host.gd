extends "./dckit_host_interface.gd"

signal placement_changed(mode: _DCKitSetting.ConsoleMode, edge: _DCKitSetting.WindowEdge)

const WINDOW_MODE_SUPPORTED := false

@export_group("Console Scene")
@export var console_scene: PackedScene = preload(
	"res://addons/dc_kit/ui/simple_console/SimpleConsole.tscn"
)

@export_group("Dock size")
# Console's share of the screen. x: left/right dock, y: top/bottom dock.
@export var default_split_ratio: Vector2 = Vector2(0.45, 0.65)
@export var min_split_ratio: Vector2 = Vector2(0.30, 0.35)

# State the host owns, so it outlives any one console.
var cmd_history_obj: _DCKitNS.UI.CommandHistory = _DCKitNS.UI.CommandHistory.new()
var _mode: _DCKitSetting.ConsoleMode = _DCKitSetting.ConsoleMode.DOCK

var _edge: _DCKitSetting.WindowEdge = _DCKitSetting.WindowEdge.BOTTOM # remembered while in WINDOW mode

var _console: _DCKitNS.UI.ConsoleBase = null
var _open := true # independent of mode: whichever host is active follows this
var _ratio_pending := false # default ratio still owed (it couldn't be measured while closed)
var _ratio_serial := 0 # bumped on every layout request; stale awaits bail out

var _connection_request_callback: Callable

@onready var split: SplitContainer = $CanvasLayer/SplitContainer
@onready var window: Window = $Window
@onready var container_for_window: MarginContainer = $Window/MarginContainer
@onready var canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	canvas_layer.layer = _DCKitSetting.get_default_canvas_layer()
	window.close_requested.connect(hide_console)

	split.resized.connect(_update_min_size)

	set_mode(_DCKitSetting.get_console_mode())
	set_edge(_DCKitSetting.get_window_edge())

	_DCKitNS.UI.mobile_layout.manual_changed.connect(_on_mobile_manual_changed)
	_on_mobile_manual_changed(_DCKitNS.UI.mobile_layout.manual)

	var new_console := _instantiate_console(console_scene)
	if new_console == null:
		return
	_install_console(new_console)


func configure(config: Dictionary) -> void:
	for key in config:
		var value = config[key]
		match key:
			"mode":
				var parsed = _parse_enum(_DCKitSetting.ConsoleMode, key, value)
				if parsed != null:
					set_mode(parsed)
			"edge":
				var parsed = _parse_enum(_DCKitSetting.WindowEdge, key, value)
				if parsed != null:
					set_edge(parsed)
			"canvas_layer":
				if value is float or value is int:
					canvas_layer.layer = value
				else:
					_warn_bad_value(key, "int", value)
			"is_mobile":
				if value is bool:
					_DCKitNS.UI.mobile_layout.set_manual(value)
				else:
					_warn_bad_value(key, "bool", value)
			"font_size":
				if value is float or value is int:
					_DCKitNS.UI.mobile_layout.get_scales().font = clampf(value, 0.5, 3.0)
				else:
					_warn_bad_value(key, "float", value)
			"space_size":
				if value is float or value is int:
					_DCKitNS.UI.mobile_layout.get_scales().space = clampf(value, 0.5, 3.0)
				else:
					_warn_bad_value(key, "float", value)
			"logger_font_size":
				if value is float or value is int:
					_DCKitNS.UI.mobile_layout.get_scales().log_font = clampf(value, 0.5, 3.0)
				else:
					_warn_bad_value(key, "float", value)
			_:
				push_warning("Dckit: unknown config key '%s' — skipped." % key)


#region console ownership
## Replaces the console. Returns false and keeps the current one if the scene is invalid.
func set_console_scene(scene: PackedScene) -> bool:
	var new_console := _instantiate_console(scene)
	if new_console == null:
		return false
	console_scene = scene
	_install_console(new_console)
	return true


func get_console_node() -> _DCKitNS.UI.ConsoleBase:
	return _console
#endregion


#region placement API
func set_mode(new_mode: _DCKitSetting.ConsoleMode) -> void:
	if new_mode == _mode:
		return
	if new_mode == _DCKitSetting.ConsoleMode.WINDOW and not WINDOW_MODE_SUPPORTED:
		push_warning(
			"DckitUiHost: window mode is not supported; staying in %s mode."
			% _DCKitSetting.ConsoleMode.keys()[_mode]
		)
		if not OS.has_feature('dev'):
			return

	if _console and _open:
		_console.release_focus_on_input()

	_mode = new_mode
	_apply()

	if _console and _open:
		_console.grab_focus_on_input()


func set_edge(new_edge: _DCKitSetting.WindowEdge) -> void:
	if new_edge == _edge:
		return
	_edge = new_edge
	if _mode == _DCKitSetting.ConsoleMode.DOCK:
		_apply()
	else:
		# Edge is kept for later, but nothing visible changes.
		placement_changed.emit(_mode, _edge)


func toggle_mode() -> void:
	set_mode(
		(
			_DCKitSetting.ConsoleMode.WINDOW
			if _mode == _DCKitSetting.ConsoleMode.DOCK
			else _DCKitSetting.ConsoleMode.DOCK
		)
	)
#endregion


#region visibility API
func show_console() -> void:
	_set_open(true)


func hide_console() -> void:
	_set_open(false)


func toggle_console() -> void:
	_set_open(not _open)


func is_console_open() -> bool:
	return _open


# For a backend that connects after the console already exists.
func request_connections() -> void:
	_update_connections()
#endregion


func set_connection_request_callback(callback: Callable):
	if callback.is_valid():
		_connection_request_callback = callback
	return


#region configure helper logic
func _parse_enum(enum_dict: Dictionary, key: String, value) -> Variant:
	if not value is String:
		_warn_bad_value(key, "String", value)
		return null
	var name := (value as String).to_upper()
	if not enum_dict.has(name):
		push_warning(
			"Dckit: '%s' is not a valid value for '%s' (expected one of %s) — skipped."
			% [value, key, enum_dict.keys()]
		)
		return null
	return enum_dict[name]


func _warn_bad_value(key: String, expected: String, value) -> void:
	push_warning(
		"Dckit: '%s' expects %s, got %s — skipped." % [key, expected, type_string(typeof(value))]
	)
#endregion


func _on_mobile_manual_changed(is_mobile: bool) -> void:
	split.touch_dragger_enabled = is_mobile


#region console
func _instantiate_console(scene: PackedScene) -> _DCKitNS.UI.ConsoleBase:
	if scene == null:
		push_error("DckitUiHost: no console scene to instantiate.")
		return null
	var node := scene.instantiate()
	var new_console := node as _DCKitNS.UI.ConsoleBase
	if new_console == null:
		push_error(
			"DckitUiHost: '%s' root must extend ConsoleBase (got %s)."
			% [scene.resource_path, node.get_class()]
		)
		node.free()
		return null
	new_console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_console.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return new_console


func _install_console(new_console: _DCKitNS.UI.ConsoleBase) -> void:
	if _console:
		if _open:
			_console.release_focus_on_input()
		# Remove now so child order in the split is right when _apply() runs.
		_console.get_parent().remove_child(_console)
		_console.queue_free()
	_console = new_console
	_apply() # puts the console in the tree, so its components are ready below
	_update_connections()
	if _open:
		_console.grab_focus_on_input()


# Attach everything the host owns, then ask the backend to attach the rest.
func _update_connections() -> void:
	if _console == null:
		return
	_console.connect_cmd_history(cmd_history_obj)
	_console.ui_close_requested.connect(hide_console)

	if not _connection_request_callback.is_valid():
		push_error("_connection_request_callback is not valid")
	_connection_request_callback.call()


func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	match _mode:
		_DCKitSetting.ConsoleMode.DOCK:
			split.visible = _open
			if _open and _ratio_pending:
				_apply_default_ratio()
		_DCKitSetting.ConsoleMode.WINDOW:
			window.visible = _open
	if _console:
		if _open:
			_console.grab_focus_on_input()
		else:
			_console.release_focus_on_input()

	console_visibility_changed.emit(_open)
#endregion


#region placement internals
func _apply() -> void:
	if _console == null:
		return
	match _mode:
		_DCKitSetting.ConsoleMode.DOCK:
			_place_in_dock()
		_DCKitSetting.ConsoleMode.WINDOW:
			_place_in_window()
	placement_changed.emit(_mode, _edge)


func _place_in_dock() -> void:
	window.hide()
	_move_console_to(split)

	split.vertical = _edge in [_DCKitSetting.WindowEdge.TOP, _DCKitSetting.WindowEdge.BOTTOM]
	# Child order decides the side: console first = left/top.
	split.move_child(_console, 0 if _console_first() else 1)
	split.visible = _open
	_update_min_size()
	_ratio_pending = true
	_apply_default_ratio() # runs after layout; not awaited on purpose


func _place_in_window() -> void:
	split.hide()
	_console.custom_minimum_size = Vector2.ZERO
	_move_console_to(container_for_window)
	_console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.visible = _open


func _move_console_to(new_parent: Node) -> void:
	if _console.get_parent() == new_parent:
		return
	if _console.get_parent():
		_console.reparent(new_parent, false)
	else:
		new_parent.add_child(_console)
#endregion


#region split sizing
func _console_first() -> bool:
	return _edge in [_DCKitSetting.WindowEdge.LEFT, _DCKitSetting.WindowEdge.TOP]


func _axis(ratio: Vector2) -> float:
	return ratio.y if split.vertical else ratio.x


func _total() -> float:
	return split.size.y if split.vertical else split.size.x


func _console_length() -> float:
	return _console.size.y if split.vertical else _console.size.x


func _update_min_size() -> void:
	if _mode != _DCKitSetting.ConsoleMode.DOCK or _console == null:
		return
	var min_length := _total() * _axis(min_split_ratio)
	_console.custom_minimum_size = (
		Vector2(0, min_length)
		if split.vertical
		else Vector2(min_length, 0)
	)


# A newer layout request (or a swap, _mode change, or hide) invalidates this one.
func _layout_stale(serial: int) -> bool:
	return (
		serial != _ratio_serial or _mode != _DCKitSetting.ConsoleMode.DOCK
		or not _open or _console == null
	)


func _apply_default_ratio() -> void:
	_ratio_serial += 1
	var serial := _ratio_serial
	# A hidden split has no layout to measure; _set_open() retries later.
	await get_tree().process_frame
	if _layout_stale(serial):
		return
	split.split_offsets = PackedInt32Array([0])
	await get_tree().process_frame
	if _layout_stale(serial):
		return

	_ratio_pending = false
	var wanted := _total() * _axis(default_split_ratio)
	var delta := wanted - _console_length()
	# The offset moves the divider towards the second child, so it grows a
	# first-placed console and shrinks a second-placed one.
	split.split_offsets = PackedInt32Array([int(delta if _console_first() else -delta)])
#endregion
