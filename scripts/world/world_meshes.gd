class_name WorldMeshes
extends RefCounted
## Procedural models for the sanctuary: ruins, obstacles, vegetation, landmarks.
## All meshes are generated once and cached; instances only reference them.

const STONE_TINT := Color(1.0, 0.97, 0.9, 1.0)
const RUNE := Color(1.0, 1.0, 1.0, 0.0) # vertex alpha 0 = rune face for stone.gdshader


static func _noise(seed_value: int, freq: float = 1.0) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n


## Fluted classical column on a square plinth. `broken` gives a shattered top.
static func column(height: float, radius: float, broken: bool, seed_value: int, segments: int = 16) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var prof := PackedVector2Array()
	var kinds: Array[int] = [] # 0 square plinth, 1 round moulding, 2 fluted shaft, 3 broken edge
	var add := func(r: float, y: float, k: int) -> void:
		prof.append(Vector2(r * radius, y))
		kinds.append(k)
	add.call(1.42, -0.3, 0)
	add.call(1.42, 0.32, 0)
	add.call(1.25, 0.32, 1)
	add.call(1.16, 0.44, 1)
	add.call(1.04, 0.52, 1)
	add.call(1.0, 0.6, 2)
	var shaft_top := height - 0.62 if not broken else height
	var steps := maxi(int(shaft_top / 0.7), 2)
	for i in range(1, steps + 1):
		var y := lerpf(0.6, shaft_top, float(i) / float(steps))
		add.call(1.0 - 0.08 * (y / maxf(height, 1.0)), y, 2)
	if broken:
		add.call(0.75, height + 0.06, 3)
		add.call(0.3, height - 0.08, 3)
		add.call(0.0, height - 0.14, 3)
	else:
		add.call(1.06, height - 0.5, 1)
		add.call(1.22, height - 0.36, 1)
		add.call(1.42, height - 0.3, 0)
		add.call(1.42, height, 0)
		add.call(0.0, height, 0)
	var flutes := 12
	var dents := []
	for i in 8:
		dents.append(Vector2(rng.randf() * TAU, rng.randf_range(0.0, height)))
	var radial := func(a: float, row: int) -> float:
		var k: int = kinds[row]
		var y: float = prof[row].y
		var f := 1.0
		if k == 0:
			# Square cross-section with softened corners.
			var c := absf(cos(a))
			var s := absf(sin(a))
			f = 1.0 / pow(pow(c, 6.0) + pow(s, 6.0), 1.0 / 6.0) * 0.82
		elif k == 2:
			f = 1.0 - 0.055 * pow(absf(sin(a * float(flutes) * 0.5)), 0.6)
		elif k == 3:
			f = 0.75 + 0.5 * MathUtil.hash01(int(a * 40.0) + seed_value)
		for d in dents:
			var da := absf(wrapf(a - d.x, -PI, PI))
			if da < 0.5 and absf(y - d.y) < 0.5:
				f -= 0.08 * (1.0 - da / 0.5) * (1.0 - absf(y - d.y) / 0.5)
		return f
	return MeshKit.lathe(prof, segments, radial, STONE_TINT, Vector2(3.0, 0.5), false, false)


