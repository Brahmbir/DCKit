## Base class for DCKit command modules.
##
## Override only what you need:
##   get_id()       — unique name of the module.
##   get_commands() — the definitions this module provides.
##   get_needs()    — Need flags for the services you want in setup().
##   setup(services) — called once, before get_commands().
class_name DCModule
extends RefCounted

## What a module asks for. Combine with | in get_needs().
enum Need {
	VARIABLES = 1 << 0,
	LOGGER = 1 << 1,
	PROFILER = 1 << 2,
	REGISTRY = 1 << 3,
}


func get_id() -> String:
	return ""


func get_commands() -> Array[DCDefinition]:
	return []


## Default: needs nothing, so setup() is never called.
func get_needs() -> int:
	return 0


func setup(_services: Services) -> void:
	pass


## What a module gets. Only the services it asked for are set.
class Services extends RefCounted:
	var variables: Object = null
	var logger: Object = null
	var profiler: Object = null
	var registry: Object = null
