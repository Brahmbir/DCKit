# constructor_registry.gd
#
# Single authority for all constructor types — built-in Godot types and any
# custom types the game registers.
#
# Rules:
#   • Append-only. No unregister. No replace.
#   • Built-in types are seeded at _init() and permanently sealed.
#   • Custom registration: first-write-wins. Duplicates are silently rejected.
#
# The executor calls resolve(name, parts) → value.
# The hint provider calls get_def(name) → DCConstructorDef and knows(name).
#
# Built-in type definitions live in ./inbuilt/.
# Each file exposes a single static func create() -> DCConstructorDef.
# Add a new built-in by:
#   1. Creating ./inbuilt/<type_name>.gd
#   2. Adding a preload constant below
#   3. Calling _add_builtin(<Const>.create()) inside _seed_builtins()
#
extends RefCounted

const ConstructorDef =preload("./constructor_def.gd")

# Built-in type files
const _TypeStr = preload("./inbuilt/t_string.gd")
const _TypeInt = preload("./inbuilt/t_int.gd")
const _TypeFloat = preload("./inbuilt/t_float.gd")
const _TypeBool = preload("./inbuilt/t_bool.gd")

const _TypeVector2 = preload("./inbuilt/t_vector2.gd")
const _TypeVector2i = preload("./inbuilt/t_vector2i.gd")
const _TypeVector3 = preload("./inbuilt/t_vector3.gd")
const _TypeVector3i = preload("./inbuilt/t_vector3i.gd")
const _TypeVector4 = preload("./inbuilt/t_vector4.gd")
const _TypeVector4i = preload("./inbuilt/t_vector4i.gd")
const _TypeColour = preload("./inbuilt/t_colour.gd")
const _TypeRect2 = preload("./inbuilt/t_rect2.gd")
const _TypeRect2i = preload("./inbuilt/t_rect2i.gd")
const _TypeAABB = preload("./inbuilt/t_aabb.gd")
const _TypeQuaternion = preload("./inbuilt/t_quaternion.gd")
const _TypePlane = preload("./inbuilt/t_plane.gd")
const _TypeBasis = preload("./inbuilt/t_basis.gd")
const _TypeTransform2D = preload("./inbuilt/t_transform2d.gd")
const _TypeTransform3D = preload("./inbuilt/t_transform3d.gd")
const _TypeProjection = preload("./inbuilt/t_projection.gd")


# State
var _defs : Dictionary = {}   # name (String) → DCConstructorDef


func _init() -> void:
	_seed_builtins()


#  PUBLIC WRITE  —  game code registers custom types here
# Registers a custom constructor type.
# Returns true on success, false (with push_warning) on any rejection.
# Rejection reasons:
#   • name collides with a built-in type
#   • name was already registered by a previous custom call
#   • handler is not a valid Callable
func register(def: ConstructorDef) -> bool:
	if _defs.has(def.name):
		var existing : ConstructorDef = _defs[def.name]
		if existing.is_builtin:
			push_warning(
				"ConstructorRegistry: '%s' is a built-in type and cannot be replaced." \
				% def.name)
		else:
			push_warning(
				"ConstructorRegistry: '%s' is already registered — ignored." \
				% def.name)
		return false

	if not def.handler.is_valid():
		push_warning(
			"ConstructorRegistry: '%s' has an invalid handler — ignored." % def.name)
		return false

	_defs[def.name] = def
	return true


func knows(name: String) -> bool:
	return _defs.has(name)

func get_def(name: String) -> ConstructorDef:
	return _defs.get(name)

func get_all() -> Array:
	var out := _defs.values()
	out.sort_custom(func(a, b): return a.name < b.name)
	return out

# Executor entry point
# Called after all parts are already resolved depth-first.
# Returns a Godot Variant on success, or a DCResult.fail() on error.
func resolve(name: String, parts: Array):
	var def : ConstructorDef = _defs.get(name)
	if def == null:
		return DCResult.fail("Unknown constructor type '%s'." % name)
	return def.handler.call(parts)

# BUILT-IN SEEDING
func _seed_builtins() -> void:
	
	_add_builtin(_TypeStr.create())
	_add_builtin(_TypeInt.create())
	_add_builtin(_TypeFloat.create())
	_add_builtin(_TypeBool.create())
	
	
	_add_builtin(_TypeVector2.create())
	_add_builtin(_TypeVector2i.create())
	_add_builtin(_TypeVector3.create())
	_add_builtin(_TypeVector3i.create())
	_add_builtin(_TypeVector4.create())
	_add_builtin(_TypeVector4i.create())
	_add_builtin(_TypeColour.create())
	_add_builtin(_TypeRect2.create())
	_add_builtin(_TypeRect2i.create())
	_add_builtin(_TypeAABB.create())
	_add_builtin(_TypeQuaternion.create())
	_add_builtin(_TypePlane.create())
	_add_builtin(_TypeBasis.create())
	_add_builtin(_TypeTransform2D.create())
	_add_builtin(_TypeTransform3D.create())
	_add_builtin(_TypeProjection.create())

func _add_builtin(def: ConstructorDef) -> void:
	def.is_builtin = true
	_defs[def.name] = def
