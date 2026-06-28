@tool
class_name MaskedIconPanel
extends PanelContainer

signal toggled(is_on: bool)   # emitted after every transition completes

@export var is_off: bool = true:
	set(v):
		if is_off == v: return
		is_off = v
		if not is_node_ready(): return
		_transition()

@export_group("Appearance")
@export var accent_color: Color = Color.ALICE_BLUE:
	set(v): accent_color = v; _apply_instant()

@export_range(0.0, 1.0, 0.01)
var dim_alpha: float = 0.10:
	set(v): dim_alpha = v; _apply_instant()

@export var border_width:  int = 1:
	set(v): border_width = v; _rebuild_style()
@export var border_radius: int = 6:
	set(v): border_radius = v; _rebuild_style()

@export var padding: int = 6:
	set(v): padding = v; _rebuild_style()

@export_group("Textures")
@export var texture_off: Texture2D:
	set(v): texture_off = v; _apply_instant()
@export var texture_on: Texture2D:
	set(v): texture_on = v; _apply_instant()

@export_group("Animation")
@export var duration: float = 0.20

# Shader (embedded — no external .gdshader file needed)
const MASK_SHADER := preload("./masked_icon_panel.gdshader")

var _style : StyleBoxFlat  = null
var _rect  : TextureRect   = null
var _mat   : ShaderMaterial = null
var _tween : Tween          = null

func _ready() -> void:
	_build()
	resized.connect(_on_resized)
	_apply_instant()

func _on_resized() -> void:
	if is_instance_valid(_mat):
		_mat.set_shader_parameter("rect_size", size)

func _build() -> void:
	# StyleBox: border shell only — fill is handled by the shader.
	_style = StyleBoxFlat.new()
	_style.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("panel", _style)
	_rebuild_style()   # fills in border_width, radius, content margins

	# ShaderMaterial with embedded GLSL.
	_mat = ShaderMaterial.new()
	_mat.shader = MASK_SHADER
	
	# TextureRect: single child, fills the content area.
	_rect = TextureRect.new()
	_rect.name                    = "IconRect"
	_rect.layout_mode             = 2
	_rect.expand_mode             = TextureRect.EXPAND_IGNORE_SIZE
	# Changed to STRETCH_SCALE so the shader runs across the entire control rect
	_rect.stretch_mode            = TextureRect.STRETCH_SCALE 
	_rect.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	_rect.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	_rect.mouse_filter            = Control.MOUSE_FILTER_IGNORE
	_rect.material                = _mat
	add_child(_rect)

func _rebuild_style() -> void:
	if not is_instance_valid(_style):
		return

	_style.border_color = _accent(1.0)

	for s in ["border_width_left","border_width_top",
			  "border_width_right","border_width_bottom"]:
		_style.set(s, border_width)

	for c in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_left","corner_radius_bottom_right"]:
		_style.set(c, border_radius)

	for m in ["content_margin_left","content_margin_top",
			  "content_margin_right","content_margin_bottom"]:
		_style.set(m, 0.0)
		
	_style.border_blend = false

	if is_instance_valid(_mat):
		_mat.set_shader_parameter("border_width", float(border_width))
		_mat.set_shader_parameter("corner_radius", float(border_radius))
		_mat.set_shader_parameter("padding", float(padding))


# Snap everything to the current state — no animation.
func _apply_instant() -> void:
	if not is_instance_valid(_mat) or not is_instance_valid(_rect):
		return

	_rect.texture = texture_off if is_off else texture_on

	_mat.set_shader_parameter("fill_color",    _accent(1.0))
	_mat.set_shader_parameter("tint_color",    _accent(1.0))
	_mat.set_shader_parameter("mask_strength", 0.0 if is_off else 1.0)
	_mat.set_shader_parameter("dim_alpha",     dim_alpha)
	_mat.set_shader_parameter("rect_size",     size)

	# The stylebox background stays completely transparent so the shader hole goes through
	_style.bg_color     = Color.TRANSPARENT
	_style.border_color = _accent(1.0)


# Animate between states.
func _transition() -> void:
	if not is_instance_valid(_mat) or not is_instance_valid(_rect):
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	# mask_strength carries the visual so the swap is invisible mid-fade.
	_rect.texture = texture_off if is_off else texture_on

	var target_mask : float = 0.0 if is_off else 1.0

	_tween = (create_tween()
		.set_ease(Tween.EASE_OUT)
		.set_trans(Tween.TRANS_CUBIC)
		.set_parallel(true))

	_tween.tween_property(_mat, "shader_parameter/mask_strength", target_mask, duration)
	# Tweening the stylebox bg_color has been removed since the shader does it.

	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: toggled.emit(not is_off))


func _accent(a: float) -> Color:
	return Color(accent_color.r, accent_color.g, accent_color.b, a)
