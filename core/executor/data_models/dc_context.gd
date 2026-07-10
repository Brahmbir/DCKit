## The sole argument every command handler receives.
##
## [b]What it contains[/b]
## [br]
## [br]
## [code]log[/code]   — scoped logger for this invocation[br]
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
## func(ctx: DevConsoleCommandContext) -> DCResult
## [/codeblock]
##
## [b]Typical eager handler[/b]
## [codeblock]
## func(ctx: DevConsoleCommandContext) -> DCResult:
##     var all = await ctx.get_all_args()
##     # check each result as needed, or just pull values directly:
##     var r0 = all[0]
##     if not r0.success: return r0
##     var name : String = r0.value.as_string()
##     ...
## [/codeblock]
## 
## [b]Lazy control-flow handler[/b]
## [codeblock]
## func(ctx: DevConsoleCommandContext) -> DCResult:
##     var cond = await ctx.arg(0)
##     if not cond.success: return cond
##     if not cond.value.raw:
##         return DCResult.ok("Condition false — skipped.")
##     var branch = await ctx.arg(1)   # only runs if condition was true
##     if not branch.success: return branch
##     return DCResult.ok(branch.value.raw)
## [/codeblock]
class_name DCContext
extends RefCounted


# Signals

## Emitted exactly once, when abort() is first called on the root context.
signal aborted


# Public fields

## Scoped logger for this command invocation.
var log : DCLogger


# Internal state

# Raw unresolved argument nodes from the parser.
# Array[DevConsoleParser.CommandNode | ConstructorNode | StringNode | VariableNode]
# Set by the executor at construction; never modified after.
var _raw_args : Array = []

# Cache: index → DCResult. Populated on first access per index.
# Stored as Dictionary so unresolved indices are absent (not null).
var _cache : Dictionary = {}

# The resolver callable injected by the executor.
# Signature: func(raw_arg, root_ctx: DevConsoleCommandContext) -> DCResult
# This decouples the context from the executor class entirely.
var _resolver : Callable

# The raw-string runner callable injected by the executor (bound right after
# construction via bind_raw_runner). Lets this command run other command
# strings nested under its own abort scope. See run_raw() below.
var _raw_runner : Callable

var _aborted  : bool = false
var _root_ctx : DCContext = null


# Construction — executor only

## Constructs a context for one command invocation.
## [param p_raw_args]  — unresolved parser nodes, one per argument.
## [param p_log]       — scoped logger for this command invocation.
## [param p_resolver]  — async callable the context uses to resolve one node.
## [param p_root]      — parent context when this is a nested command; null for root.
func _init(
		p_raw_args : Array,
		p_log      : DCLogger,
		p_resolver : Callable,
		p_root     : DCContext = null) -> void:
	_raw_args = p_raw_args
	_resolver = p_resolver
	_root_ctx = p_root
	log = p_log


# Arg API

## Returns the number of arguments this command was called with.
## Sync — no await needed.
func args_length() -> int:
	return _raw_args.size()


## Resolves and returns argument at index [param n].
## Returns a cached result on subsequent calls — the underlying node runs once.
##
## Returns [DCResult]:[br]
## success = true  → value is DCVal[br]
## success = false → message contains the error; value is null
##
## Out-of-bounds → immediate fail result, no error is pushed.
func arg(n: int, should_cache: bool = true) -> DCResult:
	if n < 0 or n >= _raw_args.size():
		return DCResult.fail(
			"Argument %d does not exist — command received %d argument(s)." \
			% [n, _raw_args.size()])

	if _cache.has(n):
		return _cache[n]

	var result : DCResult = await _resolver.call(_raw_args[n], _root_ctx if _root_ctx else self)
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
	var out : Array = []
	for i in _raw_args.size():
		var result : DCResult = await arg(i)
		out.append(result)
	return out


# Raw-string execution

# Called by the executor right after construction — not for handler use.
func _bind_raw_runner(fn: Callable) -> void:
	_raw_runner = fn


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
	if _aborted:
		return
	_aborted = true
	aborted.emit()


