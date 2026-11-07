shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Ground warning circle for rising obstacles. UV centred on the disc.
uniform vec3 color : source_color = vec3(1.0, 0.35, 0.12);
uniform float progress = 0.0; // 0..1 warning progress
uniform float intensity = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float outer = smoothstep(0.04, 0.0, abs(r - 0.92));
	float inner = smoothstep(0.03, 0.0, abs(r - 0.62 - 0.05 * sin(TIME * 6.0)));
	float ticks = smoothstep(0.25, 0.0, abs(fract((a + TIME * 1.2) / 6.2831 * 16.0) - 0.5) * 2.0) * step(0.68, r) * step(r, 0.86);
	float fill = smoothstep(progress * 0.92 + 0.02, progress * 0.92, r) * 0.22;
	float pulse = 0.65 + 0.35 * sin(TIME * (8.0 + progress * 14.0));
	float m = (outer + inner * 0.8 + ticks * 0.7 + fill) * step(r, 1.0);
	ALBEDO = color * m * pulse * intensity;
}
