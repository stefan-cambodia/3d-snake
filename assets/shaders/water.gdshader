shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec3 deep_col : source_color = vec3(0.03, 0.17, 0.22);
uniform vec3 shallow_col : source_color = vec3(0.16, 0.48, 0.46);
uniform float map_extent = 256.0;
uniform float water_level = -0.55;
uniform float wave_speed = 1.0;
// Colour of the sky near the horizon, mirrored at grazing angles.
uniform vec3 sky_col : source_color = vec3(0.7, 0.8, 0.9);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = v_world.xz;
	float t = TIME * wave_speed;
	vec3 n1 = texture(normal_tex, wp * 0.045 + vec2(t * 0.012, t * 0.007)).rgb;
	vec3 n2 = texture(normal_tex, wp * 0.11 + vec2(-t * 0.016, t * 0.011)).rgb;
	vec3 n3 = texture(normal_tex, wp * 0.012 + vec2(t * 0.003, -t * 0.002)).rgb;
	vec3 nm = normalize((n1 + n2 + n3 * 0.6) / 2.6 * 2.0 - 1.0);
	vec2 huv = wp / map_extent + 0.5;
	float ground = texture(height_map, huv).r;
	if (any(lessThan(huv, vec2(0.0))) || any(greaterThan(huv, vec2(1.0)))) {
		ground = -4.0;
	}
	float depth = max(water_level - ground, 0.0);
	float shallow = 1.0 - smoothstep(0.0, 2.4, depth);
	vec3 col = mix(deep_col, shallow_col, shallow);
	// Soft foam rim on the water side of the shore.
	float foam = smoothstep(0.32, 0.0, depth) * (0.55 + 0.45 * sin(t * 1.4 + depth * 22.0 + nm.x * 4.0));
	foam *= step(0.001, depth + 0.001);
	col = mix(col, vec3(0.9, 0.95, 0.95), clamp(foam, 0.0, 1.0) * 0.7);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(col, sky_col, fres * 0.55);
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(0.06, 0.5, foam);
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
