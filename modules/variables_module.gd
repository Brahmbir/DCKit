## Core module: the var.* commands, moved out of variable_store.gd.
## The store stays a core service; only the commands live here.
##
## Depends on two DCContext additions that are not written yet:
##   ctx.arg_node(n)      — the unresolved argument (for var.setd)
##   await ctx.resolve_var(name) — same resolver as $name (for var.get)
extends DCModule

var _vars: _DCKitNS.Core.VariableStore = null


func get_id() -> String:
	return "dckit_variables"


func get_needs() -> int:
	return Need.VARIABLES


func setup(services: Services) -> void:
	_vars = services.variables as _DCKitNS.Core.VariableStore


func get_commands() -> Array[DCDefinition]:
	return [
		_set_var(),
		_setd_var(),
		_get_var(),
		_exists_var(),
		_list_var(),
		_delete_var(),
		_try_delete_var(),
	]


func _set_var() -> DCDefinition:
	return DCDefinition.new(
		"var.set",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail("var.set requires two arguments: <name> <value>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0
			var r1 := await ctx.arg(1)
			if not r1.success:
				return r1

			var key: String = r0.value.as_string()
			var r := _vars.set_value(key, r1.raw) # r1.raw is the real Vector2/Color/etc.
			if not r.ok:
				return DCResult.fail(r.message)
			return DCResult.ok(str(r1.raw)), # display string for the console log
		"Writes a variable into the store. The value is resolved first and keeps its type. "
		+ "Replaces any existing variable, including deferred ones.",
		[DCDefinition.Param.new("name").describe(
				"Variable name. Must start with a letter or underscore."
			), DCDefinition.Param.new("value").describe("Value to store. Resolved once, now.")],
	)


func _setd_var() -> DCDefinition:
	return DCDefinition.new(
		"var.setd",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() != 2:
				return DCResult.fail("var.setd requires two arguments: <name> <expression>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0

			var key: String = r0.value.as_string()
			# Arg 1 is deliberately NOT resolved: it is stored as-is and
			# run again every time the variable is read.
			var r := _vars.set_deferred_var(key, ctx.arg_node(1))
			if not r.ok:
				return DCResult.fail(r.message)
			return DCResult.ok("'%s' set as deferred." % key),
		"Stores an expression [b]unresolved[/b]. It runs again every time the variable is read.",
		[DCDefinition.Param.new("name").describe(
				"Variable name. Must start with a letter or underscore."
			), DCDefinition.Param.new("expression").describe(
				"Command or value kept unresolved. Runs on every read."
			)],
	)


func _get_var() -> DCDefinition:
	return DCDefinition.new(
		"var.get",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail("var.get requires two arguments: <name> <default>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0
			var r1 := await ctx.arg(1)
			if not r1.success:
				return r1

			var key: String = r0.value.as_string()
			if not _vars.is_valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			if not _vars.has(key):
				return r1 # the default, with its own type
			# Same resolver as $name: live values run, a failing live
			# expression is reported instead of hidden behind the default.
			return DCResult.ok(await _vars.get_value(key)),
		"Reads a variable like [code]$name[/code] does: live values are run and the current "
		+ "value is returned. Returns the default when the variable does not exist.",
		[DCDefinition.Param.new("name").suggest(_vars.get_keys), DCDefinition
			.Param
			.new("default")
			.describe("Returned as-is when the variable does not exist.")],
	)


func _exists_var() -> DCDefinition:
	return DCDefinition.new(
		"var.exists",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail("var.exists requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0
			var key: String = r0.value.as_string()
			if not _vars.is_valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			return DCResult.ok("true" if _vars.has(key) else "false"),
		"Returns [b]true[/b] if the variable exists, [b]false[/b] otherwise.",
		[DCDefinition.Param.new("name").suggest(_vars.get_keys)],
	)


func _list_var() -> DCDefinition:
	return DCDefinition.new(
		"var.list",
		func(ctx: DCContext) -> DCResult:
			var keys: Array = _vars.get_keys()
			if ctx.args_length() >= 1:
				var r0 := await ctx.arg(0)
				if not r0.success:
					return r0
				var prefix: String = r0.value.as_string()
				keys = keys.filter(
					func(k: String) -> bool:
						return k.begins_with(prefix),
				)
			if keys.is_empty():
				return DCResult.ok("empty")
			return DCResult.ok(", ".join(keys)),
		"Lists all variable names, static and deferred, comma-separated. Optionally filters by prefix.",
		[DCDefinition.Param.new("prefix").describe(
				"Optional. Only names starting with this are returned."
			)],
	)


func _delete_var() -> DCDefinition:
	return DCDefinition.new(
		"var.delete",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail("var.delete requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0
			var key: String = r0.value.as_string()
			if not _vars.is_valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			if not _vars.delete(key):
				return DCResult.fail("Variable '%s' does not exist." % key)
			return DCResult.ok(),
		"Deletes a variable, static or deferred. Fails if it does not exist.",
		[DCDefinition.Param.new("name").suggest(_vars.get_keys)],
	)


func _try_delete_var() -> DCDefinition:
	return DCDefinition.new(
		"var.try_delete",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail("var.try_delete requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success:
				return r0
			var key: String = r0.value.as_string()
			if not _vars.is_valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			_vars.delete(key)
			return DCResult.ok(),
		"Deletes a variable if it exists. Succeeds silently when absent.",
		[DCDefinition.Param.new("name").suggest(_vars.get_keys)],
	)
