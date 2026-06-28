@tool 
extends Node3D

@export var day_length: float = 60.0 # Seconds for a full day

@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var pause: Node3D = $Pause

var time := 0.0

func _process(delta: float) -> void:
	time += delta

	# Rotate the sun
	var angle := (time / day_length) * 360.0
	directional_light.rotation_degrees.x = angle + 180

	_update_sun()


func _update_sun() -> void:
	# Sun height (-1 to 1)
	var sun_height := directional_light.global_basis.z.y

	# Light intensity
	directional_light.light_energy = clamp(sun_height * 2.0, 0.0, 1.5)

	# Change light color
	if sun_height > 0.2:
		# Day
		directional_light.light_color = Color(1.0, 0.98, 0.92)
	elif sun_height > -0.1:
		# Sunrise/Sunset
		directional_light.light_color = Color(1.0, 0.65, 0.35)
	else:
		# Night (moonlight)
		directional_light.light_color = Color(0.45, 0.55, 0.8)
		directional_light.light_energy = 0.08


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		DCKit.toggle_console()
		if DCKit.is_console_open():
			pause.process_mode = Node.PROCESS_MODE_DISABLED
		else : 
			pause.process_mode = Node.PROCESS_MODE_INHERIT
		get_viewport().set_input_as_handled()
