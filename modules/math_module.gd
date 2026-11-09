## Mathematical commands for DCKit.
## All operands are resolved through DCContext and parsed as floats.
extends DCModule


func get_id() -> String:
	return "dckit_math"


func get_commands() -> Array[DCDefinition]:
	return [
		_add_cmd(),
		_sub_cmd(),
		_mul_cmd(),
		_div_cmd(),
		_mod_cmd(),
		_abs_cmd(),
		_min_cmd(),
		_max_cmd(),
		_clamp_cmd(),
		_round_cmd(),
		_floor_cmd(),
		_ceil_cmd(),
		_sqrt_cmd(),
		_pow_cmd(),
	]


func _add_cmd() -> DCDefinition:
	return _fold_command(
		"math.add",
		"Adds two or more numbers from left to right.",
		func(a: float, b: float) -> float: return a + b
	)


func _sub_cmd() -> DCDefinition:
	return _fold_command(
		"math.sub",
		"Subtracts each following number from the first number, left to right.",
		func(a: float, b: float) -> float: return a - b
	)


func _mul_cmd() -> DCDefinition:
	return _fold_command(
		"math.mul",
		"Multiplies two or more numbers.",
		func(a: float, b: float) -> float: return a * b
	)


func _div_cmd() -> DCDefinition:
	return _fold_command(
		"math.div",
		"Divides the first number by each following number, left to right. Division by zero fails.",
		func(a: float, b: float) -> float: return a / b
	)


func _mod_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.mod",
		func(ctx: DCContext) -> DCResult:
			var pair := await _resolve_pair(ctx, "math.mod", 2)
			if not pair.success:
				return DCResult.fail(pair.message)
			if is_zero_approx(pair.b):
				return DCResult.fail("math.mod: division by zero.")
			return DCResult.ok(str(fposmod(pair.a, pair.b))),
		"Returns the positive modulo of two numbers. The divisor cannot be zero.",
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)


func _abs_cmd() -> DCDefinition:
	return _unary_command(
		"math.abs", "Returns the absolute value.",
		func(value: float) -> float: return absf(value)
	)


func _min_cmd() -> DCDefinition:
	return _aggregate_command(
		"math.min", "Returns the smallest of one or more numbers.",
		func(a: float, b: float) -> float: return minf(a, b)
	)


func _max_cmd() -> DCDefinition:
	return _aggregate_command(
		"math.max", "Returns the largest of one or more numbers.",
		func(a: float, b: float) -> float: return maxf(a, b)
	)


func _clamp_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.clamp",
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, "math.clamp", 3, 3)
			if not values.success:
				return DCResult.fail(values.message)
			if values.numbers[1] > values.numbers[2]:
				return DCResult.fail("math.clamp: minimum cannot exceed maximum.")
			return DCResult.ok(str(clampf(values.numbers[0], values.numbers[1], values.numbers[2]))),
		"Clamps a value between a minimum and maximum.",
		[DCDefinition.Param.new("value"), DCDefinition.Param.new("min"), DCDefinition.Param.new("max")],
	)


func _round_cmd() -> DCDefinition:
	return _unary_command(
		"math.round", "Rounds to the nearest integer.",
		func(value: float) -> float: return roundf(value)
	)


func _floor_cmd() -> DCDefinition:
	return _unary_command(
		"math.floor", "Rounds down to the nearest integer.",
		func(value: float) -> float: return floorf(value)
	)


func _ceil_cmd() -> DCDefinition:
	return _unary_command(
		"math.ceil", "Rounds up to the nearest integer.",
		func(value: float) -> float: return ceilf(value)
	)


func _sqrt_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.sqrt",
		func(ctx: DCContext) -> DCResult:
			var value := await _resolve_values(ctx, "math.sqrt", 1, 1)
			if not value.success:
				return DCResult.fail(value.message)
			if value.numbers[0] < 0.0:
				return DCResult.fail("math.sqrt: value cannot be negative.")
			return DCResult.ok(str(sqrt(value.numbers[0]))),
		"Returns the square root. Negative values fail.",
		[DCDefinition.Param.new("value")],
	)


func _pow_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.pow",
		func(ctx: DCContext) -> DCResult:
			var pair := await _resolve_pair(ctx, "math.pow", 2)
			if not pair.success:
				return DCResult.fail(pair.message)
			return DCResult.ok(str(pow(pair.a, pair.b))),
		"Raises the first number to the power of the second.",
		[DCDefinition.Param.new("base"), DCDefinition.Param.new("exponent")],
	)


func _unary_command(command_name: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, command_name, 1, 1)
			if not values.success:
				return DCResult.fail(values.message)
			return DCResult.ok(str(operation.call(values.numbers[0]))),
		description,
		[DCDefinition.Param.new("value")],
	)


func _fold_command(command_name: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, command_name, 2, -1)
			if not values.success:
				return DCResult.fail(values.message)

			var result: float = values.numbers[0]
			for index in range(1, values.numbers.size()):
				if command_name == "math.div" and is_zero_approx(values.numbers[index]):
					return DCResult.fail("math.div: division by zero.")
				result = operation.call(result, values.numbers[index])
			return DCResult.ok(str(result)),
		description,
		[
			DCDefinition.Param.new("a"),
			DCDefinition.Param.new("b_and_more").describe("Two or more numeric operands in total.").rest(),
		],
	)


func _aggregate_command(command_name: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, command_name, 1, -1)
			if not values.success:
				return DCResult.fail(values.message)

			var result: float = values.numbers[0]
			for index in range(1, values.numbers.size()):
				result = operation.call(result, values.numbers[index])
			return DCResult.ok(str(result)),
		description,
		[DCDefinition.Param.new("values").describe("One or more numbers.").rest()],
	)


func _resolve_pair(ctx: DCContext, command_name: String, expected_count: int) -> _ResolvedNumbers:
	var values := await _resolve_values(ctx, command_name, expected_count, expected_count)
	var pair := _ResolvedNumbers.new()
	pair.success = values.success
	pair.message = values.message
	if values.success:
		pair.a = values.numbers[0]
		pair.b = values.numbers[1]
	return pair


func _resolve_values(ctx: DCContext, command_name: String, min_count: int, max_count: int) -> _ResolvedNumbers:
	var out := _ResolvedNumbers.new()
	var count := ctx.args_length()
	if count < min_count or (max_count >= 0 and count > max_count):
		var expected := str(min_count) if min_count == max_count else ("at least %d" % min_count)
		out.message = "%s requires %s argument(s)." % [command_name, expected]
		return out

	for index in count:
		var result := await ctx.arg(index)
		if not result.success:
			out.message = result.message
			return out

		var text_value := result.text()
		if not text_value.is_valid_float():
			out.message = "%s: '%s' is not a number." % [command_name, text_value]
			return out
		out.numbers.append(float(text_value))

	out.success = true
	return out


class _ResolvedNumbers:
	var success: bool = false
	var message: String = ""
	var numbers: Array[float] = []
	var a: float = 0.0
	var b: float = 0.0
