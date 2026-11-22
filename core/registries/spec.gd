class_name DCSpec
extends RefCounted
## A spec is a plain Dictionary describing one value. Every key is optional:
##   what it is      type  items  fields  choices
##   what to offer   suggest  desc
##   what to enforce unique  min  max  validate
## Anywhere a spec is expected you may pass a shorthand instead:
##   Array / Callable → { suggest }     TYPE_* constant → { type }     Dictionary → the spec itself
##
## Helpers build specs from Godot's own property hints (the `hint` / `hint_string` pair used by
## @export_*, get_property_list() and get_method_list()):
##   DCSpec.of(TYPE_INT, PROPERTY_HINT_RANGE, "0,10")        DCSpec.as_enum(Mode)
##   DCSpec.as_array(DCSpec.of(...), { unique = true })       DCSpec.as_dictionary({ "hp!": TYPE_INT })

const KEYS := [
	"type",
	"items",
	"fields",
	"choices",
	"suggest",
	"desc",
	"unique",
	"min",
	"max",
	"validate",
]


#region HELPERS
## A value of `type` refined by a property hint:
##   PROPERTY_HINT_ENUM "A,B:5,C"           → choices            PROPERTY_HINT_ENUM_SUGGESTION "a,b" → suggest
##   PROPERTY_HINT_RANGE "0,100,1"          → min / max          PROPERTY_HINT_ARRAY_TYPE            → items
##   PROPERTY_HINT_DICTIONARY_TYPE "K;V"    → fields["*"]
## `obj` lets an enum written as a class path (what Array[Mode] reports) be resolved to its values.
static func of(
	type: int,
	hint := PROPERTY_HINT_NONE,
	hint_string := "",
	obj: Object = null,
) -> Dictionary:
	var out := { }
	if type != TYPE_NIL:
		out["type"] = type
	match hint:
		PROPERTY_HINT_ENUM:
			var c := parse_enum(hint_string, type == TYPE_STRING)
			if not c.is_empty():
				out["choices"] = c
		PROPERTY_HINT_ENUM_SUGGESTION:
			out["suggest"] = parse_enum(hint_string, true).keys()
		PROPERTY_HINT_RANGE:
			_range(out, type, hint_string)
		PROPERTY_HINT_ARRAY_TYPE:
			var item := element(hint_string, obj)
			if not item.is_empty():
				out["items"] = item
		PROPERTY_HINT_DICTIONARY_TYPE:
			var parts := hint_string.split(";")
			if parts.size() == 2:
				var value := element(parts[1], obj)
				if not value.is_empty():
					out["fields"] = { "*": value }
	return out


## The same, from a property-info Dictionary ({ type, hint, hint_string, class_name, usage }), the shape
## get_method_list() / get_property_list() return. A typed enum parameter is resolved through `obj`'s script.
static func from_property(info: Dictionary, obj: Object = null) -> Dictionary:
	var out := of(info.get("type", TYPE_NIL), info.get("hint", 0), info.get("hint_string", ""), obj)

	if (
		info.get("type") == TYPE_INT and (info.get("usage", 0) & PROPERTY_USAGE_CLASS_IS_ENUM)
		and not out.has("choices")
	):
		var found := enum_by_path(info.get("class_name", ""), obj)
		if not found.is_empty():
			out["choices"] = found
	return out


## The spec of the key of a Dictionary[K, V] parameter (empty when untyped).
static func key_of(info: Dictionary, obj: Object = null) -> Dictionary:
	if info.get("hint", 0) != PROPERTY_HINT_DICTIONARY_TYPE:
		return { }
	var parts := String(info.get("hint_string", "")).split(";")
	return element(parts[0], obj) if parts.size() == 2 else { }


## An array whose items follow `item` (a spec or shorthand); `rules` adds unique / min / max / validate / suggest ...
static func as_array(item: Variant = null, rules: Variant = null) -> Dictionary:
	var out := { }
	if item != null:
		out["items"] = normalize(item)
	return merge(out, normalize(rules))


## A dictionary with named `fields` ("key!" required, "key?" optional, "*" any other key); `rules` as above.
static func as_dictionary(fields: Dictionary = { }, rules: Variant = null) -> Dictionary:
	return merge({ "fields": normalize({ "fields": fields }).get("fields", { }) }, normalize(rules))


