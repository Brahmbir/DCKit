# plugin.gd
# EditorPlugin entry point.
# Registers/unregisters the AutoLoad singleton so every project
# that enables this plugin gets "DCKit" as a global.
#
# The AutoLoad is the ONLY thing the editor touches.
# All systems (executor, logger, UI, etc.) are created at runtime by the AutoLoad.
@tool
extends EditorPlugin

const _AUTOLOAD_NAME   = "DCKit"
const _AUTOLOAD_SCRIPT = "res://addons/dc_kit/dckit_autoload.gd"
const ExportPlugin = preload("./export_plugin.gd")

var _export_plugin: ExportPlugin = ExportPlugin.new()

func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")



func _enter_tree() -> void:
	_DCKitNamespace.Setting._register_project_settings()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)

func _enable_plugin() -> void:
	_DCKitNamespace.Setting._register_project_settings()
	_DCKitNamespace.Setting.set_settings_internal(false)
	
	if not ProjectSettings.has_setting("autoload/" + _AUTOLOAD_NAME):
		add_autoload_singleton(_AUTOLOAD_NAME, _AUTOLOAD_SCRIPT)

func _disable_plugin() -> void:
	_DCKitNamespace.Setting.set_settings_internal(true)
	remove_autoload_singleton(_AUTOLOAD_NAME)
