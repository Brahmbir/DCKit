## The sole argument every command handler receives.
##
## [b]What it contains[/b]
## [br]
## [br]
## [code]abort[/code] — cooperative cancellation: is_aborted(), aborted signal, step()[br]
## [code]args[/code]  — lazy arg resolution: arg(n), get_all_args(), args_length()
##
## [br]
## [br]
## [b]Arg resolution[/b]
## [br]
## Arguments are never pre-resolved. The handler pulls each one on demand.
## Resolution is async because nested commands and constructors may await.
##
## [codeblock]
## await ctx.arg(n)           → DCResult
##                                .success = true  → .value is DCVal
##                                .success = false → .message is the error
##
## await ctx.get_all_args()   → Array[DCResult]
##                                one entry per argument, in order
##                                the handler decides what to do with failures
##
## ctx.args_length()          → int   (sync — no await needed)
## [/codeblock]
##
## Results are cached after first resolution. Calling ctx.arg(0) twice
## runs the nested command / constructor only once. The second call returns
## the cached DCResult immediately.
##
## [br]
## [br]
## [b]Running raw command strings[/b]
## [codeblock]
## await ctx.run_raw(raw: String) → Array[DCResult]
## [/codeblock]
##
## Lets a handler execute another command string through the executor's
## full pipeline (analyze → execute), nested under this command. Shares
## this command's abort scope (ctx.abort() cancels it too) and logging
## origin. Same return shape as Executor.run() — currently 0 or 1 entries
## (chains are gated upstream at the lexer), but chain-ready.
##
## [codeblock]
## var results := await ctx.run_raw("var.set speed 5")
## if not results.is_empty() and not results.back().success:
##     return results.back()
## [/codeblock]
##
## [br]
## [b]Handler signature[/b]
## [codeblock]
## func(ctx: DCContext) -> DCResult
## [/codeblock]
##
## [b]Typical eager handler[/b]
## [codeblock]
## func(ctx: DCContext) -> DCResult:
##     var all = await ctx.get_all_args()
##     # check each result as needed, or just pull values directly:
##     var r0 = all[0]
##     if not r0.success: return r0
##     var name : String = r0.text()
##     ...
## [/codeblock]
##
## [b]Lazy control-flow handler[/b]
## [codeblock]
## func(ctx: DCContext) -> DCResult:
##     var cond = await ctx.arg(0)
##     if not cond.success: return cond
##     if not cond.value:
##         return DCResult.ok("Condition false — skipped.")
##     var branch = await ctx.arg(1)   # only runs if condition was true
##     if not branch.success: return branch
##     return DCResult.ok(branch.value)
## [/codeblock]
class_name DCContext
extends RefCounted

# Signals
## Emitted exactly once, when abort() is first called on the root context.
signal aborted

var breadcrumb: String = ""

# Internal state
# Raw unresolved argument nodes from the parser.
# Array[DevConsoleParser.CommandNode | ConstructorNode | StringNode | VariableNode]
# Set by the executor at construction; never modified after.
var _raw_args: Array = []

# Cache: index → DCResult. Populated on first access per index.
# Stored as Dictionary so unresolved indices are absent (not null).
var _cache: Dictionary = { }

# The resolver callable injected by the executor.
# Signature: func(raw_arg, root_ctx: DevConsoleCommandContext) -> DCResult
# This decouples the context from the executor class entirely.
var _resolver: Callable

# The raw-string runner callable injected by the executor (bound right after
# construction via bind_raw_runner). Lets this command run other command
# strings nested under its own abort scope. See run_raw() below.
var _raw_runner: Callable

var _aborted: bool = false
var _root_ctx: DCContext = null
var _var_resolver: Callable

# Construction — executor only
## Constructs a context for one command invocation.
## [param p_raw_args]  — unresolved parser nodes, one per argument.
## [param p_log]       — scoped logger for this command invocation.
## [param p_resolver]  — async callable the context uses to resolve one node.
## [param p_root]      — parent context when this is a nested command; null for root.
func _init(
	p_raw_args: Array,
	p_resolver: Callable,
	p_root: DCContext = null,
	_breadcrumb: String = "",
) -> void:
	_raw_args = p_raw_args
	_resolver = p_resolver
	_root_ctx = p_root
	breadcrumb = _breadcrumb


# Arg API
## Returns the number of arguments this command was called with.
## Sync — no await needed.
func args_length() -> int:
	return _raw_args.size()


