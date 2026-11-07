shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Body tube skinned on the GPU: every vertex stores (around, ring index) in UV.
// Ring frames are uploaded each frame into a small float texture:
//   row 0: centre.xyz, radius
//   row 1: right.xyz,  arc length from head (m)
//   row 2: up.xyz,     glow amount
uniform sampler2D spine_data : filter_nearest, repeat_disable;
uniform int active_rings = 2;

uniform vec3 col_back : source_color = vec3(0.07, 0.3, 0.17);
uniform vec3 col_side : source_color = vec3(0.22, 0.52, 0.27);
uniform vec3 col_belly : source_color = vec3(0.86, 0.8, 0.5);
uniform vec3 col_pattern : source_color = vec3(0.02, 0.08, 0.05);
uniform vec3 col_accent : source_color = vec3(1.0, 0.72, 0.18);
uniform int pattern_type = 0;
uniform float gloss = 0.55;
uniform float metallic_amt = 0.0;
uniform float iridescence = 0.15;
uniform float emission_amt = 0.0;
uniform float surge = 0.0;
uniform float flash = 0.0;
uniform float detail = 1.0; // 0 = low quality (no scale relief)

varying float v_s;
varying float v_u;
varying float v_up;
varying float v_glow;

void vertex() {
	int j = clamp(int(UV.y + 0.5), 0, max(active_rings - 1, 0));
	vec4 c = texelFetch(spine_data, ivec2(j, 0), 0);
	vec4 r = texelFetch(spine_data, ivec2(j, 1), 0);
	vec4 u = texelFetch(spine_data, ivec2(j, 2), 0);
	float theta = UV.x * TAU;
	float cs = cos(theta);
	float sn = sin(theta);
	float wx = 1.06;
	float wy = sn > 0.0 ? 0.92 : 0.68; // flattened belly
	VERTEX = c.xyz + (r.xyz * (cs * wx) + u.xyz * (sn * wy)) * c.w;
	NORMAL = normalize(r.xyz * (cs / wx) + u.xyz * (sn / wy));
	TANGENT = normalize(-r.xyz * sn + u.xyz * cs);
	BINORMAL = normalize(cross(u.xyz, r.xyz));
	v_s = r.w;
	v_u = UV.x;
	v_up = sn;
	v_glow = u.w;
}

