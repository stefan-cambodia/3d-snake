class_name MeshKit
extends RefCounted
## Procedural mesh construction helpers.
##
## Conventions: helpers take triangles in counter-clockwise order as seen from
## the outside (the usual math convention) and emit them in Godot's clockwise
## front-face order. Normals are computed by SurfaceTool from that winding.


## Append one triangle given CCW-from-outside vertices.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, col := Color.WHITE) -> void:
	st.set_color(col)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_color(col)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_color(col)
	st.set_uv(ub)
	st.add_vertex(b)


## Grid of vertices `rows` x `cols` (row-major) joined into quads.
## `wrap_cols` joins the last column back to the first. Vertices must be laid out
## so that (row, col) -> (row, col+1) -> (row+1, col) is CCW seen from outside.
static func grid_indices(st: SurfaceTool, rows: int, cols: int, base: int = 0, wrap_cols: bool = false) -> void:
	var ccount := cols if wrap_cols else cols - 1
	for r in rows - 1:
		for c in ccount:
			var c1 := (c + 1) % cols
			var i00 := base + r * cols + c
			var i01 := base + r * cols + c1
			var i10 := base + (r + 1) * cols + c
			var i11 := base + (r + 1) * cols + c1
			# CCW (i00, i01, i11) and (i00, i11, i10) -> emitted clockwise.
			st.add_index(i00)
			st.add_index(i11)
			st.add_index(i01)
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i11)


## Surface of revolution around +Y. `profile` = Vector2(radius, y) from bottom to top.
## `radial_fn(angle, row) -> float` optionally scales the radius (flutes, damage).
static func lathe(profile: PackedVector2Array, segments: int, radial_fn: Callable = Callable(), col := Color.WHITE, uv_scale := Vector2(1, 1), cap_top := false, cap_bottom := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := segments + 1
	var vlen := 0.0
	for r in profile.size():
		if r > 0:
			vlen += profile[r].distance_to(profile[r - 1])
		for s in cols:
			var a := TAU * float(s) / float(segments)
			var rad := profile[r].x
			if radial_fn.is_valid():
				rad *= float(radial_fn.call(a, r))
			# Angle goes clockwise seen from above so rows/cols are CCW from outside.
			var p := Vector3(cos(a) * rad, profile[r].y, -sin(a) * rad)
			st.set_color(col)
			st.set_uv(Vector2(float(s) / float(segments) * uv_scale.x, vlen * uv_scale.y))
			st.add_vertex(p)
	# Rows go upward, columns go around; (r,c)->(r,c+1)->(r+1,c+1) is CCW seen from
	# outside, so emit the reverse (Godot front faces are clockwise).
	for r in profile.size() - 1:
		for c in segments:
			var i00 := r * cols + c
			var i01 := r * cols + c + 1
			var i10 := (r + 1) * cols + c
			var i11 := (r + 1) * cols + c + 1
			st.add_index(i00)
			st.add_index(i11)
			st.add_index(i01)
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i11)
	var base := profile.size() * cols
	if cap_top and profile[profile.size() - 1].x > 0.0:
		_cap(st, profile[profile.size() - 1], segments, radial_fn, profile.size() - 1, true, base, col)
		base += segments + 1
	if cap_bottom and profile[0].x > 0.0:
		_cap(st, profile[0], segments, radial_fn, 0, false, base, col)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _cap(st: SurfaceTool, ring: Vector2, segments: int, radial_fn: Callable, row: int, top: bool, base: int, col: Color) -> void:
	st.set_color(col)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3(0, ring.y, 0))
	for s in segments:
		var a := TAU * float(s) / float(segments)
		var rad := ring.x
		if radial_fn.is_valid():
			rad *= float(radial_fn.call(a, row))
		st.set_color(col)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		st.add_vertex(Vector3(cos(a) * rad, ring.y, -sin(a) * rad))
	for s in segments:
		var i1 := base + 1 + s
		var i2 := base + 1 + (s + 1) % segments
		if top:
			st.add_index(base)
			st.add_index(i2)
			st.add_index(i1)
		else:
			st.add_index(base)
			st.add_index(i1)
			st.add_index(i2)


