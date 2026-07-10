# command_registry.gd
# Flat case-sensitive map of command name → CommandDefinition.
# "player.warp" and "Player.Warp" are distinct keys.
# Rules:
#   register   — validates name, rejects collision (first-write wins)
#   unregister — rejects if locked or absent
#   lock/unlock — toggles locked flag only
#
# Aliases
#   Stored in _aliases (alias → primary name).  Aliases are transparent:
#   has(), get_definition(), get_handler() all resolve through them.
#   get_all() / get_matching() operate on PRIMARY names only — no duplicates.
#   get_alias_matches() gives autocomplete the alias labels it needs.
extends RefCounted

var _commands : Dictionary = {}  # primary name → DCDefinition
var _aliases  : Dictionary = {}  # alias name   → primary name


# Validates name then stores the definition and all its aliases.
# Returns false + warns on invalid name, collision, or bad alias.
func register(def: DCDefinition) -> bool:
	var err := _validate_name(def.name)
	if err != "":
		push_warning("CommandRegistry: register('%s') — %s" % [def.name, err])
		return false
	if _commands.has(def.name):
		push_warning("CommandRegistry: '%s' already registered — ignored." % def.name)
		return false
	_commands[def.name] = def

	for a in def._aliases:
		var aerr := _validate_name(a)
		if aerr != "":
			push_warning("CommandRegistry: alias '%s' for '%s' — %s" % [a, def.name, aerr])
			continue
		if _commands.has(a) or _aliases.has(a):
			push_warning("CommandRegistry: alias '%s' for '%s' is already taken — ignored." % [a, def.name])
			continue
		_aliases[a] = def.name

	return true


# Removes a command and all its aliases. Returns false + warns if locked or absent.
func unregister(name: String) -> bool:
	var def : DCDefinition = _commands.get(name)
	if def == null:
		push_warning("CommandRegistry: unregister('%s') — not found." % name)
		return false
	if def.locked:
		push_warning("CommandRegistry: '%s' is locked — unregister denied." % name)
		return false
	_commands.erase(name)
	for a in def.aliases:
		_aliases.erase(a)
	return true


# lock/unlock accept both primary names and aliases.
func lock(name: String) -> void:
	var def := get_definition(name)
	if def != null: def.locked = true

func unlock(name: String) -> void:
	var def := get_definition(name)
	if def != null: def.locked = false


# Returns an invalid Callable when name (or alias) is unknown.
func get_handler(name: String) -> Callable:
	var def : DCDefinition = get_definition(name)
	return def.handler if def else Callable()


# Resolves primary names first, then aliases.
func get_definition(name: String) -> DCDefinition:
	if _commands.has(name):
		return _commands[name]
	var primary : String = _aliases.get(name, "")
	return _commands.get(primary) if not primary.is_empty() else null


# All definitions sorted by name — baseline for all query operations.
# Never returns duplicates for aliased commands.
func get_all() -> Array:
	var out := _commands.values()
	out.sort_custom(func(a, b): return a.name < b.name)
	return out


# Segment-aware search with ranked ordering.
#
# A dotted name like "var.set" has two segments: ["var", "set"].
# The query matches a definition when it is a prefix of:
#   rank 0 — the full name exactly          "var.set" → "var.set"
#   rank 1 — the full name as prefix        "var"     → "var.set"
#   rank 2 — the first segment              "va"      → "var.set"
#   rank 3 — any non-first segment          "se"      → "var.set"
#
# Within each rank, results are sorted alphabetically.
# Empty query returns all definitions (same as get_all).
# Operates on primary names only — use get_alias_matches() for aliases.
func get_matching(query: String) -> Array:
	return _rank_matches(
		_commands.values(),
		query,
		func(def: DCDefinition): return def.name,
		func(a: DCDefinition, b: DCDefinition): return a.name < b.name
	)


func get_alias_matches(query: String) -> Array:
	var aliases: Array = []

	for alias in _aliases:
		var def: DCDefinition = _commands.get(_aliases[alias])
		if def != null:
			aliases.append({
				"alias": alias,
				"def": def
			})

	return _rank_matches(
		aliases,
		query,
		func(entry): return entry.alias,
		func(a, b): return a.alias < b.alias
	)


func _rank_matches(items: Array, query: String, text_fn: Callable, sort_fn: Callable) -> Array:
	if query.is_empty():
		var out := items.duplicate()
		out.sort_custom(sort_fn)
		return out

	var buckets: Array = [[], [], [], []]

	for item in items:
		var rank := _match_rank(text_fn.call(item), query)
		if rank >= 0:
			buckets[rank].append(item)

	var out: Array = []

	for bucket in buckets:
		bucket.sort_custom(sort_fn)
		out.append_array(bucket)

	return out


func has(name: String) -> bool:
	return _commands.has(name) or _aliases.has(name)


# Returns "" on success or a human-readable error string on failure.
# Rules mirror the tokenizer's identifier rules so the parser never chokes:
#   • Each dot-separated segment must start with [A-Za-z_]
#   • Continuation chars are [A-Za-z0-9_.]
#   • No empty segments (no leading dot, trailing dot, or double dot)
func _validate_name(name: String) -> String:
	if name.is_empty():
		return "name cannot be empty."
	# Walk once — validate first char of each segment and all continuation chars.
	var segment_start := true
	for i in name.length():
		var c := name[i]
		if c == ".":
			if segment_start:
				return "empty segment at position %d (leading/double dot)." % i
			segment_start = true
			continue
		if segment_start:
			if not _is_ident_start(c):
				return "segment at position %d must start with [A-Za-z_], got '%s'." % [i, c]
			segment_start = false
		elif not _is_ident_char(c):
			return "invalid character '%s' at position %d." % [c, i]
	if segment_start:
		return "name cannot end with a dot."
	return ""


func _is_ident_start(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c == "_"

func _is_ident_char(c: String) -> bool:
	var code := c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or (code >= 48 and code <= 57) or c == "_"


# Returns the rank (0–3) of the best match, or -1 for no match.
func _match_rank(cmd_name: String, query: String) -> int:
	if cmd_name == query:                           return 0  # exact
	if cmd_name.begins_with(query):                 return 1  # full-name prefix
	var segs := cmd_name.split(".")
	if segs[0].begins_with(query):                  return 2  # first-segment prefix
	for i in range(1, segs.size()):
		if segs[i].begins_with(query):              return 3  # any other segment
	return -1
