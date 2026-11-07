class_name SnakeView
extends Node3D
## Renders a SnakeSim: GPU-skinned body tube + procedural head, eyes and tongue.
##
## Each frame the body is sampled along the spine (exact head path) into ring
## frames, a travelling lateral wave fixed in world space is added (so the body
## slides along a serpentine track like a real snake), and the frames are
## uploaded as a small float texture read by the body vertex shader.

const MAX_RINGS := 512
const BODY_SHADER := preload("res://assets/shaders/snake_body.gdshader")
const HEAD_SHADER := preload("res://assets/shaders/snake_head.gdshader")
const EYE_SHADER := preload("res://assets/shaders/snake_eye.gdshader")

const WAVE_LENGTH := 3.6
const WAVE_AMPLITUDE := 0.12
const BULGE_SPEED := 2.2
const HEAD_BACK := -0.42
const HEAD_TIP := 0.56

var sim: SnakeSim
var sides: int = 14
var ring_spacing: float = 0.26
var max_active_rings: int = 420

var _body: MeshInstance3D
var _body_mat: ShaderMaterial
var _head_pivot: Node3D
var _head: MeshInstance3D
var _head_mat: ShaderMaterial
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: ShaderMaterial
var _tongue_pivot: Node3D
var _tongue: MeshInstance3D

var _img: Image
var _tex: ImageTexture
var _data := PackedFloat32Array()
var _centers := PackedVector3Array()
var _tangents := PackedVector3Array()

var _bulges: Array[Vector2] = [] # x = arc position, y = strength
var _gulp: float = 0.0
var _flash: float = 0.0
var _surge_vis: float = 0.0
var _tongue_timer: float = 1.0
var _tongue_t: float = -1.0
var _head_yaw_offset: float = 0.0
var _head_lift: float = 0.0
var _pitch: float = 0.0
var _eye_look := Vector2.ZERO
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()

## Optional world point the eyes track (e.g. nearest food).
var look_target: Variant = null
## 0..1 extra wave/attitude while idle on menus.
var idle_amount: float = 0.0


func setup(p_sim: SnakeSim, quality: int = 2) -> void:
	sim = p_sim
	_rng.randomize()
	_build_body(quality)
	_build_head()
	set_quality(quality)


func set_quality(quality: int) -> void:
	match quality:
		0:
			ring_spacing = 0.42
			max_active_rings = 260
		1:
			ring_spacing = 0.32
			max_active_rings = 340
		_:
			ring_spacing = 0.26
			max_active_rings = 420
	if _body_mat:
		_body_mat.set_shader_parameter("detail", 0.0 if quality == 0 else 1.0)


func apply_skin(skin: Dictionary) -> void:
	for m in [_body_mat, _head_mat]:
		m.set_shader_parameter("col_back", skin["back"])
		m.set_shader_parameter("col_side", skin["side"])
		m.set_shader_parameter("col_belly", skin["belly"])
		m.set_shader_parameter("col_pattern", skin["pattern"])
		m.set_shader_parameter("col_accent", skin["accent"])
		m.set_shader_parameter("gloss", skin["gloss"])
		m.set_shader_parameter("metallic_amt", skin["metallic"])
		m.set_shader_parameter("iridescence", skin["iridescence"])
		m.set_shader_parameter("emission_amt", skin["emission"])
	_body_mat.set_shader_parameter("pattern_type", skin["pattern_type"])
	_eye_mat.set_shader_parameter("iris_color", skin["accent"])


# --- Construction -----------------------------------------------------------

