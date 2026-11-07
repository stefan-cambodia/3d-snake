shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

// Grass blades in a MultiMesh. COLOR.a of each vertex = sway weight (0 root, 1 tip).
uniform vec3 base_col : source_color = vec3(0.2, 0.32, 0.1);
uniform vec3 tip_col : source_color = vec3(0.6, 0.62, 0.26);
uniform vec3 player_pos = vec3(0.0, -100.0, 0.0);
uniform float wind_strength = 1.0;

varying float v_tip;
varying float v_var;

void vertex() {
	vec3 world = VERTEX;
	float w = COLOR.a;
	float phase = dot(world.xz, vec2(0.21, 0.17)) + TIME * 1.7;
	vec2 sway = vec2(sin(phase), cos(phase * 0.73)) * 0.12 * wind_strength * w * w;
	// Push away from the snake's head.
	vec2 away = world.xz - player_pos.xz;
	float d = length(away);
	float push = smoothstep(1.4, 0.2, d) * step(abs(world.y - player_pos.y), 1.5);
	sway += (d > 0.001 ? away / d : vec2(0.0)) * push * 0.45 * w;
	vec3 offs = vec3(sway.x, -push * 0.25 * w, sway.y);
	VERTEX += offs;
	v_tip = w;
	v_var = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = mix(base_col, tip_col * (0.85 + 0.3 * v_var), v_tip);
	ALBEDO = col * mix(0.55, 1.0, v_tip);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * v_tip;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