## Standing stone with rune faces (also used for rising obstacles). `shape`:
## 0 plain slab, 1 stele on a plinth with a pediment, 2 obelisk with a pointed
## top, 3 post under a small roof. All stay inside the slab's footprint (the
## collision is two circles of 0.5 m at +-0.38 m).
static func monolith(height: float, seed_value: int, shape: int = 0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var w := 0.78
	var d := 0.42
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.06, 0.06))
	var tw := 0.72
	var body_top := height
	if shape == 1:
		lean = Vector3.ZERO
		body_top = height - 0.42
	elif shape == 2:
		tw = 0.5
		body_top = height - 0.5
	elif shape == 3:
		lean = Vector3.ZERO
		tw = 0.86
		body_top = height - 0.5
	var slant := 0.18 if shape == 0 else 0.0
	# The decorated shapes have a slimmer body, so their plinth and cap can stand
	# proud of it without leaving the slab's footprint.
	var full_w := w
	var full_d := d
	if shape != 0:
		w *= 0.86
		d *= 0.84
	var c: Array[Vector3] = [
		Vector3(-w, -0.6, -d), Vector3(w, -0.6, -d), Vector3(w, -0.6, d), Vector3(-w, -0.6, d),
		Vector3(-w * tw, body_top, -d * 0.85) + lean, Vector3(w * tw, body_top - slant, -d * 0.85) + lean,
		Vector3(w * tw, body_top - slant, d * 0.85) + lean, Vector3(-w * tw, body_top, d * 0.85) + lean,
	]
	MeshKit.add_hexahedron(st, c, STONE_TINT, 0.5)
	var dark := STONE_TINT * 0.88
	dark.a = 1.0
	if shape == 1:
		# Plinth and a stepped pediment.
		MeshKit.add_hexahedron(st, _box(Vector3(0, -0.6, 0), Vector3(full_w * 2.0, 0.95, full_d * 2.0), 1.0), dark, 0.5)
		MeshKit.add_hexahedron(st, _box(Vector3(0, body_top, 0), Vector3(w * tw * 2.3, 0.14, full_d * 2.0), 1.0), dark, 0.5)
		MeshKit.add_hexahedron(st, _box(Vector3(0, body_top + 0.14, 0), Vector3(w * tw * 2.0, 0.28, d * 1.6), 0.3), STONE_TINT, 0.5)
	elif shape == 2:
		MeshKit.add_hexahedron(st, _box(Vector3(0, -0.6, 0), Vector3(full_w * 2.0, 0.9, full_d * 2.0), 1.0), dark, 0.5)
		MeshKit.add_hexahedron(st, _box(lean + Vector3(0, body_top, 0), Vector3(w * tw * 2.0, 0.5, d * 1.7), 0.04), STONE_TINT, 0.5)
	elif shape == 3:
		MeshKit.add_hexahedron(st, _box(Vector3(0, -0.6, 0), Vector3(full_w * 2.0, 0.85, full_d * 2.0), 1.0), dark, 0.5)
		MeshKit.add_hexahedron(st, _box(Vector3(0, body_top, 0), Vector3(full_w * 2.0, 0.12, full_d * 2.0), 1.0), dark, 0.5)
		MeshKit.add_hexahedron(st, _box(Vector3(0, body_top + 0.12, 0), Vector3(full_w * 1.9, 0.38, full_d * 1.9), 0.2), STONE_TINT, 0.5)
	# Rune plates on both broad faces (slightly proud of the surface).
	for side in [-1.0, 1.0]:
		var z: float = d * side * 1.02
		var zt: float = d * 0.85 * side * 1.02
		var p0 := Vector3(-w * 0.62, 0.35, z)
		var p1 := Vector3(w * 0.62, 0.35, z)
		var p2 := Vector3(w * tw * 0.62, body_top - 0.5, zt) + lean
		var p3 := Vector3(-w * tw * 0.62, body_top - 0.38 - (0.12 if shape != 0 else 0.0), zt) + lean
		if side > 0.0:
			MeshKit.tri(st, p0, p1, p2, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), RUNE)
			MeshKit.tri(st, p0, p2, p3, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), RUNE)
		else:
			MeshKit.tri(st, p1, p0, p3, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), RUNE)
			MeshKit.tri(st, p1, p3, p2, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), RUNE)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Boulder cluster matching Obstacle.KIND_ROCKS circles.
