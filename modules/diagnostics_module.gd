## Core module: clear, profile, profile_last, help, list_cmd.
## Needs services, so it declares them and keeps what setup() gives it.
extends DCModule

var _logger: _DCKitNS.Core.Tracer = null
var _profiler: _DCKitNS.Executor.Profiler = null
var _registry: _DCKitNS.Registries.CommandRegistry = null


func get_id() -> String:
	return "dckit_diagnostics"


func get_needs() -> int:
	return Need.LOGGER | Need.PROFILER | Need.REGISTRY


func setup(services: Services) -> void:
	_logger = services.logger as _DCKitNS.Core.Tracer
	_profiler = services.profiler as _DCKitNS.Executor.Profiler
	_registry = services.registry as _DCKitNS.Registries.CommandRegistry


func get_commands() -> Array[DCDefinition]:
	return [_clear(), _profile(), _help(), _list_cmd()]


func _clear() -> DCDefinition:
	return DCDefinition \
			.new(
		"clear",
		func(_ctx: DCContext) -> DCResult:
			_logger.clear()
			return DCResult.ok("cleared"),
		"Clears all console log entries.",
	) \
			.as_utility()


#region Profile
func _profile() -> DCDefinition:
	return DCDefinition.new(
		"profile",
		func(ctx: DCContext) -> DCResult:
			var count := ctx.args_length()
			if count == 0:
				return DCResult.fail("profile requires at least one nested command.")

			_profiler.reset()
			_profiler.enabled = true
			# The profiler keeps a single root, so several commands are wrapped
			# in one synthetic node. A single command is profiled as before.
			if count > 1:
				_profiler.begin("profile (%d commands)" % count)

			var outputs: PackedStringArray = []
			var failure := ""
			for i in count:
				var result: DCResult = await ctx.arg(i)
				if not result.success:
					failure = result.message
					break # stop at the first failure, keep the partial report
				var text := result.value.as_string()
				if not text.is_empty():
					outputs.append(text)

			if count > 1:
				_profiler.end()
			_profiler.enabled = false

			var _report = _profiler.report()
			if not failure.is_empty():
				return DCResult.fail("%s\n%s" % [failure, _report])
			if outputs.is_empty():
				return DCResult.ok(_report)
			return DCResult.ok("< %s >\n%s" % ["; ".join(outputs), _report]),
		"Profiles one or more nested commands, run in order, as a single report.",
		[DCDefinition.Param.new("command").describe("Command(s) to profile.").rest()],
		true,
	)
#endregion


#region Help
func _help() -> DCDefinition:
	return DCDefinition.new(
		"help",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() == 0:
				return DCResult.ok(
					"Use 'list_cmd [query]' to browse commands and 'help <command>' for details."
				)
			var arg := await ctx.arg(0)
			if not arg.success:
				return arg
			var name := arg.value.as_string()
			var def := _registry.get_definition(name)
			if def == null:
				return DCResult.fail("Unknown command '%s'. Try 'list_cmd %s'." % [name, name])
			return DCResult.ok(_format_help(def)),
		"Shows usage, parameters and description of a command.",
		[DCDefinition.Param.new("command").describe("Command name or alias.").suggest(
				_command_names
			)],
	)


func _list_cmd() -> DCDefinition:
	return DCDefinition.new(
		"list_cmd",
		func(ctx: DCContext) -> DCResult:
			var query := ""
			if ctx.args_length() > 0:
				var arg := await ctx.arg(0)
				if not arg.success:
					return arg
				query = arg.value.as_string()

			var defs := _registry.get_matching(query)
			if defs.is_empty():
				return DCResult.fail("No commands match '%s'." % query)

			var lines: PackedStringArray = ["%d command(s)" % defs.size(), ""]
			for def: DCDefinition in defs:
				var summary := def.description.get_slice("\n", 0)
				if summary.is_empty():
					lines.append(def.name)
				else:
					lines.append("%s — %s" % [def.name, summary])
			return DCResult.ok("\n".join(lines)),
		"Lists registered commands. An optional query filters by name.",
		[DCDefinition.Param.new("query").describe("Optional name or prefix, e.g. 'var'.")],
	)


func _command_names() -> Array[String]:
	var out: Array[String] = []
	for def: DCDefinition in _registry.get_all():
		out.append(def.name)
	return out


func _format_help(def: DCDefinition) -> String:
	var usage := def.name
	for p in def.params:
		usage += " <%s%s>" % [p.name, "..." if p.is_rest else ""]

	var lines: PackedStringArray = [usage]
	if not def.aliases.is_empty():
		lines.append("Aliases: %s" % ", ".join(def.aliases))
	if def.deprecated:
		lines.append("Deprecated. %s" % def.deprecated_message)
	if not def.description.is_empty():
		lines.append("")
		lines.append(def.description)
	if not def.params.is_empty():
		lines.append("")
		lines.append("Parameters:")
		for p in def.params:
			var line := "  %s" % p.name
			if not p.description.is_empty():
				line += " — %s" % p.description
			lines.append(line)
	return "\n".join(lines)
#endregion