float scale_height(vec2 g) {
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(g) - 0.5;
	float d = abs(f.x) * 1.05 + abs(f.y) * 0.95;
	float plate = smoothstep(0.52, 0.34, d);
	// Overlapping shingles: each scale is raised at its rear edge.
	return plate * (0.55 + 0.45 * (0.5 + f.y));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// Angular distance from the dorsal line (0 = spine top, 1 = belly midline).
	float a = abs(fract(v_u - 0.25 + 0.5) - 0.5) * 2.0;
	float top = v_up;

	// --- Scale relief ---------------------------------------------------------
	vec2 g = vec2(v_u * 26.0, v_s * 8.0);
	float belly = smoothstep(-0.45, -0.7, top);
	float h = scale_height(g);
	vec3 nm = vec3(0.5, 0.5, 1.0);
	if (detail > 0.5) {
		float e = 0.08;
		float hx = scale_height(g + vec2(e, 0.0)) - h;
		float hy = scale_height(g + vec2(0.0, e)) - h;
		// Ventral scutes: wide transverse plates on the belly.
		float scute = smoothstep(0.0, 0.18, fract(v_s * 4.2)) * smoothstep(1.0, 0.82, fract(v_s * 4.2));
		hy = mix(hy, (smoothstep(0.0, 0.18, fract((v_s + 0.02) * 4.2)) - smoothstep(0.0, 0.18, fract(v_s * 4.2))) * 0.6, belly);
		hx = mix(hx, 0.0, belly);
		h = mix(h, scute, belly);
		nm = normalize(vec3(-hx * 3.2, -hy * 3.2, 1.0)) * 0.5 + 0.5;
	}
	NORMAL_MAP = nm;

	// --- Base colouring ------------------------------------------------------
	vec3 col = mix(col_side, col_back, smoothstep(0.15, 0.85, top));
	col = mix(col, col_belly, smoothstep(-0.3, -0.72, top));

	// --- Pattern -------------------------------------------------------------
	float pat = 0.0;
	float accent_mask = 0.0;
	float glow_mask = 0.0;
	float seg = v_s / 0.95;
	float p = fract(seg) - 0.5;
	if (pattern_type == 0) {
		// Dorsal diamond chain with lighter centres + lateral blotches.
		float dd = abs(p) * 1.25 + a * 2.1;
		float ring = smoothstep(0.62, 0.55, dd) - smoothstep(0.44, 0.37, dd);
		pat = ring + smoothstep(0.22, 0.16, length(vec2(fract(seg + 0.5) - 0.5, (a - 0.55) * 2.2))) * 0.8;
		accent_mask = smoothstep(0.36, 0.2, dd) * 0.25;
	} else if (pattern_type == 1) {
		// Transverse bands with thin accent borders (coral / ember).
		float b = abs(fract(v_s / 0.75) - 0.5);
		pat = smoothstep(0.17, 0.13, b) * (1.0 - belly * 0.8);
		accent_mask = (smoothstep(0.23, 0.2, b) - smoothstep(0.16, 0.13, b)) * (1.0 - belly);
		glow_mask = 1.0 - h;
	} else if (pattern_type == 2) {
		// Long stripes along the flanks.
		pat = smoothstep(0.07, 0.035, abs(a - 0.38)) + smoothstep(0.05, 0.02, a) * 0.8;
		accent_mask = pat;
	} else if (pattern_type == 3) {
		// Saddles across the back.
		float sd = length(vec2(p * 1.3, a * 1.5));
		pat = smoothstep(0.38, 0.3, sd) * (0.7 + 0.3 * smoothstep(0.24, 0.32, sd));
	} else if (pattern_type == 5) {
		// Glowing rune segments running along the spine.
		float cell = floor(v_s * 1.6);
		float rnd = hash12(vec2(cell, 3.0));
		float local = fract(v_s * 1.6);
		float line = smoothstep(0.06, 0.02, a) * step(0.2, local) * step(local, 0.75);
		float tick = smoothstep(0.03, 0.0, abs(local - 0.48)) * step(a, 0.18 + rnd * 0.12);
		glow_mask = max(line, tick) * step(0.25, rnd);
		pat = glow_mask * 0.4;
	}
	pat *= 1.0 - belly * 0.85;
	col = mix(col, col_pattern, clamp(pat, 0.0, 1.0));
	col = mix(col, col_accent, clamp(accent_mask, 0.0, 1.0) * 0.6);

	// Fine speckle and per-scale tint variation.
	float rnd = hash12(floor(g));
	col *= 0.9 + 0.2 * rnd;
	// Crevice occlusion between scales; darker towards the ground.
	float cav = mix(0.55, 1.0, smoothstep(0.0, 0.35, h));
	col *= cav;
	col *= mix(0.55, 1.0, smoothstep(-1.0, -0.35, top));

	ALBEDO = col;
	ROUGHNESS = mix(0.85, 1.0 - gloss * 0.78, smoothstep(0.1, 0.5, h));
	METALLIC = metallic_amt * smoothstep(0.1, 0.5, h);
	SPECULAR = 0.5;
	RIM = 0.25 * gloss;
	RIM_TINT = 0.6;

	// Iridescent sheen at grazing angles.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fres * 1.4 + v_s * 0.05 + vec3(0.0, 0.33, 0.67)));
	vec3 emit = irid * fres * iridescence * 0.35 * smoothstep(-0.2, 0.5, top);

	float pulse = 0.65 + 0.35 * sin(TIME * 2.4 - v_s * 1.3);
	emit += col_accent * glow_mask * emission_amt * pulse * 1.6;
	// Energy surge: bright waves travelling from head to tail.
	float wave = 0.5 + 0.5 * sin(v_s * 3.2 - TIME * 16.0);
	emit += col_accent * surge * (0.25 + 0.9 * wave * wave) * (0.4 + 0.6 * h);
	emit += vec3(1.0, 0.85, 0.6) * v_glow * 1.5;
	emit += vec3(1.0, 0.25, 0.15) * flash;
	EMISSION = emit;
}