func _build_body(quality: int) -> void:
	sides = 10 if quality == 0 else 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := sides + 1
	for j in MAX_RINGS:
		for k in cols:
			var th := TAU * float(k) / float(sides)
			st.set_uv(Vector2(float(k) / float(sides), float(j)))
			st.set_normal(Vector3(-cos(th), sin(th), 0.0))
			st.add_vertex(Vector3(-cos(th) * 0.4, sin(th) * 0.4, -float(j) * 0.3))
	# Rest pose: body along -Z, right = -X, up = +Y. Quads emitted clockwise from outside.
	for j in MAX_RINGS - 1:
		for k in sides:
			var a := j * cols + k
			var b := j * cols + k + 1
			var c := (j + 1) * cols + k
			var d := (j + 1) * cols + k + 1
			st.add_index(a)
			st.add_index(d)
			st.add_index(b)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	var mesh := st.commit()
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = mesh
	# Vertices are placed by the shader anywhere in the arena.
	_body.custom_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 30, 160))
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = BODY_SHADER
	_body.material_override = _body_mat
	add_child(_body)

	_data.resize(MAX_RINGS * 3 * 4)
	_img = Image.create_from_data(MAX_RINGS, 3, false, Image.FORMAT_RGBAF, _data.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	_body_mat.set_shader_parameter("spine_data", _tex)


## Head cross-section half sizes at local z: Vector3(half_width, half_height_top, half_height_bottom).
static func head_profile(z: float) -> Vector3:
	var w: float
	var ht: float
	var hb: float
	if z < -0.12:
		var t := MathUtil.smooth01(HEAD_BACK, -0.12, z)
		w = lerpf(0.35, 0.5, t)
		ht = lerpf(0.29, 0.27, t)
		hb = lerpf(0.21, 0.22, t)
	elif z < 0.12:
		var t := MathUtil.smooth01(-0.12, 0.12, z)
		w = lerpf(0.5, 0.43, t)
		ht = lerpf(0.27, 0.25, t)
		hb = lerpf(0.22, 0.18, t)
	else:
		var t := clampf((z - 0.12) / (HEAD_TIP - 0.12), 0.0, 1.0)
		var round_k := sqrt(maxf(1.0 - pow(maxf(t - 0.55, 0.0) / 0.45, 2.0), 0.0))
		w = lerpf(0.43, 0.2, t) * round_k
		ht = lerpf(0.25, 0.13, t) * round_k
		hb = lerpf(0.18, 0.08, t) * round_k
	return Vector3(w, ht, hb)


static func head_surface(z: float, phi: float) -> Vector3:
	var pr := head_profile(z)
	var c := cos(phi)
	var s := sin(phi)
	var ex := 2.0 / 2.7
	var x := signf(c) * pow(absf(c), ex) * pr.x
	var hh := pr.y if s > 0.0 else pr.z
	var y := signf(s) * pow(absf(s), ex) * hh
	# Supraocular ridges above the eyes and slight flat crown.
	var brow := exp(-pow((z - 0.1) / 0.09, 2.0)) * exp(-pow((phi if phi < PI else TAU - phi) - 0.75, 2.0) / 0.05)
	var lat := Vector3(x, y, 0.0)
	return Vector3(x, y, z) + lat.normalized() * brow * 0.035


func _build_head() -> void:
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	add_child(_head_pivot)
	var rows := 26
	var cols := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in rows:
		var z := lerpf(HEAD_BACK, HEAD_TIP, pow(float(r) / float(rows - 1), 0.9))
		var row: Array[Vector3] = []
		for c in cols:
			row.append(head_surface(z, TAU * float(c) / float(cols)))
		grid.append(row)
	for r in rows - 1:
		for c in cols:
			var c1 := (c + 1) % cols
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c1]
			var cc: Vector3 = grid[r + 1][c1]
			var d: Vector3 = grid[r + 1][c]
			var centre := Vector3(0, 0, (a.z + cc.z) * 0.5)
			var mid := (a + b + cc + d) * 0.25
			var n := (b - a).cross(d - a)
			if n.length_squared() < 1e-12:
				n = (cc - a).cross(d - a)
			if n.dot(mid - centre) >= 0.0:
				MeshKit.tri(st, a, b, cc)
				MeshKit.tri(st, a, cc, d)
			else:
				MeshKit.tri(st, a, d, cc)
				MeshKit.tri(st, a, cc, b)
	st.generate_normals()
	_head = MeshInstance3D.new()
	_head.name = "Head"
	_head.mesh = st.commit()
	_head_mat = ShaderMaterial.new()
	_head_mat.shader = HEAD_SHADER
	_head.material_override = _head_mat
	_head_pivot.add_child(_head)

	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = EYE_SHADER
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.078
	eye_mesh.height = 0.156
	eye_mesh.radial_segments = 16
	eye_mesh.rings = 10
	for side in [-1.0, 1.0]:
		var phi := 0.62 if side > 0.0 else PI - 0.62
		var surf := head_surface(0.12, phi)
		var outward := Vector3(surf.x, surf.y * 0.6, 0.0).normalized()
		var eye := MeshInstance3D.new()
		eye.name = "Eye"
		eye.mesh = eye_mesh
		eye.material_override = _eye_mat
		eye.position = surf - outward * 0.035 + Vector3(0, 0.0, 0.0)
		# Local +Z of the eye points outward and slightly forward.
		var look := (outward + Vector3(0, 0.15, 0.55)).normalized()
		eye.basis = Basis.looking_at(-look, Vector3.UP)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_pivot.add_child(eye)
		_eyes.append(eye)

	_tongue_pivot = Node3D.new()
	_tongue_pivot.name = "TonguePivot"
	_tongue_pivot.position = Vector3(0, -0.07, HEAD_TIP - 0.08)
	_head_pivot.add_child(_tongue_pivot)
	_tongue = MeshInstance3D.new()
	_tongue.mesh = _build_tongue_mesh()
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.72, 0.08, 0.16)
	tm.roughness = 0.35
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.emission_enabled = true
	tm.emission = Color(0.25, 0.0, 0.03)
	_tongue.material_override = tm
	_tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tongue_pivot.add_child(_tongue)
	_tongue_pivot.visible = false


