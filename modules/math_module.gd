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
		func(a: float, b: float) -> Variant: return a + b
	)


func _sub_cmd() -> DCDefinition:
	return _fold_command(
		"math.sub",
		"Subtracts each following number from the first number, left to right.",
		func(a: float, b: float) -> Variant: return a - b
	)


func _mul_cmd() -> DCDefinition:
	return _fold_command(
		"math.mul",
		"Multiplies two or more numbers.",
		func(a: float, b: float) -> Variant: return a * b
	)


func _div_cmd() -> DCDefinition:
	return _fold_command(
		"math.div",
		"Divides the first number by each following number, left to right. Division by zero fails.",
		func(a: float, b: float) -> Variant:
			return DCResult.fail("Division by zero.") if is_zero_approx(b) else a / b
	)


func _mod_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.mod",
		func(ctx: DCContext) -> DCResult:
			var pair := await _resolve_pair(ctx)
			if not pair.success:
				return pair.failure

			if is_zero_approx(pair.b):
				return DCResult.fail("Division by zero.")

			return DCResult.ok(fposmod(pair.a, pair.b)),
		"Returns the positive modulo of two numbers. The divisor cannot be zero.",
		["a", "b"],
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
			var values := await _resolve_values(ctx, 3, 3)
			if not values.success:
				return values.failure

			if values.numbers[1] > values.numbers[2]:
				return DCResult.fail("Minimum cannot exceed maximum.")

			return DCResult.ok(
				clampf(values.numbers[0], values.numbers[1], values.numbers[2])
			),
		"Clamps a value between a minimum and maximum.",
		["value", "min", "max"],
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
			var values := await _resolve_values(ctx, 1, 1)
			if not values.success:
				return values.failure

			if values.numbers[0] < 0.0:
				return DCResult.fail("Value cannot be negative.")

			return DCResult.ok(sqrt(values.numbers[0])),
		"Returns the square root. Negative values fail.",
		["value"],
	)


func _pow_cmd() -> DCDefinition:
	return DCDefinition.new(
		"math.pow",
		func(ctx: DCContext) -> DCResult:
			var pair := await _resolve_pair(ctx)
			if not pair.success:
				return pair.failure

			return DCResult.ok(pow(pair.a, pair.b)),
		"Raises the first number to the power of the second.",
		["base", "exponent"],
	)


func _unary_command(cmd: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		cmd,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, 1, 1)
			if not values.success:
				return values.failure

			return DCResult.ok(operation.call(values.numbers[0])),
		description,
		["value"],
	)


## operation may return a DCResult to abort the fold.
func _fold_command(cmd: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		cmd,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, 2, -1)
			if not values.success:
				return values.failure

			var result: Variant = values.numbers[0]
			for i in range(1, values.numbers.size()):
				result = operation.call(result, values.numbers[i])
				if result is DCResult:
					return result

			return DCResult.ok(result),
		description,
		[DCDefinition.Param.new("numbers").describe("Two or more numbers.").rest()],
	)


func _aggregate_command(cmd: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		cmd,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_values(ctx, 1, -1)
			if not values.success:
				return values.failure

			var result: float = values.numbers[0]
			for i in range(1, values.numbers.size()):
				result = operation.call(result, values.numbers[i])

			return DCResult.ok(result),
		description,
		[DCDefinition.Param.new("numbers").describe("One or more numbers.").rest()],
	)


func _resolve_pair(ctx: DCContext) -> _ResolvedNumbers:
	var out := await _resolve_values(ctx, 2, 2)
	if out.success:
		out.a = out.numbers[0]
		out.b = out.numbers[1]
	return out


func _resolve_values(ctx: DCContext, min_count: int, max_count: int) -> _ResolvedNumbers:
	var out := _ResolvedNumbers.new()
	var count := ctx.args_length()

	if count < min_count or (max_count >= 0 and count > max_count):
		var expected := str(min_count) if min_count == max_count else "at least %d" % min_count
		out.failure = DCResult.fail("Requires %s argument(s), got %d." % [expected, count])
		return out

	for i in count:
		var result := await ctx.arg(i)
		if not result.success:
			out.failure = result
			return out

		var operand: Variant = result.value
		if operand is float or operand is int:
			out.numbers.append(float(operand))
		elif operand is String and operand.is_valid_float():
			out.numbers.append(operand.to_float())
		else:
			out.failure = DCResult.fail("'%s' is not a number." % result.text())
			return out

	out.success = true
	return out


class _ResolvedNumbers:
	var success := false
	var failure: DCResult
	var numbers: Array[float] = []
	var a := 0.0
	var b := 0.0
