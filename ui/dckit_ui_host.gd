extends Node

# Replaces the old, unused _request_connection_updates.
# Emitted whenever a console is in the tree and ready to be wired up.
signal connection_requested(console: _DCKitUINamespace.ConsoleBase)

signal placement_changed(mode: Mode, edge: Edge)

enum Mode {
	DOCK,
	WINDOW, # not supported yet
}
enum Edge {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
}

const WINDOW_MODE_SUPPORTED := false

@export var console_scene: PackedScene = preload(
	"res://addons/dc_kit/ui/simple_console/SimpleConsole.tscn"
)

# Console's share of the screen. x: left/right dock, y: top/bottom dock.
@export var default_split_ratio: Vector2 = Vector2(0.45, 0.65)
@export var min_split_ratio: Vector2 = Vector2(0.30, 0.35)

var mode: Mode = Mode.WINDOW
var edge: Edge = Edge.LEFT # remembered while in WINDOW mode

# State the host owns, so it outlives any one console.
var cmd_history_obj: _DCKitUINamespace.CommandHistory = _DCKitUINamespace.CommandHistory.new()

var _console: _DCKitUINamespace.ConsoleBase = null
var _open := true # independent of mode: whichever host is active follows this
var _ratio_pending := false # default ratio still owed (it couldn't be measured while closed)
var _ratio_serial := 0 # bumped on every layout request; stale awaits bail out

@onready var split: SplitContainer = $CanvasLayer/SplitContainer
@onready var window: Window = $Window
@onready var container_for_window: MarginContainer = $Window/MarginContainer


func _ready() -> void:
	window.close_requested.connect(set_mode.bind(Mode.DOCK))
	split.resized.connect(_update_min_size)

	_on_mobile_manual_changed(_DCKitUINamespace.mobile_layout.manual)
	_DCKitUINamespace.mobile_layout.manual_changed.connect(_on_mobile_manual_changed)

	var new_console := _instantiate_console(console_scene)
	if new_console == null:
		return
	_install_console(new_console)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F1:
		cycle_edge()

	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F2:
		_DCKitUINamespace.mobile_layout.set_manual(not _DCKitUINamespace.mobile_layout.manual)

	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F3:
		var m := _DCKitUINamespace.mobile_layout
		var test_width := m.breakpoint_width + 1.0 if m.screen else m.breakpoint_width - 1.0
		m.set_screen_width(test_width)


#region console ownership
func get_console() -> _DCKitUINamespace.ConsoleBase:
	return _console


## Replaces the console. Returns false and keeps the current one if the scene is invalid.
func set_console_scene(scene: PackedScene) -> bool:
	var new_console := _instantiate_console(scene)
	if new_console == null:
		return false
	console_scene = scene
	_install_console(new_console)
	return true


#region placement API
func cycle_edge() -> void:
	set_edge((edge + 1) % Edge.size() as Edge)


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	if new_mode == Mode.WINDOW and not WINDOW_MODE_SUPPORTED:
		push_warning(
			"DckitUiHost: window mode is not supported; staying in %s mode." % Mode.keys()[mode]
		)
		return
	mode = new_mode
	_apply()


func set_edge(new_edge: Edge) -> void:
	if new_edge == edge:
		return
	edge = new_edge
	if mode == Mode.DOCK:
		_apply()
	else:
		# Edge is kept for later, but nothing visible changes.
		placement_changed.emit(mode, edge)


func toggle_mode() -> void:
	if _console and _open:
		_console.release_focus_on_input()
	set_mode(Mode.WINDOW if mode == Mode.DOCK else Mode.DOCK)
	if _console and _open:
		_console.grab_focus_on_input()
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


func _on_mobile_manual_changed(is_mobile: bool) -> void:
	split.touch_dragger_enabled = is_mobile


func _instantiate_console(scene: PackedScene) -> _DCKitUINamespace.ConsoleBase:
	if scene == null:
		push_error("DckitUiHost: no console scene to instantiate.")
		return null
	var node := scene.instantiate()
	var new_console := node as _DCKitUINamespace.ConsoleBase
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


func _install_console(new_console: _DCKitUINamespace.ConsoleBase) -> void:
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
	connection_requested.emit(_console)


func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	match mode:
		Mode.DOCK:
			split.visible = _open
			if _open and _ratio_pending:
				_apply_default_ratio()
		Mode.WINDOW:
			window.visible = _open
	if _console:
		if _open:
			_console.grab_focus_on_input()
		else:
			_console.release_focus_on_input()
#endregion


#region placement internals
func _apply() -> void:
	if _console == null:
		return
	match mode:
		Mode.DOCK:
			_place_in_dock()
		Mode.WINDOW:
			_place_in_window()
	placement_changed.emit(mode, edge)


func _place_in_dock() -> void:
	window.hide()
	_move_console_to(split)

	split.vertical = edge in [Edge.TOP, Edge.BOTTOM]
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


# --- split sizing -----------------------------------------------------------
# split_offsets[0] moves the divider away from its default position, and the
# default position depends on the children's expand flags. So we don't assume
# where it is: reset to 0, measure the console's size there, then offset by the
# difference to the size we want.
# The minimum is enforced by the console's custom_minimum_size; the container
# clamps the offsets to it, so no drag handling is needed.
func _console_first() -> bool:
	return edge in [Edge.LEFT, Edge.TOP]


func _axis(ratio: Vector2) -> float:
	return ratio.y if split.vertical else ratio.x


func _total() -> float:
	return split.size.y if split.vertical else split.size.x


func _console_length() -> float:
	return _console.size.y if split.vertical else _console.size.x


func _update_min_size() -> void:
	if mode != Mode.DOCK or _console == null:
		return
	var min_length := _total() * _axis(min_split_ratio)
	_console.custom_minimum_size = (
		Vector2(0, min_length)
		if split.vertical
		else Vector2(min_length, 0)
	)


# A newer layout request (or a swap, mode change, or hide) invalidates this one.
func _layout_stale(serial: int) -> bool:
	return serial != _ratio_serial or mode != Mode.DOCK or not _open or _console == null


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
