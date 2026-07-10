# plugin.gd
# EditorPlugin entry point.
# Registers/unregisters the AutoLoad singleton so every project
# that enables this plugin gets "DevConsole" as a global.
#
# The AutoLoad is the ONLY thing the editor touches.
# All systems (executor, logger, UI, etc.) are created at runtime by the AutoLoad.

@tool
extends EditorPlugin

const _AUTOLOAD_NAME   = "DCKit"
const _AUTOLOAD_SCRIPT = "res://addons/dc_kit/dckit_autoload.gd"

const ExportPlugin = preload("./export_plugin.gd")

var _export_plugin:ExportPlugin = null

# add_autoload_singleton registers the node as a global AutoLoad.
func _enable_plugin() -> void:
	if not ProjectSettings.has_setting("autoload/" + _AUTOLOAD_NAME):
		add_autoload_singleton(_AUTOLOAD_NAME, _AUTOLOAD_SCRIPT)

	if _export_plugin: add_export_plugin(_export_plugin)

func _disable_plugin() -> void:
	remove_autoload_singleton(_AUTOLOAD_NAME)
	if _export_plugin: remove_export_plugin(_export_plugin)



func _enter_tree() -> void:
	_export_plugin = ExportPlugin.new()
	_DCKitNamespace.Setting._register_project_settings()
	
func _exit_tree() -> void: _DCKitNamespace.Setting._unregister_project_settings()