static func rocks(big: float, height: float, seed_value: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _noise(seed_value, 1.2)
	var col := Color(0.86, 0.84, 0.8)
	MeshKit.add_blob(st, Vector3(0, 0.0, 0), Vector3(big * 1.05, height, big), 2, n, 0.28, col, -0.15)
	MeshKit.add_blob(st, Vector3(big * 0.9, 0.0, 0), Vector3(big * 0.62, height * 0.6, big * 0.62), 2, n, 0.3, col * 0.95, -0.15)
	MeshKit.add_blob(st, Vector3(-big * 0.7, 0.0, big * 0.6), Vector3(big * 0.35, height * 0.3, big * 0.35), 1, n, 0.3, col, -0.1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Box corners for MeshKit.add_hexahedron: base centre, size, top scale.
static func _box(pos: Vector3, size: Vector3, taper: float) -> Array[Vector3]:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	return [pos + Vector3(-hx, 0, -hz), pos + Vector3(hx, 0, -hz), pos + Vector3(hx, 0, hz), pos + Vector3(-hx, 0, hz),
		pos + Vector3(-hx * taper, size.y, -hz * taper), pos + Vector3(hx * taper, size.y, -hz * taper),
		pos + Vector3(hx * taper, size.y, hz * taper), pos + Vector3(-hx * taper, size.y, hz * taper)]


## Stone brazier; the fire is added by the view at 1.45 m. `shape`: 0 scalloped
## bowl on a pedestal, 1 slender chalice, 2 square fire-altar. All within 0.72 m.
static func brazier(shape: int = 0) -> ArrayMesh:
	var p: PackedVector2Array
	match shape:
		1:
			p = PackedVector2Array([
				Vector2(0.5, -0.2), Vector2(0.5, 0.08), Vector2(0.3, 0.16), Vector2(0.14, 0.4), Vector2(0.12, 0.86), Vector2(0.2, 0.92),
				Vector2(0.14, 0.98), Vector2(0.4, 1.14), Vector2(0.62, 1.4), Vector2(0.66, 1.5), Vector2(0.56, 1.5), Vector2(0.4, 1.3), Vector2(0.0, 1.24),
			])
		2:
			p = PackedVector2Array([
				Vector2(0.7, -0.2), Vector2(0.7, 0.2), Vector2(0.56, 0.2), Vector2(0.56, 1.0), Vector2(0.7, 1.0), Vector2(0.7, 1.22),
				Vector2(0.6, 1.22), Vector2(0.66, 1.5), Vector2(0.54, 1.5), Vector2(0.44, 1.3), Vector2(0.0, 1.26),
			])
		_:
			p = PackedVector2Array([
				Vector2(0.62, -0.2), Vector2(0.62, 0.12), Vector2(0.5, 0.18), Vector2(0.3, 0.3), Vector2(0.24, 0.9),
				Vector2(0.3, 1.0), Vector2(0.55, 1.12), Vector2(0.68, 1.36), Vector2(0.72, 1.5), Vector2(0.6, 1.5),
				Vector2(0.48, 1.32), Vector2(0.0, 1.26),
			])
	var radial := func(a: float, row: int) -> float:
		if shape == 2:
			# Square, with softened corners (kept inside the round footprint).
			var c := absf(cos(a))
			var s := absf(sin(a))
			return 1.0 / pow(pow(c, 6.0) + pow(s, 6.0), 1.0 / 6.0) * 0.8
		if shape == 0:
			return 1.0 - (0.06 * absf(sin(a * 4.0)) if row >= 6 and row <= 8 else 0.0)
		return 1.0 - (0.05 * absf(sin(a * 6.0)) if row >= 7 and row <= 9 else 0.0)
	return MeshKit.lathe(p, 18, radial, STONE_TINT, Vector2(3.0, 0.6))


## Ruined wall section of stacked blocks along local X (matches 3 circles).
static func wall(height: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rows := maxi(int(height / 0.45), 2)
	for r in rows:
		var y0 := -0.3 + float(r) * 0.45
		var offset := 0.0 if r % 2 == 0 else 0.48
		var x := -1.5 + offset * 0.5
		while x < 1.45:
			var bw := rng.randf_range(0.75, 1.05)
			var x1 := minf(x + bw, 1.5)
			# Top rows crumble away toward the ends.
			var keep := r < rows - 2 or rng.randf() > 0.35 + absf((x + x1) * 0.5) * 0.3
			if keep and x1 - x > 0.25:
				var j := rng.randf_range(-0.03, 0.03)
				var dz := 0.4 + rng.randf_range(-0.04, 0.04)
				var yt := y0 + 0.43 + rng.randf_range(-0.03, 0.02)
				var c: Array[Vector3] = [
					Vector3(x + 0.02, y0, -dz + j), Vector3(x1 - 0.02, y0, -dz + j), Vector3(x1 - 0.02, y0, dz + j), Vector3(x + 0.02, y0, dz + j),
					Vector3(x + 0.04, yt, -dz + j + 0.02), Vector3(x1 - 0.04, yt, -dz + j + 0.02), Vector3(x1 - 0.04, yt, dz + j - 0.02), Vector3(x + 0.04, yt, dz + j - 0.02),
				]
				var tint := STONE_TINT * rng.randf_range(0.85, 1.05)
				tint.a = 1.0
				MeshKit.add_hexahedron(st, c, tint, 0.6)
			x = x1
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Column lying on its side along local X, half sunk, with a loose drum.
static func fallen_column(seed_value: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft := column(3.4, 0.48, true, seed_value, 14)
	var xf := Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(-1.75, 0.3, 0))
	st.append_from(shaft, 0, xf)
	var drum := MeshKit.lathe(PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 0.7), Vector2(0.0, 0.7)]), 14, Callable(), STONE_TINT, Vector2(3, 0.5))
	st.append_from(drum, 0, Transform3D(Basis(Vector3(1, 0, 0), 1.3), Vector3(1.9, 0.2, 0.3)))
	return st.commit()