## Icosphere with optional per-vertex displacement fn(dir: Vector3) -> Vector3 (position).
static func icosphere_points(subdiv: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	for _i in subdiv:
		var cache := {}
		var nf: Array[Vector3i] = []
		for f in faces:
			var a := _mid(verts, cache, f.x, f.y)
			var b := _mid(verts, cache, f.y, f.z)
			var c := _mid(verts, cache, f.z, f.x)
			nf.append(Vector3i(f.x, a, c))
			nf.append(Vector3i(f.y, b, a))
			nf.append(Vector3i(f.z, c, b))
			nf.append(Vector3i(a, b, c))
		faces = nf
	return [verts, faces]


static func _mid(verts: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1


## Displaced icosphere blob (rocks, foliage clusters). Faces are CCW from outside.
static func add_blob(st: SurfaceTool, center: Vector3, scale: Vector3, subdiv: int, noise: FastNoiseLite, amount: float, col: Color, flat_bottom: float = -INF, smooth := true) -> void:
	var data := icosphere_points(subdiv)
	var verts: Array[Vector3] = data[0]
	var faces: Array[Vector3i] = data[1]
	var pts: Array[Vector3] = []
	for v in verts:
		var n := 1.0
		if noise != null:
			n += noise.get_noise_3d(v.x * 1.7 + center.x, v.y * 1.7 + center.y, v.z * 1.7 + center.z) * amount
		var p := v * scale * n
		if p.y < flat_bottom:
			p.y = flat_bottom + (p.y - flat_bottom) * 0.15
		pts.append(center + p)
	for f in faces:
		# Icosphere faces above are CCW seen from outside.
		var c := col
		if not smooth:
			c = col * (0.92 + 0.16 * MathUtil.hash01(f.x * 31 + f.y))
			c.a = col.a
		tri(st, pts[f.x], pts[f.y], pts[f.z], Vector2(v_uv(verts[f.x])), Vector2(v_uv(verts[f.y])), Vector2(v_uv(verts[f.z])), c)


static func v_uv(d: Vector3) -> Vector2:
	return Vector2(atan2(d.z, d.x) / TAU + 0.5, d.y * 0.5 + 0.5)


## Box from 8 corners order: bottom (x-,z-),(x+,z-),(x+,z+),(x-,z+), then top same order.
static func add_hexahedron(st: SurfaceTool, c: Array[Vector3], col: Color, uv_scale: float = 1.0) -> void:
	var quads := [
		[0, 1, 5, 4], # -Z face
		[1, 2, 6, 5], # +X
		[2, 3, 7, 6], # +Z
		[3, 0, 4, 7], # -X
		[4, 5, 6, 7], # top
		[3, 2, 1, 0], # bottom
	]
	for q in quads:
		var a: Vector3 = c[q[0]]
		var b: Vector3 = c[q[1]]
		var cc: Vector3 = c[q[2]]
		var d: Vector3 = c[q[3]]
		var w := a.distance_to(b) * uv_scale
		var h := a.distance_to(d) * uv_scale
		# Determine CCW-from-outside order using the face normal vs centre direction.
		var centre := Vector3.ZERO
		for p in c:
			centre += p
		centre /= 8.0
		var n := (b - a).cross(d - a)
		var face_c := (a + b + cc + d) * 0.25
		if n.dot(face_c - centre) < 0.0:
			# Flip to make it CCW from outside.
			var tmp := b
			b = d
			d = tmp
		tri(st, a, b, cc, Vector2(0, 0), Vector2(w, 0), Vector2(w, h), col)
		tri(st, a, cc, d, Vector2(0, 0), Vector2(w, h), Vector2(0, h), col)


## Tube along a polyline with per-point radius. Returns an ArrayMesh surface added to st.
static func add_tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int, col: Color, uv_v_scale: float = 1.0, close_end := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var up_ref := Vector3.UP
	var rings: Array = []
	var vacc := 0.0
	for i in n:
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == n - 1:
			t = (pts[n - 1] - pts[n - 2]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		if absf(t.dot(up_ref)) > 0.95:
			up_ref = Vector3.RIGHT
		var right := t.cross(up_ref).normalized()
		var up := right.cross(t).normalized()
		up_ref = up
		if i > 0:
			vacc += pts[i].distance_to(pts[i - 1])
		var ring: Array[Vector3] = []
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			ring.append(pts[i] + (right * cos(a) + up * sin(a)) * radii[i])
		rings.append([ring, vacc])
	for i in n - 1:
		var r0: Array[Vector3] = rings[i][0]
		var r1: Array[Vector3] = rings[i + 1][0]
		var v0: float = rings[i][1] * uv_v_scale
		var v1: float = rings[i + 1][1] * uv_v_scale
		for s in sides:
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			# Seen from outside, r0[s] -> r1[s] -> r1[s+1] -> r0[s+1] is CCW.
			tri(st, r0[s], r1[s], r1[s + 1], Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), col)
			tri(st, r0[s], r1[s + 1], r0[s + 1], Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), col)
	if close_end and radii[n - 1] > 0.001:
		var last: Array[Vector3] = rings[n - 1][0]
		var tip := pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * radii[n - 1] * 0.6
		for s in sides:
			tri(st, last[s], tip, last[s + 1], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)


## Flat-ish grid draped on the terrain (decals such as warning circles).
static func draped_disc(terrain: TerrainField, center: Vector2, radius: float, res: int, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in res + 1:
		for ix in res + 1:
			var u := float(ix) / float(res)
			var v := float(iz) / float(res)
			var x := (u - 0.5) * 2.0 * radius
			var z := (v - 0.5) * 2.0 * radius
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x, terrain.height(center.x + x, center.y + z) + lift, z))
	# Rows along +Z, columns along +X: (r,c)->(r,c+1)->(r+1,c+1) is already clockwise
	# seen from above, which is Godot's front-face order.
	for r in res:
		for c in res:
			var i00 := r * (res + 1) + c
			var i01 := i00 + 1
			var i10 := i00 + res + 1
			var i11 := i10 + 1
			st.add_index(i00)
			st.add_index(i01)
			st.add_index(i11)
			st.add_index(i00)
			st.add_index(i11)
			st.add_index(i10)
	return st.commit()
