## Adapts a plain function into a (ctx) -> DCResult handler.
## Resolves args, coerces to the function's declared types, wraps the return in DCResult.ok.
extends RefCounted

const Spec := preload("../spec.gd")


static func build(p_name: String, fn: Callable, p_description: String) -> DCDefinition:
	var info := _method_info(fn)
	var margs: Array = info.get("args", [])
	var count := fn.get_argument_count()

	var unbound_defaults := maxi(
		0,
		info.get("default_args", []).size() - fn.get_bound_arguments_count(),
	)
	var required: int = count - unbound_defaults

	var names: Array[String] = []
	var types: Array[int] = []
	var sigs: Array[Dictionary] = [] # what each signature already says (see DCSpec.from_property)
	var key_sigs: Array[Dictionary] = []
	var params: Array[DCDefinition.Param] = []
	var obj := fn.get_object()
	for i in count:
		var meta: Dictionary = margs[i] if i < margs.size() else { }
		names.append(meta.get("name", "arg%d" % i))
		types.append(meta.get("type", TYPE_NIL))
		var p := DCDefinition.Param.new(names[i])
		sigs.append(Spec.from_property(meta, obj))
		key_sigs.append(Spec.key_of(meta, obj))
		p.spec = sigs[i]
		var found := _detect_enum(obj, meta)
		if not found.is_empty():
			p.enum_of(found)
		params.append(p)
	var slots := params.duplicate() # Param refs; unaffected by remove_param

	var handler := func(ctx: DCContext) -> DCResult:
		if not fn.is_valid():
			return DCResult.fail("The owner of this command no longer exists.")
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
			var c := _coerce(_lookup(r.value, p.choices), types[i], sigs[i], key_sigs[i])
			if not c.success:
				var hint := (
					""
					if p.choices.is_empty()
					else " Try: %s." % ", ".join(PackedStringArray(p.choices.keys()))
				)
				return DCResult.fail(
					"%s: argument %d (%s) %s%s" % [p_name, i, p.name, c.message, hint]
				)
			values.append(c.value)

		var ret = await fn.callv(values)
		if ret is DCResult:
			return ret
		return DCResult.ok(ret, "Success" if ret == null else "")

	return DCDefinition.new(p_name, handler, p_description, params)


static func _lookup(v: Variant, choices: Dictionary) -> Variant:
	if choices.is_empty() or not (v is String):
		return v
	var s: String = v.strip_edges()
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


static func _coerce(v: Variant, type: int, sig := { }, key_sig := { }) -> DCResult:
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
			if raw is String and raw.is_valid_hex_number(true):
				return DCResult.ok(raw.hex_to_int())
		TYPE_COLOR:
			if raw is Color:
				return DCResult.ok(raw)
			if raw is String and Color.html_is_valid(raw):
				return DCResult.ok(Color.html(raw))
		TYPE_BOOL:
			if raw is bool:
				return DCResult.ok(raw)
			if raw is int:
				return DCResult.ok(raw != 0)
			if raw is String:
				match raw.strip_edges().to_lower():
					"true", "yes", "1","on":
						return DCResult.ok(true)
					"false", "no", "0","off":
						return DCResult.ok(false)
		TYPE_STRING:
			return DCResult.ok(v if v is String else var_to_str(v))
		TYPE_STRING_NAME:
			return DCResult.ok(StringName(v if v is String else var_to_str(v)))
		TYPE_ARRAY:
			if raw is Array:
				return _coerce_array(raw, sig)
		TYPE_DICTIONARY:
			if raw is Dictionary:
				return _coerce_dictionary(raw, sig, key_sig)
		_:
			if typeof(raw) == type:
				return DCResult.ok(raw)
	return DCResult.fail("expected %s, got %s." % [type_string(type), type_string(typeof(raw))])


# One item / value / key: an enum goes through its choices, anything else through its type.
static func _coerce_spec(v: Variant, spec: Dictionary) -> DCResult:
	if spec.has("choices"):
		return _coerce_enum(v, spec["choices"])
	return _coerce(v, spec.get("type", TYPE_NIL))


# Array[T] parameters need a typed array: coerce every item, then build it.
static func _coerce_array(raw: Array, sig: Dictionary) -> DCResult:
	var item: Dictionary = sig.get("items", { })
	var item_t: int = item.get("type", TYPE_NIL)
	if item_t <= TYPE_NIL:
		return DCResult.ok(raw)
	var out: Array = []
	for i in raw.size():
		var c := _coerce_spec(raw[i], item)
		if not c.success:
			return DCResult.fail("item %d %s" % [i, c.message])
		out.append(c.value)
	return DCResult.ok(Array(out, item_t, &"", null))


# Dictionary[K, V] parameters likewise.
static func _coerce_dictionary(raw: Dictionary, sig: Dictionary, key_sig: Dictionary) -> DCResult:
	var value_spec: Dictionary = sig.get("fields", { }).get("*", { })
	var key_t: int = key_sig.get("type", TYPE_NIL)
	var val_t: int = value_spec.get("type", TYPE_NIL)
	if key_t <= TYPE_NIL or val_t <= TYPE_NIL:
		return DCResult.ok(raw)
	var out := { }
	for k in raw:
		var ck := _coerce_spec(k, key_sig)
		var cv := _coerce_spec(raw[k], value_spec)
		if not ck.success:
			return DCResult.fail("key '%s' %s" % [k, ck.message])
		if not cv.success:
			return DCResult.fail("value of '%s' %s" % [k, cv.message])
		out[ck.value] = cv.value
	return DCResult.ok(Dictionary(out, key_t, &"", null, val_t, &"", null))


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
