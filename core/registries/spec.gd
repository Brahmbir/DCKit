extends RefCounted
## A spec is a plain Dictionary describing one value. Every key is optional:
##   what it is      type  items  fields
##   what to offer   suggest  desc
##   what to enforce unique  min  max  validate
## Anywhere a spec is expected you may pass a shorthand instead:
##   Array / Callable → { suggest }     TYPE_* constant → { type }     Dictionary → the spec itself

const KEYS := ["type", "items", "fields", "suggest", "desc", "unique", "min", "max", "validate"]


static func normalize(raw: Variant) -> Dictionary:
	if raw == null:
		return { }
	if raw is Callable or raw is Array:
		return { "suggest": raw }
	if raw is PackedStringArray:
		return { "suggest": Array(raw) }
	if raw is int:
		return { "type": raw }
	if raw is Dictionary:
		return _clean(raw)
	push_error("Spec: expected a Dictionary, Array, Callable or TYPE_* constant, got %s." % type_string(typeof(raw)))
	return { }


## Keys of `over` win; `items` is merged one level down so { unique = true } keeps an inferred item type.
static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k in over:
		if k == "items" and out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


## What a function signature already says: the value's type, an Array[T] item type, a Dictionary[K, V] value type.
static func from_signature(type: int, hint: int, hint_string: String) -> Dictionary:
	if type == TYPE_NIL:
		return { }
	var out := { "type": type }
	if type == TYPE_ARRAY and hint == PROPERTY_HINT_ARRAY_TYPE:
		var t := type_from_name(hint_string)
		if t > TYPE_NIL:
			out["items"] = { "type": t }
	elif type == TYPE_DICTIONARY and hint == PROPERTY_HINT_DICTIONARY_TYPE:
		var parts := hint_string.split(";")
		if parts.size() == 2:
			var t := type_from_name(parts[1])
			if t > TYPE_NIL:
				out["fields"] = { "*": { "type": t } }
	return out


## "int" → TYPE_INT, "Vector2" → TYPE_VECTOR2 …; -1 when the name is not a built-in type (e.g. a class).
static func type_from_name(type_name: String) -> int:
	for t in TYPE_MAX:
		if type_string(t) == type_name:
			return t
	return -1


static func _clean(d: Dictionary) -> Dictionary:
	var out := { }
	for k in d:
		var key := str(k)
		var v = d[k]
		match key:
			"type":
				if v is int:
					out[key] = v
				else:
					push_error("Spec: 'type' must be a TYPE_* constant.")
			"items":
				out[key] = normalize(v)
			"fields":
				if v is Dictionary:
					var fields := { }
					for fk in v:
						fields[str(fk)] = normalize(v[fk])
					out[key] = fields
				else:
					push_error("Spec: 'fields' must be a Dictionary of key: spec.")
			"suggest":
				if v is Callable or v is Array or v is Dictionary:
					out[key] = v
				elif v is PackedStringArray:
					out[key] = Array(v)
				else:
					push_error("Spec: 'suggest' must be an Array, a Dictionary or a Callable.")
			"desc":
				out[key] = str(v)
			"unique":
				out[key] = bool(v)
			"min", "max":
				if v is int or v is float:
					out[key] = v
				else:
					push_error("Spec: '%s' must be a number." % key)
			"validate":
				if v is Callable:
					out[key] = v
				else:
					push_error("Spec: 'validate' must be a Callable returning \"\" or an error message.")
			_:
				push_warning("Spec: unknown key '%s' (expected one of: %s)." % [key, ", ".join(KEYS)])
	return out
