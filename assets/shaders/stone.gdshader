shader_type spatial;
render_mode cull_back;

// Weathered stone with moss on upward faces. Vertex colour: rgb tint, a = rune mask.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 moss_col : source_color = vec3(0.24, 0.36, 0.12);
uniform vec3 rune_col : source_color = vec3(1.0, 0.62, 0.25);
uniform float uv_scale = 0.5;
uniform float moss_amount = 1.0;
uniform float rune_base = 0.35;
// Extra rune light while a monolith rises (set on that monolith's own copy of
// the material). Deliberately not an instance uniform: under OpenGL, Godot
// caps objects using instance uniforms at 256 in total.
uniform float rune_glow = 0.0;

varying vec3 v_wnormal;
varying vec3 v_world;
varying vec2 v_origin;

void vertex() {
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_origin = MODEL_MATRIX[3].xz;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 col = texture(albedo_tex, uv).rgb * COLOR.rgb;
	// Each stone gets its own tint, from where it stands.
	col *= 0.9 + 0.2 * hash12(floor(v_origin * 2.3) + 0.5);
	float d = texture(detail_tex, v_world.xz * 0.21 + v_world.y * 0.13).g;
	float up = smoothstep(0.35, 0.85, v_wnormal.y);
	float low = smoothstep(0.9, 0.0, v_world.y + 0.3);
	float moss = clamp(up * smoothstep(0.35, 0.65, d) + low * smoothstep(0.45, 0.7, d) * 0.8, 0.0, 1.0) * moss_amount;
	col = mix(col, moss_col * (0.75 + 0.5 * d), moss);
	// Rune glyphs on marked faces (COLOR.a), procedurally laid out in UV cells.
	float rune = 0.0;
	if (COLOR.a < 0.5) {
		vec2 g = UV * vec2(3.0, 5.0);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float h = hash12(cell);
		float s1 = smoothstep(0.07, 0.0, abs(f.x - 0.5)) * step(0.15, f.y) * step(f.y, 0.85);
		float s2 = smoothstep(0.07, 0.0, abs(f.y - (0.25 + 0.5 * h))) * step(0.2, f.x) * step(f.x, 0.8);
		float s3 = smoothstep(0.07, 0.0, abs(f.x - f.y)) * step(0.5, h) * step(0.15, f.y) * step(f.y, 0.85);
		float s4 = smoothstep(0.05, 0.0, abs(length(f - 0.5) - 0.28)) * step(h, 0.3);
		rune = clamp(s1 * step(0.2, fract(h * 13.0)) + s2 + s3 + s4, 0.0, 1.0) * (1.0 - COLOR.a * 2.0);
		col = mix(col, col * 0.4, rune);
	}
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = mix(0.86, 0.95, moss);
	SPECULAR = 0.35;
	EMISSION = rune_col * rune * (rune_base + rune_glow) * (0.75 + 0.25 * sin(TIME * 3.0 + v_world.y * 2.0));
}
