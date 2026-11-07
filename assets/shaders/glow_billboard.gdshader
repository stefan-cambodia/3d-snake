shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Soft additive halo, always facing the camera.
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.4);
uniform float intensity = 1.0;
instance uniform float fade = 1.0;
instance uniform vec3 inst_color = vec3(1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - d, 0.0), 2.4);
	ALBEDO = color * inst_color * a * intensity * fade;
}
