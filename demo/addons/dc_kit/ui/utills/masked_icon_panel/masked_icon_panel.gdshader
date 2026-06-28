shader_type canvas_item;

// Background accent fill
uniform vec4 fill_color : source_color = vec4(1.0);
// OFF-state icon tint
uniform vec4 tint_color : source_color = vec4(1.0);

// 0 = OFF state
// 1 = ON state
uniform float mask_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float dim_alpha = 0.10;
uniform vec2 rect_size = vec2(100.0);
uniform float border_width = 1.0;
uniform float corner_radius = 6.0;
uniform float padding = 6.0;

void fragment() {
	vec2 center = rect_size * 0.5;
	vec2 p = (UV * rect_size) - center;

	// 1) Background SDF
	// Draws the background perfectly flushed against the inner edge of the StyleBox border
	vec2 bg_half = (rect_size * 0.5) - vec2(border_width);
	float bg_radius = max(0.0, corner_radius - border_width);
	
	vec2 q = abs(p) - bg_half + vec2(bg_radius);
	float bg_dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - bg_radius;
	float bg_mask = clamp(0.5 - bg_dist, 0.0, 1.0);

	// 2) Padding and Aspect Ratio
	// Scales UVs so the texture sits perfectly inside the padding bounds while retaining aspect
	float inset = border_width + padding;
	vec2 padded_size = max(vec2(1.0), rect_size - vec2(inset * 2.0));
	vec2 uv = ((UV * rect_size) - vec2(inset)) / padded_size;

	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	if (tex_size.x > 0.0 && tex_size.y > 0.0) {
		float aspect_rect = padded_size.x / padded_size.y;
		float aspect_tex = tex_size.x / tex_size.y;

		if (aspect_rect > aspect_tex) {
			float scale = aspect_tex / aspect_rect;
			uv.x = (uv.x - 0.5) / scale + 0.5;
		} else {
			float scale = aspect_rect / aspect_tex;
			uv.y = (uv.y - 0.5) / scale + 0.5;
		}
	}

	vec4 tex = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		tex = texture(TEXTURE, uv);
	}

	// 3) State Mixing
	// OFF: Dimmed background with the tinted icon overlayed
	vec4 off_bg = vec4(fill_color.rgb, fill_color.a * dim_alpha * bg_mask);
	vec4 off_icon = vec4(tint_color.rgb, tex.a * tint_color.a);
	vec4 off_state = mix(off_bg, vec4(off_icon.rgb, 1.0), off_icon.a);

	// ON: Solid background with a transparent hole punched out using the texture alpha mask
	float hole_alpha = 1.0 - tex.a;
	vec4 on_state = vec4(fill_color.rgb, fill_color.a * bg_mask * hole_alpha);

	COLOR = mix(off_state, on_state, mask_strength);
}