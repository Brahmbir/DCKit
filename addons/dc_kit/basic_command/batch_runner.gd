# batch_runner.gd
# Reads a bat.txt file line by line and feeds each line to the Executor
# via ctx.run_raw(), so script lines share the calling command's call
# stack (log ancestry "bat > <cmd>") and abort scope.
# Accessed via preload; no class_name.
#
# Built-in commands
#
#   bat <path>  — execute a script file
#
# Rules
#
#   • Nested bat is fully supported — each call pushes a new ScriptFrame.
#   • Lines beginning with '#' are comments — skipped entirely.
#   • Empty lines are skipped.
#   • Abort is handled via the DCContext passed to the handler.
#     When ctx.is_aborted(), the loop stops after the current line completes.
#
# Constructor:
#   DevConsoleBatchRunner.new()
extends RefCounted

var bat_cmd := DCDefinition.new(
	"bat",
	func(ctx: DCContext) -> DCResult:
		if ctx.args_length() < 1:
			return DCResult.fail("bat requires a file path.")
		var r0 := await ctx.arg(0)
		if not r0.success:
			return r0
		return await run(r0.value.as_string(), ctx),
	"Executes a [b]bat.txt[/b] script file line by line.\n\n"
	+ "Lines beginning with [code]#[/code] are comments. "
	+ "Nested [b]bat[/b] calls are fully supported.",
	[
		DCDefinition
		.Param
		.new("path")
		.describe("Path to the script file. Relative paths resolve from the configured root folder.")
		.suggest(
			func() -> Array[String]:
				var out: Array[String] = []

				for alias in _predefined_files:
					out.append(alias)
				_collect_scripts(_root_folder, "", out)

				out.sort()
				return out,
		)
	],
	true,
)
var _root_folder: String = "res://batch_file/"

var _predefined_files: Dictionary[String, String] = {
	#"init": "res://batch_file/init.txt",
	#"dev": "res://batch_file/dev_tools.txt"
}


func _init() -> void:
	_read_project_settings()


# COMMAND REGISTRATION
func get_command_def_array() -> Array[DCDefinition]:
	return [bat_cmd]


# PUBLIC
func register_file_alias(name: String, file_path: String) -> void:
	_predefined_files[name] = file_path


# Runs a script file.
# exec_ctx — the ExecutionContext for script-frame nesting / recursion depth.
# ctx      — the DCContext from the calling handler. Lines are dispatched via
#            ctx.run_raw(), so they share this command's call stack (log
#            ancestry) and abort scope (ctx.is_aborted()).
func run(path: String, ctx: DCContext) -> DCResult:
	path = _resolve_script_path(path)

	if not FileAccess.file_exists(path):
		return DCResult.fail("bat: file not found '%s'." % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return DCResult.fail("bat: could not open '%s'." % path)

	var lines: Array[ScriptLine] = []
	var actual_line := 0

	while not file.eof_reached():
		actual_line += 1
		var raw_line := file.get_line()
		var cmd_line := _strip_comments(raw_line)
		if not cmd_line.is_empty():
			lines.append(ScriptLine.new(actual_line, cmd_line))

	file.close()

	var last_result := DCResult.ok("")

	for entry: ScriptLine in lines:
		if ctx.is_aborted():
			return DCResult.fail("Script '%s' aborted at line %d." % [path, entry.line_number])

		# run_raw shares this command's call stack and abort scope, so nested
		# commands show up as "bat > <cmd>" in the log and respect ctx.abort().
		var results: Array = await ctx.run_raw(entry.command)
		last_result = results.back() if not results.is_empty() else DCResult.ok(null)

		if not last_result.success:
			return DCResult.fail(
				"Script '%s' failed at line %d: %s" % [path, entry.line_number, last_result.message]
			)

	return (
		DCResult.ok("Script '%s' completed successfully." % path)
		if last_result.success
		else last_result
	)


func _read_project_settings() -> void:
	var path: String = _DCKitNamespace.Setting.get_setting(
		_DCKitNamespace.Setting.SETTING_BATCH_DIR,
		_root_folder,
	)

	_root_folder = _resolve_batch_root(path)


func _resolve_batch_root(path: String) -> String:
	if OS.has_feature("editor"):
		if path.begins_with("res://") or path.begins_with("user://"):
			return ProjectSettings.globalize_path(path)
		return path

	var exe_dir := OS.get_executable_path().get_base_dir()

	# res:// → strip prefix, resolve relative to exe dir
	if path.begins_with("res://"):
		return exe_dir.path_join(path.trim_prefix("res://"))

	# user:// → strip user data root, resolve relative to exe dir
	if path.begins_with("user://"):
		var user_root := ProjectSettings.globalize_path("user://")
		var abs := ProjectSettings.globalize_path(path)
		if abs.begins_with(user_root):
			return exe_dir.path_join(abs.trim_prefix(user_root))
		return abs

	# Absolute path → use as-is; never feed an absolute path into path_join
	if path.is_absolute_path():
		return path

	# Relative path → resolve relative to exe dir
	return exe_dir.path_join(path)


# INTERNAL
func _resolve_script_path(path: String) -> String:
	if _predefined_files.has(path):
		path = _predefined_files[path]

	# res:// and user:// → normalize to a native OS path,
	# same logic as _resolve_batch_root (editor: globalize, exported: exe-relative).
	if path.begins_with("res://") or path.begins_with("user://"):
		var ext := path.get_extension()
		if ext.is_empty() or ext.to_lower() in ["i", "ignore"]:
			path += ".txt"
		return _resolve_batch_root(path)

	# Native absolute path → use as-is.
	if path.is_absolute_path():
		return path

	# Relative path → add .txt if bare name, then anchor to the root folder.
	var ext := path.get_extension()
	if ext.is_empty() or ext.to_lower() in ["i", "ignore"]:
		path += ".txt"
	return _root_folder.path_join(path)


func _collect_scripts(folder: String, relative: String, out: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		# Extension check catches: folder.ignore, folder.i, script.i, script.ignore
		var ext := name.get_extension().to_lower()
		if ext == "i" or ext == "ignore":
			continue

		# Basename check catches double-extension files: script.ignore.txt, script.i.txt
		var base := name.get_basename().to_lower()
		if base.ends_with(".i") or base.ends_with(".ignore"):
			continue

		var rel := name if relative.is_empty() else relative.path_join(name)
		var full := folder.path_join(name)

		if dir.current_is_dir():
			_collect_scripts(full, rel, out)
		elif ext == "txt":
			out.append("'%s'" % rel.get_basename())

	dir.list_dir_end()


func _strip_comments(line: String) -> String:
	var idx := line.find("#")
	return line.strip_edges() if idx == -1 else line.substr(0, idx).strip_edges()


class ScriptLine:
	var line_number: int
	var command: String


	func _init(p_line: int, p_cmd: String) -> void:
		line_number = p_line
		command = p_cmd
