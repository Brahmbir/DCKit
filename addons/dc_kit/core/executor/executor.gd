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
#   execution tree. run_raw() inherits the caller's stack so the logger
#   always sees the full ancestry: "player.warp > var.get > ..."
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
#                  string. Stack is always empty at this point.
#   log_system   — fires only for chain steps (one per command in a multi-
#                  command chain) and for every ctx.run_raw() call. Carries
#                  a human-readable message. Nowhere else.
#   log_result   — fires in _execute() after the handler returns (one per
#                  command frame). Also fires for early failures in run()
#                  and for analysis failures in _run_execution().
extends RefCounted

signal command_executed(raw: String, result: DCResult)
signal command_aborted

# Call-stack safety limits — tune per project. These bound recursion depth,
# not total work (see header).
const MAX_EXECUTION_DEPTH: int = 8
const Profiler := preload("./profiler.gd")

const _ORIGIN_USER := "user"

var logger: _DCKitNamespace.Tracer = null
var profiler: Profiler = null
var _cmd_reg
var _vars
var _ctor_reg
var _analyzer

var _active_ctx: DCContext = null
var _running: bool = false


func _init(cmd_reg, ctor_reg, vars_store, analyzer) -> void:
	_cmd_reg = cmd_reg
	_vars = vars_store
	_ctor_reg = ctor_reg
	_analyzer = analyzer

	profiler = Profiler.new()

	logger = _DCKitNamespace.Tracer.new()
	logger.open_session()


func get_command_def_array() -> Array[DCDefinition]:
	var def_arr: Array[DCDefinition] = []

	def_arr.append(
		DCDefinition
		.new(
			"clear",
			func(_ctx: DCContext) -> DCResult:
				logger.clear()
				return DCResult.ok("cleared"),
			"Clears all console log entries.",
			[],
		)
		.as_utility()
	)

	def_arr.append(
		DCDefinition.new(
			"profile",
			func(ctx: DCContext) -> DCResult:
				if ctx.args_length() != 1:
					return DCResult.fail("profile requires one argument (nested command).")
				if profiler == null:
					return DCResult.fail("Profiler is unavailable.")
				profiler.reset()
				profiler.enabled = true
				var result: DCResult = await ctx.arg(0)
				profiler.enabled = false
				var report := profiler.report()
				if not result.success:
					return DCResult.fail("%s\n\n%s" % [result.message, report])
				var output := report
				if not result.value.as_string().is_empty():
					output = "%s\n\n%s" % [result.value.as_string(), report]
				return DCResult.ok(output),
			"Profiles a nested command and all commands executed beneath it.",
			[DCDefinition.Param.new("command").describe("Command to profile.")],
			true,
		)
	)

	return def_arr


# PUBLIC
func run(raw: String) -> DCResult:
	# Always log what the user typed first — even if we reject it below.
	_log_command(raw, _ORIGIN_USER, [])

	if _running:
		var f := DCResult.fail("A command is already running.")
		_log_result(f, _ORIGIN_USER, [])
		return f

	_running = true
	var exec := _Execution.new(raw, _ORIGIN_USER, null, _CallStack.new())
	var result: DCResult = await _run_execution(exec)
	_running = false
	command_executed.emit(raw, result)
	return result


func abort() -> void:
	if _active_ctx != null:
		_active_ctx.abort()
		command_aborted.emit()


func reset() -> void:
	_active_ctx = null
	_running = false


