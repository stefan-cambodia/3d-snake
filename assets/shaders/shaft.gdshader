shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Shaft of sunlight falling through the haze. UV.y = 0 at the top.
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.7);
uniform float intensity = 0.12;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = pow(1.0 - abs(UV.x - 0.5) * 2.0, 1.6);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float shimmer = 0.75 + 0.25 * sin(TIME * 0.5 + v_world.x * 0.35 + UV.x * 9.0);
	// Fade when looked at edge-on or from very close, so it never reads as a card.
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color * across * along * shimmer * intensity * smoothstep(0.05, 0.5, facing);
}
