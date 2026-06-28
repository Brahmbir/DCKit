shader_type spatial;

// Custom colors and sizing settings editable in the Inspector
uniform vec4 bg_color : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform vec4 line_color : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform float grid_scale = 1.0;
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;

varying vec3 world_position;

void vertex() {
	// Grab the vertex positions relative to the game world
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Scale the position coordinates according to desired spacing
	vec3 scaled_pos = world_position * grid_scale;
	
	// Create a sharp grid edge pattern using fractional values
	vec3 grid_xyz = abs(fract(scaled_pos - 0.5) - 0.5) / line_thickness;
	vec3 grid_lines = smoothstep(vec3(0.0), vec3(1.0), grid_xyz);
	
	// Find the minimum value among all axes to merge lines perfectly
	float grid_factor = min(min(grid_lines.x, grid_lines.y), grid_lines.z);
	
	// Blend background and lines based on the calculated factors
	ALBEDO = mix(line_color.rgb, bg_color.rgb, grid_factor);
	ROUGHNESS = 0.8;
}
