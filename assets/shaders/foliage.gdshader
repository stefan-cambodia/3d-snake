shader_type spatial;
render_mode cull_back;

// Trees: vertex colour rgb = albedo, a = sway weight.
uniform float wind_strength = 1.0;
uniform vec3 tint : source_color = vec3(1.0);

void vertex() {
	vec3 world = MODEL_MATRIX[3].xyz;
	float w = COLOR.a;
	float ph = TIME * 1.1 + world.x * 0.13 + world.z * 0.17;
	VERTEX.x += sin(ph + VERTEX.y * 0.4) * 0.09 * w * wind_strength;
	VERTEX.z += cos(ph * 0.8 + VERTEX.y * 0.3) * 0.07 * w * wind_strength;
}

void fragment() {
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	BACKLIGHT = COLOR.rgb * 0.35 * COLOR.a;
}
