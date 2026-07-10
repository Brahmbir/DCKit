extends RefCounted

# Maximum iterations for repeat and while — safeguards against runaway loops.
# Both commands fail-fast on body failure so abort still terminates them early.
const MAX_REPEAT_COUNT : int = 1_000
const MAX_WHILE_ITERS  : int = 10_000


static func get_command_def_array() -> Array[DCDefinition]:
	return [
		if_cmd, not_cmd, and_cmd, or_cmd, # conditionals
		try_cmd, # error handling
		repeat_cmd, while_cmd, # loops
		# comparisons
		cmp_eq_cmd, cmp_neq_cmd,
		cmp_gt_cmd, cmp_lt_cmd, cmp_gte_cmd, cmp_lte_cmd,
	]

#region CONDITIONALS

static var if_cmd := DCDefinition.new(
	"if",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() < 2 or ctx.args_length() > 3:
			return DCResult.fail(
				"if requires 2 or 3 arguments:  if (condition) (then) [else]")
		var cond := await ctx.arg(0)
		if _is_truthy(cond):
			return await ctx.arg(1)
		if ctx.args_length() == 3:
			return await ctx.arg(2)
		return DCResult.ok(""),
	"Evaluates a condition and runs one of two branches.\n"
	+ "A result is [b]truthy[/b] when it succeeds and its value is not [code]\"\"[/code], "
	+ "[code]\"false\"[/code], or [code]\"0\"[/code].",
	[
		DCDefinition.Param.new("condition").describe("Command whose result determines the branch."),
		DCDefinition.Param.new("then").describe("Runs when the condition is truthy."),
		DCDefinition.Param.new("else").describe("Runs when the condition is falsy. Optional."),
	]
).as_utility()

static var not_cmd := DCDefinition.new(
	"not",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 1:
			return DCResult.fail("not requires exactly one argument.")
		var r := await ctx.arg(0)
		return DCResult.ok("false" if _is_truthy(r) else "true"),
	"Returns [b]true[/b] if its argument is falsy, [b]false[/b] if truthy.",
	[DCDefinition.Param.new("value").describe("Any command or literal value.")]
)

static var and_cmd := DCDefinition.new(
	"and",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() == 0:
			return DCResult.fail("and requires at least one argument.")
		var last := DCResult.ok("")
		for i in ctx.args_length():
			last = await ctx.arg(i)
			if not _is_truthy(last):
				return last  # short-circuit on first falsy / failed result
		return last,
	"Evaluates arguments left-to-right; returns the last result if all are truthy, "
	+ "or short-circuits on the first falsy / failed result.",
	[DCDefinition.Param.new("conditions").describe("Two or more commands or values.").rest()]
)

static var or_cmd := DCDefinition.new(
	"or",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() == 0:
			return DCResult.fail("or requires at least one argument.")
		var last := DCResult.ok("")
		for i in ctx.args_length():
			last = await ctx.arg(i)
			if _is_truthy(last):
				return last  # short-circuit on first truthy success
		return last,
	"Evaluates arguments left-to-right; returns the first truthy result "
	+ "or the last result if none are truthy.",
	[DCDefinition.Param.new("conditions").describe("Two or more commands or values.").rest()]
)
#endregion 

#region  ERROR HANDLING
static var try_cmd := DCDefinition.new(
	"try",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() == 0 or ctx.args_length() > 2:
			return DCResult.fail(
				"try requires 1 or 2 arguments:  try (command) [fallback]")
		var r := await ctx.arg(0)
		if r.success:
			return r
		if ctx.args_length() == 2:
			return await ctx.arg(1)
		return DCResult.ok(""),
	"Runs a command; on failure runs an optional fallback instead of "
	+ "propagating the error. Returns empty string when the command fails "
	+ "and no fallback is given.",
	[
		DCDefinition.Param.new("command").describe("Command to attempt."),
		DCDefinition.Param.new("fallback").describe("Runs if the first command fails. Optional."),
	]
).as_utility()
#endregion 

#region LOOPS

static var repeat_cmd := DCDefinition.new(
	"repeat",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() < 2:
			return DCResult.fail(
				"repeat requires at least 2 arguments: repeat N (command)...")

		var count_r := await ctx.arg(0)
		if not count_r.success:
			return count_r

		var count_s := count_r.value.as_string()
		if not count_s.is_valid_float():
			return DCResult.fail(
				"repeat: N must be a number, got '%s'." % count_s)

		var count := int(float(count_s))

		if count <= 0:
			return DCResult.ok("")

		if count > MAX_REPEAT_COUNT:
			return DCResult.fail(
				"repeat: count %d exceeds the limit of %d."
				% [count, MAX_REPEAT_COUNT])

		var last := DCResult.ok("")

		for _i in count:
			for arg in range(1, ctx.args_length()):
				last = await ctx.arg(arg, false)
				if not last.success:
					return last

		return last,
	"Runs one or more commands [b]N[/b] times and returns the last result.\n"
	+ "Each command is executed in order every iteration.\n"
	+ "Stops immediately if any command fails.\n"
	+ "Maximum %d repetitions." % MAX_REPEAT_COUNT,
	[
		DCDefinition.Param.new("count")
			.describe("Number of iterations. Truncated to an integer."),
		DCDefinition.Param.new("commands")
			.describe("One or more commands to run each iteration.")
			.rest(),
	]
).as_utility()

