shader_type spatial;
render_mode cull_back;

// Snake head. Local space: +Z forward (snout), +Y up, X lateral.
uniform vec3 col_back : source_color = vec3(0.07, 0.3, 0.17);
uniform vec3 col_side : source_color = vec3(0.22, 0.52, 0.27);
uniform vec3 col_belly : source_color = vec3(0.86, 0.8, 0.5);
uniform vec3 col_pattern : source_color = vec3(0.02, 0.08, 0.05);
uniform vec3 col_accent : source_color = vec3(1.0, 0.72, 0.18);
uniform float gloss = 0.55;
uniform float metallic_amt = 0.0;
uniform float iridescence = 0.15;
uniform float emission_amt = 0.0;
uniform float surge = 0.0;
uniform float flash = 0.0;
uniform float mouth_y = -0.06;

varying vec3 v_local;
varying vec3 v_lnormal;

void vertex() {
	v_local = VERTEX;
	v_lnormal = NORMAL;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 p = v_local;
	float up = v_lnormal.y;
	vec3 col = mix(col_side, col_back, smoothstep(-0.05, 0.75, up));
	col = mix(col, col_belly, smoothstep(-0.25, -0.65, up));

	// Large head plates on top, small scales elsewhere (cellular pattern).
	vec2 q = up > 0.45 ? p.xz * vec2(9.0, 7.0) : vec2(atan(p.x, p.y) * 4.0, p.z * 14.0);
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float d = max(abs(f.x), abs(f.y));
	float plate = smoothstep(0.5, 0.36, d);
	col *= 0.86 + 0.24 * hash12(cell);
	col *= mix(0.62, 1.0, plate);

	// Dark mask stripe through the eye toward the jaw, and a crown chevron.
	float stripe = smoothstep(0.035, 0.0, abs(p.y - (0.05 - p.z * 0.25)) - 0.02) * step(-0.4, p.z) * smoothstep(0.1, 0.4, abs(v_lnormal.x));
	float chevron = smoothstep(0.05, 0.0, abs(abs(p.x) * 1.3 - (p.z + 0.35) * 0.55) - 0.025) * step(0.6, up) * step(p.z, 0.05);
	col = mix(col, col_pattern, max(stripe * 0.8, chevron * 0.85));

	// Mouth line along the lips.
	float lip = smoothstep(0.012, 0.0, abs(p.y - mouth_y - p.z * 0.03)) * step(-0.12, p.z) * smoothstep(0.15, 0.45, abs(v_lnormal.x) + max(p.z, 0.0));
	col = mix(col, vec3(0.03, 0.01, 0.01), lip * 0.85);
	// Nostrils.
	vec2 nos = vec2(abs(p.x) - 0.075, p.z - 0.43);
	float nostril = smoothstep(0.022, 0.012, length(vec2(nos.x, nos.y * 0.7))) * step(0.0, p.y);
	col = mix(col, vec3(0.02), nostril);

	ALBEDO = col;
	ROUGHNESS = mix(0.8, 1.0 - gloss * 0.78, plate);
	METALLIC = metallic_amt * plate;
	RIM = 0.25 * gloss;
	RIM_TINT = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (fres * 1.4 + vec3(0.0, 0.33, 0.67)));
	EMISSION = irid * fres * iridescence * 0.35 * smoothstep(-0.2, 0.6, up)
		+ col_accent * surge * 0.35 + col_accent * emission_amt * (1.0 - plate) * 0.6
		+ vec3(1.0, 0.25, 0.15) * flash;
}
