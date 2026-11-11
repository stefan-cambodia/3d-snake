shader_type sky;
render_mode use_debanding;

uniform vec3 sky_top : source_color = vec3(0.2, 0.42, 0.72);
uniform vec3 sky_horizon : source_color = vec3(0.98, 0.72, 0.48);
uniform vec3 sky_ground : source_color = vec3(0.18, 0.2, 0.22);
uniform vec3 cloud_tint : source_color = vec3(1.0, 0.86, 0.76);
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover = 0.75;
uniform float night = 0.0;
uniform float sun_size = 0.9994;
uniform vec2 cloud_offset = vec2(0.0);
// Northern lights: curtains of green and violet light (0 = none).
uniform float aurora = 0.0;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, sky_ground, smoothstep(0.0, -0.12, h));
	vec3 sdir = LIGHT0_DIRECTION;
	float sd = clamp(dot(d, sdir), 0.0, 1.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// Warm haze around the sun, stronger near the horizon.
	col += sun_col * pow(sd, 8.0) * 0.28 * (1.0 - 0.6 * clamp(h, 0.0, 1.0));
	col += sun_col * pow(sd, 64.0) * 0.5;
	if (!AT_CUBEMAP_PASS) {
		float disc = smoothstep(sun_size, sun_size + 0.0003, sd);
		col += sun_col * disc * (night > 0.5 ? 1.6 : 6.0);
		if (h > 0.0) {
			vec2 uv = d.xz / (h + 0.22) * 0.32 + cloud_offset;
			float c = texture(clouds, uv).r;
			c = smoothstep(1.0 - cloud_cover, 1.0, c + 0.2) * smoothstep(0.0, 0.25, h);
			vec3 ccol = cloud_tint * (0.75 + 0.6 * pow(sd, 4.0)) + sky_horizon * 0.15;
			col = mix(col, ccol, c * 0.85);
		}
		if (night > 0.5 && h > 0.0) {
			vec3 cell = floor(d * 280.0);
			float star = step(0.9965, hash13(cell));
			float tw = 0.5 + 0.5 * hash13(cell + 7.0);
			col += vec3(0.9, 0.95, 1.0) * star * tw * smoothstep(0.05, 0.4, h) * 1.4;
		}
		if (aurora > 0.0 && h > 0.04) {
			vec2 p = d.xz / (h + 0.4);
			float w1 = sin(p.x * 2.1 + TIME * 0.06 + sin(p.y * 1.4 + TIME * 0.045) * 1.7);
			float w2 = sin(p.y * 1.7 - TIME * 0.05 + sin(p.x * 0.9 - TIME * 0.03) * 2.1);
			float rays = 0.55 + 0.45 * sin(p.x * 34.0 + p.y * 11.0 + TIME * 0.35);
			float fade = smoothstep(0.06, 0.3, h) * smoothstep(0.98, 0.5, h);
			vec3 acol = mix(vec3(0.12, 1.0, 0.62), vec3(0.62, 0.32, 1.0), smoothstep(0.18, 0.7, h));
			col += acol * (smoothstep(0.5, 1.0, w1) + 0.7 * smoothstep(0.6, 1.0, w2)) * rays * fade * aurora * 0.6;
		}
	}
	COLOR = col;
}
