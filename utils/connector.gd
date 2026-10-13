extends RefCounted

signal event_raised(event: String, args: Array)

var _slots: Dictionary = { }


func bind(slot: String, callable: Callable) -> void:
	_slots[slot] = callable


func unbind(slot: String) -> void:
	_slots.erase(slot)


func unbind_all() -> void:
	_slots.clear()


func is_bound(slot: String) -> bool:
	var callable: Callable = _slots.get(slot, Callable())
	return callable.is_valid()


func call_slot(slot: String, args: Array = [], fallback: Variant = null) -> Variant:
	if not is_bound(slot):
		return fallback
	return (_slots[slot] as Callable).callv(args)


func raise(event: String, args: Array = []) -> void:
	event_raised.emit(event, args)
