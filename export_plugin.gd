@tool
extends EditorExportPlugin

func _get_name() -> String: return "DCKitBatFileExport"

func _export_begin(features, is_debug, path, flags):
	var source_dir := _DCKitNamespace.Setting.get_setting(
		_DCKitNamespace.Setting.SETTING_BATCH_DIR,
	    ""
	)
	var _enabled = is_debug or _DCKitNamespace.Setting.get_setting(_DCKitNamespace.Setting.SETTING_ENABLED_IN_RELEASE, false)

	if not _enabled : return
	if source_dir.is_empty() : return

	source_dir = ProjectSettings.globalize_path(source_dir)
	var project_root = ProjectSettings.globalize_path("res://")

	if !source_dir.begins_with(project_root):
		push_error("Batch directory must be inside the project: %s" % source_dir)
		return

	if !DirAccess.dir_exists_absolute(source_dir):
		push_error("Batch directory does not exist: %s" % source_dir)
		return

	var relative :String= source_dir.trim_prefix(project_root).trim_prefix("/")
	var export_dir :String= path.get_base_dir().path_join(relative)
	
	_copy_text_files(source_dir, export_dir)

func _copy_text_files(source: String, destination: String) -> void:
	if DirAccess.dir_exists_absolute(source):
		DirAccess.make_dir_recursive_absolute(destination)

		var entries := DirAccess.get_directories_at(source)
		entries.append_array(DirAccess.get_files_at(source))

		for entry in entries:
			_copy_text_files(
				source.path_join(entry),
				destination.path_join(entry)
			)
		return

	if source.get_extension().to_lower() != "txt":
		return

	var bytes := FileAccess.get_file_as_bytes(source)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.close()