# PIPELINE
# Shared by run() and ctx.run_raw(). Does NOT touch _running.
func _run_execution(exec: _Execution) -> DCResult:
	var analysis: _DCKitNamespace.Analyzer.DCAnalysisResult = _analyzer.analyze(exec.raw)
	if not analysis.ok():
		var f := DCResult.fail(_format_errors(analysis.diagnostics))
		_log_result(f, exec.origin, exec.call_stack.snapshot())
		return f

	exec.commands = analysis.ast
	if exec.commands.is_empty():
		return DCResult.ok(null)

	# Announce each step only when there are multiple commands in the chain.
	# Single-command runs (including run_raw) are announced by their caller.
	var is_chain := exec.commands.size() > 1
	var total := exec.commands.size()

	for i in total:
		var cmd: _DCKitNamespace.Parser.CommandNode = exec.commands[i]

		if is_chain:
			var segment := _slice(exec.raw, cmd) if not exec.raw.is_empty() else cmd.name
			_log_system(
				"Chain [%d/%d]: %s" % [i + 1, total, segment],
				exec.origin,
				exec.call_stack.snapshot(),
			)

		var r: DCResult = await _execute(cmd, exec, _CallStack.FrameKind.EXECUTION)
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
func _execute(node: _DCKitNamespace.Parser.CommandNode, exec: _Execution, kind: int) -> DCResult:
	var definition: DCDefinition = _cmd_reg.get_definition(node.name)
	if definition == null:
		return DCResult.fail("Unknown command '%s'." % node.name)

	var handler: Callable = definition.handler if definition else Callable()

	if not handler.is_valid():
		return DCResult.fail("Unknown command '%s'." % node.name)

	var max_arg_depth := 8
	if _analyzer != null:
		max_arg_depth = _analyzer.MAX_ARGUMENT_DEPTH

	if kind == _CallStack.FrameKind.ARGUMENT:
		if exec.call_stack.argument_depth() >= max_arg_depth:
			return DCResult.fail(
				"Maximum nested-argument depth (%d) exceeded at '%s'." \
						% [max_arg_depth, node.name]
			)
	else:
		if exec.call_stack.execution_depth() >= MAX_EXECUTION_DEPTH:
			return DCResult.fail(
				"Maximum execution depth (%d) exceeded at '%s'." \
						% [MAX_EXECUTION_DEPTH, node.name]
			)

	var is_root := exec.abort_root == null
	exec.call_stack.push(node.name, kind)

	var resolver := func(raw_arg, ctx: DCContext) -> DCResult:
		return await _resolve_node(raw_arg, exec, ctx)

	var cmd_ctx := DCContext.new(
		node.args,
		_create_logger(exec.origin, exec.call_stack.snapshot()),
		resolver,
		null if is_root else exec.abort_root,
	)

	# run_raw inherits the live call stack so nesting stays visible in log ancestry.
	# log_system fires here — this is the only place run_raw is announced.
	var effective_root: DCContext = cmd_ctx if is_root else exec.abort_root
	cmd_ctx._bind_raw_runner(
		func(s: String) -> DCResult:
			_log_system("run_raw: %s" % s, exec.origin, exec.call_stack.snapshot())
			var nested := _Execution.new(s, exec.origin, effective_root, exec.call_stack)
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
		_log_system(msg, exec.origin, exec.call_stack.snapshot())

	var raw_result = await handler.call(cmd_ctx)

	if profiler != null and profiler.enabled:
		profiler.end()

	if is_root:
		_active_ctx = null

	var result := _normalise(raw_result)

	# Don't spam the console with successful utility commands.
	match definition.log_mode:
		DCDefinition.LogMode.NORMAL:
			_log_result(result, exec.origin, exec.call_stack.snapshot())
		DCDefinition.LogMode.HIDDEN_ALL:
			pass
		DCDefinition.LogMode.HIDDEN_SUCCESS:
			if not result.success:
				_log_result(result, exec.origin, exec.call_stack.snapshot())

	exec.call_stack.pop()
	return result


# NODE RESOLUTION
# root_ctx passed from DCContext.arg() — the command's own context,
# used as abort parent for anything resolved under it.
func _resolve_node(node, exec: _Execution, root_ctx: DCContext) -> DCResult:
	if node is _DCKitNamespace.Parser.StringNode:
		return DCResult.ok(DCResult.Value.literal(node.value))
	if node is _DCKitNamespace.Parser.VariableNode:
		return await _resolve_variable(node, exec, root_ctx)
	if node is _DCKitNamespace.Parser.ConstructorNode:
		return await _resolve_ctor(node, exec, root_ctx)
	if node is _DCKitNamespace.Parser.CommandNode:
		# Nested arg command: runs under the same exec (same stack, same origin).
		# abort_root is temporarily set to the calling command's context.
		var scoped := _Execution.new("", exec.origin, root_ctx, exec.call_stack)
		scoped.commands = [node]
		var inner: DCResult = await _execute(node, scoped, _CallStack.FrameKind.ARGUMENT)
		if not inner.success:
			return DCResult.fail("Nested '%s' failed: %s" % [node.name, inner.message])
		return DCResult.ok(DCResult.Value.from_command(inner.raw))
	return DCResult.ok(DCResult.Value.literal(""))


# $name        → missing = FAIL
# $?name       → missing = ""
# $?name:node  → missing = resolve fallback node recursively
func _resolve_variable(
	node: _DCKitNamespace.Parser.VariableNode,
	exec: _Execution,
	root_ctx: DCContext,
) -> DCResult:
	var value = _vars.get_value_raw(node.name)
	if value != null:
		if value is String:
			return DCResult.ok(DCResult.Value.literal(value))
		return DCResult.ok(DCResult.Value.from_constructor(value))
	if node.is_silent:
		if node.fallback != null:
			return await _resolve_node(node.fallback, exec, root_ctx)
		return DCResult.ok(DCResult.Value.literal(""))
	return DCResult.fail("Variable '$%s' is not defined." % node.name)


# Parts resolved eagerly depth-first; first failure short-circuits.
func _resolve_ctor(
	node: _DCKitNamespace.Parser.ConstructorNode,
	exec: _Execution,
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
# These define the interface the new logger must implement.
# See the "Log contract" section in the file header for when each fires.
#
# raw:     the verbatim string the user submitted — log_command only.
# message: human-readable description of a system event — log_system only.
# stack:   Array[String] — ancestry from root to current command, oldest first.
#          Empty ([]) at run() entry; populated once frames are pushed.
func _log_command(raw: String, origin: String, stack: Array) -> void:
	logger.log_command(raw, stack, origin)


func _log_system(message: String, origin: String, stack: Array) -> void:
	logger.log_system(message, stack, origin)


func _log_result(result: DCResult, origin: String, stack: Array) -> void:
	logger.log_result(result, stack, origin)


func _create_logger(origin: String, stack: Array) -> DCLogger:
	return logger.create_command_logger(stack, origin)


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
		if d.severity == _DCKitNamespace.Analyzer.DCDiagnostic.Severity.ERROR:
			msgs.append(d.message)
	return "\n".join(msgs) if not msgs.is_empty() else "Analysis failed."


func _slice(raw: String, node: _DCKitNamespace.Parser.CommandNode) -> String:
	var a := clampi(node.start_pos, 0, raw.length())
	var b := clampi(node.end_pos, a, raw.length())
	return raw.substr(a, b - a)


#region inner classes
# CALL STACK
# Tracks the live command call hierarchy for one execution tree, plus two
# independent depth counters used for the safety caps in _execute().
# Shared (not copied) across nested run_raw calls so ancestry is always
# visible and depth accumulates correctly across the whole tree.
#
#   root run()          frames: []                exec=0 arg=0
#   → player.warp       frames: [player.warp]     exec=1 arg=0
#     → (var.get speed) frames: [player.warp,     exec=1 arg=1
#                                 var.get]
#     ← var.get done    frames: [player.warp]     exec=1 arg=0
#     → run_raw(...)    frames: [player.warp,     exec=2 arg=0
#                                 other.cmd]
#     ← done            frames: [player.warp]     exec=1 arg=0
#   ← player.warp done  frames: []                exec=0 arg=0
class _CallStack:
	enum FrameKind {
		EXECUTION,
		ARGUMENT,
	}

	# Array[Dictionary] — {name: String, kind: FrameKind}, oldest → newest.
	var frames: Array = []

	var _execution_depth: int = 0
	var _argument_depth: int = 0


	func push(cmd: String, kind: int) -> void:
		frames.append({ "name": cmd, "kind": kind })
		if kind == FrameKind.EXECUTION:
			_execution_depth += 1
		else:
			_argument_depth += 1


	func pop() -> void:
		if frames.is_empty():
			return
		var frame: Dictionary = frames.pop_back()
		if frame.kind == FrameKind.EXECUTION:
			_execution_depth -= 1
		else:
			_argument_depth -= 1


	func depth() -> int:
		return frames.size()


	func execution_depth() -> int:
		return _execution_depth


	func argument_depth() -> int:
		return _argument_depth


	func top() -> String:
		return frames.back().name if not frames.is_empty() else ""


	func breadcrumb() -> String:
		return " > ".join(snapshot())


	# Immutable list of command names, oldest → newest — safe to store in a log entry.
	func snapshot() -> Array:
		var names: Array = []
		for f in frames:
			names.append(f.name)
		return names


# EXECUTION
# One pipeline run: parsed chain + accumulated results + shared call stack.
# Created by run() (fresh stack) and by ctx.run_raw() (inherited stack).
class _Execution:
	var raw: String
	var origin: String
	var abort_root: DCContext # null = this is the outermost run
	var commands: Array # Array[_DCKitNamespace.Parser.CommandNode]
	var results: Array # Array[DCResult]
	var call_stack: _CallStack


	func _init(p_raw: String, p_origin: String, p_root: DCContext, p_stack: _CallStack) -> void:
		raw = p_raw
		origin = p_origin
		abort_root = p_root
		call_stack = p_stack


	func record(r: DCResult) -> void:
		results.append(r)


	func to_result() -> DCResult:
		return results.back() if not results.is_empty() else DCResult.ok(null)
#endregion