## Grass clump: thin tapered blades. Vertex alpha = sway weight.
static func grass_clump(blades: int, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in blades:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.22)
		var base := Vector3(cos(a) * r, -0.02, sin(a) * r)
		var h := rng.randf_range(0.28, 0.55)
		var lean_dir := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.18)
		var face := rng.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face)) * rng.randf_range(0.025, 0.04)
		var mid := base + Vector3(0, h * 0.55, 0) + lean_dir * 0.4
		var tip := base + Vector3(0, h, 0) + lean_dir
		var c0 := Color(1, 1, 1, 0.0)
		var c1 := Color(1, 1, 1, 0.55)
		var c2 := Color(1, 1, 1, 1.0)
		for v in [[base - side, c0], [base + side, c0], [mid + side * 0.6, c1], [base - side, c0], [mid + side * 0.6, c1], [mid - side * 0.6, c1], [mid - side * 0.6, c1], [mid + side * 0.6, c1], [tip, c2]]:
			st.set_color(v[1])
			st.set_normal(Vector3(0, 1, 0).lerp(-Vector3(cos(face + PI * 0.5), 0, sin(face + PI * 0.5)), 0.35).normalized())
			st.add_vertex(v[0])
	return st.commit()


## Stylised broadleaf tree with a bent trunk and clustered canopy.
static func broadleaf_tree(seed_value: int, leaf: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.32, 0.24, 0.17, 0.0)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var h := rng.randf_range(4.5, 6.5)
	var bend := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
	for i in 6:
		var t := float(i) / 5.0
		pts.append(Vector3(0, t * h, 0) + bend * t * t)
		radii.append(lerpf(0.32, 0.14, t))
	MeshKit.add_tube(st, pts, radii, 7, bark, 0.5, false)
	var n := _noise(seed_value, 1.4)
	var top := pts[pts.size() - 1]
	for i in rng.randi_range(5, 7):
		var off := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.8, 0.9), rng.randf_range(-1.6, 1.6))
		var sz := rng.randf_range(1.1, 1.7)
		var c := leaf * rng.randf_range(0.8, 1.15)
		c.a = 1.0
		MeshKit.add_blob(st, top + off, Vector3(sz, sz * 0.8, sz), 1, n, 0.35, c, -INF, false)
	st.generate_normals()
	return st.commit()


## Tall narrow cypress.
static func cypress_tree(seed_value: int, leaf: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.3, 0.22, 0.16, 0.0)
	MeshKit.add_tube(st, PackedVector3Array([Vector3.ZERO, Vector3(0, 1.4, 0)]), PackedFloat32Array([0.2, 0.15]), 6, bark, 0.5, false)
	var n := _noise(seed_value, 1.8)
	var h := rng.randf_range(6.0, 8.5)
	var layers := 6
	for i in layers:
		var t := float(i) / float(layers - 1)
		var r := lerpf(1.1, 0.35, t) * rng.randf_range(0.9, 1.1)
		var c := leaf * lerpf(0.75, 1.05, t)
		c.a = clampf(t + 0.3, 0.0, 1.0)
		MeshKit.add_blob(st, Vector3(0, 1.4 + t * (h - 1.8), 0), Vector3(r, (h - 1.4) / float(layers) * 0.95, r), 1, n, 0.25, c, -INF, false)
	st.generate_normals()
	return st.commit()


