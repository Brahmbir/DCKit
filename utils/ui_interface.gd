extends Node

# Replaces the old, unused _request_connection_updates.
# Emitted whenever a console is in the tree and ready to be wired up.
signal connection_requested(console: _DCKitNS.UI.ConsoleBase)

func set_console_scene(scene: PackedScene) -> bool:
	return false


func set_mode(new_mode: _DCKitSetting.ConsoleMode) -> void:
	return


func set_edge(new_edge: _DCKitSetting.WindowEdge) -> void:
	return


func toggle_mode() -> void:
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
