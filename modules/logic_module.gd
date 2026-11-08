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
	return DCDefinition.new(
		"if",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2 or ctx.args_length() > 3:
				return DCResult.fail(
					"if requires 2 or 3 arguments:  if (condition) (then) [else]"
				)

			var condition := await ctx.arg(0)
			if _is_truthy(condition):
				return await ctx.arg(1)

			if ctx.args_length() == 3:
				return await ctx.arg(2)

			return DCResult.ok(""),
		"Evaluates a condition and runs one of two branches.\n"
		+ "A result is [b]truthy[/b] when it succeeds and its value is not "
		+ "[code]\"\"[/code], [code]\"false\"[/code], or [code]\"0\"[/code].",
		[
			DCDefinition.Param.new("condition").describe(
				"Command whose result determines the branch."
			),
			DCDefinition.Param.new("then").describe(
				"Runs when the condition is truthy."
			),
			DCDefinition.Param.new("else").describe(
				"Runs when the condition is falsy. Optional."
			),
		],
	).as_utility()


func _not_cmd() -> DCDefinition:
	return DCDefinition.new(
		"not",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail("not requires exactly one argument.")

			var result := await ctx.arg(0)
			return DCResult.ok("false" if _is_truthy(result) else "true"),
		"Returns [b]true[/b] if its argument is falsy, [b]false[/b] if truthy.",
		[DCDefinition.Param.new("value").describe("Any command or literal value.")],
	)


func _and_cmd() -> DCDefinition:
	return DCDefinition.new(
		"and",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.fail("and requires at least one argument.")

			var last := DCResult.ok("")
			for i in ctx.args_length():
				last = await ctx.arg(i)
				if not _is_truthy(last):
					return last

			return last,
		"Evaluates arguments left-to-right; returns the last result if all are truthy, "
		+ "or short-circuits on the first falsy / failed result.",
		[
			DCDefinition.Param.new("conditions")
			.describe("Two or more commands or values.")
			.rest()
		],
	)


func _or_cmd() -> DCDefinition:
	return DCDefinition.new(
		"or",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.fail("or requires at least one argument.")

			var last := DCResult.ok("")
			for i in ctx.args_length():
				last = await ctx.arg(i)
				if _is_truthy(last):
					return last

			return last,
		"Evaluates arguments left-to-right; returns the first truthy result "
		+ "or the last result if none are truthy.",
		[
			DCDefinition.Param.new("conditions")
			.describe("Two or more commands or values.")
			.rest()
		],
	)

#endregion


#region ERROR HANDLING

func _try_cmd() -> DCDefinition:
	return DCDefinition.new(
		"try",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0 or ctx.args_length() > 2:
				return DCResult.fail(
					"try requires 1 or 2 arguments:  try (command) [fallback]"
				)

			var result := await ctx.arg(0)
			if result.success:
				return result

			if ctx.args_length() == 2:
				return await ctx.arg(1)

			return DCResult.ok(""),
		"Runs a command; on failure runs an optional fallback instead of "
		+ "propagating the error. Returns empty string when the command fails "
		+ "and no fallback is given.",
		[
			DCDefinition.Param.new("command").describe("Command to attempt."),
			DCDefinition.Param.new("fallback").describe(
				"Runs if the first command fails. Optional."
			),
		],
	).as_utility()

#endregion


#region LOOPS

func _repeat_cmd() -> DCDefinition:
	return DCDefinition.new(
		"repeat",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"repeat requires at least 2 arguments: repeat N (command)..."
				)

			var count_result := await ctx.arg(0)
			if not count_result.success:
				return count_result

			var count_string := count_result.value.as_string()
			if not count_string.is_valid_float():
				return DCResult.fail(
					"repeat: N must be a number, got '%s'." % count_string
				)

			var count := int(float(count_string))
			if count <= 0:
				return DCResult.ok("")

			if count > MAX_REPEAT_COUNT:
				return DCResult.fail(
					"repeat: count %d exceeds the limit of %d."
					% [count, MAX_REPEAT_COUNT]
				)

			var last := DCResult.ok("")
			for _iteration in count:
				for arg_index in range(1, ctx.args_length()):
					last = await ctx.arg(arg_index, false)
					if not last.success:
						return last

			return last,
		"Runs one or more commands [b]N[/b] times and returns the last result.\n"
		+ "Each command is executed in order every iteration.\n"
		+ "Stops immediately if any command fails.\n"
		+ "Maximum %d repetitions." % MAX_REPEAT_COUNT,
		[
			DCDefinition.Param.new("count").describe(
				"Number of iterations. Truncated to an integer."
			),
			DCDefinition.Param.new("commands")
			.describe("One or more commands to run each iteration.")
			.rest(),
		],
	).as_utility()


func _while_cmd() -> DCDefinition:
	return DCDefinition.new(
		"while",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"while requires at least 2 arguments: while (condition) (command)..."
				)

			var last := DCResult.ok("")
			for _iteration in MAX_WHILE_ITERS:
				var condition := await ctx.arg(0)
				if not _is_truthy(condition):
					break

				for arg_index in range(1, ctx.args_length()):
					last = await ctx.arg(arg_index, false)
					if not last.success:
						return last

			return last,
		"Re-evaluates a condition before every iteration and executes one or more "
		+ "commands while it is truthy.\n"
		+ "Commands are executed in order each iteration.\n"
		+ "Returns the last command result, or an empty string if the body never ran.\n"
		+ "Hard limit: %d iterations." % MAX_WHILE_ITERS,
		[
			DCDefinition.Param.new("condition").describe(
				"Re-evaluated before each iteration."
			),
			DCDefinition.Param.new("commands")
			.describe("One or more commands executed each iteration.")
			.rest(),
		],
	).as_utility()