static func bush(seed_value: int, leaf: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _noise(seed_value, 2.0)
	for i in 3:
		var c := leaf * rng.randf_range(0.75, 1.05)
		c.a = 0.5
		var s := rng.randf_range(0.5, 0.85)
		MeshKit.add_blob(st, Vector3(rng.randf_range(-0.5, 0.5), s * 0.5, rng.randf_range(-0.5, 0.5)), Vector3(s, s * 0.75, s), 1, n, 0.3, c, 0.0, false)
	st.generate_normals()
	return st.commit()


## Lily pad with a notch (flat disc on the water).
static func lily_pad() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 14
	var col := Color(0.22, 0.42, 0.16, 0.2)
	for i in seg:
		var a0 := 0.35 + (TAU - 0.35) * float(i) / float(seg)
		var a1 := 0.35 + (TAU - 0.35) * float(i + 1) / float(seg)
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.5
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.5
		# CCW seen from above (+Y): centre, p1, p0.
		MeshKit.tri(st, Vector3(0, 0.01, 0), p1, p0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)
	st.generate_normals()
	return st.commit()


## Stone lantern post for the arena ring.
static func lantern_post() -> ArrayMesh:
	var p := PackedVector2Array([
		Vector2(0.32, -0.2), Vector2(0.32, 0.15), Vector2(0.2, 0.25), Vector2(0.16, 1.15), Vector2(0.34, 1.25),
		Vector2(0.34, 1.32), Vector2(0.2, 1.36), Vector2(0.2, 1.62), Vector2(0.42, 1.68), Vector2(0.1, 1.95), Vector2(0.0, 2.0),
	])
	var radial := func(a: float, row: int) -> float:
		if row <= 1 or row == 4 or row == 5 or row == 8:
			var c := absf(cos(a))
			var s := absf(sin(a))
			return 1.0 / pow(pow(c, 4.0) + pow(s, 4.0), 0.25) * 0.85
		return 1.0
	return MeshKit.lathe(p, 8, radial, STONE_TINT, Vector2(2.0, 0.6))


## Coiled serpent statue (landmark), built from the same tube primitive as the snake.
static func serpent_statue() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var turns := 2.6
	var n := 90
	for i in n:
		var t := float(i) / float(n - 1)
		var a := t * turns * TAU
		var rad := lerpf(4.2, 1.4, t)
		var y := 0.6 + t * 4.0
		pts.append(Vector3(cos(a) * rad, y, sin(a) * rad))
		radii.append(lerpf(0.3, 1.0, MathUtil.smooth01(0.0, 0.25, t)) * lerpf(1.0, 0.78, t))
	# Rising neck and head.
	var last := pts[n - 1]
	var dir := (pts[n - 1] - pts[n - 2]).normalized()
	for i in range(1, 14):
		var t := float(i) / 13.0
		var p := last + dir * t * 1.5 + Vector3(0, t * 5.5, 0) - dir * t * t * 2.2
		pts.append(p)
		radii.append(lerpf(0.78, 0.62, t))
	MeshKit.add_tube(st, pts, radii, 12, STONE_TINT, 0.3, true)
	var head_pos := pts[pts.size() - 1]
	var nz := _noise(5, 1.0)
	MeshKit.add_blob(st, head_pos + Vector3(0, 0.25, 0) + dir * 0.3, Vector3(1.0, 0.55, 1.4), 2, nz, 0.06, STONE_TINT)
	# Hood fan.
	MeshKit.add_blob(st, head_pos - Vector3(0, 1.0, 0) - dir * 0.1, Vector3(1.7, 1.6, 0.35), 2, nz, 0.05, STONE_TINT)
	# Plinth.
	var plinth := MeshKit.lathe(PackedVector2Array([Vector2(5.4, -1.0), Vector2(5.4, 0.35), Vector2(5.0, 0.6), Vector2(0.0, 0.6)]), 24, Callable(), STONE_TINT, Vector2(8.0, 0.5))
	st.generate_normals()
	st.generate_tangents()
	st.index() # the plinth below is indexed: a merged surface must be indexed throughout
	var mesh := st.commit()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.append_from(mesh, 0, Transform3D())
	st2.append_from(plinth, 0, Transform3D())
	return st2.commit()


## Monumental temple gate (landmark).
static func temple_gate() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := column(13.0, 1.25, false, 77, 18)
	st.append_from(col, 0, Transform3D(Basis(), Vector3(-5.5, 1.2, 0)))
	st.append_from(col, 0, Transform3D(Basis(), Vector3(5.5, 1.2, 0)))
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.set_smooth_group(-1)
	var lintel: Array[Vector3] = [
		Vector3(-8.2, 14.2, -1.6), Vector3(8.2, 14.2, -1.6), Vector3(8.2, 14.2, 1.6), Vector3(-8.2, 14.2, 1.6),
		Vector3(-8.6, 16.2, -1.8), Vector3(8.6, 16.2, -1.8), Vector3(8.6, 16.2, 1.8), Vector3(-8.6, 16.2, 1.8),
	]
	MeshKit.add_hexahedron(st2, lintel, STONE_TINT, 0.4)
	var roof: Array[Vector3] = [
		Vector3(-8.0, 16.2, -1.5), Vector3(8.0, 16.2, -1.5), Vector3(8.0, 16.2, 1.5), Vector3(-8.0, 16.2, 1.5),
		Vector3(-1.5, 18.6, -0.6), Vector3(1.5, 18.6, -0.6), Vector3(1.5, 18.6, 0.6), Vector3(-1.5, 18.6, 0.6),
	]
	MeshKit.add_hexahedron(st2, roof, STONE_TINT, 0.4)
	for i in 4:
		var w := 9.5 - float(i) * 0.6
		var y0 := -1.0 + float(i) * 0.55
		var d := 4.0 - float(i) * 0.6
		var stepc: Array[Vector3] = [
			Vector3(-w, y0, -d), Vector3(w, y0, -d), Vector3(w, y0, d), Vector3(-w, y0, d),
			Vector3(-w, y0 + 0.55, -d), Vector3(w, y0 + 0.55, -d), Vector3(w, y0 + 0.55, d), Vector3(-w, y0 + 0.55, d),
		]
		MeshKit.add_hexahedron(st2, stepc, STONE_TINT * 0.95, 0.5)
	st2.generate_normals()
	st2.generate_tangents()
	st2.index()
	st.append_from(st2.commit(), 0, Transform3D())
	return st.commit()


## Distant mountain ring (vertex coloured, fogged).
static func mountains(seed_value: int, inner: float, outer: float) -> ArrayMesh:
	var n := _noise(seed_value, 0.012)
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 160
	var rows := 7
	var cols := segs + 1
	for r in rows:
		var t := float(r) / float(rows - 1)
		var rad := lerpf(inner, outer, t)
		for s in cols:
			var a := TAU * float(s) / float(segs)
			var x := cos(a) * rad
			var z := sin(a) * rad
			var ridge := n.get_noise_2d(x, z) * 0.5 + 0.5
			var envelope := sin(t * PI) * (0.55 + 0.45 * sin(a * 3.0 + 1.3))
			var h := lerpf(-2.0, 70.0, pow(ridge, 1.6) * envelope) if r > 0 else -3.0
			var snow := MathUtil.smooth01(38.0, 52.0, h)
			var c := Color(0.32, 0.38, 0.36).lerp(Color(0.5, 0.52, 0.55), MathUtil.smooth01(5.0, 30.0, h)).lerp(Color(0.92, 0.94, 0.96), snow)
			st.set_color(c)
			st.add_vertex(Vector3(x, h, z))
	# Rows go outward, columns go clockwise seen from above; emit clockwise from above.
	for r in rows - 1:
		for s in segs:
			var i00 := r * cols + s
			var i01 := i00 + 1
			var i10 := i00 + cols
			var i11 := i10 + 1
			st.add_index(i00)
			st.add_index(i11)
			st.add_index(i01)
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i11)
	st.generate_normals()
	return st.commit()


