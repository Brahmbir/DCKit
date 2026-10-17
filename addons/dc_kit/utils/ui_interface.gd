extends Node

# Replaces the old, unused _request_connection_updates.
# Emitted whenever a console is in the tree and ready to be wired up.
signal console_visibility_changed(is_open: bool)


func set_console_scene(scene: PackedScene) -> bool:
	return false


func set_connection_request_callback(callback: Callable):
	return


func show_console() -> void:
	return


func hide_console() -> void:
	return


func toggle_console() -> void:
	return


func is_console_open() -> bool:
	return false


func request_connections() -> void:
	return


func configure(config: Dictionary) -> void:
	return
