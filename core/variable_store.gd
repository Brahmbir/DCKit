# variable_store.gd
# Flat string-only key-value store.
# Accessed via preload; no class_name.

extends RefCounted

const DCCommandRegistry = preload("./registries/command_registry/command_registry.gd")

var _vars : Dictionary = {}


# READ
# Returns stored value or null if missing (used by executor for $var behaviour).
func get_value_raw(key: String) -> Variant:
	return _vars.get(key)   # null if absent


# get_value is used by var.get for display — still returns String
func get_value(key: String, fallback := "") -> String:
	var v = _vars.get(key)
	if v == null: return fallback
	return str(v)

func has(key: String) -> bool:
	return _vars.has(key)

func get_all() -> Dictionary:
	return _vars.duplicate()

func get_keys() -> Array:
	var k := _vars.keys()
	k.sort()
	return k

# Write
func set_value(key: String, value: Variant) -> Dictionary:
	if not _valid_key(key):
		return _fail("Invalid variable name '%s'." % key)
	var existed := _vars.has(key)
	_vars[key] = value
	return { ok = true, existed = existed }

# Delete
func delete(key: String) -> bool:
	if not _vars.has(key):
		return false
	_vars.erase(key)
	return true

# Substitution
func substitute(raw: String) -> String:
	var s := raw
	var rx_braced := RegEx.new()
	var rx_plain  := RegEx.new()
	rx_braced.compile(r"\$\{([A-Za-z_]\w*)\}")
	rx_plain.compile(r"\$([A-Za-z_]\w*)")
	for m in rx_braced.search_all(s):
		s = s.replace(m.get_string(), _vars.get(m.get_string(1), ""))
	for m in rx_plain.search_all(s):
		s = s.replace(m.get_string(), _vars.get(m.get_string(1), ""))
	return s

# INTERNALS
func _valid_key(key: String) -> bool:
	if key.is_empty():
		return false
	var c0 := key.unicode_at(0)
	if not ((c0 >= 65 and c0 <= 90) or (c0 >= 97 and c0 <= 122) or c0 == 95):
		return false
	for i in key.length():
		var c := key.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122)
				or (c >= 48 and c <= 57) or c == 95):
			return false
	return true


func _fail(msg: String) -> Dictionary:
	return { ok = false, message = msg }


# Command registration
func get_command_def_array() -> Array[DCDefinition]: 
	var set_cmd := DCDefinition.new(
		"var.set",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"var.set requires two arguments: <name> <value>")
			var r0 := await ctx.arg(0)
			if not r0.success: return r0
			var r1 := await ctx.arg(1)
			if not r1.success: return r1
			
			var key   : String  = r0.value.as_string()
			var r := set_value(key, r1.raw) # ← r1.raw is the actual Vector2/Color/etc.
			if not r.ok:
				return DCResult.fail(r.message)
			return DCResult.ok(str(r1.raw)),          # display string for the console log
		"Writes a variable into the store.",
		[
			DCParam.new("name").describe(
				"Variable name. Must start with a letter or underscore."),
			DCParam.new("value").describe(
				"Value to store. Always kept as a string."),
		]
	)
	
	var get_cmd := DCDefinition.new(
		"var.get",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 2:
				return DCResult.fail(
					"var.get requires two arguments: <name> <default>")
			var r0 := await ctx.arg(0)
			if not r0.success: return r0
			var r1 := await ctx.arg(1)
			if not r1.success: return r1
			var key      : String = r0.value.as_string()
			var fallback : String = r1.value.as_string()
			if not _valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			return DCResult.ok(get_value(key, fallback)),
		"Reads a variable. Returns the default value when the variable is absent.",
		[ 
			DCParam.new("name").suggest(func(): return get_keys() ),
			DCParam.new("default").describe(
				"Returned as-is when the variable does not exist."),
		]
	)

	var exist_cmd := DCDefinition.new(
		"var.exists",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail(
					"var.exists requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success: return r0
			var key : String = r0.value.as_string()
			if not _valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			return DCResult.ok("true" if has(key) else "false"),
		"Returns [b]true[/b] if the variable exists, [b]false[/b] otherwise.",
		[ DCParam.new("name").suggest(func(): return get_keys() ) ]
	)
	var list_cmd := DCDefinition.new(
		"var.list",
		func(ctx: DCContext) -> DCResult:
			var keys : Array = get_keys()
			if ctx.args_length() >= 1:
				var r0 := await ctx.arg(0)
				if not r0.success: return r0
				var prefix : String = r0.value.as_string()
				keys = keys.filter(func(k: String) -> bool:
					return k.begins_with(prefix))
			if keys.is_empty():
				return DCResult.ok("emp")
			return DCResult.ok(", ".join(keys)),
		"Lists variable names, space-separated. Optionally filters by prefix.",
		[ DCParam.new("prefix").describe(
			"Optional. Only names starting with this are returned.") ]
	)


	var delete_cmd := DCDefinition.new(
		"var.delete",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail(
					"var.delete requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success: return r0
			var key : String = r0.value.as_string()
			if not _valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			if not delete(key):
				return DCResult.fail(
					"Variable '%s' does not exist." % key)
			return DCResult.ok(),
		"Deletes a variable. Fails if it does not exist.",
		[ DCParam.new("name").suggest(func(): return get_keys() ) ]
	)


	var try_delete_cmd := DCDefinition.new(
		"var.try_delete",
		func(ctx: DCContext) -> DCResult:
			if ctx.args_length() < 1:
				return DCResult.fail(
					"var.try_delete requires one argument: <name>")
			var r0 := await ctx.arg(0)
			if not r0.success: return r0
			var key : String = r0.value.as_string()
			if not _valid_key(key):
				return DCResult.fail("Invalid variable name '%s'." % key)
			delete(key)
			return DCResult.ok(),
		"Deletes a variable if it exists. Succeeds silently when absent.",
		[ DCParam.new("name").suggest(func(): return get_keys() ) ]
	)
	return [set_cmd, get_cmd, exist_cmd, list_cmd, delete_cmd, try_delete_cmd]
	
	
