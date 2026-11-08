# executor.gd
# Async pipeline: raw String → DCResult
#
# run(raw) → DCResult
#   Single command or a semicolon chain (lexer-gated for now).
#   Chain runs sequentially, fail-fast. Always returns one DCResult.
#   This is the user-input entry point — origin is always "user".
#
# Call-stack tracing
#   Every _execute() push/pops a _CallStack shared across the whole
#   execution tree. run_raw() inherits the caller's stack, so the breadcrumb
#   string (CallStack.breadcrumb) always shows the full ancestry:
#   "player.warp>var.get>...". It is passed to the logger as `details` and
#   exposed to handlers as ctx.breadcrumb.
#
# Depth limits
#   _CallStack tracks two independent depths, each checked in _execute()
#   before a new frame is pushed:
#
#     argument depth  — commands nested as arguments, constructor parts, or
#                        variable fallbacks (anything reached via
#                        _resolve_node). Purely structural: determined by
#                        the parsed AST, identical every time a given
#                        command string runs. Capped by MAX_ARGUMENT_DEPTH.
#
#     execution depth — commands run via the chain loop in _run_execution,
#                        including everything triggered by ctx.run_raw().
#                        Depends on handler implementation, not on the
#                        command string. Capped by MAX_EXECUTION_DEPTH.
#
#   The two never share a budget — deeply nested arguments won't fail
#   because some inner handler happens to use run_raw, and vice versa.
#   Both limits guard only against runaway recursion; total work done per
#   run() is intentionally uncapped — that's the handler author's call.
#
# Log contract
#   log_command  — fires once in run(), before execution, with the raw user
#                  string. Details are always empty at this point.
#   log_system   — fires only for chain steps (one per command in a multi-
#                  command chain) and for every ctx.run_raw() call. Carries
#                  a human-readable message. Nowhere else.
#   log_result   — fires in _execute() after the handler returns (one per
#                  command frame). Also fires for early failures in run()
#                  and for analysis failures in _run_execution().
extends RefCounted

signal command_executed(raw: String, result: DCResult)
signal command_aborted
signal state_changed

const Profiler := preload("./profiler.gd")
const Detail := _DCKitNS.Executor.StateTracker.Detail

const _ORIGIN_USER := "user"

# Call-stack safety limits — tune per project. These bound recursion depth,
# not total work (see header).
var MAX_EXECUTION_DEPTH: int = _DCKitSetting.get_max_execution_depth()
var MAX_ARGUMENT_DEPTH: int = _DCKitSetting.get_max_argument_depth()

# Owned by the backend and injected; the executor only writes to it.
var logger: _DCKitNS.Core.Tracer = null
var profiler: Profiler = null

var detail: Detail:
	get:
		return _tracker.detail
	set(value):
		_tracker.detail = value

var _tracker := _DCKitNS.Executor.StateTracker.new()

# Names of deferred variables being resolved right now. Guards against a
# deferred variable that (directly or indirectly) reads itself.
var _resolving: Array[String] = []

var _cmd_reg: _DCKitNS.Registries.CommandRegistry
var _vars: _DCKitNS.Core.VariableStore
var _ctor_reg: _DCKitNS.Registries.ConstructorRegistry
var _analyzer: _DCKitNS.Analyzer.Analyzer

var _active_ctx: DCContext = null

var _root_exec: _DCKitNS.Executor.Execution = null # the user's run only; nested run_raw never replaces it


func _init(
	cmd_reg: _DCKitNS.Registries.CommandRegistry,
	ctor_reg: _DCKitNS.Registries.ConstructorRegistry,
	vars_store: _DCKitNS.Core.VariableStore,
	analyzer: _DCKitNS.Analyzer.Analyzer,
	tracer: _DCKitNS.Core.Tracer,
) -> void:
	_cmd_reg = cmd_reg
	_vars = vars_store
	_ctor_reg = ctor_reg
	_analyzer = analyzer
	logger = tracer

	profiler = Profiler.new()

	_tracker.changed.connect(state_changed.emit)