# --- More vegetation and ground cover --------------------------------------------

## Triangle seen from both sides (the foliage shader culls back faces).
static func _leaf_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [b, cb]]:
		st.set_color(v[1])
		st.add_vertex(v[0])


## Palm with a leaning ringed trunk and a crown of arching fronds.
static func palm_tree(seed_value: int, leaf: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.4, 0.32, 0.22, 0.0)
	var h := rng.randf_range(6.0, 8.0)
	var bend := Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(0, t * h, 0) + bend * t * t)
		radii.append(lerpf(0.3, 0.16, t) * (1.0 + 0.12 * float(i % 2)))
	MeshKit.add_tube(st, pts, radii, 7, bark, 0.5, false)
	var top := pts[8]
	for f in 9:
		var a := TAU * float(f) / 9.0 + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var length := rng.randf_range(2.6, 3.4)
		var prev := top
		var prev_w := 0.12
		for sgm in range(1, 6):
			var t := float(sgm) / 5.0
			var p := top + dir * length * t + Vector3(0, 0.9 * sin(t * PI * 0.75) - 1.3 * t * t, 0)
			var w := 0.5 * sin(t * PI) + 0.04
			var c0 := leaf * lerpf(0.8, 1.1, t)
			c0.a = clampf(t + 0.2, 0.0, 1.0)
			_leaf_tri(st, prev - side * prev_w, prev + side * prev_w, p + side * w, c0, c0, c0)
			_leaf_tri(st, prev - side * prev_w, p + side * w, p - side * w, c0, c0, c0)
			prev = p
			prev_w = w
	st.generate_normals()
	return st.commit()


