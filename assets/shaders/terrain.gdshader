shader_type spatial;
render_mode cull_back;

// Vertex colour: r = grass amount, g = sand/dirt amount, b = darker soil, a = ao.
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.33, 0.46, 0.16);
uniform vec3 grass_b : source_color = vec3(0.58, 0.6, 0.24);
uniform vec3 sand_col : source_color = vec3(0.78, 0.68, 0.5);
uniform vec3 soil_col : source_color = vec3(0.34, 0.26, 0.17);
uniform vec3 plaza_col : source_color = vec3(0.78, 0.72, 0.62);
uniform vec3 rune_col : source_color = vec3(1.0, 0.75, 0.35);
uniform float rune_glow = 0.6;
uniform float water_level = -0.55;
uniform float plaza_radius = 9.5;
uniform float detail_scale = 0.16;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 wp = v_world.xz;
	vec3 det = texture(detail_tex, wp * detail_scale).rgb;
	vec3 det_far = texture(detail_tex, wp * detail_scale * 0.13).rgb;
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.3, 0.75, det_far.g * 0.6 + det.r * 0.5));
	grass *= 0.82 + 0.3 * det.r;
	vec3 sand = sand_col * (0.88 + 0.2 * det.b);
	vec3 soil = soil_col * (0.8 + 0.35 * det.g);
	float g = clamp(COLOR.r + (det_far.r - 0.5) * 0.5, 0.0, 1.0);
	float sd = clamp(COLOR.g, 0.0, 1.0);
	vec3 col = mix(soil, grass, smoothstep(0.25, 0.6, g));
	col = mix(col, sand, smoothstep(0.35, 0.75, sd));
	// Pebbles in the soil.
	col = mix(col, vec3(0.62, 0.6, 0.55), smoothstep(0.65, 0.85, det.b) * (1.0 - g) * 0.6);
	vec3 nmap = texture(detail_normal, wp * detail_scale).rgb;
	float rough = 0.92;
	vec3 emit = vec3(0.0);

	// Stone plaza: concentric rings of paving slabs with an engraved rune band.
	float r = length(wp);
	if (r < plaza_radius + 0.6) {
		float ang = atan(wp.y, wp.x);
		float ring_w = 1.15;
		float ring = floor(r / ring_w);
		float segs = max(6.0, floor(6.0 + ring * 6.0));
		float a01 = ang / 6.2831853 + 0.5;
		float seg = floor(a01 * segs + mod(ring, 2.0) * 0.5);
		float fr = fract(r / ring_w);
		float fa = fract(a01 * segs + mod(ring, 2.0) * 0.5);
		float joint = min(min(fr, 1.0 - fr) * ring_w, min(fa, 1.0 - fa) * 6.2831 * r / segs);
		float grout = smoothstep(0.035, 0.0, joint);
		vec3 stone = texture(stone_tex, wp * 0.22).rgb * plaza_col * 1.25;
		stone *= 0.85 + 0.3 * hash12(vec2(ring, seg));
		// Rune band.
		float band = smoothstep(0.05, 0.0, abs(r - 6.9) - 0.42);
		float glyph_cell = floor(a01 * 48.0);
		float gx = fract(a01 * 48.0);
		float gy = (r - 6.48) / 0.84;
		float h = hash12(vec2(glyph_cell, 4.0));
		float stroke = 0.0;
		stroke = max(stroke, smoothstep(0.08, 0.0, abs(gx - 0.5)) * step(0.15, gy) * step(gy, 0.85));
		stroke = max(stroke, smoothstep(0.07, 0.0, abs(gy - (0.3 + h * 0.4))) * step(0.2, gx) * step(gx, 0.8));
		stroke = max(stroke, smoothstep(0.08, 0.0, abs(gx - gy * (h > 0.5 ? 1.0 : -1.0) - (h > 0.5 ? 0.0 : 1.0))) * step(0.15, gy) * step(gy, 0.85) * step(0.3, fract(h * 7.0)));
		float rim = smoothstep(0.03, 0.0, abs(abs(r - 6.9) - 0.46));
		float engraving = clamp(stroke * band + rim, 0.0, 1.0);
		// Centre emblem: concentric rings and an eight-point star.
		float star = smoothstep(0.05, 0.0, abs(r - 2.4)) + smoothstep(0.04, 0.0, abs(r - 1.6));
		float rays = smoothstep(0.06, 0.0, abs(fract(a01 * 8.0) - 0.5) * r * 0.8) * step(r, 2.4) * step(0.5, r);
		engraving = max(engraving, max(star, rays));
		stone = mix(stone, stone * 0.45, grout);
		stone = mix(stone, vec3(0.32, 0.27, 0.2), engraving * 0.7);
		float in_plaza = smoothstep(plaza_radius + 0.5, plaza_radius - 0.1, r);
		// Moss creeping over the plaza edge.
		float moss = smoothstep(0.55, 0.8, det_far.g + det.r * 0.3) * smoothstep(plaza_radius - 3.0, plaza_radius, r);
		stone = mix(stone, grass * 0.8, moss * 0.8);
		col = mix(col, stone, in_plaza);
		nmap = mix(nmap, texture(stone_normal, wp * 0.22).rgb, in_plaza);
		rough = mix(rough, 0.75, in_plaza);
		emit += rune_col * engraving * rune_glow * in_plaza * (0.55 + 0.45 * sin(TIME * 1.5 + a01 * 12.0));
	}

	// Wet sand and foam at the water line.
	float wl = v_world.y - water_level;
	float wet = smoothstep(0.35, 0.0, wl);
	col *= mix(1.0, 0.6, wet);
	rough = mix(rough, 0.35, wet);
	float foam_line = smoothstep(0.12, 0.0, abs(wl - 0.04 - 0.05 * sin(TIME * 0.9 + wp.x * 0.3 + wp.y * 0.2)));
	foam_line *= 0.6 + 0.4 * det.r;
	col = mix(col, vec3(0.92, 0.95, 0.94), foam_line * 0.75);

	ALBEDO = col * COLOR.a;
	NORMAL_MAP = nmap;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = emit;
}