func _build_tongue_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.018
	# Stem then two tines; flat ribbon (double-sided material).
	var pts := [Vector3(0, 0, 0), Vector3(0, 0.0, 0.26)]
	MeshKit.tri(st, Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w * 0.8, 0, 0.26))
	MeshKit.tri(st, Vector3(-w, 0, 0), Vector3(w * 0.8, 0, 0.26), Vector3(-w * 0.8, 0, 0.26))
	for side in [-1.0, 1.0]:
		var base := Vector3(side * w * 0.4, 0, 0.25)
		var tip := Vector3(side * 0.06, 0.012, 0.38)
		var perp := Vector3(-(tip - base).z, 0, (tip - base).x).normalized() * w * 0.55
		MeshKit.tri(st, base - perp, base + perp, tip)
	st.generate_normals()
	return st.commit()


# --- Per-frame update ----------------------------------------------------------

func on_pickup(kind: int) -> void:
	_bulges.append(Vector2(0.35, 1.0 if kind == Collectible.Kind.FOOD else 1.35))
	_gulp = 1.0
	_tongue_t = -1.0


func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


func flick_tongue() -> void:
	if _tongue_t < 0.0:
		_tongue_t = 0.0


func update_view(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_flash = maxf(_flash - delta * 2.2, 0.0)
	_gulp = maxf(_gulp - delta * 4.0, 0.0)
	_surge_vis = move_toward(_surge_vis, 1.0 if sim.is_surging() else 0.0, delta * 3.0)
	for i in range(_bulges.size() - 1, -1, -1):
		var b := _bulges[i]
		b.x += BULGE_SPEED * delta
		if b.x > sim.length:
			_bulges.remove_at(i)
		else:
			_bulges[i] = b
	_update_body()
	_update_head(delta)
	_body_mat.set_shader_parameter("surge", _surge_vis)
	_body_mat.set_shader_parameter("flash", _flash)
	_head_mat.set_shader_parameter("surge", _surge_vis)
	_head_mat.set_shader_parameter("flash", _flash)


func _radius_at(s: float, length: float) -> float:
	var r := GameConfig.BODY_RADIUS
	# Slim neck behind the head.
	r *= 0.78 + 0.22 * MathUtil.smooth01(0.35, 1.3, s)
	# Tail taper over the last ~35 %.
	var taper := clampf(length * 0.36, 1.4, 10.0)
	var u := clampf((length - s) / taper, 0.0, 1.0)
	r *= pow(u, 0.7) * 0.97 + 0.03 * u
	for b in _bulges:
		var d := (s - b.x) / 0.42
		r *= 1.0 + 0.3 * b.y * exp(-d * d) * (1.0 - b.x / maxf(length, 0.01))
	return r


func _update_body() -> void:
	var L := sim.length
	var spacing := maxf(ring_spacing, L / float(max_active_rings - 1))
	var n := clampi(int(ceil(L / spacing)) + 1, 6, mini(max_active_rings, MAX_RINGS))
	var step := L / float(n - 1)
	sim.spine.sample_uniform(n, step, _centers)
	if _tangents.size() < n:
		_tangents.resize(n)
	var D := sim.distance_travelled
	var amp := WAVE_AMPLITUDE * (1.0 + idle_amount * 0.6)
	# Pass 1: horizontal tangents (toward the head) and the lateral wave.
	for j in n:
		var a := _centers[maxi(j - 1, 0)]
		var b := _centers[mini(j + 1, n - 1)]
		var t := Vector3(a.x - b.x, 0.0, a.z - b.z)
		var tl := t.length()
		if tl < 0.00001:
			t = sim.forward()
		else:
			t /= tl
		_tangents[j] = t
	for j in n:
		var s := step * float(j)
		var t := _tangents[j]
		var a_s := amp * MathUtil.smooth01(0.5, 2.4, s) * (1.0 - 0.6 * MathUtil.smooth01(L - 1.5, L, s))
		if a_s > 0.0:
			var off := a_s * sin(TAU * (D - s) / WAVE_LENGTH)
			var c := _centers[j]
			_centers[j] = Vector3(c.x - t.z * off, c.y, c.z + t.x * off)
	# Pass 2: frames from the final (waved) curve, packed for the GPU.
	var glow_sum := 0.0
	for j in n:
		var s := step * float(j)
		var a := _centers[maxi(j - 1, 0)]
		var b := _centers[mini(j + 1, n - 1)]
		var t := a - b
		if t.length_squared() < 1e-10:
			t = sim.forward()
		t = t.normalized()
		var right := Vector3(-t.z, 0.0, t.x).normalized()
		var up := right.cross(t).normalized()
		var c := _centers[j]
		var rad := _radius_at(s, L)
		var glow := 0.0
		for bl in _bulges:
			var d := (s - bl.x) / 0.5
			glow += exp(-d * d) * 0.35 * bl.y * (1.0 - bl.x / maxf(L, 0.01))
		glow_sum += glow
		var i0 := j * 4
		var i1 := (MAX_RINGS + j) * 4
		var i2 := (2 * MAX_RINGS + j) * 4
		_data[i0] = c.x
		_data[i0 + 1] = c.y
		_data[i0 + 2] = c.z
		_data[i0 + 3] = rad
		_data[i1] = right.x
		_data[i1 + 1] = right.y
		_data[i1 + 2] = right.z
		_data[i1 + 3] = s
		_data[i2] = up.x
		_data[i2 + 1] = up.y
		_data[i2 + 2] = up.z
		_data[i2 + 3] = glow
	_img.set_data(MAX_RINGS, 3, false, Image.FORMAT_RGBAF, _data.to_byte_array())
	_tex.update(_img)
	_body_mat.set_shader_parameter("active_rings", n)


func _update_head(delta: float) -> void:
	var pos := sim.position
	# Anticipation: the head leads into the turn; lifts slightly under boost.
	_head_yaw_offset = MathUtil.damp(_head_yaw_offset, -sim.steer * 0.26, 0.08, delta)
	_head_lift = MathUtil.damp(_head_lift, (0.07 if sim.boosting else 0.0) + idle_amount * 0.12, 0.15, delta)
	var behind := sim.spine.point_at(0.7)
	var dy := pos.y - behind.y
	_pitch = MathUtil.damp(_pitch, -atan2(dy, 0.7) - _head_lift * 0.8, 0.1, delta)
	var yaw := sim.heading + _head_yaw_offset + sin(_time * 1.3) * 0.04 * idle_amount
	var bob := sin(sim.distance_travelled * TAU / WAVE_LENGTH * 2.0) * 0.012
	_head_pivot.position = pos + Vector3(0, _head_lift + bob, 0)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _pitch)
	var gulp := 1.0 + 0.1 * sin(_gulp * PI)
	_head_pivot.basis = basis.scaled(Vector3(gulp, 1.0 + (gulp - 1.0) * 0.6, 1.0))

	# Eyes track the look target a little.
	var want := Vector2.ZERO
	if look_target is Vector3:
		var to := _head_pivot.global_transform.affine_inverse() * (look_target as Vector3)
		want = Vector2(clampf(atan2(to.x, to.z) * 0.5, -0.25, 0.25), clampf(atan2(to.y, to.z) * 0.3, -0.12, 0.12))
	_eye_look = _eye_look.lerp(want, MathUtil.damp_factor(0.12, delta))
	var pupil := 0.16 + 0.14 * _surge_vis + (0.08 if sim.boosting else 0.0)
	_eye_mat.set_shader_parameter("pupil_width", pupil)

	# Tongue flicks: periodic, more often when idle or near food.
	_tongue_timer -= delta
	if _tongue_timer <= 0.0 and _tongue_t < 0.0:
		_tongue_t = 0.0
		_tongue_timer = _rng.randf_range(1.2, 3.4) * (0.6 if idle_amount > 0.5 else 1.0)
	if _tongue_t >= 0.0:
		_tongue_t += delta
		var dur := 0.5
		var ext := MathUtil.smooth01(0.0, 0.07, _tongue_t) * (1.0 - MathUtil.smooth01(dur - 0.08, dur, _tongue_t))
		_tongue_pivot.visible = ext > 0.02
		_tongue_pivot.scale = Vector3(1, 1, maxf(ext, 0.01))
		_tongue_pivot.rotation = Vector3(sin(_tongue_t * 38.0) * 0.35 * ext, 0, 0)
		if _tongue_t > dur:
			_tongue_t = -1.0
			_tongue_pivot.visible = false


func head_transform() -> Transform3D:
	return _head_pivot.global_transform


func body_material() -> ShaderMaterial:
	return _body_mat