## Returns a new [Step] builder bound to this context.
## Each call produces a fresh Step — do not reuse instances.
##
## [b]Usage[/b]
## [codeblock]
## var timer : SceneTreeTimer = null
## var was_aborted := await ctx.step() \
##     .init(func():
##         timer = Engine.get_main_loop().create_timer(5.0)
##     ) \
##     .exec(func() -> Signal:
##         return timer.timeout
##     ) \
##     .cleanup(func():
##         pass
##     ) \
##     .run()
## if was_aborted:
##     return DCResult.fail("Aborted.")
## [/codeblock]
func step() -> Step:
	return Step.new(self)


## Abortable async block. Races an exec signal against ctx.aborted.
## Whichever fires first wins — no polling, no frame spinning.
##
## [b]Three cases[/b][br]
## Case 1 — Normal:     exec signal fires.   cleanup skipped. run() → false.[br]
## Case 2 — Pre-abort:  ctx already aborted. init skipped.    run() → true.[br]
## Case 3 — Mid-abort:  abort fires during await.  cleanup runs. run() → true.
##
## [b]Constraints[/b][br]
## init    — must be synchronous.[br]
## cleanup — must be synchronous.[br]
## exec    — must return a valid live Signal. If the owning object is freed
## before the signal fires, the step will hang. cleanup must prevent
## this by freeing or stopping the resource.
class Step extends RefCounted:

	signal _resolved(was_aborted: bool)

	var _ctx        : DCContext
	var _init_fn    : Callable
	var _exec_fn    : Callable
	var _cleanup_fn : Callable

	func _init(ctx: DCContext) -> void:
		_ctx = ctx

	# Fluent builders

	## Sets a synchronous function to run before exec.
	func init(fn: Callable) -> Step:
		_init_fn = fn
		return self

	## Sets the async trigger. [param fn] must have signature: func() -> Signal.
	func exec(fn: Callable) -> Step:
		_exec_fn = fn
		return self

	## Sets a synchronous function to run only if aborted mid-exec.
	func cleanup(fn: Callable) -> Step:
		_cleanup_fn = fn
		return self

	# Run

	## Runs the step, awaiting either the exec signal or abort, whichever
	## fires first. Returns true if the step was aborted, false otherwise.
	func run() -> bool:
		# Case 2 — already aborted before this step starts.
		if _ctx.is_aborted():
			return true

		# init — synchronous, always runs before exec.
		if _init_fn.is_valid():
			_init_fn.call()

		# No exec provided — nothing async to race.
		if not _exec_fn.is_valid():
			return false

		# Retrieve the signal to await.
		var exec_signal = _exec_fn.call()
		if not exec_signal is Signal:
			push_error("DevConsoleCommandContext.Step: exec() must return a Signal.")
			return false

		# Always race against the ROOT context's aborted signal.
		# If this IS the root, _root_ctx is null and we use ourselves.
		var abort_source : DCContext = _ctx._root_ctx if _ctx._root_ctx != null else _ctx

		# Race both signals. _guard[0] is the fired flag.
		# An Array is used instead of a plain bool because GDScript lambdas
		# capture variables by value — assigning _fired = true inside a lambda
		# only modifies the lambda's local copy and the outer variable never
		# changes. Arrays are reference types, so both lambdas share the same
		# object and _guard[0] = true is visible to both.
		var _guard := [false]

		var on_exec_done := func() -> void:
			if _guard[0]: return
			_guard[0] = true
			_resolved.emit(false)

		var on_aborted := func() -> void:
			if _guard[0]: return
			_guard[0] = true
			if _cleanup_fn.is_valid():
				_cleanup_fn.call()
			_resolved.emit(true)

		exec_signal.connect(on_exec_done, CONNECT_ONE_SHOT)
		abort_source.aborted.connect(on_aborted, CONNECT_ONE_SHOT)

		var was_aborted : bool = await _resolved

		if exec_signal.is_connected(on_exec_done):
			exec_signal.disconnect(on_exec_done)
		if abort_source.aborted.is_connected(on_aborted):
			abort_source.aborted.disconnect(on_aborted)

		return was_aborted