## Resolves and returns argument at index [param n].
## Returns a cached result on subsequent calls — the underlying node runs once.
##
## Returns [DCResult]:[br]
## success = true  → value is DCResult.Value[br]
## success = false → message contains the error; value is null
##
## Out-of-bounds → immediate fail result, no error is pushed.
func arg(n: int, should_cache: bool = true) -> DCResult:
	if n < 0 or n >= _raw_args.size():
		return DCResult.fail(
			"Argument %d does not exist — command received %d argument(s)." \
					% [n, _raw_args.size()]
		)

	if _cache.has(n):
		return _cache[n]

	var result: DCResult = await _resolver.call(_raw_args[n], _root_ctx if _root_ctx else self)
	if should_cache:
		_cache[n] = result
	return result


## Resolves all arguments and returns one DCResult per argument.
## Each entry is independently succeeded or failed.
## The handler decides what to do with failures — no fail-fast here.
##
## Returns [code]Array[DCResult][/code] — same length as args_length().
## Returns an empty array when the command has no arguments.
func get_all_args() -> Array:
	var out: Array = []
	for i in _raw_args.size():
		var result: DCResult = await arg(i)
		out.append(result)
	return out


## Returns the unresolved argument at index [param n] exactly as the parser
## produced it, or null when out of bounds. For commands that must keep an
## argument unevaluated (var.setd). Pass it back to the executor's
## resolver later; don't inspect it.
func arg_node(n: int) -> Variant:
	if n < 0 or n >= _raw_args.size():
		return null
	return _raw_args[n]


## Runs a raw command string through the executor's full pipeline
## (analyze → execute), nested under this command. See class doc for
## usage and return shape.
func run_raw(raw: String) -> Array:
	if not _raw_runner.is_valid():
		return [DCResult.fail("run_raw is not available in this context.")]
	var result = await _raw_runner.call(raw)
	if result is DCResult:
		return [result]
	return result

## Resolves a variable exactly like $name does: live values run, a failing
## deferred expression is reported. With [param fallback] (an unresolved node,
## e.g. ctx.arg_node(1)) a missing variable resolves the fallback instead of failing,
## the same as ${key?:fallback}.
func resolve_var(key: String, fallback: Variant = null) -> DCResult:
	if not _var_resolver.is_valid():
		return DCResult.fail("resolve_var is not available in this context.")
	return await _var_resolver.call(key, fallback)

# Abort
## Returns whether this command has been aborted.
## Delegates upward — if root is aborted, so are all children.
func is_aborted() -> bool:
	if _root_ctx != null:
		return _root_ctx.is_aborted()
	return _aborted


## Called by DevConsole when the user presses Stop.
## Idempotent — safe to call multiple times, emits exactly once.
func abort() -> void:
	if _root_ctx != null:
		_root_ctx.abort()
		return
	if _aborted:
		return
	_aborted = true
	aborted.emit()



func await_or_abort(exec_signal: Signal) -> bool:
	var abort_source := _root_ctx if _root_ctx != null else self

	if abort_source.is_aborted():
		return true

	var race := _SignalRace.new()
	var winner: int = await race.wait(exec_signal, abort_source.aborted)

	return winner == 1


# Raw-string execution
# Called by the executor right after construction — not for handler use.
func _bind_raw_runner(fn: Callable) -> void:
	_raw_runner = fn

# next to _bind_raw_runner — executor only
func _bind_var_resolver(fn: Callable) -> void:
	_var_resolver = fn


class _SignalRace extends RefCounted:
	signal completed(winner: int)

	var _resolved := false


	## Waits for whichever signal fires first.
	## Returns 0 if first_signal wins, 1 if second_signal wins.
	func wait(first_signal: Signal, second_signal: Signal) -> int:
		var on_first := func() -> void:
			_resolve(0)

		var on_second := func() -> void:
			_resolve(1)

		first_signal.connect(on_first, CONNECT_ONE_SHOT)
		second_signal.connect(on_second, CONNECT_ONE_SHOT)

		var winner: int = await completed

		if first_signal.is_connected(on_first):
			first_signal.disconnect(on_first)

		if second_signal.is_connected(on_second):
			second_signal.disconnect(on_second)

		return winner


	func _resolve(winner: int) -> void:
		if _resolved:
			return

		_resolved = true
		completed.emit(winner)
