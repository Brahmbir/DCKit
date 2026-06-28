@tool
class_name FrostBlurRect
extends ColorRect

const BLUR_SHADER := preload("./frost_blur.gdshader")

@export_group("Blur")

@export_range(0.0, 200.0, 1)
var blur_radius: float = 80.0:
	set(value):
		blur_radius = maxf(value, 0.0)
		_sync_shader()

@export_range(0.0, 1.0, 0.01)
var blur_strength: float = 1.0:
	set(value):
		blur_strength = clampf(value, 0.0, 1.0)
		_sync_shader()

@export_group("Glass")
@export var glass_color: Color = Color(0.039, 0.055, 0.078, 0.65):
	set(value):
		glass_color = value
		_sync_shader()

@export_range(0.0, 1.0, 0.01) var darken: float = 0.35:
	set(value):
		darken = clampf(value, 0.0, 1.0)
		_sync_shader()


@export_group("Frost")

# Intensity of the fine-grain + patch frost overlay.
@export_range(0.0, 1.0, 0.01) var frost_grain: float = 0.045:
	set(value):
		frost_grain = clampf(value, 0.0, 1.0)
		_sync_shader()

# Scale of the FBM frost noise pattern.
@export_range(0.5, 8.0, 0.1) var frost_scale: float = 8.0:
	set(value):
		frost_scale = clampf(value, 0.5, 8.0)
		_sync_shader()

# Pixel-equivalent RGB channel split toward edges.
@export_range(0.0, 6.0, 0.05) var chroma_shift: float = 0.8:
	set(value):
		chroma_shift = clampf(value, 0.0, 6.0)
		_sync_shader()

# Subtle horizontal scanline amplitude (CRT / terminal flavour).
@export_range(0.0, 1.0, 0.01) var scanline_str: float = 0.0:
	set(value):
		scanline_str = clampf(value, 0.0, 1.0)
		_sync_shader()

# Radial darkening toward the panel edges for perceived depth.
@export_range(0.0, 2.0, 0.01) var edge_vignette: float = 0.22:
	set(value):
		edge_vignette = clampf(value, 0.0, 2.0)
		_sync_shader()

func _ready() -> void:
	_ensure_material()
	_sync_shader()
	_update_style()


func _update_style():
	var style := get_theme_stylebox("PanelContainer").duplicate()
	
	if style is StyleBoxFlat:
		style.bg_color = Color.WHITE

	add_theme_stylebox_override("BlurPanelContainer", style)

func _ensure_material() -> ShaderMaterial:
	if material is ShaderMaterial:
		return material as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	material  = mat
	return mat

func _sync_shader() -> void:
	var mat := _ensure_material()
	mat.set_shader_parameter("blur_radius",   blur_radius)
	mat.set_shader_parameter("blur_strength", blur_strength)
	mat.set_shader_parameter("glass_color",   glass_color)
	mat.set_shader_parameter("darken",        darken)
	mat.set_shader_parameter("frost_grain",   frost_grain)
	mat.set_shader_parameter("frost_scale",   frost_scale)
	mat.set_shader_parameter("chroma_shift",  chroma_shift)
	mat.set_shader_parameter("scanline_str",  scanline_str)
	mat.set_shader_parameter("edge_vignette", edge_vignette)