## Conifer: a straight trunk and tiers of drooping boughs.
static func pine_tree(seed_value: int, leaf: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.28, 0.2, 0.15, 0.0)
	var h := rng.randf_range(7.0, 9.5)
	MeshKit.add_tube(st, PackedVector3Array([Vector3.ZERO, Vector3(0, h * 0.5, 0), Vector3(0, h, 0)]), PackedFloat32Array([0.26, 0.16, 0.04]), 6, bark, 0.5, false)
	var tiers := 6
	for i in tiers:
		var t := float(i) / float(tiers - 1)
		var y := lerpf(h * 0.22, h * 0.9, t)
		var r := lerpf(2.3, 0.5, t) * rng.randf_range(0.9, 1.1)
		var top := Vector3(0, y + lerpf(1.7, 1.0, t), 0)
		var sides := 8
		var col := leaf * lerpf(0.6, 0.9, t)
		col.a = clampf(0.3 + t * 0.5, 0.0, 1.0)
		var tipc := col * 1.15
		tipc.a = col.a
		for sgm in sides:
			var a0 := TAU * float(sgm) / float(sides)
			var a1 := TAU * float(sgm + 1) / float(sides)
			var k0 := 1.0 if sgm % 2 == 0 else 0.72
			var k1 := 1.0 if (sgm + 1) % 2 == 0 else 0.72
			var p0 := Vector3(cos(a0) * r * k0, y - 0.25 * k0, sin(a0) * r * k0)
			var p1 := Vector3(cos(a1) * r * k1, y - 0.25 * k1, sin(a1) * r * k1)
			_leaf_tri(st, top, p1, p0, tipc, col, col)
	st.generate_normals()
	return st.commit()


## Bare, weathered tree.
static func dead_tree(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.34, 0.3, 0.27, 0.0)
	var h := rng.randf_range(4.0, 5.5)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 6:
		var t := float(i) / 5.0
		pts.append(Vector3(0, t * h, 0) + lean * t * t)
		radii.append(lerpf(0.3, 0.08, t))
	MeshKit.add_tube(st, pts, radii, 6, bark, 0.5, true)
	for b in 5:
		var from := pts[2 + b % 4]
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), rng.randf_range(0.5, 1.1), sin(a)).normalized()
		var len := rng.randf_range(1.4, 2.6)
		var mid := from + dir * len * 0.5 + Vector3(0, 0.15, 0)
		var tip := from + dir * len + Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4))
		MeshKit.add_tube(st, PackedVector3Array([from, mid, tip]), PackedFloat32Array([0.11, 0.07, 0.02]), 5, bark, 0.5, true)
	st.generate_normals()
	return st.commit()


