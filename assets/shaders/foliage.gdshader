shader_type spatial;
render_mode cull_back;

// Trees: vertex colour rgb = albedo, a = sway weight.
uniform float wind_strength = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
// A sanctuary can give the leaves its own two colours (leaf_mix = 1); each tree
// picks a blend of the two from its position. Bark (COLOR.a = 0) is left alone.
uniform float leaf_mix = 0.0;
uniform vec3 leaf_col : source_color = vec3(0.24, 0.42, 0.16);
uniform vec3 leaf_col_b : source_color = vec3(0.36, 0.46, 0.14);

varying float tree_hash;

void vertex() {
	vec3 world = MODEL_MATRIX[3].xyz;
	float w = COLOR.a;
	tree_hash = fract(sin(dot(world.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float ph = TIME * 1.1 + world.x * 0.13 + world.z * 0.17;
	VERTEX.x += sin(ph + VERTEX.y * 0.4) * 0.09 * w * wind_strength;
	VERTEX.z += cos(ph * 0.8 + VERTEX.y * 0.3) * 0.07 * w * wind_strength;
}

void fragment() {
	// Keep each leaf cluster's own brightness (0.34 = brightness of the default leaf green).
	float lum = dot(COLOR.rgb, vec3(0.3, 0.6, 0.1)) / 0.34;
	vec3 own = mix(leaf_col, leaf_col_b, tree_hash) * lum;
	vec3 base = mix(COLOR.rgb, own, leaf_mix * step(0.05, COLOR.a));
	ALBEDO = base * tint;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	BACKLIGHT = base * 0.35 * COLOR.a;
}
