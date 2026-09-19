@tool
extends EditorExportPlugin

const IGNORE_FILES := ["fonts/OFL.txt"]

const INCLUDE_FILES := [
	# "plugin.cfg",
	# "plugin.gd",
	"dckit_autoload.gd",
	"dc_analysis_result.gd",
	"dc_result.gd",
	"bb_code_utils.gd",
	"command_definition.gd",
	"dc_logger.gd",
	"dc_context.gd",
]

var _is_debug_export := false


func _get_name() -> String:
	return "DCKitBatFileExport"


func _is_enabled(is_debug: bool) -> bool:
	return is_debug or _DCKitUtilsNamespace.Setting.get_setting(
			_DCKitUtilsNamespace.Setting.SETTING_ENABLED_IN_RELEASE,
			false,
		)

func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if not path.contains("addons/dc_kit"):
		return

	if _should_skip_file(path, _is_debug_export):
		skip()


func _should_skip_file(path: String, is_debug: bool) -> bool:
	var file_path := path.get_file()

	# Explicitly ignored files always get skipped, regardless of build type.
	if IGNORE_FILES.has(file_path):
		return true

	# Console feature is active (debug build, or opted into release) —
	# it needs its full file set, so nothing else gets skipped here.
	if _is_enabled(is_debug):
		return false

	# Console feature is inactive: ship only the minimal footprint
	# listed in INCLUDE_FILES, and skip everything not on that list.
	if not INCLUDE_FILES.is_empty():
		return not INCLUDE_FILES.has(file_path)

	# No include list defined — nothing else to skip.
	return false

func _export_end() -> void:
	_is_debug_export = false

func _export_begin(_features, is_debug, path, _flags):
	_is_debug_export = is_debug
	
	var source_dir := _DCKitUtilsNamespace.Setting.get_setting(
		_DCKitUtilsNamespace.Setting.SETTING_BATCH_DIR,
		"",
	)

	if not _is_enabled(is_debug):
		return
	if source_dir.is_empty():
		return

	source_dir = ProjectSettings.globalize_path(source_dir)
	var project_root = ProjectSettings.globalize_path("res://")

	if !source_dir.begins_with(project_root):
		push_error("Batch directory must be inside the project: %s" % source_dir)
		return

	if !DirAccess.dir_exists_absolute(source_dir):
		push_error("Batch directory does not exist: %s" % source_dir)
		return

	var relative: String = source_dir.trim_prefix(project_root).trim_prefix("/")
	var export_dir: String = path.get_base_dir().path_join(relative)

	_copy_text_files(source_dir, export_dir)


func _copy_text_files(source: String, destination: String) -> void:
	if DirAccess.dir_exists_absolute(source):
		DirAccess.make_dir_recursive_absolute(destination)

		var entries := DirAccess.get_directories_at(source)
		entries.append_array(DirAccess.get_files_at(source))

		for entry in entries:
			_copy_text_files(source.path_join(entry), destination.path_join(entry))
		return

	if source.get_extension().to_lower() != "txt":
		return

	var bytes := FileAccess.get_file_as_bytes(source)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.close()
