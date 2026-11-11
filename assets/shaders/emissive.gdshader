shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// Glowing parts of the architecture (flames, crystals, lantern lights).
// Vertex colour = light colour; a slow, uneven pulse keeps them alive.
uniform float intensity = 2.2;
uniform float pulse = 0.25;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float p = 1.0 - pulse + pulse * sin(TIME * 2.3 + v_world.x * 0.9 + v_world.z * 0.7 + v_world.y * 1.7);
	ALBEDO = COLOR.rgb * intensity * p;
}
