class_name Effects
extends Node3D
## Pooled one-shot visual effects: sparkle bursts, shockwave rings, dust, flashes.

const GLOW_SHADER := preload("res://assets/shaders/glow_billboard.gdshader")
const POOL_SIZE := 6

var _soft_tex: Texture2D
var _bursts: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _flashes: Array[MeshInstance3D] = []
var _next := {"burst": 0, "dust": 0, "ring": 0, "flash": 0}
var _anims: Array[Dictionary] = []
var quality: int = 2


func setup(soft_tex: Texture2D) -> void:
	_soft_tex = soft_tex
	for i in POOL_SIZE:
		_bursts.append(_make_particles(28, 0.75, false))
		_dust.append(_make_particles(20, 1.2, true))
		_rings.append(_make_ring())
		_flashes.append(_make_flash())


func _make_particles(amount: int, life: float, dusty: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 10, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25 if not dusty else 0.8
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 75.0 if not dusty else 50.0
	pm.initial_velocity_min = 2.0 if not dusty else 0.8
	pm.initial_velocity_max = 5.5 if not dusty else 2.4
	pm.gravity = Vector3(0, -5.5, 0) if not dusty else Vector3(0, 0.4, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5 if not dusty else 1.0
	pm.scale_max = 1.2 if not dusty else 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18) if not dusty else Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if not dusty else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_tex
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_ring() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	m.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func _make_flash() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func _take(kind: String, pool: Array) -> Variant:
	var i: int = _next[kind]
	_next[kind] = (i + 1) % pool.size()
	return pool[i]


func burst(pos: Vector3, color: Color, scale_mult: float = 1.0) -> void:
	var p: GPUParticles3D = _take("burst", _bursts)
	(p.process_material as ParticleProcessMaterial).color = color
	(p.process_material as ParticleProcessMaterial).initial_velocity_max = 5.5 * scale_mult
	p.amount = int(28 * (0.5 if quality == 0 else 1.0))
	p.global_position = pos
	p.restart()
	p.emitting = true


func dust(pos: Vector3, color: Color = Color(0.72, 0.62, 0.48, 0.8)) -> void:
	var p: GPUParticles3D = _take("dust", _dust)
	(p.process_material as ParticleProcessMaterial).color = color
	p.global_position = pos
	p.restart()
	p.emitting = true


func ring(pos: Vector3, color: Color, max_scale: float = 2.6, duration: float = 0.45) -> void:
	var m: MeshInstance3D = _take("ring", _rings)
	m.global_position = pos
	m.visible = true
	_anims.append({"node": m, "t": 0.0, "dur": duration, "type": "ring", "color": color, "max": max_scale})


func flash(pos: Vector3, color: Color, size: float = 4.0, duration: float = 0.35) -> void:
	var m: MeshInstance3D = _take("flash", _flashes)
	m.global_position = pos
	m.visible = true
	(m.material_override as ShaderMaterial).set_shader_parameter("color", color)
	_anims.append({"node": m, "t": 0.0, "dur": duration, "type": "flash", "size": size})


func _process(delta: float) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		a["t"] = float(a["t"]) + delta
		var k := clampf(float(a["t"]) / float(a["dur"]), 0.0, 1.0)
		var node: MeshInstance3D = a["node"]
		if a["type"] == "ring":
			var s := lerpf(0.3, float(a["max"]), ease(k, 0.35))
			node.scale = Vector3(s, 0.5, s)
			var c: Color = a["color"]
			(node.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, (1.0 - k) * 0.9)
		else:
			node.scale = Vector3.ONE * float(a["size"]) * (0.6 + 0.4 * k)
			(node.material_override as ShaderMaterial).set_shader_parameter("intensity", (1.0 - k) * 2.0)
		if k >= 1.0:
			node.visible = false
			_anims.remove_at(i)
