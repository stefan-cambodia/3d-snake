shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Arena boundary curtain: faint at rest, lights up near the snake head.
uniform vec3 color : source_color = vec3(1.0, 0.75, 0.35);
uniform vec3 head_pos = vec3(0.0, -100.0, 0.0);
uniform float base_alpha = 0.06;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(v_world.xz, head_pos.xz);
	float near = smoothstep(10.0, 1.0, d);
	float h = UV.y; // 0 bottom .. 1 top
	float a = UV.x * 260.0;
	float hexa = abs(fract(a + h * 6.0 + TIME * 0.2) - 0.5) * 2.0;
	float lines = smoothstep(0.85, 1.0, hexa) + smoothstep(0.08, 0.0, abs(fract(h * 6.0 + 0.5) - 0.5));
	float vfade = (1.0 - h) * smoothstep(0.0, 0.08, h);
	float glow = base_alpha * (0.6 + 0.4 * sin(TIME * 1.3 + UV.x * 40.0)) + near * (0.25 + 0.75 * lines);
	ALBEDO = color * glow * vfade;
}
