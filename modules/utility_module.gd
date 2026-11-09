class_name UtilityModule
extends DCModule


static func _parse_duration(text: String) -> float:
	text = text.strip_edges().to_lower()

	if text.ends_with("ms"):
		return text.left(-2).to_float() / 1000.0

	if text.ends_with("s"):
		return text.left(-1).to_float()

	if text.ends_with("m"):
		return text.left(-1).to_float() * 60.0

	if text.ends_with("h"):
		return text.left(-1).to_float() * 3600.0

	# No suffix: default to seconds.
	if text.is_valid_float():
		return text.to_float()

	if text.is_valid_int():
		return float(text.to_int())

	return -1.0


func get_id() -> String:
	return "dckit_utility"


func get_commands() -> Array[DCDefinition]:
	return [_echo_cmd(), _wait_cmd(), _abort_cmd(), _time_cmd(), _type_of_cmd()]


func _echo_cmd() -> DCDefinition:
	return DCDefinition.new(
		"echo",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.ok("''")

			var parts: PackedStringArray = []

			for i in ctx.args_length():
				var result := await ctx.arg(i)
				if not result.success:
					return result

				parts.append(result.text())

			return DCResult.ok(" ".join(parts)),
		"Prints text to the console.",
		[DCDefinition.Param.new("text").describe("Text to display.").rest()],
		true,
	)


func _wait_cmd() -> DCDefinition:
	return DCDefinition \
			.new(
		"wait",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("wait requires one argument.")

			var result := await ctx.arg(0)
			if not result.success:
				return result

			var duration_text := result.text()
			var seconds := _parse_duration(duration_text)

			if seconds < 0.0:
				return DCResult.fail("Invalid duration '%s'." % duration_text)

			if ctx.is_aborted():
				return DCResult.fail("Wait aborted.")

			var timer: SceneTreeTimer = Engine.get_main_loop().create_timer(seconds)

			var was_aborted := await ctx.await_or_abort(timer.timeout)

			if was_aborted:
				return DCResult.fail("Wait aborted.")

			return DCResult.ok(null,"Waited %s." % duration_text),
		"Pauses execution for a duration.",
		[DCDefinition.Param.new("duration").describe("Examples: 500ms, 2s, 1m")],
	).as_utility()


func _abort_cmd() -> DCDefinition:
	return DCDefinition.new(
		"abort",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.fail("Execution aborted.")

			var result := await ctx.arg(0)
			if not result.success:
				return DCResult.fail("Execution aborted. reason: %s" % result.message)

			ctx.abort()
			return DCResult.fail("Execution aborted. reason:%s" % result.text()),
		"Aborts the current command or script.",
		[DCDefinition.Param.new("reason").describe("Optional reason.")],
	)


func _time_cmd() -> DCDefinition:
	return DCDefinition.new(
		"time",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("time requires one nested command.")

			var start := Time.get_ticks_usec()
			var result := await ctx.arg(0)

			var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0

			if not result.success:
				return DCResult.fail("%s\nExecuted in %.3f ms." % [result.message, elapsed_ms])

			return DCResult.ok(
				elapsed_ms,
				"%s\nExecuted in %.3f ms." % [result.message, elapsed_ms],
			),
		"Measures how long a nested command takes.",
		[DCDefinition.Param.new("command").describe("Command to execute.")],
		true,
	)


func _type_of_cmd() -> DCDefinition:
	return DCDefinition.new(
		"type_of",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("type_of requires one value.")

			var result := await ctx.arg(0)
			if not result.success:
				return result

			var value := result.value

			if value == null:
				return DCResult.ok("null")

			var type_name := ""

			match typeof(value):
				TYPE_OBJECT:
					if value != null:
						type_name = value.get_class()
					else:
						type_name = "Object"
				_:
					type_name = type_string(typeof(value))

			return DCResult.ok(typeof(value), type_name),
		"Returns the type of a value.",
		[DCDefinition.Param.new("value").describe("Value to inspect.")],
		true,
	)