# INFO PUBLIC Methods
func is_running() -> bool:
	return _tracker.is_running()


func get_state() -> _DCKitNS.Executor.ExecutorState:
	return _tracker.snapshot()


func reset() -> void:
	_active_ctx = null
	_tracker.end()


func run(raw: String) -> DCResult:
	# Always log what the user typed first — even if we reject it below.
	_log_command(raw)

	if _tracker.is_running():
		var f := DCResult.fail("A command is already running.")
		_log_result(f)
		return f

	var exec := _DCKitNS.Executor.Execution.new(
		raw,
		_ORIGIN_USER,
		null,
		_DCKitNS.Executor.CallStack.new(),
	)

	_tracker.begin(exec, raw)
	var result: DCResult = await _run_execution(exec)
	_tracker.end()
	command_executed.emit(raw, result)
	return result


func abort() -> void:
	if _active_ctx != null:
		_active_ctx.abort()
		command_aborted.emit()


func _publish() -> void:
	_tracker.publish()


# PIPELINE
# Shared by run() and ctx.run_raw(). Does NOT touch _running.
func _run_execution(exec: _DCKitNS.Executor.Execution) -> DCResult:
	var analysis: DCAnalysisResult = _analyzer.analyze(exec.raw)
	if not analysis.ok():
		var f := DCResult.fail(_format_errors(analysis.diagnostics))
		_log_result(f, exec.call_stack.breadcrumb())
		return f

	exec.commands = analysis.ast
	if exec.commands.is_empty():
		return DCResult.ok(null)

	# Announce each step only when there are multiple commands in the chain.
	# Single-command runs (including run_raw) are announced by their caller.
	var is_chain := exec.commands.size() > 1
	var total := exec.commands.size()
	exec.chain_total = total

	for i in total:
		var cmd: _DCKitNS.Analyzer.Parser.CommandNode = exec.commands[i]

		if is_chain:
			var segment := _slice(exec.raw, cmd) if not exec.raw.is_empty() else cmd.name
			_log_system(
				"Chain [%d/%d]: %s" % [i + 1, total, segment],
				exec.call_stack.breadcrumb(),
			)

		exec.chain_index = i + 1
		_publish()

		var r: DCResult = await _execute(cmd, exec, _DCKitNS.Executor.CallStack.FrameKind.EXECUTION)
		exec.record(r)
		if not r.success:
			break
		# very important: yield to the engine so the UI can update between chain steps
		await Engine.get_main_loop().process_frame

	return exec.to_result()


