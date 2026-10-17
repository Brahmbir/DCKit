@tool
extends Node3D

@export var day_length: float = 60.0 # Seconds for a full day

var time := 0.0

var day_night_enabled := true

@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var pause: Node3D = $Pause


func _ready() -> void:
	DCKit.console_visibility_changed.connect(_on_console_visibility_changed)

	for cmd: DCDefinition in _get_dckit_def():
		DCKit.register_def(cmd)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not day_night_enabled:
		return

	time += delta

	var angle := (time / day_length) * 360.0
	directional_light.rotation_degrees.x = angle + 180.0

	_update_sun()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		DCKit.toggle_console()
		get_viewport().set_input_as_handled()


func _on_console_visibility_changed(is_open: bool) -> void:
	pause.process_mode = (Node.PROCESS_MODE_DISABLED if is_open else Node.PROCESS_MODE_INHERIT)


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


func _get_dckit_def() -> Array[DCDefinition]:
	var set_time_cmd := DCDefinition.new(
		"setTime",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("Usage: setTime <seconds>")
			var value = (await ctx.arg(0)).value
			time = value.as_float()
			_update_sun()

			return DCResult.ok("Time set to %.2f seconds." % time),
		"Sets the current time in the day/night cycle.",
		[DCDefinition.Param.new("seconds").describe("Time in seconds.")],
		true,
	)

	var set_day_length_cmd := DCDefinition.new(
		"setDayLength",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("Usage: setDayLength <seconds>")

			var value = (await ctx.arg(0)).value
			var length := value.as_float()

			if length <= 0.0:
				return DCResult.fail("Day length must be greater than zero.")

			day_length = length
			return DCResult.ok("Day length set to %.2f seconds." % day_length),
		"Sets the duration of a full day/night cycle.",
		[DCDefinition.Param.new("seconds").describe("Duration of one full day in seconds.")],
		true,
	)

	var toggle_day_night_cmd := DCDefinition.new(
		"toggleDayNight",
		func(_ctx: DCContext) -> DCResult:
			day_night_enabled = not day_night_enabled
			return DCResult.ok(
				"Day/night cycle %s." % ("enabled" if day_night_enabled else "paused")
			),
		"Pauses or resumes the day/night cycle.",
		[],
		true,
	)

	var get_time_cmd := DCDefinition.new(
		"getTime",
		func(_ctx: DCContext) -> DCResult:
			var progress := fposmod(time, day_length) / day_length
			var degrees := progress * 360.0
			return DCResult.ok(
				"Time: %.2f seconds | Day progress: %.1f%% | Sun angle: %.1f° | Day length: %.2f seconds"
				% [time, progress * 100.0, degrees, day_length]
			),
		"Displays the current day/night cycle status.",
		[],
		true,
	)
	return [set_time_cmd, set_day_length_cmd, toggle_day_night_cmd, get_time_cmd]
