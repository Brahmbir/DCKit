//  blur_material.gdshader  –  Optimised Frost-Glass / Terminal
//  Technique stack (single pass, no extra viewports needed):
//    1. LOD-level blur        – mip-map "blur" at near-zero cost
//    2. FBM warp              – frost distortion on sample UVs
//    3. Chromatic aberration  – RGB fringe for glass realism
//    4. Glass tint + darken   – colour/depth of the panel
//    5. Frost grain overlay   – IGN noise + value-noise patches
//    6. Scanline hint         – subtle terminal CRT feel
//    7. Edge vignette         – depth / border softness
shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Screen back-buffer (mip levels give LOD blur for free)
uniform sampler2D screen_texture : hint_screen_texture,
                                   repeat_disable,
                                   filter_linear_mipmap;

// Core (mirror BlurRect exports)
uniform float blur_radius   : hint_range(0.0, 24.0, 0.1)  = 4.0;
uniform float blur_strength : hint_range(0.0,  1.0, 0.01) = 1.0;
uniform vec4  glass_color   : source_color = vec4(0.039, 0.055, 0.078, 0.65);
uniform float darken        : hint_range(0.0,  1.0, 0.01) = 0.35;

// Frost / atmosphere
uniform float frost_grain   : hint_range(0.0,  1.0, 0.01) = 0.045;
uniform float frost_scale   : hint_range(0.5,  8.0, 0.1)  = 3.0;
uniform float chroma_shift  : hint_range(0.0,  6.0, 0.05) = 0.8;
uniform float scanline_str  : hint_range(0.0,  1.0, 0.01) = 0.04;
uniform float edge_vignette : hint_range(0.0,  2.0, 0.01) = 0.22;


//  MATH HELPERS
// Interleaved Gradient Noise – spatially uncorrelated, never tiles.
// (Jorge Jimenez, "Filmic SMAA", SIGGRAPH 2014)
float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Fast integer hash → float
float hash21(vec2 p) {
    p  = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Bilinear value-noise
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);             // smoothstep kernel
    return mix(
        mix(hash21(i),               hash21(i + vec2(1, 0)), u.x),
        mix(hash21(i + vec2(0, 1)),  hash21(i + vec2(1, 1)), u.x),
        u.y
    );
}

// 2-octave FBM – cheap, avoids 4-octave over-kill
float fbm(vec2 p) {
    return vnoise(p) * 0.62 + vnoise(p * 2.17 + 5.31) * 0.38;
}

//  FRAGMENT
void fragment() {
    vec2 uv  = SCREEN_UV;
    vec2 px  = SCREEN_PIXEL_SIZE;
    vec2 fpx = uv / px;

    // Resolution scale: normalise to 720p so blur_radius behaves as "pixels"
    //    regardless of display size. At 4K this doubles the effective LOD.
    float res_scale     = ((1.0 / px.y) / 720.0);          // frost warp unchanged
	float blur_res_scale = ((1.0 / px.y) / 1080.0);          // only drives LOD

    // 1. LOD BLUR — scale by resolution so blur_radius = "screen pixels" always
	//float lod = log2(max(blur_radius * blur_res_scale, 0.001) + 1.0) * blur_strength;
	float lod =log2(1000.001);
    // 2. FROST UV WARP — keep warp in pixel units, not UV fraction
    float grain_field = fbm(fpx * frost_scale * 0.012);
    vec2 warp = (vec2(grain_field) - 0.5)
              * px * blur_radius * res_scale * 0.45  // <-- add res_scale here
              * blur_strength;
    vec2 uv_w = clamp(uv + warp, px, 1.0 - px);

    
    // 3. CHROMATIC ABERRATION
    //    RGB channels sampled at ±shift along the outward radial direction.
    //    Gives glass a slight prismatic fringe, especially near edges.
    vec2 radial = normalize(UV - 0.5 + 1e-5);       // from widget centre
    vec2 cab    = radial * px * chroma_shift * blur_strength;

    float r = textureLod(screen_texture, clamp(uv_w + cab,      px, 1.0-px), lod).r;
    float g = textureLod(screen_texture, uv_w,                                lod).g;
    float b = textureLod(screen_texture, clamp(uv_w - cab,      px, 1.0-px), lod).b;

    vec3 blurred = vec3(r, g, b);

    
    // 4. DARKEN + GLASS TINT
    //    Darken first (reduces bleed from bright BG), then alpha-composite
    //    the glass_color over it.
    blurred *= 1.0 - darken;
    vec3 tinted = mix(blurred, glass_color.rgb, glass_color.a);

    
    // 5. FROST GRAIN OVERLAY
    //    Two-layer: fine per-pixel IGN noise + large FBM frost patches.
    //    Blended so neither dominates.
    float fine  = ign(fpx);
    float coarse = fbm(fpx * frost_scale * 0.035);
    float frost_combined = mix(fine, coarse, 0.55);

    tinted = mix(tinted, tinted + (frost_combined - 0.5) * 0.15, frost_grain * 2.0);
    tinted = mix(tinted, vec3(frost_combined), frost_grain * 0.4);

    // 6. SCANLINE HINT  (very subtle – terminal CRT flavour)
    //    Operates in widget-local UV so lines stay fixed to the panel.
    float scan = sin(UV.y / px.y * PI) * 0.5 + 0.5;  // 1 px sine wave
    tinted *= 1.0 - scanline_str * (1.0 - scan);

    // 7. EDGE VIGNETTE
    //    Smooth distance-to-edge darkening for perceived depth/frame.
    //    Uses widget-local UV so it always fits the rect exactly.
    vec2 uv_c = UV * 2.0 - 1.0;
    float vig  = 1.0 - dot(uv_c * uv_c, vec2(edge_vignette));
    tinted    *= clamp(vig, 0.0, 1.0);


    COLOR = vec4(tinted, 1.0);
}