## An enum: a GDScript enum or { name: value } Dictionary, an Array of names, or a hint string "A,B:5,C".
static func as_enum(source: Variant) -> Dictionary:
	var choices := { }
	if source is Dictionary:
		choices = source
	elif source is Array or source is PackedStringArray:
		for n in source:
			choices[str(n)] = str(n)
	elif source is String:
		choices = parse_enum(source)
	return normalize({ "choices": choices })
#endregion


#region HINT PARSING
## "A,B:5,C" → { A: 0, B: 5, C: 6 }. With `as_strings` every value is its own name (string enums).
static func parse_enum(hint_string: String, as_strings := false) -> Dictionary:
	var out := { }
	var next := 0
	for part in hint_string.split(","):
		var p := part.strip_edges()
		if p.is_empty():
			continue
		var name := p
		var value := next
		var colon := p.rfind(":")
		if colon > 0 and p.substr(colon + 1).is_valid_int():
			name = p.substr(0, colon)
			value = p.substr(colon + 1).to_int()
		out[name] = name if as_strings else value
		next = value + 1
	return out


## One element type as it appears in an Array[T] / Dictionary[K, V] hint string:
## a built-in type name ("int", "Vector2"), an enum class path (needs `obj`), or the property-list
## encoding "TYPE/HINT:HINT_STRING" ("2/2:A,B" is an int enum).
static func element(hint_string: String, obj: Object = null) -> Dictionary:
	var hs := hint_string.strip_edges()
	if hs.is_empty():
		return { }
	var slash := hs.find("/")
	var colon := hs.find(":")
	if (
		slash > 0 and colon > slash and hs.substr(0, slash).is_valid_int()
		and hs.substr(slash + 1, colon - slash - 1).is_valid_int()
	):
		return of(
			hs.substr(0, slash).to_int(),
			hs.substr(slash + 1, colon - slash - 1).to_int(),
			hs.substr(colon + 1),
			obj,
		)
	var t := type_from_name(hs)
	if t > TYPE_NIL:
		return { "type": t }
	var found := enum_by_path(hs, obj)
	return { "type": TYPE_INT, "choices": found } if not found.is_empty() else { }


## "res://x.gd.Cmds.Mode" → the enum { name: value } declared in obj's script, or {}.
static func enum_by_path(path: String, obj: Object) -> Dictionary:
	if obj == null or path.is_empty():
		return { }
	var script: Script = obj.get_script()
	if script == null:
		return { }
	var found = script.get_script_constant_map().get(path.split(".")[-1])
	return found if found is Dictionary else { }


## "int" → TYPE_INT, "Vector2" → TYPE_VECTOR2 …; -1 when the name is not a built-in type (e.g. a class).
static func type_from_name(type_name: String) -> int:
	for t in TYPE_MAX:
		if type_string(t) == type_name:
			return t
	return -1


static func _range(out: Dictionary, type: int, hint_string: String) -> void:
	var p := hint_string.split(",")
	if p.size() < 2 or not (p[0].is_valid_float() and p[1].is_valid_float()):
		return
	var whole := type == TYPE_INT
	if not hint_string.contains("or_less"):
		out["min"] = int(p[0].to_float()) if whole else p[0].to_float()
	if not hint_string.contains("or_greater"):
		out["max"] = int(p[1].to_float()) if whole else p[1].to_float()
#endregion


#region SPEC PLUMBING
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
	push_error(
		"Spec: expected a Dictionary, Array, Callable or TYPE_* constant, got %s."
		% type_string(typeof(raw))
	)
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


## What a function signature already says. Kept for older callers; prefer from_property().
static func from_signature(
	type: int,
	hint: int,
	hint_string: String,
	obj: Object = null,
) -> Dictionary:
	return of(type, hint, hint_string, obj)


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
			"choices":
				if v is Dictionary:
					out[key] = v
				elif v is Array or v is PackedStringArray:
					var names := { }
					for n in v:
						names[str(n)] = str(n)
					out[key] = names
				else:
					push_error(
						"Spec: 'choices' must be an enum, a { name: value } Dictionary or an Array of names."
					)
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
					push_error(
						"Spec: 'validate' must be a Callable returning \"\" or an error message."
					)
			_:
				push_warning(
					"Spec: unknown key '%s' (expected one of: %s)." % [key, ", ".join(KEYS)]
				)
	return out
#endregion
