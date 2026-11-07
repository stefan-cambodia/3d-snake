shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Vertical light beam (rare relic marker). UV.y = 0 bottom, 1 top.
uniform vec3 color : source_color = vec3(0.85, 0.55, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float v = UV.y;
	float edge = pow(1.0 - abs(UV.x - 0.5) * 2.0, 1.5);
	float stripes = 0.65 + 0.35 * sin(v * 40.0 - TIME * 6.0);
	float fade = (1.0 - v) * smoothstep(0.0, 0.05, v);
	ALBEDO = color * edge * fade * stripes * intensity;
}
