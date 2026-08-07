extends Node

const ADDON_PATH :String= "res://addons/dc_kit"

func _ready() -> void:
	var export_addon_cmd := DCDefinition.new(
		"exportAddonZip",
		func(ctx: DCContext) -> DCResult:
			if not OS.has_feature("editor"):
				return DCResult.fail("This command is only available when running from the Godot editor.")
			
			var plugin_version := get_plugin_version()
			var version := plugin_version
			if ctx.args_length() > 1:
				return DCResult.fail("Usage: exportAddonZip [version]")
			
			if ctx.args_length() == 1:
				var arg := (await ctx.arg(0)).value.as_string()

				var regex := RegEx.new()
				regex.compile("^\\d+(?:\\.\\d+)*(?:-[A-Za-z0-9]+)?$")

				if not regex.search(arg):
					return DCResult.fail(
						"Invalid version. Expected format: MAJOR.MINOR.PATCH[-alpha|-beta|-rc] (e.g. 0.0.1, 0.0.1-alpha)."
					)
				
				if compare_versions(arg, plugin_version) > 0:
					var err_config := set_plugin_version(arg)
					if err_config != OK:
						return DCResult.fail("Couldn't update plugin.cfg.")
					
					version = arg

			var output_zip := "res://tmp/DCKit-v%s.zip" % version

			var err := addon_export(
				ADDON_PATH,
				output_zip,
				{
					"res://LICENSE": "addons/dc_kit/LICENSE",
					"res://README.md": "addons/dc_kit/README.md",
					"res://icon.svg": "addons/dc_kit/icon.svg"
				}
			)

			if err != OK:
				return DCResult.fail("Failed to export addon (Error %d)." % err)

			return DCResult.ok(
				"Addon exported successfully.\nOutput: %s"
				% ProjectSettings.globalize_path(output_zip)
			),
		"Exports a Godot addon as a ZIP archive.",
		[
			DCDefinition.Param.new("version")
				.describe("Addon version (e.g. 0.0.1 or 0.9.0-<alpha/beta/rc>]).").suggest([get_plugin_version()])
		],
		true
	)

	DCKit.register_def(export_addon_cmd)
	

static func addon_export(
	addon_path: String,
	output_zip: String,
	extra_files: Dictionary = {}
) -> Error:

	var output_dir := output_zip.get_base_dir()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_dir)
	)

	var zipper := ZIPPacker.new()

	var err := zipper.open(output_zip)
	if err != OK:
		return err

	err = _zip_directory(zipper, addon_path)
	if err != OK:
		zipper.close()
		return err

	for source in extra_files:
		err = _zip_file(zipper, source, extra_files[source])
		if err != OK:
			zipper.close()
			return err

	zipper.close()
	return OK


static func _zip_directory(
	zipper: ZIPPacker,
	directory: String
) -> Error:

	var dir := DirAccess.open(directory)
	if dir == null:
		return ERR_CANT_OPEN

	dir.list_dir_begin()

	while true:
		var filename := dir.get_next()

		if filename.is_empty():
			break
#
		#if filename.begins_with("."):
			#continue
#
		#if filename.get_extension() == "import":
			#continue

		var full_path := directory.path_join(filename)

		if dir.current_is_dir():
			var err := _zip_directory(zipper, full_path)
			if err != OK:
				dir.list_dir_end()
				return err
		else:
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file == null:
				dir.list_dir_end()
				return ERR_CANT_OPEN

			var archive_path := full_path.trim_prefix("res://")

			var err := zipper.start_file(archive_path)
			if err != OK:
				file.close()
				dir.list_dir_end()
				return err

			err = zipper.write_file(
				file.get_buffer(file.get_length())
			)

			file.close()

			if err != OK:
				dir.list_dir_end()
				return err

	dir.list_dir_end()
	return OK


static func _zip_file(
	zipper: ZIPPacker,
	source: String,
	destination: String
) -> Error:

	if not FileAccess.file_exists(source):
		return OK

	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN

	var err := zipper.start_file(destination)
	if err != OK:
		file.close()
		return err

	err = zipper.write_file(
		file.get_buffer(file.get_length())
	)

	file.close()

	return err

#region helper methods

static func get_plugin_version() -> String:
	var cfg := ConfigFile.new()

	if cfg.load(ADDON_PATH + "/plugin.cfg") != OK:
		return "0.0.0"

	return cfg.get_value("plugin", "version", "0.0.0")


static func set_plugin_version(version_str: String) -> Error:
	var cfg := ConfigFile.new()

	var err := cfg.load(ADDON_PATH + "/plugin.cfg")
	if err != OK:
		return err

	cfg.set_value("plugin", "version", version_str)
	return cfg.save(ADDON_PATH + "/plugin.cfg")

static func compare_versions(a: String, b: String) -> int:
	var pa := _parse_version(a)
	var pb := _parse_version(b)
	
	var count := maxi(pa.numbers.size(), pb.numbers.size())

	for i in count:
		var av :int= pa.numbers[i] if i < pa.numbers.size() else 0
		var bv :int= pb.numbers[i] if i < pb.numbers.size() else 0

		if av < bv:
			return -1
		elif av > bv:
			return 1

	var order := {
		"": 3,
		"rc": 2,
		"beta": 1,
		"alpha": 0,
	}

	var ar : int = order.get(pa.suffix, -1)
	var br : int = order.get(pb.suffix, -1)

	if ar < br:
		return -1
	elif ar > br:
		return 1

	return 0


static func _parse_version(version_str: String) -> Dictionary:
	var split := version_str.split("-", false)

	var numbers: Array[int] = []

	for s in split[0].split("."):
		numbers.append(s.to_int())

	return {
		"numbers": numbers,
		"suffix": split[1].to_lower() if split.size() > 1 else ""
	}

#endregion
