## Core module: conditional, error-handling, loop, and comparison commands.
##
## Commands are grouped here because they provide the control-flow primitives
## used by DCKit scripts. The module has no service dependencies.
extends DCModule

const MAX_REPEAT_COUNT: int = 1_000
const MAX_WHILE_ITERS: int = 10_000


func get_id() -> String:
	return "dckit_logic"


func get_commands() -> Array[DCDefinition]:
	return [
		_if_cmd(),
		_not_cmd(),
		_and_cmd(),
		_or_cmd(),
		_try_cmd(),
		_repeat_cmd(),
		_while_cmd(),
		_cmp_eq_cmd(),
		_cmp_neq_cmd(),
		_cmp_gt_cmd(),
		_cmp_lt_cmd(),
		_cmp_gte_cmd(),
		_cmp_lte_cmd(),
		_cmp_in_cmd(),
		_cmp_contains_cmd(),
		_cmp_empty_cmd(),
	]


#region CONDITIONALS
func _if_cmd() -> DCDefinition:
	return DCDefinition \
			.new(
		"if",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2 or ctx.args_length() > 3:
				return DCResult.fail("Requires 2 or 3 arguments:  if (condition) (then) [else]")

			var condition := await ctx.arg(0)
			if condition.truthy():
				return await ctx.arg(1)

			if ctx.args_length() == 3:
				return await ctx.arg(2)
			return _ok(condition.truthy()),
		"Evaluates a condition and runs one of two branches.\n"
		+ "A result is [b]truthy[/b] when it succeeds and its value is not "
		+ "[code]\"\"[/code], [code]\"false\"[/code], or [code]\"0\"[/code].",
		[
			DCDefinition.Param.new("condition").describe(
				"Command whose result determines the branch."
			),
			DCDefinition.Param.new("then").describe("Runs when the condition is truthy."),
			DCDefinition.Param.new("else").describe("Runs when the condition is falsy. Optional."),
		],
	)


func _not_cmd() -> DCDefinition:
	return DCDefinition.new(
		"not",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("Requires exactly one argument.")

			var result := await ctx.arg(0)
			return _ok(not result.truthy()),
		"Returns [b]true[/b] if its argument is falsy, [b]false[/b] if truthy.",
		[DCDefinition.Param.new("value").describe("Any command or literal value.")],
	)


func _and_cmd() -> DCDefinition:
	return DCDefinition.new(
		"and",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.fail("Requires at least one argument.")

			var last := DCResult.ok("")
			for i in ctx.args_length():
				last = await ctx.arg(i)
				if not last.truthy():
					return last

			return last,
		"Evaluates arguments left-to-right; returns the last result if all are truthy, "
		+ "or short-circuits on the first falsy / failed result.",
		[DCDefinition.Param.new("conditions").describe("Two or more commands or values.").rest()],
	)


func _or_cmd() -> DCDefinition:
	return DCDefinition.new(
		"or",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.fail("Requires at least one argument.")

			var last := DCResult.ok("")
			for i in ctx.args_length():
				last = await ctx.arg(i)
				if last.truthy():
					return last

			return last,
		"Evaluates arguments left-to-right; returns the first truthy result "
		+ "or the last result if none are truthy.",
		[DCDefinition.Param.new("conditions").describe("Two or more commands or values.").rest()],
	)
#endregion


#region ERROR HANDLING
func _try_cmd() -> DCDefinition:
	return DCDefinition \
			.new(
		"try",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0 or ctx.args_length() > 2:
				return DCResult.fail("Requires 1 or 2 arguments:  try (command) [fallback]")

			var result := await ctx.arg(0)
			if result.success:
				return result

			if ctx.is_aborted():
				return result

			if ctx.args_length() == 2:
				return await ctx.arg(1)

			return DCResult.ok("", "Success"),
		"Runs a command; on failure runs an optional fallback instead of "
		+ "propagating the error. Returns empty string when the command fails "
		+ "and no fallback is given.",
		[DCDefinition.Param.new("command").describe("Command to attempt."), DCDefinition
			.Param
			.new("fallback")
			.describe("Runs if the first command fails. Optional.")],
	)
#endregion


#region LOOPS
func _repeat_cmd() -> DCDefinition:
	return DCDefinition \
			.new(
		"repeat",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail("Requires at least 2 arguments: repeat N (command)...")

			var count_result := await ctx.arg(0)
			if not count_result.success:
				return count_result

			var count_string := count_result.text()
			if not count_string.is_valid_float():
				return DCResult.fail("N must be a number, got '%s'." % count_string)

			var count := int(float(count_string))
			if count <= 0:
				return DCResult.ok(null, "Success")

			if count > MAX_REPEAT_COUNT:
				return DCResult.fail(
					"Count %d exceeds the limit of %d." % [count, MAX_REPEAT_COUNT]
				)

			var last := DCResult.ok(null, "Success")
			for _iteration in count:
				if not await ctx.step():
					return DCResult.fail("Repeat aborted.")
				for arg_index in range(1, ctx.args_length()):
					last = await ctx.arg(arg_index, false)
					if not last.success:
						return last
			return last,

		"Runs one or more commands [b]N[/b] times and returns the last result.\n"
		+ "Each command is executed in order every iteration.\n"
		+ "Stops immediately if any command fails.\n" + "Maximum %d repetitions." % MAX_REPEAT_COUNT,
		[
			DCDefinition.Param.new("count").describe(
				"Number of iterations. Truncated to an integer."
			),
			DCDefinition
			.Param
			.new("commands")
			.describe("One or more commands to run each iteration.")
			.rest(),
		],
	)


