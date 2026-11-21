extends RefCounted

const COMMAND_HINT := "Command names use letters, digits and '_', with '.' between segments (e.g. player.heal)."


## [] when valid, else [char_index, message]. Same rule the command registry enforces.
static func command_name_error(name: String) -> Array:
	if name.is_empty():
		return [0, "A command name cannot be empty."]
	var segment_start := true
	for i in name.length():
		var c := name.unicode_at(i)
		if c == 46:
			if segment_start:
				return [i, "A command name cannot have an empty segment (leading or double '.')."]
			segment_start = true
		elif segment_start:
			if not _is_start(c):
				if c >= 48 and c <= 57:
					return [i, "A command name segment cannot start with a digit."]
				return [i, "Invalid character '%s' in command name '%s'." % [name[i], name]]
			segment_start = false
		elif not _is_char(c):
			return [i, "Invalid character '%s' in command name '%s'." % [name[i], name]]
	if segment_start:
		return [name.length() - 1, "A command name cannot end with a '.'."]
	return []


## [] when valid, else [char_index, message].
static func type_name_error(name: String) -> Array:
	var dot := name.find(".")
	if dot >= 0:
		return [dot, "Constructor type '%s' cannot be a dotted name." % name]
	for i in name.length():
		var c := name.unicode_at(i)
		if not (_is_start(c) or (i > 0 and _is_char(c))):
			if i == 0 and c >= 48 and c <= 57:
				return [i, "A constructor type cannot start with a digit."]
			return [i, "Invalid character '%s' in constructor type '%s'." % [name[i], name]]
	return []


static func _is_start(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


static func _is_char(c: int) -> bool:
	return _is_start(c) or (c >= 48 and c <= 57)