#endregion


#region COMPARISONS

func _cmp_eq_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.eq",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("cmp.eq requires exactly 2 arguments.")

			var pair := await _resolve_string_pair(ctx)
			if not pair.success:
				return DCResult.fail(pair.message)

			return DCResult.ok("true" if pair.a == pair.b else "false"),
		"Returns [b]true[/b] when both values are equal (string comparison).",
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)


func _cmp_neq_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.neq",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("cmp.neq requires exactly 2 arguments.")

			var pair := await _resolve_string_pair(ctx)
			if not pair.success:
				return DCResult.fail(pair.message)

			return DCResult.ok("true" if pair.a != pair.b else "false"),
		"Returns [b]true[/b] when the two values differ (string comparison).",
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)


func _cmp_gt_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.gt",
		"Returns [b]true[/b] when [i]a[/i] > [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool: return a > b
	)


func _cmp_lt_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.lt",
		"Returns [b]true[/b] when [i]a[/i] < [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool: return a < b
	)


func _cmp_gte_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.gte",
		"Returns [b]true[/b] when [i]a[/i] ≥ [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool: return a >= b
	)


func _cmp_lte_cmd() -> DCDefinition:
	return _numeric_comparison_cmd(
		"cmp.lte",
		"Returns [b]true[/b] when [i]a[/i] ≤ [i]b[/i] (numeric comparison).",
		func(a: float, b: float) -> bool: return a <= b
	)


func _cmp_in_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.in",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"cmp.in requires at least 2 arguments: <value> <candidate>..."
				)

			var value_result := await ctx.arg(0)
			if not value_result.success:
				return value_result

			var value := value_result.value.as_string()

			for index in range(1, ctx.args_length()):
				var candidate := await ctx.arg(index)
				if not candidate.success:
					return candidate

				if value == candidate.value.as_string():
					return DCResult.ok("true")

			return DCResult.ok("false"),
		"Returns [b]true[/b] when the first value equals any following candidate (string comparison).",
		[
			DCDefinition.Param.new("value"),
			DCDefinition.Param.new("candidates")
				.describe("One or more values to compare against.")
				.rest(),
		],
	)


func _cmp_contains_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.contains",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail(
					"cmp.contains requires exactly 2 arguments: <text> <substring>"
				)

			var text_result := await ctx.arg(0)
			if not text_result.success:
				return text_result

			var substring_result := await ctx.arg(1)
			if not substring_result.success:
				return substring_result

			var text_value := text_result.value.as_string()
			var substring := substring_result.value.as_string()

			return DCResult.ok(
				"true" if text_value.contains(substring) else "false"
			),
		"Returns [b]true[/b] when the first string contains the second string.",
		[
			DCDefinition.Param.new("text"),
			DCDefinition.Param.new("substring"),
		],
	)


func _cmp_empty_cmd() -> DCDefinition:
	return DCDefinition.new(
		"cmp.empty",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 1:
				return DCResult.fail(
					"cmp.empty requires exactly 1 argument."
				)

			var result := await ctx.arg(0)
			if not result.success:
				return result

			return DCResult.ok(
				"true" if result.value.as_string().is_empty() else "false"
			),
		"Returns [b]true[/b] when the value is an empty string. Whitespace is not considered empty.",
		[
			DCDefinition.Param.new("value"),
		],
	)

func _numeric_comparison_cmd(
	command_name: String,
	description: String,
	compare: Callable
) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("%s requires exactly 2 arguments." % command_name)

			var pair := await _resolve_numeric_pair(ctx, command_name)
			if not pair.success:
				return DCResult.fail(pair.message)

			return DCResult.ok(
				"true" if compare.call(pair.a, pair.b) else "false"
			),
		description,
		[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")],
	)

#endregion


#region HELPERS

## A result is truthy only when it succeeded and its value converts to true.
func _is_truthy(result: DCResult) -> bool:
	if not result.success:
		return false

	var value := result.value.as_bool()
	return value != null and value


func _resolve_string_pair(ctx: DCContext) -> _ValuePair:
	var pair := _ValuePair.new()

	var left := await ctx.arg(0)
	if not left.success:
		pair.message = left.message
		return pair

	var right := await ctx.arg(1)
	if not right.success:
		pair.message = right.message
		return pair

	pair.success = true
	pair.a = left.value.as_string()
	pair.b = right.value.as_string()
	return pair


func _resolve_numeric_pair(ctx: DCContext, command_name: String) -> _ValuePair:
	var pair := _ValuePair.new()

	var left := await ctx.arg(0)
	if not left.success:
		pair.message = left.message
		return pair

	var right := await ctx.arg(1)
	if not right.success:
		pair.message = right.message
		return pair

	var left_string := left.value.as_string()
	var right_string := right.value.as_string()

	if not left_string.is_valid_float():
		pair.message = "%s: '%s' is not a number." % [command_name, left_string]
		return pair

	if not right_string.is_valid_float():
		pair.message = "%s: '%s' is not a number." % [command_name, right_string]
		return pair

	pair.success = true
	pair.a = float(left_string)
	pair.b = float(right_string)
	return pair

#endregion


## Internal resolved pair used by comparison command handlers.
class _ValuePair:
	var success: bool = false
	var message: String = ""
	var a: Variant
	var b: Variant
