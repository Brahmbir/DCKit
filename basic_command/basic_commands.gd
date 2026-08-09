extends RefCounted

static var echo_cmd := DCDefinition.new(
	"echo",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() == 0:
			return DCResult.ok("''")
		var parts: PackedStringArray = []
		for i in ctx.args_length():
			var result := await ctx.arg(i)
			if not result.success:
				return result
			parts.append(result.value.as_string())
		return DCResult.ok(" ".join(parts)),
	"Prints text to the console.",
	[DCDefinition.Param.new("text").describe("Text to display.").rest()],
	true,
)

static var wait_cmd := DCDefinition \
		.new(
	"wait",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 1:
			return DCResult.fail("wait requires one argument.")

		var result := await ctx.arg(0)
		if not result.success:
			return result

		var duration_text := result.value.as_string()
		var seconds := _parse_duration(duration_text)

		if seconds < 0.0:
			return DCResult.fail("Invalid duration '%s'." % duration_text)

		var timer: SceneTreeTimer = null

		var was_aborted := await ctx \
				.step() \
				.exec(
			func() -> Signal:
				return Engine.get_main_loop().create_timer(seconds).timeout,
		) \
				.run()

		if was_aborted:
			return DCResult.fail("Wait aborted.")

		return DCResult.ok("Waited %s." % duration_text),
	"Pauses execution for a duration.",
	[DCDefinition.Param.new("duration").describe("Examples: 500ms, 2s, 1m")],
) \
		.as_utility()

static var abort_cmd := DCDefinition.new(
	"abort",
	func(ctx: DCContext) -> DCResult:
		ctx.abort()

		if ctx.args_length() == 0:
			return DCResult.fail("Execution aborted.")

		var result := await ctx.arg(0)
		if not result.success:
			return DCResult.fail("Execution aborted.\n%s" % result.message)

		return DCResult.fail("Execution aborted.\n%s" % result.value.as_string()),
	"Aborts the current command or script.",
	[DCDefinition.Param.new("reason").describe("Optional reason.")],
)

static var time_cmd := DCDefinition.new(
	"time",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 1:
			return DCResult.fail("time requires one nested command.")

		var start := Time.get_ticks_usec()

		var result := await ctx.arg(0)

		var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0

		if not result.success:
			return DCResult.fail("%s\nExecuted in %.3f ms." % [result.message, elapsed_ms])

		return DCResult.ok("%s\nExecuted in %.3f ms." % [result.message, elapsed_ms]),
	"Measures how long a nested command takes.",
	[DCDefinition.Param.new("command").describe("Command to execute.")],
	true,
)

static var type_of_cmd := DCDefinition.new(
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

		var raw := value.raw

		var type_name := ""
		match typeof(raw):
			TYPE_NIL:
				type_name = "null"
			TYPE_BOOL:
				type_name = "bool"
			TYPE_INT:
				type_name = "int"
			TYPE_FLOAT:
				type_name = "float"
			TYPE_STRING:
				type_name = "String"
			TYPE_VECTOR2:
				type_name = "Vector2"
			TYPE_VECTOR2I:
				type_name = "Vector2i"
			TYPE_VECTOR3:
				type_name = "Vector3"
			TYPE_VECTOR3I:
				type_name = "Vector3i"
			TYPE_VECTOR4:
				type_name = "Vector4"
			TYPE_VECTOR4I:
				type_name = "Vector4i"
			TYPE_COLOR:
				type_name = "Color"
			TYPE_RECT2:
				type_name = "Rect2"
			TYPE_RECT2I:
				type_name = "Rect2i"
			TYPE_TRANSFORM2D:
				type_name = "Transform2D"
			TYPE_TRANSFORM3D:
				type_name = "Transform3D"
			TYPE_BASIS:
				type_name = "Basis"
			TYPE_QUATERNION:
				type_name = "Quaternion"
			TYPE_PLANE:
				type_name = "Plane"
			TYPE_AABB:
				type_name = "AABB"
			TYPE_STRING_NAME:
				type_name = "StringName"
			TYPE_NODE_PATH:
				type_name = "NodePath"
			TYPE_ARRAY:
				type_name = "Array"
			TYPE_DICTIONARY:
				type_name = "Dictionary"
			TYPE_OBJECT:
				if raw != null:
					type_name = raw.get_class()
				else:
					type_name = "Object"
			_:
				type_name = type_string(typeof(raw))

		return DCResult.ok(type_name),
	"Returns the type of a value.",
	[DCDefinition.Param.new("value").describe("Value to inspect.")],
	true,
)


static func get_command_def_array() -> Array[DCDefinition]:
	return [echo_cmd, wait_cmd, abort_cmd, time_cmd, type_of_cmd]


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

	# No suffix: default to seconds
	if text.is_valid_float():
		return text.to_float()

	if text.is_valid_int():
		return float(text.to_int())

	return -1.0
