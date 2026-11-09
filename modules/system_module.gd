class_name SystemModule
extends DCModule

const DEFAULT_TREE_DEPTH := 3
const MAX_TREE_DEPTH := 32
const MAX_TREE_LINES := 500


func get_id() -> String:
	return "dckit_system"


func get_commands() -> Array[DCDefinition]:
	return [_sys_info_cmd(), _perf_cmd(), _tree_cmd(), _orphans_cmd()]


#region SYSTEM INFO
func _sys_info_cmd() -> DCDefinition:
	return DCDefinition.new(
		"sys.info",
		func(_ctx: DCContext) -> DCResult:
			var version := Engine.get_version_info()
			var debug := OS.is_debug_build()

			var renderer := str(
				ProjectSettings.get_setting("rendering/renderer/rendering_method", "Unknown")
			)

			var output := PackedStringArray(
				[
					"[b]Godot[/b]: %s.%s.%s (%s)"
					% [
						version.get("major", 0),
						version.get("minor", 0),
						version.get("patch", 0),
						version.get("status", "Unknown"),
					],
					"[b]OS[/b]: %s" % OS.get_name(),
					"[b]Build[/b]: %s" % ("Debug" if debug else "Release"),
					"[b]Renderer[/b]: %s" % renderer,
					"[b]GPU[/b]: %s" % RenderingServer.get_video_adapter_name(),
				]
			)

			return DCResult.ok(null, "\n".join(output)),
		"Displays Godot engine, operating system, build and renderer information.",
		[],
		true,
	)
#endregion


#region PERFORMANCE
func _perf_cmd() -> DCDefinition:
	return DCDefinition.new(
		"perf",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() > 1:
				return DCResult.fail("perf accepts at most one monitor name.")

			if ctx.args_length() == 1:
				var result := await ctx.arg(0)
				if not result.success:
					return result

				return _get_perf_monitor(result.text())

			var output := PackedStringArray()

			output.append("[b]Performance[/b]")
			output.append("FPS: %s" % Performance.get_monitor(Performance.TIME_FPS))
			output.append(
				"Memory: %s" % _format_bytes(Performance.get_monitor(Performance.MEMORY_STATIC))
			)
			output.append("Objects: %s" % Performance.get_monitor(Performance.OBJECT_COUNT))
			output.append(
				"Resources: %s" % Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
			)
			output.append("Nodes: %s" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			output.append(
				"Draw calls: %s"
				% Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			)

			return DCResult.ok(null, "\n".join(output)),
		"Displays performance monitor values. Optionally specify one monitor.",
		[DCDefinition.Param.new("monitor").describe(
				"Optional: fps, memory, objects, resources, nodes, draw_calls."
			)],
		true,
	)


func _get_perf_monitor(monitor: String) -> DCResult:
	var value: float

	match monitor.to_lower():
		"fps":
			value = Performance.get_monitor(Performance.TIME_FPS)

		"memory":
			value = Performance.get_monitor(Performance.MEMORY_STATIC)
			return DCResult.ok(_format_bytes(value))

		"objects":
			value = Performance.get_monitor(Performance.OBJECT_COUNT)

		"resources":
			value = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)

		"nodes":
			value = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

		"draw_calls":
			value = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

		_:
			return DCResult.fail(
				"Unknown monitor '%s'. Available: fps, memory, objects, resources, nodes, draw_calls."
				% monitor
			)

	return DCResult.ok(str(value))


func _format_bytes(bytes: float) -> String:
	if bytes >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (bytes / 1024.0 / 1024.0 / 1024.0)

	if bytes >= 1024.0 * 1024.0:
		return "%.2f MB" % (bytes / 1024.0 / 1024.0)

	if bytes >= 1024.0:
		return "%.2f KB" % (bytes / 1024.0)

	return "%d B" % int(bytes)
#endregion


#region SCENE TREE
func _tree_cmd() -> DCDefinition:
	return DCDefinition.new(
		"tree",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() > 2:
				return DCResult.fail("tree accepts at most two arguments: [path] [depth].")

			var tree := Engine.get_main_loop() as SceneTree
			if tree == null:
				return DCResult.fail("SceneTree is unavailable.")

			var scene_root := tree.root
			var target: Node = tree.current_scene

			if target == null:
				return DCResult.fail("No active main scene.")
			var depth := DEFAULT_TREE_DEPTH

			if ctx.args_length() >= 1:
				var path_result := await ctx.arg(0)
				if not path_result.success:
					return path_result

				var path := path_result.text()

				if not path.is_empty() and path != ".":
					target = target.get_node_or_null(NodePath(path))

					if target == null:
						return DCResult.fail("Node not found: '%s'." % path)

			if ctx.args_length() == 2:
				var depth_result := await ctx.arg(1)
				if not depth_result.success:
					return depth_result

				var depth_input := depth_result.value

				if typeof(depth_input) in [TYPE_INT, TYPE_FLOAT]:
					return DCResult.fail("Tree depth must be an integer.")

				depth = int(depth_input)

			if depth < 0 or depth > MAX_TREE_DEPTH:
				return DCResult.fail("Tree depth must be between 0 and %d." % MAX_TREE_DEPTH)

			var lines := PackedStringArray()
			_dump_tree(target, 0, depth, lines)

			if lines.size() >= MAX_TREE_LINES:
				lines.append("... Output truncated.")

			return DCResult.ok(null, "\n".join(lines)),
		"Dumps the scene tree. Optionally specify a node path and maximum depth.",
		[DCDefinition.Param.new("path").describe(
				"Optional node path. Relative to the current main scene by default. "
				+ "Use '/' to access the SceneTree root, or '.' to reference the current main scene."
			), DCDefinition.Param.new("depth").describe(
				"Optional maximum child depth. Defaults to %d." % DEFAULT_TREE_DEPTH
			)],
		true,
	)


func _dump_tree(node: Node, current_depth: int, max_depth: int, lines: PackedStringArray) -> void:
	if lines.size() >= MAX_TREE_LINES:
		return

	var indent := "  ".repeat(current_depth)

	lines.append("%s%s [%s]" % [indent, node.name, node.get_class()])

	if current_depth >= max_depth:
		return

	for child in node.get_children():
		if lines.size() >= MAX_TREE_LINES:
			return

		_dump_tree(child, current_depth + 1, max_depth, lines)
#endregion


#region ORPHANS
func _orphans_cmd() -> DCDefinition:
	return DCDefinition.new(
		"orphans",
		func(_ctx: DCContext) -> DCResult:
			var orphan_ids := Node.get_orphan_node_ids()

			if orphan_ids.is_empty():
				return DCResult.ok(0, "No orphan nodes found.")

			var output := PackedStringArray()
			var found_ids := PackedInt64Array()

			output.append("[b]Orphan Nodes: %d[/b]" % orphan_ids.size())

			for instance_id in orphan_ids:
				var object := instance_from_id(instance_id)

				if object == null or not object is Node:
					continue

				var node := object as Node
				found_ids.append(instance_id)

				output.append("- %s [%s] (ID: %d)" % [node.name, node.get_class(), instance_id])

			return DCResult.ok(found_ids, "\n".join(output)),
		"Lists nodes that are not inside the active scene tree.",
		[],
		true,
	)
#endregion
