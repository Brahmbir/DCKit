class_name CameraRig
extends Node3D
## Third-person camera rig. This node is the yaw pivot.
## Children are built at runtime: Pitch > SpringArm3D > Camera3D.

signal free_cam_toggled(active: bool)

@export var target: Node3D
@export var settings: CameraSettings

@export_group("Free Cam")
@export var toggle_key: Key = KEY_F
@export var free_cam_speed: float = 12.0
@export var free_cam_fast_multiplier: float = 3.0

var free_cam: bool = false

var _pitch: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _pitch_angle: float = 0.0


func _ready() -> void:
	if settings == null:
		settings = CameraSettings.new()

	_register_commands()

	# Independent of whatever parent it sits under.
	top_level = true

	_build()
	_apply_settings()

	if target:
		global_position = target.global_position + Vector3.UP * settings.follow_height

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if free_cam:
		_free_cam_move(delta)
		return
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * settings.follow_height
	if settings.follow_lag <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-delta / settings.follow_lag))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * settings.mouse_sensitivity
		_pitch_angle = clampf(
			_pitch_angle - event.relative.y * settings.mouse_sensitivity,
			deg_to_rad(settings.pitch_min_deg),
			deg_to_rad(settings.pitch_max_deg),
		)
		_pitch.rotation.x = _pitch_angle
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_free_cam() -> void:
	set_free_cam(not free_cam)


func set_free_cam(active: bool) -> void:
	if active == free_cam:
		return
	free_cam = active
	if active:
		# Move the pivot to where the camera is now, then collapse the arm,
		# so the view doesn't jump when free cam starts.
		global_position = _camera.global_position
		_arm.spring_length = 0.0
	else:
		# Restore the arm; the follow code flies the pivot back to the target.
		_arm.spring_length = settings.follow_distance
	free_cam_toggled.emit(active)


## Yaw-only basis for camera-relative movement.
func yaw_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _register_commands() -> void:
	DCKit.register_def(
		DCDefinition
		.new(
			"toggle_free_cam",
			func(_ctx: DCContext) -> DCResult:
				toggle_free_cam()

				DCKit.hide_console()
				return DCResult.ok("Free cam [b]%s[/b]." % ("on" if free_cam else "off")),
			"Toggles the free-flying camera.",
			[],
		)
		.alias("tfc")
	)

	DCKit.register_def(
		DCDefinition
		.new(
			"set_free_cam",
			func(ctx: DCContext) -> DCResult:
				var enabled: bool = (await ctx.arg(0)).value.as_bool()

				if free_cam != enabled:
					toggle_free_cam()

				return DCResult.ok("Free cam [b]%s[/b]." % ("on" if free_cam else "off")),
			"Enables or disables the free-flying camera.",
			[DCDefinition.Param.new("switch").describe("on or off")],
		)
		.alias("sfc")
	)


func _build() -> void:
	_pitch = Node3D.new()
	_pitch.name = "Pitch"
	add_child(_pitch)

	_arm = SpringArm3D.new()
	_arm.name = "SpringArm3D"
	_arm.shape = SphereShape3D.new()
	_pitch.add_child(_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_arm.add_child(_camera)
	_camera.make_current()


func _apply_settings() -> void:
	_arm.spring_length = settings.follow_distance
	_arm.margin = settings.spring_margin
	_arm.collision_mask = settings.collision_mask
	(_arm.shape as SphereShape3D).radius = settings.probe_radius
	_camera.fov = settings.fov

	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())


func _free_cam_move(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var axis := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)),
	)
	if axis == Vector3.ZERO:
		return
	# Horizontal axes follow the view direction (including pitch); Q/E are world up/down.
	var move := _camera.global_basis * Vector3(axis.x, 0.0, axis.z) + Vector3.UP * axis.y
	var speed := free_cam_speed
	if Input.is_physical_key_pressed(KEY_SHIFT):
		speed *= free_cam_fast_multiplier
	global_position += move.normalized() * speed * delta
