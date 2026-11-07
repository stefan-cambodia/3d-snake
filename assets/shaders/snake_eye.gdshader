shader_type spatial;
render_mode cull_back;

// Reptile eye on a sphere; local +Z is the viewing axis.
uniform vec3 iris_color : source_color = vec3(1.0, 0.72, 0.18);
uniform float pupil_width = 0.18; // 0.1 slit .. 0.6 round
uniform float glow = 0.25;

varying vec3 v_dir;

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float c = d.z;
	float iris = smoothstep(0.2, 0.28, c);
	vec2 pp = d.xy / max(c, 0.2);
	float pupil = smoothstep(1.0, 0.85, length(vec2(pp.x / max(pupil_width, 0.05), pp.y / 0.95)));
	float r = length(pp);
	vec3 col = mix(vec3(0.02, 0.02, 0.015), iris_color, iris);
	// Radial fibres and a darker limbal ring.
	float ang = atan(pp.y, pp.x);
	col *= 0.78 + 0.22 * sin(ang * 23.0) * sin(ang * 7.0 + r * 9.0);
	col = mix(col, iris_color * 1.25, smoothstep(0.55, 0.0, r) * 0.4);
	col *= mix(0.35, 1.0, smoothstep(1.25, 0.95, r));
	col = mix(col, vec3(0.005), pupil * iris);
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.05;
	EMISSION = iris_color * iris * (1.0 - pupil) * glow;
}