# Pushes to the shared call stack, dispatches the handler, pops on return.
# All log calls happen while the command is on the stack so ancestry is intact.
#
# kind — _CallStack.FrameKind.EXECUTION for chain items (root run() and
#        anything ctx.run_raw() triggers), or .ARGUMENT for commands
#        resolved as arguments / constructor parts / variable fallbacks.
func _execute(
	node: _DCKitNS.Analyzer.Parser.CommandNode,
	exec: _DCKitNS.Executor.Execution,
	kind: int,
) -> DCResult:
	var definition: DCDefinition = _cmd_reg.get_definition(node.name)
	if definition == null:
		return DCResult.fail("Unknown command '%s'." % node.name)

	var handler: Callable = definition.handler if definition else Callable()

	if not handler.is_valid():
		return DCResult.fail("Unknown command '%s'." % node.name)

	if kind == _DCKitNS.Executor.CallStack.FrameKind.ARGUMENT:
		if exec.call_stack.argument_depth() >= MAX_ARGUMENT_DEPTH:
			return DCResult.fail(
				"Maximum nested-argument depth (%d) exceeded at '%s'." \
						% [MAX_ARGUMENT_DEPTH, node.name]
			)
	else:
		if exec.call_stack.execution_depth() >= MAX_EXECUTION_DEPTH:
			return DCResult.fail(
				"Maximum execution depth (%d) exceeded at '%s'." \
						% [MAX_EXECUTION_DEPTH, node.name]
			)

	var is_root := exec.abort_root == null
	exec.call_stack.push(node.name, kind)
	_publish()

	var resolver := func(raw_arg, ctx: DCContext) -> DCResult:
		return await _resolve_node(raw_arg, exec, ctx)

	var cmd_ctx := DCContext.new(
		node.args,
		resolver,
		null if is_root else exec.abort_root,
		exec.call_stack.breadcrumb(),
	)

	# run_raw inherits the live call stack so nesting stays visible in log ancestry.
	# log_system fires here — this is the only place run_raw is announced.
	var effective_root: DCContext = cmd_ctx if is_root else exec.abort_root
	cmd_ctx._bind_raw_runner(
		func(s: String) -> DCResult:
			_log_system("run_raw: %s" % s, cmd_ctx.breadcrumb)
			var nested := _DCKitNS.Executor.Execution.new(
				s,
				exec.origin,
				effective_root,
				exec.call_stack,
			)
			return await _run_execution(nested),
	)

	if is_root:
		_active_ctx = cmd_ctx

	if profiler != null and profiler.enabled:
		profiler.begin(node.name)

	if definition.deprecated:
		var msg: String
		if definition.name == node.name:
			msg = "[warn]'%s' is deprecated.[warn/]" % definition.name
		else:
			msg = "[warn]Command '%s' (invoked as '%s') is deprecated.[warn/]" % [
				definition.name,
				node.name,
			]
		if not definition.deprecated_message.is_empty():
			msg += " " + definition.deprecated_message
		_log_system(msg, cmd_ctx.breadcrumb)

	var raw_result = await handler.call(cmd_ctx)

	if profiler != null and profiler.enabled:
		profiler.end()

	if is_root:
		_active_ctx = null

	var result := _normalise(raw_result)

	# Don't spam the console with successful utility commands.
	match definition.log_mode:
		DCDefinition.LogMode.NORMAL:
			_log_result(result, cmd_ctx.breadcrumb)
		DCDefinition.LogMode.HIDDEN_ALL:
			pass
		DCDefinition.LogMode.HIDDEN_SUCCESS:
			if not result.success:
				_log_result(result, cmd_ctx.breadcrumb)

	exec.call_stack.pop()
	_publish()
	return result


# NODE RESOLUTION
# root_ctx passed from DCContext.arg() — the command's own context,
# used as abort parent for anything resolved under it.
func _resolve_node(node, exec: _DCKitNS.Executor.Execution, root_ctx: DCContext) -> DCResult:
	if node is _DCKitNS.Analyzer.Parser.StringNode:
		return DCResult.ok(DCResult.Value.literal(node.value))
	if node is _DCKitNS.Analyzer.Parser.VariableNode:
		return await _resolve_variable(node, exec, root_ctx)
	if node is _DCKitNS.Analyzer.Parser.ConstructorNode:
		return await _resolve_ctor(node, exec, root_ctx)
	if node is _DCKitNS.Analyzer.Parser.CommandNode:
		# Nested arg command: runs under the same exec (same stack, same origin).
		# abort_root is temporarily set to the calling command's context.
		var scoped := _DCKitNS.Executor.Execution.new("", exec.origin, root_ctx, exec.call_stack)
		scoped.commands = [node]
		var inner: DCResult = await _execute(
			node,
			scoped,
			_DCKitNS.Executor.CallStack.FrameKind.ARGUMENT,
		)
		if not inner.success:
			return DCResult.fail("Nested '%s' failed: %s" % [node.name, inner.message])
		return DCResult.ok(DCResult.Value.from_command(inner.raw))
	return DCResult.ok(DCResult.Value.literal(""))


