## String manipulation commands for DCKit.
## Inputs are resolved through DCContext and converted to strings.
extends DCModule


func get_id() -> String:
	return "dckit_string"


func get_commands() -> Array[DCDefinition]:
	return [
		_len_cmd(),
		_trim_cmd(),
		_lower_cmd(),
		_upper_cmd(),
		_contains_cmd(),
		_replace_cmd(),
		_starts_with_cmd(),
		_ends_with_cmd(),
		_split_cmd(),
		_join_cmd(),
		_slice_cmd(),
	]


func _len_cmd() -> DCDefinition:
	return _unary_string_command(
		"str.len", "Returns the number of characters in the string.",
		func(value: String) -> String: return str(value.length())
	)


func _trim_cmd() -> DCDefinition:
	return _unary_string_command(
		"str.trim", "Removes whitespace from both ends of the string.",
		func(value: String) -> String: return value.strip_edges()
	)


func _lower_cmd() -> DCDefinition:
	return _unary_string_command(
		"str.lower", "Converts the string to lowercase.",
		func(value: String) -> String: return value.to_lower()
	)


func _upper_cmd() -> DCDefinition:
	return _unary_string_command(
		"str.upper", "Converts the string to uppercase.",
		func(value: String) -> String: return value.to_upper()
	)


func _contains_cmd() -> DCDefinition:
	return _binary_string_bool_command(
		"str.contains", "Returns [b]true[/b] when the first string contains the second.",
		func(a: String, b: String) -> bool: return a.contains(b)
	)


func _starts_with_cmd() -> DCDefinition:
	return _binary_string_bool_command(
		"str.starts_with", "Returns [b]true[/b] when the first string starts with the second.",
		func(a: String, b: String) -> bool: return a.begins_with(b)
	)


func _ends_with_cmd() -> DCDefinition:
	return _binary_string_bool_command(
		"str.ends_with", "Returns [b]true[/b] when the first string ends with the second.",
		func(a: String, b: String) -> bool: return a.ends_with(b)
	)


func _replace_cmd() -> DCDefinition:
	return DCDefinition.new(
		"str.replace",
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, "str.replace", 3, 3)
			if not values.success:
				return DCResult.fail(values.message)
			return DCResult.ok(values.items[0].replace(values.items[1], values.items[2])),
		"Replaces every occurrence of the search string with the replacement string.",
		[DCDefinition.Param.new("text"), DCDefinition.Param.new("search"), DCDefinition.Param.new("replacement")],
	)


func _split_cmd() -> DCDefinition:
	return DCDefinition.new(
		"str.split",
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, "str.split", 2, 3)
			if not values.success:
				return DCResult.fail(values.message)
			var allow_empty := values.items.size() == 3 and values.items[2].to_lower() == "true"
			var parts := values.items[0].split(values.items[1], allow_empty)
			return DCResult.ok(parts),
		"Splits a string using a delimiter. Optional third argument enables empty entries when set to true.",
		[
			DCDefinition.Param.new("text"),
			DCDefinition.Param.new("delimiter"),
			DCDefinition.Param.new("allow_empty").describe("Optional boolean; defaults to false."),
		],
	)


func _join_cmd() -> DCDefinition:
	return DCDefinition.new(
		"str.join",
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, "str.join", 2, -1)
			if not values.success:
				return DCResult.fail(values.message)
			var delimiter := values.items[0]
			var parts: PackedStringArray = []
			for index in range(1, values.items.size()):
				parts.append(values.items[index])
			return DCResult.ok(delimiter.join(parts)),
		"Joins two or more strings using the first argument as the delimiter.",
		[
			DCDefinition.Param.new("delimiter"),
			DCDefinition.Param.new("values").describe("Strings to join.").rest(),
		],
	)


func _slice_cmd() -> DCDefinition:
	return DCDefinition.new(
		"str.slice",
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, "str.slice", 2, 3)
			if not values.success:
				return DCResult.fail(values.message)

			var start_text := values.items[1]
			if not start_text.is_valid_int():
				return DCResult.fail("str.slice: start must be an integer.")
			var start := int(start_text)
			var length := -1
			if values.items.size() == 3:
				if not values.items[2].is_valid_int():
					return DCResult.fail("str.slice: length must be an integer.")
				length = int(values.items[2])
				if length < 0:
					return DCResult.fail("str.slice: length cannot be negative.")

			return DCResult.ok(values.items[0].substr(start, length)),
		"Extracts a substring from a start index and optional character length.",
		[
			DCDefinition.Param.new("text"),
			DCDefinition.Param.new("start"),
			DCDefinition.Param.new("length").describe("Optional number of characters; defaults to the end."),
		],
	)


func _unary_string_command(command_name: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, command_name, 1, 1)
			if not values.success:
				return DCResult.fail(values.message)
			return DCResult.ok(operation.call(values.items[0])),
		description,
		[DCDefinition.Param.new("value")],
	)


func _binary_string_bool_command(command_name: String, description: String, operation: Callable) -> DCDefinition:
	return DCDefinition.new(
		command_name,
		func(ctx: DCContext) -> DCResult:
			var values := await _resolve_strings(ctx, command_name, 2, 2)
			if not values.success:
				return DCResult.fail(values.message)
			return DCResult.ok("true" if operation.call(values.items[0], values.items[1]) else "false"),
		description,
		[DCDefinition.Param.new("text"), DCDefinition.Param.new("search")],
	)


func _resolve_strings(ctx: DCContext, command_name: String, min_count: int, max_count: int) -> _ResolvedStrings:
	var out := _ResolvedStrings.new()
	var count := ctx.args_length()
	if count < min_count or (max_count >= 0 and count > max_count):
		var expected := str(min_count) if min_count == max_count else ("at least %d" % min_count)
		out.message = "%s requires %s argument(s)." % [command_name, expected]
		return out

	for index in count:
		var result := await ctx.arg(index)
		if not result.success:
			out.message = result.message
			return out
		out.items.append(result.value.as_string())

	out.success = true
	return out


class _ResolvedStrings:
	var success: bool = false
	var message: String = ""
	var items: PackedStringArray = []
