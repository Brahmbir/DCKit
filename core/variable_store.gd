# variable_store.gd
# Flat key-value store. Values keep their real type.
# A value can also be "live": a Callable (set from code) or a Deferred
# expression (set by var.setd). Live values are not resolved here — the
# executor resolves them on read, because resolving may need to await.
# Accessed via preload; no class_name.
extends RefCounted

var _vars: Dictionary = { }


#region Read
## Exactly what is stored: a plain value, a Callable, or a Deferred.
## Used by the executor, which resolves live values itself.
func get_value_raw(key: String) -> Variant:
	return _vars.get(key) # null if absent


## Real type back. Sync only: a Callable is called, a Deferred needs the
## executor (ctx.resolve_var / DCKit.resolve_var) and returns the fallback.
func get_value(key: String, fallback: Variant = null) -> Variant:
	var v: Variant = _vars.get(key)
	if v == null:
		return fallback
	if v is Callable:
		if not v.is_valid():
			return fallback # dead Callable counts as missing
		return v.call()
	if v is Deferred:
		return fallback
	return v


## get_value(), but only if it is of the wanted TYPE_* — otherwise fallback.
func get_typed(key: String, type: int, fallback: Variant = null) -> Variant:
	var v: Variant = get_value(key, null)
	if v == null or typeof(v) != type:
		return fallback
	return v


func has(key: String) -> bool:
	return _vars.has(key)


## True for a Callable or a Deferred (static, plain values are false).
func is_live(key: String) -> bool:
	var v: Variant = _vars.get(key)
	return v is Callable or v is Deferred


## True only for a var.setd expression (needs the executor to resolve).
func is_deferred(key: String) -> bool:
	return _vars.get(key) is Deferred


## Copy of everything stored, unresolved.
func get_all() -> Dictionary:
	return _vars.duplicate()


func get_keys() -> Array:
	var k := _vars.keys()
	k.sort()
	return k
#endregion


#region Write
## Any type. A Callable is stored as a live value.
func set_value(key: String, value: Variant) -> Dictionary:
	if not is_valid_key(key):
		return _fail("Invalid variable name '%s'." % key)
	var existed := _vars.has(key)
	_vars[key] = value
	return { ok = true, existed = existed }


## Stores an unresolved expression (var.setd).
func set_deferred_var(key: String, node) -> Dictionary:
	return set_value(key, Deferred.new(node))


func delete(key: String) -> bool:
	if not _vars.has(key):
		return false
	_vars.erase(key)
	return true
#endregion


#region Internals
func is_valid_key(key: String) -> bool:
	if key.is_empty():
		return false
	var c0 := key.unicode_at(0)
	if not ((c0 >= 65 and c0 <= 90) or (c0 >= 97 and c0 <= 122) or c0 == 95):
		return false
	for i in key.length():
		var c := key.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95):
			return false
	return true


func _fail(msg: String) -> Dictionary:
	return { ok = false, message = msg }
#endregion


## Unresolved expression stored by var.setd. The executor resolves it
## in the reader's context every time the variable is read.
class Deferred extends RefCounted:
	var node = null # unresolved parser node


	func _init(p_node = null) -> void:
		node = p_node
