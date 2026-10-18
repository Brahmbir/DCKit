extends CharacterBody3D

const SPEED = 12.0
const JUMP_VELOCITY = 4.5

@export var camera_rig: CameraRig
## How fast the body turns toward its movement direction.
@export var turn_speed: float = 12.0


func _physics_process(delta: float) -> void:
	var controlled := not camera_rig.free_cam

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if controlled and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Camera-relative movement
	var input_dir := Vector2.ZERO
	if controlled:
		input_dir = Input.get_vector("left", "right", "up", "down")
	var direction := (camera_rig.yaw_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