## Fern: a rosette of arching fronds.
static func fern(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in 6:
		var a := TAU * float(f) / 6.0 + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var length := rng.randf_range(0.35, 0.6)
		var prev := Vector3(0, 0.02, 0)
		var prev_w := 0.02
		for sgm in range(1, 4):
			var t := float(sgm) / 3.0
			var p := dir * length * t + Vector3(0, 0.38 * sin(t * PI * 0.8), 0)
			var w := 0.13 * sin(t * PI) + 0.01
			var c := Color(0.07, 0.17, 0.06).lerp(Color(0.17, 0.3, 0.1), t)
			c.a = t
			_leaf_tri(st, prev - side * prev_w, prev + side * prev_w, p + side * w, c, c, c)
			_leaf_tri(st, prev - side * prev_w, p + side * w, p - side * w, c, c, c)
			prev = p
			prev_w = w
	st.generate_normals()
	return st.commit()


## Small flowering plant: a few stems, each with a five-petal bloom.
static func flowers(seed_value: int, petal: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.2, 0.42, 0.14, 0.3)
	for s in 3:
		var base := Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.22, 0.22))
		var h := rng.randf_range(0.22, 0.42)
		var top := base + Vector3(rng.randf_range(-0.06, 0.06), h, rng.randf_range(-0.06, 0.06))
		var g1 := green
		g1.a = 0.9
		_leaf_tri(st, base + Vector3(-0.012, 0, 0), base + Vector3(0.012, 0, 0), top, green, green, g1)
		var pc := petal * rng.randf_range(0.85, 1.1)
		pc.a = 1.0
		var centre := Color(1.0, 0.85, 0.3, 1.0)
		for p in 5:
			var a0 := TAU * float(p) / 5.0
			var a1 := a0 + TAU / 5.0 * 0.8
			var r := rng.randf_range(0.06, 0.09)
			# Seen from above only: one side is enough (wound to face up).
			for v in [[top, centre], [top + Vector3(cos(a1) * r, 0.03, sin(a1) * r), pc], [top + Vector3(cos(a0) * r, 0.03, sin(a0) * r), pc]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## A scatter of fallen leaves lying on the ground.
static func leaf_litter(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: Array[Color] = [Color(0.86, 0.36, 0.08), Color(0.74, 0.16, 0.08), Color(0.92, 0.66, 0.14), Color(0.56, 0.26, 0.1)]
	for i in 9:
		var c := cols[rng.randi() % cols.size()]
		c.a = 0.0
		var o := Vector3(rng.randf_range(-0.5, 0.5), 0.03 + rng.randf() * 0.02, rng.randf_range(-0.5, 0.5))
		var a := rng.randf() * TAU
		var u := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.07, 0.11)
		var v := Vector3(-sin(a), 0, cos(a)) * rng.randf_range(0.04, 0.06)
		_leaf_tri(st, o - u, o + v, o + u, c, c, c)
		_leaf_tri(st, o - u, o + u, o - v, c, c, c)
	st.generate_normals()
	return st.commit()


## Cluster of small shards (ice, salt, crystal) for the accent material.
static func shards(seed_value: int, col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 4:
		var o := Vector3(rng.randf_range(-0.2, 0.2), -0.03, rng.randf_range(-0.2, 0.2))
		var h := rng.randf_range(0.18, 0.5)
		var w := h * 0.22
		var lean := Vector3(rng.randf_range(-0.12, 0.12), h, rng.randf_range(-0.12, 0.12))
		var c: Array[Vector3] = [o + Vector3(-w, 0, -w), o + Vector3(w, 0, -w), o + Vector3(w, 0, w), o + Vector3(-w, 0, w),
			o + lean + Vector3(-w, 0, -w) * 0.1, o + lean + Vector3(w, 0, -w) * 0.1, o + lean + Vector3(w, 0, w) * 0.1, o + lean + Vector3(-w, 0, w) * 0.1]
		MeshKit.add_hexahedron(st, c, col * rng.randf_range(0.85, 1.1), 1.0)
	st.generate_normals()
	return st.commit()


## A few glowing mushrooms (vertex colour = light colour, for the emissive material).
static func mushrooms(seed_value: int, col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var o := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
		var h := rng.randf_range(0.1, 0.24)
		var r := h * rng.randf_range(0.5, 0.7)
		var stem := col * 0.35
		var sides := 6
		for sgm in sides:
			var a0 := TAU * float(sgm) / float(sides)
			var a1 := TAU * float(sgm + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			MeshKit.tri(st, o + d0 * r * 0.2, o + d1 * r * 0.2, o + Vector3(0, h, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, stem)
			MeshKit.tri(st, o + Vector3(0, h * 0.7, 0) + d0 * r, o + Vector3(0, h * 0.7, 0) + d1 * r, o + Vector3(0, h * 1.25, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)
			MeshKit.tri(st, o + Vector3(0, h * 0.7, 0) + d1 * r, o + Vector3(0, h * 0.7, 0) + d0 * r, o + Vector3(0, h * 0.8, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col * 0.6)
	st.generate_normals()
	return st.commit()


## A handful of pebbles (stone material).
static func pebbles(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _noise(seed_value, 2.4)
	for i in 3:
		var s := rng.randf_range(0.07, 0.17)
		MeshKit.add_blob(st, Vector3(rng.randf_range(-0.3, 0.3), s * 0.3, rng.randf_range(-0.3, 0.3)), Vector3(s * rng.randf_range(1.0, 1.6), s * 0.7, s), 0, n, 0.25, Color(0.86, 0.84, 0.8) * rng.randf_range(0.8, 1.05), -0.02)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
