shader_type spatial;
render_mode cull_back;

// Vertex colour: r = grass amount, g = sand/dirt amount, b = paved stone (ramps,
// terrace edges), a = ambient occlusion. Steep faces (terrace walls) are drawn
// as dressed-stone masonry.
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
uniform vec3 sandstone_col : source_color = vec3(0.66, 0.61, 0.52);
uniform vec3 laterite_col : source_color = vec3(0.52, 0.38, 0.3);
uniform vec3 moss_col : source_color = vec3(0.22, 0.32, 0.12);

varying vec3 v_world;
varying vec3 v_nrm;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Running-bond stone courses on a wall face: x = mortar (0..1), y = block tone,
// z = edge darkening. u runs along the wall, y is world height.
vec3 courses(float u, float y) {
	// Large dressed blocks; course heights vary a little from course to course.
	float ch = 0.62;
	float c = floor(y / ch);
	float fy = fract(y / ch);
	float len = 1.05 + 0.75 * hash12(vec2(c, 1.7));
	float bu = (u + hash12(vec2(c, 3.1)) * len) / len;
	float b = floor(bu);
	float fx = fract(bu);
	// Joints wander slightly so the courses do not look machine-cut.
	float wob = (hash12(vec2(b, c + 9.0)) - 0.5) * 0.06;
	float edge = min(min(fy + wob, 1.0 - fy - wob) * ch, min(fx, 1.0 - fx) * len);
	float mortar = 1.0 - smoothstep(0.008, 0.03, edge);
	float bevel = 1.0 - smoothstep(0.02, 0.13, edge);
	// x: joint, y: block tone, z: worn edge (darker, rounded).
	return vec3(mortar, hash12(vec2(b, c)), bevel * (0.6 + 0.4 * hash12(vec2(c, b + 4.0))));
}

// Square paving slabs (ramps and terrace edges): x = grout, y = slab tone.
vec2 slabs(vec2 p) {
	vec2 q = p / vec2(1.1, 0.8);
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float edge = min(min(f.x, 1.0 - f.x) * 1.1, min(f.y, 1.0 - f.y) * 0.8);
	return vec2(1.0 - smoothstep(0.015, 0.045, edge), hash12(cell));
}

void fragment() {
	vec2 wp = v_world.xz;
	vec3 det = texture(detail_tex, wp * detail_scale).rgb;
	vec3 det_far = texture(detail_tex, wp * detail_scale * 0.13).rgb;
	vec3 n = normalize(v_nrm);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.3, 0.75, det_far.g * 0.6 + det.r * 0.5));
	grass *= 0.82 + 0.3 * det.r;
	// Broad lush and sun-dried patches across the island.
	float dry = smoothstep(0.42, 0.72, texture(detail_tex, wp * 0.021).b);
	grass = mix(grass * vec3(0.92, 1.0, 0.9), grass * vec3(1.18, 1.06, 0.72), dry * 0.55);
	vec3 sand = sand_col * (0.88 + 0.2 * det.b);
	vec3 soil = soil_col * (0.8 + 0.35 * det.g);
	float g = clamp(COLOR.r + (det_far.r - 0.5) * 0.5, 0.0, 1.0);
	float sd = clamp(COLOR.g, 0.0, 1.0);
	// Hill slopes wear through to bare earth where they get steeper.
	g *= 1.0 - 0.55 * smoothstep(0.95, 0.88, n.y) * smoothstep(0.35, 0.65, det.g + det_far.b * 0.4);
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

	// Paved ramps and terrace edges.
	float pv = clamp(COLOR.b, 0.0, 1.0);
	if (pv > 0.01) {
		vec2 sl = slabs(wp);
		vec3 stone = texture(stone_tex, wp * 0.22).rgb * plaza_col * 1.2;
		stone *= 0.8 + 0.35 * sl.y;
		stone = mix(stone, laterite_col * 1.1, step(0.86, sl.y) * 0.6);
		float moss_g = smoothstep(0.5, 0.8, det_far.g + det.r * 0.35) * 0.7 + sl.x * 0.4;
		stone = mix(stone, mix(stone * 0.5, grass * 0.7, moss_g), sl.x);
		float k = smoothstep(0.15, 0.6, pv);
		col = mix(col, stone, k);
		nmap = mix(nmap, texture(stone_normal, wp * 0.22).rgb, k);
		rough = mix(rough, 0.78, k);
	}

	// Terrace walls: weathered sandstone courses on a laterite footing.
	float wall = smoothstep(0.88, 0.74, n.y);
	if (wall > 0.0) {
		float wx = n.x * n.x;
		float wz = n.z * n.z;
		float wsum = max(wx + wz, 1e-4);
		vec3 ca = courses(v_world.z, v_world.y);
		vec3 cb = courses(v_world.x + 17.3, v_world.y);
		vec3 cm = (ca * wx + cb * wz) / wsum;
		float u = (v_world.z * wx + v_world.x * wz) / wsum;
		// Surface grain and big weathering patches.
		vec3 grain = texture(detail_tex, vec2(u, v_world.y) * 0.9).rgb;
		vec3 patches = texture(detail_tex, vec2(u, v_world.y) * 0.11).rgb;
		// Laterite footing (the occluded foot of the wall), sandstone above, and
		// a few odd blocks.
		float lat = clamp(step(0.82, cm.y) + 1.0 - smoothstep(0.62, 0.86, COLOR.a), 0.0, 1.0);
		vec3 block = mix(sandstone_col, laterite_col, lat * 0.85);
		block *= 0.86 + 0.22 * fract(cm.y * 7.31);
		block *= 0.8 + 0.35 * grain.r;
		block *= mix(0.78, 1.08, patches.g);
		block *= 1.0 - 0.22 * cm.z;
		block = mix(block, block * 0.55, cm.x);
		// Dark run-off streaks from the top, and moss in damp places.
		float streak = smoothstep(0.45, 0.85, texture(detail_tex, vec2(u * 0.7, v_world.y * 0.05)).b);
		block *= 1.0 - 0.3 * streak;
		float moss = smoothstep(0.58, 0.88, patches.r * 0.7 + grain.g * 0.35 + cm.x * 0.3);
		float lip = smoothstep(0.78, 0.9, n.y);
		block = mix(block, moss_col * (0.75 + 0.45 * grain.r), clamp(moss * 0.6 + lip * 0.35, 0.0, 0.8));
		col = mix(col, block, wall);
		nmap = mix(nmap, vec3(0.5, 0.5, 1.0), wall);
		rough = mix(rough, 0.9, wall);
	}

	// Wet sand and foam at the water line.
	float wl = v_world.y - water_level;
	float wet = smoothstep(0.35, 0.0, wl);
	col *= mix(1.0, 0.6, wet);
	rough = mix(rough, 0.35, wet);
	float foam_line = smoothstep(0.12, 0.0, abs(wl - 0.04 - 0.05 * sin(TIME * 0.9 + wp.x * 0.3 + wp.y * 0.2)));
	foam_line *= 0.6 + 0.4 * det.r;
	col = mix(col, vec3(0.92, 0.95, 0.94), foam_line * 0.75);

	float ao = clamp(COLOR.a, 0.0, 1.0);
	ALBEDO = col * mix(1.0, ao, 0.65);
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL_MAP = nmap;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = emit;
}