func _while_cmd() -> DCDefinition:
	return DCDefinition \
			.new(
		"while",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"Requires at least 2 arguments: while (condition) (command)..."
				)

			var last := DCResult.ok(null, "Success")
			for _iteration in MAX_WHILE_ITERS:
				if not await ctx.step():
					return DCResult.fail("While aborted.")
				var condition := await ctx.arg(0, false)
				if not condition.truthy():
					break
				for arg_index in range(1, ctx.args_length()):
					last = await ctx.arg(arg_index, false)
					if not last.success:
						return last
			return last,
		"Re-evaluates a condition before every iteration and executes one or more "
		+ "commands while it is truthy.\n" + "Commands are executed in order each iteration.\n"
		+ "Returns the last command result, or an empty string if the body never ran.\n"
		+ "Hard limit: %d iterations." % MAX_WHILE_ITERS,
		[
			DCDefinition.Param.new("condition").describe("Re-evaluated before each iteration."),
			DCDefinition
			.Param
			.new("commands")
			.describe("One or more commands executed each iteration.")
			.rest(),
		],
	)
#endregion


#region COMPARISONS
func _compare_values(a: String, b: String) -> bool:
	if a.is_valid_float() and b.is_valid_float():
		return float(a) == float(b)

	return a == b


func _cmp_eq_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.eq",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("Requires exactly 2 arguments.")

			var pair := await _resolve_string_pair(ctx)
			if not pair.success:
				return DCResult.fail(pair.message)

			return _ok(_compare_values(pair.a, pair.b)),
		"Returns [b]true[/b] when both values are equal (numeric or string comparison).",
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)


func _cmp_neq_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.neq",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("Requires exactly 2 arguments.")

			var pair := await _resolve_string_pair(ctx)
			if not pair.success:
				return DCResult.fail(pair.message)

			return _ok(not _compare_values(pair.a, pair.b)),
		"Returns [b]true[/b] when the two values differ (numeric or string comparison).",
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)


func _cmp_gt_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.gt",
		"Returns [b]true[/b] when [i]a[/i] > [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool:
			return a > b,
	)


func _cmp_lt_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.lt",
		"Returns [b]true[/b] when [i]a[/i] < [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool:
			return a < b,
	)


func _cmp_gte_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.gte",
		"Returns [b]true[/b] when [i]a[/i] ≥ [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool:
			return a >= b,
	)


func _cmp_lte_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.lte",
		"Returns [b]true[/b] when [i]a[/i] ≤ [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool:
			return a <= b,
	)


func _cmp_in_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.in",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail("Requires at least 2 arguments: <value> <candidate>...")

			var value_result := await ctx.arg(0)
			if not value_result.success:
				return value_result

			var value := value_result.text()

			for index in range(1, ctx.args_length()):
				var candidate := await ctx.arg(index)
				if not candidate.success:
					return candidate

				if value == candidate.text():
					return DCResult.ok(true)

			return DCResult.ok(false),
		"Returns [b]true[/b] when the first value equals any following candidate (string comparison).",
		[
			DCDefinition.Param.new("value"),
			DCDefinition
			.Param
			.new("candidates")
			.describe("One or more values to compare against.")
			.rest(),
		],
	)


func _cmp_contains_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.contains",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("Requires exactly 2 arguments: <text> <substring>")

			var text_result := await ctx.arg(0)
			if not text_result.success:
				return text_result

			var substring_result := await ctx.arg(1)
			if not substring_result.success:
				return substring_result

			var text_value := text_result.text()
			var substring := substring_result.text()

			return DCResult.ok(text_value.contains(substring)),
		"Returns [b]true[/b] when the first string contains the second string.",
		[DCDefinition.Param.new("text"), DCDefinition.Param.new("substring")],
	)


func _cmp_empty_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.empty",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("Requires exactly 1 argument.")

			var result := await ctx.arg(0)
			if not result.success:
				return result

			return DCResult.ok(result.text().is_empty()),
		"Returns [b]true[/b] when the value is an empty string. Whitespace is not considered empty.",
		[DCDefinition.Param.new("value")],
	)


func _numeric_comparison_cmd(
	command_name: String,
	description: String,
	compare: Callable,
) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("Requires exactly 2 arguments.")

			var pair := await _resolve_numeric_pair(ctx)
			if not pair.success:
				return DCResult.fail(pair.message)

			return _ok(compare.call(pair.a, pair.b)),
		description,
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)
#endregion


#region HELPERS
func _resolve_string_pair(ctx: DCContext) -> _ValuePair:
	var pair := _ValuePair.new()

	var left := await ctx.arg(0)
	if not left.success:
		pair.message = left.full_message()
		return pair

	var right := await ctx.arg(1)
	if not right.success:
		pair.message = right.full_message()
		return pair

	pair.success = true
	pair.a = left.text()
	pair.b = right.text()

	return pair


func _resolve_numeric_pair(ctx: DCContext) -> _ValuePair:
	var pair := _ValuePair.new()

	var left := await ctx.arg(0)
	if not left.success:
		pair.message = left.full_message()
		return pair

	var right := await ctx.arg(1)
	if not right.success:
		pair.message = right.full_message()
		return pair

	var left_string := str(left.value)
	var right_string := str(right.value)

	if not left_string.is_valid_float():
		pair.message = "'%s' is not a number." % [left_string]
		return pair

	if not right_string.is_valid_float():
		pair.message = "'%s' is not a number." % [right_string]
		return pair

	pair.success = true
	pair.a = float(left_string)
	pair.b = float(right_string)
	return pair
#endregion


func _ok(value: Variant) -> DCResult:
	return DCResult.ok(value, "" if value == null else "Success")


## Internal resolved pair used by comparison command handlers.
class _ValuePair:
	var success: bool = false
	var message: String = ""
	var a: Variant
	var b: Variant
