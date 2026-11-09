## Adapts a plain function into a (ctx) -> DCResult handler.
## Resolves args, coerces to the function's declared types, wraps the return in DCResult.ok.
extends RefCounted


static func build(p_name: String, fn: Callable, p_description: String) -> DCDefinition:
	var info := _method_info(fn)
	var margs: Array = info.get("args", [])
	var count := fn.get_argument_count()
	var required: int = count - info.get("default_args", []).size()

	var names: Array[String] = []
	var types: Array[int] = []
	var params: Array[DCDefinition.Param] = []
	var obj := fn.get_object()
	for i in count:
		var meta: Dictionary = margs[i] if i < margs.size() else { }
		names.append(meta.get("name", "arg%d" % i))
		types.append(meta.get("type", TYPE_NIL))
		var p := DCDefinition.Param.new(names[i])
		var found := _detect_enum(obj, meta)
		if not found.is_empty():
			p.enum_of(found)
		params.append(p)
	var slots := params.duplicate() # Param refs; unaffected by remove_param

	var handler := func(ctx: DCContext) -> DCResult:
		var given := ctx.args_length()
		if given < required or given > count:
			var expected := str(count) if required == count else "%d-%d" % [required, count]
			return DCResult.fail("%s expects %s argument(s), got %d." % [p_name, expected, given])
		var values: Array = []
		for i in given:
			var r: DCResult = await ctx.arg(i)
			if not r.success:
				return r
			var p: DCDefinition.Param = slots[i]
			var c := _coerce(_lookup(r.value, p.choices), types[i])
			if not c.success:
				var hint := "" if p.choices.is_empty() else " Try: %s." % ", ".join(PackedStringArray(p.choices.keys()))
				return DCResult.fail("%s: argument %d (%s) %s%s" % [p_name, i, p.name, c.message, hint])
			values.append(c.raw)
		
		var ret = await fn.callv(values)
		if ret is DCResult:
			return ret
		return DCResult.ok(ret, "Success" if ret == null else "")


	return DCDefinition.new(p_name, handler, p_description, params)

static func _lookup(v: Variant, choices: Dictionary) -> Variant:
	if choices.is_empty() or not (v is String):
		return v
	var s: String = v.value.strip_edges()
	for k in choices:
		if String(k).nocasecmp_to(s) == 0:
			var val = choices[k]
			return val.call() if val is Callable else val
	return v

static func _method_info(fn: Callable) -> Dictionary:
	var obj := fn.get_object()
	if obj == null:
		return { }
	var method := fn.get_method()
	for m in obj.get_method_list():
		if m.name == method:
			return m
	return { } # lambdas land here


static func _coerce(v: Variant, type: int) -> DCResult:
	var raw = v
	match type:
		TYPE_NIL, TYPE_OBJECT:
			return DCResult.ok(raw)
		TYPE_FLOAT:
			if raw is float or raw is int:
				return DCResult.ok(float(raw))
			if raw is String and raw.is_valid_float():
				return DCResult.ok(raw.to_float())
		TYPE_INT:
			if raw is int:
				return DCResult.ok(raw)
			if raw is float and is_equal_approx(raw, roundf(raw)):
				return DCResult.ok(int(raw))
			if raw is String and raw.is_valid_int():
				return DCResult.ok(raw.to_int())
		TYPE_BOOL:
			if raw is bool:
				return DCResult.ok(raw)
			if raw is int:
				return DCResult.ok(raw != 0)
			if raw is String:
				match raw.strip_edges().to_lower():
					"true", "yes", "1":
						return DCResult.ok(true)
					"false", "no", "0":
						return DCResult.ok(false)
		TYPE_STRING:
			return DCResult.ok(v.as_string())
		TYPE_STRING_NAME:
			return DCResult.ok(StringName(v.as_string()))
		_:
			if typeof(raw) == type:
				return DCResult.ok(raw)
	return DCResult.fail("expected %s, got %s." % [type_string(type), type_string(typeof(raw))])

static func _coerce_enum(v: Variant, choices: Dictionary) -> DCResult:
	var raw = v
	if raw is String:
		var s: String = raw.strip_edges()
		for k in choices:
			if String(k).nocasecmp_to(s) == 0:
				return DCResult.ok(choices[k])
		if s.is_valid_int() and choices.values().has(s.to_int()):
			return DCResult.ok(s.to_int())
	elif choices.values().has(raw):
		return DCResult.ok(raw)
	return DCResult.fail("expected one of: %s." % ", ".join(PackedStringArray(choices.keys())))


# Best effort: resolves an enum-typed arg through the owning script's constants.
static func _detect_enum(obj: Object, meta: Dictionary) -> Dictionary:
	if obj == null or meta.get("type") != TYPE_INT:
		return { }
	if not (meta.get("usage", 0) & PROPERTY_USAGE_CLASS_IS_ENUM):
		return { }
	var script: Script = obj.get_script()
	if script == null:
		return { }
	var key: String = String(meta.get("class_name", "")).split(".")[-1]
	var found = script.get_script_constant_map().get(key)
	return found if found is Dictionary else { }