static var while_cmd := DCDefinition.new(
	"while",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() < 2:
			return DCResult.fail(
				"while requires at least 2 arguments: while (condition) (command)...")

		var last := DCResult.ok("")

		for _i in MAX_WHILE_ITERS:
			var cond := await ctx.arg(0)
			if not _is_truthy(cond):
				break

			for arg in range(1, ctx.args_length()):
				last = await ctx.arg(arg, false)
				if not last.success:
					return last

		return last,
	"Re-evaluates a condition before every iteration and executes one or more "
	+ "commands while it is truthy.\n"
	+ "Commands are executed in order each iteration.\n"
	+ "Returns the last command result, or an empty string if the body never ran.\n"
	+ "Hard limit: %d iterations." % MAX_WHILE_ITERS,
	[
		DCDefinition.Param.new("condition")
			.describe("Re-evaluated before each iteration."),
		DCDefinition.Param.new("commands")
			.describe("One or more commands executed each iteration.")
			.rest(),
	]
).as_utility()
#endregion 

#region COMPARISONS
# String comparisons: cmp.eq, cmp.neq
# Numeric comparisons: cmp.gt, cmp.lt, cmp.gte, cmp.lte

static var cmp_eq_cmd := DCDefinition.new(
	"cmp.eq",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.eq requires exactly 2 arguments.")
		var a := await ctx.arg(0)
		if not a.success: return a
		var b := await ctx.arg(1)
		if not b.success: return b
		return DCResult.ok("true" if a.value.as_string() == b.value.as_string() else "false"),
	"Returns [b]true[/b] when both values are equal (string comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)

static var cmp_neq_cmd := DCDefinition.new(
	"cmp.neq",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.neq requires exactly 2 arguments.")
		var a := await ctx.arg(0)
		if not a.success: return a
		var b := await ctx.arg(1)
		if not b.success: return b
		return DCResult.ok("true" if a.value.as_string() != b.value.as_string() else "false"),
	"Returns [b]true[/b] when the two values differ (string comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)

static var cmp_gt_cmd := DCDefinition.new(
	"cmp.gt",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.gt requires exactly 2 arguments.")
		var pair := await _resolve_num_pair(ctx, "cmp.gt")
		if not pair.success: return DCResult.fail(pair.message)
		return DCResult.ok("true" if pair.a > pair.b else "false"),
	"Returns [b]true[/b] when [i]a[/i] > [i]b[/i] (numeric comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)

static var cmp_lt_cmd := DCDefinition.new(
	"cmp.lt",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.lt requires exactly 2 arguments.")
		var pair := await _resolve_num_pair(ctx, "cmp.lt")
		if not pair.success: return DCResult.fail(pair.message)
		return DCResult.ok("true" if pair.a < pair.b else "false"),
	"Returns [b]true[/b] when [i]a[/i] < [i]b[/i] (numeric comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)

static var cmp_gte_cmd := DCDefinition.new(
	"cmp.gte",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.gte requires exactly 2 arguments.")
		var pair := await _resolve_num_pair(ctx, "cmp.gte")
		if not pair.success: return DCResult.fail(pair.message)
		return DCResult.ok("true" if pair.a >= pair.b else "false"),
	"Returns [b]true[/b] when [i]a[/i] ≥ [i]b[/i] (numeric comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)

static var cmp_lte_cmd := DCDefinition.new(
	"cmp.lte",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() != 2:
			return DCResult.fail("cmp.lte requires exactly 2 arguments.")
		var pair := await _resolve_num_pair(ctx, "cmp.lte")
		if not pair.success: return DCResult.fail(pair.message)
		return DCResult.ok("true" if pair.a <= pair.b else "false"),
	"Returns [b]true[/b] when [i]a[/i] ≤ [i]b[/i] (numeric comparison).",
	[DCDefinition.Param.new("a"), DCDefinition.Param.new("b")]
)
#endregion

#region  HELPERS

## A DCResult is truthy when it succeeded AND its string value is not
## empty, "false", or "0".  A failed result is always falsy.
static func _is_truthy(r: DCResult) -> bool:
	if not r.success:
		return false
	var s := r.value.as_bool()
	return s != null and s


## Resolves both arguments of a numeric-comparison command and parses them
## as floats.  Returns a pseudo-DCResult: if .success is true the caller
## may read .a and .b (both float); otherwise .message carries the error.
class _NumPair:
	var success : bool  = false
	var message : String = ""
	var a       : float = 0.0
	var b       : float = 0.0


static func _resolve_num_pair(ctx: DCContext, cmd: String) -> _NumPair:
	var out := _NumPair.new()
	var ra  := await ctx.arg(0)
	if not ra.success:
		out.message = ra.message; return out
	var rb := await ctx.arg(1)
	if not rb.success:
		out.message = rb.message; return out
	var sa := ra.value.as_string(); var sb := rb.value.as_string()
	if not sa.is_valid_float():
		out.message = "%s: '%s' is not a number." % [cmd, sa]; return out
	if not sb.is_valid_float():
		out.message = "%s: '%s' is not a number." % [cmd, sb]; return out
	out.success = true; out.a = float(sa); out.b = float(sb)
	return out
#endregion 
