class_name _DCKitExecutorNamespace

const Executor := preload("./executor.gd")
const Tracer := preload("./tracer/tracer.gd")


#region inner classes
# STATE
# What a UI can know about the executor. Executor owns the real one;
# get_state() hands out copies. Later levels add fields here.
class ExecutorState:
	var running: bool = false
	var raw: String = ""
	# CHAIN level (1-based step, 0 when not populated)
	var chain_index: int = 0
	var chain_total: int = 0
	# TRACE level, oldest → newest
	var breadcrumb: Array = []


	func duplicate() -> ExecutorState:
		var s := ExecutorState.new()
		s.running = running
		s.raw = raw
		s.chain_index = chain_index
		s.chain_total = chain_total
		s.breadcrumb = breadcrumb.duplicate()
		return s


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
class CallStack:
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
class Execution:
	var raw: String
	var origin: String
	var abort_root: DCContext # null = this is the outermost run
	var commands: Array # Array[_DCKitAnalyzerNamespace.Parser.CommandNode]
	var results: Array # Array[DCResult]
	var call_stack: CallStack
	var chain_index: int = 0 # 1-based, 0 = not started
	var chain_total: int = 0


	func _init(p_raw: String, p_origin: String, p_root: DCContext, p_stack: CallStack) -> void:
		raw = p_raw
		origin = p_origin
		abort_root = p_root
		call_stack = p_stack


	func record(r: DCResult) -> void:
		results.append(r)


	func to_result() -> DCResult:
		return results.back() if not results.is_empty() else DCResult.ok(null)
#endregion


class StateTracker extends RefCounted:
	signal changed

	enum Detail {
		COARSE,
		CHAIN,
		TRACE,
	}

	var detail: Detail = Detail.COARSE:
		set(value):
			if detail == value:
				return
			detail = value
			publish() # raise = catch up from live data, lower = clear

	var _state := _DCKitExecutorNamespace.ExecutorState.new()
	var _root: _DCKitExecutorNamespace.Execution = null


	func is_running() -> bool:
		return _state.running


	func snapshot() -> _DCKitExecutorNamespace.ExecutorState:
		return _state.duplicate()


	func begin(exec: _DCKitExecutorNamespace.Execution, raw: String) -> void:
		_root = exec
		_apply(true, raw)


	func end() -> void:
		_root = null
		_apply(false, "")


	# Zero-argument nudge: re-read from the attached execution.
	func publish() -> void:
		if _sync():
			changed.emit()


	func _apply(running: bool, raw: String) -> void:
		var dirty := _state.running != running or _state.raw != raw
		_state.running = running
		_state.raw = raw
		dirty = _sync() or dirty
		if dirty:
			changed.emit()


	# Rebuilds gated fields from live sources. Returns true if anything changed.
	func _sync() -> bool:
		var idx := 0
		var total := 0
		var crumb: Array = []
		if _root != null:
			if detail >= Detail.CHAIN:
				idx = _root.chain_index
				total = _root.chain_total
			if detail >= Detail.TRACE:
				crumb = _root.call_stack.snapshot()
		if idx == _state.chain_index and total == _state.chain_total and crumb == _state.breadcrumb:
			return false
		_state.chain_index = idx
		_state.chain_total = total
		_state.breadcrumb = crumb
		return true