# $name        → missing = FAIL
# $?name       → missing = ""
# $?name:node  → missing = resolve fallback node recursively
func _resolve_variable(
	node: _DCKitNS.Analyzer.Parser.VariableNode,
	exec: _DCKitNS.Executor.Execution,
	root_ctx: DCContext,
) -> DCResult:
	var value = _vars.get_value_raw(node.name)
	if value is Callable and not value.is_valid():
		value = null # dead Callable counts as missing
	if value != null:
		return await _resolve_stored(node.name, value, exec, root_ctx)
	if node.is_silent:
		if node.fallback != null:
			return await _resolve_node(node.fallback, exec, root_ctx)
		return DCResult.ok(DCResult.Value.literal(""))
	return DCResult.fail("Variable '$%s' is not defined." % node.name)


# The store hands back what it holds, unresolved:
#   plain value → wrapped as before
#   Callable    → called now; sync or coroutine, await handles both
#   Deferred    → its stored node is resolved in THIS reader's context
func _resolve_stored(
	name: String,
	value,
	exec: _DCKitNS.Executor.Execution,
	root_ctx: DCContext,
) -> DCResult:
	if value is Callable:
		return _wrap_value(await value.call())
	if value is _DCKitNS.Core.VariableStore.Deferred:
		if _resolving.has(name):
			return DCResult.fail("Circular variable '$%s'." % name)
		_resolving.append(name)
		var result: DCResult = await _resolve_node(value.node, exec, root_ctx)
		_resolving.erase(name)
		if not result.success:
			return DCResult.fail("Deferred '$%s': %s" % [name, result.message])
		return result
	return _wrap_value(value)


# String stays a literal (as before); anything else keeps its real type.
func _wrap_value(value) -> DCResult:
	if value == null:
		return DCResult.ok(DCResult.Value.literal(""))
	if value is String:
		return DCResult.ok(DCResult.Value.literal(value))
	return DCResult.ok(DCResult.Value.from_constructor(value))


# Parts resolved eagerly depth-first; first failure short-circuits.
func _resolve_ctor(
	node: _DCKitNS.Analyzer.Parser.ConstructorNode,
	exec: _DCKitNS.Executor.Execution,
	root_ctx: DCContext,
) -> DCResult:
	var parts: Array = []
	for part in node.parts:
		var r: DCResult = await _resolve_node(part, exec, root_ctx)
		if not r.success:
			return DCResult.fail("Constructor '%s': %s" % [node.type_name, r.message])
		parts.append(r.value)
	var ctor_result = _ctor_reg.resolve(node.type_name, parts)
	if ctor_result is DCResult:
		if not ctor_result.success:
			return ctor_result
		return DCResult.ok(DCResult.Value.from_constructor(ctor_result.raw))
	return DCResult.ok(DCResult.Value.from_constructor(ctor_result))


# LOGGER STUBS
# These define the interface the logger must implement.
# See the "Log contract" section in the file header for when each fires.
#
# raw:     the verbatim string the user submitted — log_command only.
# message: human-readable description of a system event — log_system only.
# details: breadcrumb string (CallStack.breadcrumb) — empty at run() entry,
#          populated once frames are pushed. The logger caps it at 100 chars.
func _log_command(raw: String, details: String = "") -> void:
	logger.log_command(raw, details)


func _log_system(message: String, details: String = "") -> void:
	logger.log_system(message, details)


func _log_result(result: DCResult, details: String = "") -> void:
	logger.log_result(result, details)


# HELPERS
func _normalise(raw) -> DCResult:
	if raw is DCResult:
		return raw
	if raw == null:
		return DCResult.ok(null)
	return DCResult.ok(raw)


func _format_errors(diagnostics: Array) -> String:
	var msgs: Array = []
	for d in diagnostics:
		if d.severity == DCAnalysisResult.Diagnostic.Severity.ERROR:
			msgs.append(d.message)
	return "\n".join(msgs) if not msgs.is_empty() else "Analysis failed."


func _slice(raw: String, node: _DCKitNS.Analyzer.Parser.CommandNode) -> String:
	var a := clampi(node.start_pos, 0, raw.length())
	var b := clampi(node.end_pos, a, raw.length())
	return raw.substr(a, b - a)
