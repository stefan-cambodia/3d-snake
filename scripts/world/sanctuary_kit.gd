class_name SanctuaryKit
extends RefCounted
## Modular architecture kit: columns in several orders, arches, stairs, tiered
## roofs, domes, stupas, obelisks, statues and ceremonial props. Pieces are added
## at the kit's current transform `xf` and merged into three surfaces:
##   stone  - stone.gdshader (UVs, vertex tint, alpha 0 = rune face)
##   accent - vertex-coloured bronze, ceramic, timber and leaves
##   glow   - unshaded emissive parts (flames, crystals, lantern lights)
## so a whole group of structures costs three draw calls.

const STONE := Color(1.0, 0.97, 0.9, 1.0)
const RUNE := Color(1.0, 1.0, 1.0, 0.0)
const BRONZE := Color(0.62, 0.44, 0.2)
const VERDIGRIS := Color(0.28, 0.5, 0.44)
const TERRACOTTA := Color(0.66, 0.36, 0.22)
const GOLD := Color(0.95, 0.72, 0.25)
const TIMBER := Color(0.3, 0.2, 0.13)
const VINE := Color(0.16, 0.34, 0.12)

## Column orders. Every order keeps inside 1.42 x radius, like the classic one,
## so a pillar's collision circle fits them all.
const ORDERS: Array[String] = ["classic", "lotus", "square", "ringed", "faceted"]

var rng := RandomNumberGenerator.new()
## Where the next pieces go (world or group space).
var xf := Transform3D()

var _flat := SurfaceTool.new()
var _round := SurfaceTool.new()
var _aflat := SurfaceTool.new()
var _around := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _used := {"flat": false, "round": false, "aflat": false, "around": false, "glow": false}

static var _cache: Dictionary = {}


func _init(seed_value: int) -> void:
	rng.seed = seed_value
	for st: SurfaceTool in [_flat, _round, _aflat, _around, _glow]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flat.set_smooth_group(-1)
	_aflat.set_smooth_group(-1)
	_glow.set_smooth_group(-1)


## Stone tint, `k` times as bright (alpha stays 1: not a rune face).
static func tint(k: float) -> Color:
	return Color(STONE.r * k, STONE.g * k, STONE.b * k, 1.0)


## Run `fn` with the kit moved to `pos`, turned by `yaw` and scaled.
func at(pos: Vector3, yaw: float, fn: Callable, scale: float = 1.0, tilt: Basis = Basis()) -> void:
	var old := xf
	xf = xf * Transform3D(Basis(Vector3.UP, yaw) * tilt * Basis().scaled(Vector3.ONE * scale), pos)
	fn.call()
	xf = old


# --- Primitives -----------------------------------------------------------------

## Block standing on `pos` (centre of its base). `taper` scales the top face.
func box(pos: Vector3, size: Vector3, col: Color = STONE, taper: float = 1.0, yaw: float = 0.0, accent: bool = false) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var t := xf * Transform3D(Basis(Vector3.UP, yaw), pos)
	var c: Array[Vector3] = [
		t * Vector3(-hx, 0, -hz), t * Vector3(hx, 0, -hz), t * Vector3(hx, 0, hz), t * Vector3(-hx, 0, hz),
		t * Vector3(-hx * taper, size.y, -hz * taper), t * Vector3(hx * taper, size.y, -hz * taper),
		t * Vector3(hx * taper, size.y, hz * taper), t * Vector3(-hx * taper, size.y, hz * taper),
	]
	MeshKit.add_hexahedron(_aflat if accent else _flat, c, col, 0.5)
	_used["aflat" if accent else "flat"] = true


## Block between eight free corners (bottom four, then top four).
func block(corners: Array[Vector3], col: Color = STONE, accent: bool = false) -> void:
	var c: Array[Vector3] = []
	for p in corners:
		c.append(xf * p)
	MeshKit.add_hexahedron(_aflat if accent else _flat, c, col, 0.5)
	_used["aflat" if accent else "flat"] = true


## Carved, glowing inscription panel facing local +Z (after `yaw`).
func rune_panel(pos: Vector3, w: float, h: float, yaw: float = 0.0) -> void:
	var t := xf * Transform3D(Basis(Vector3.UP, yaw), pos)
	var p0 := t * Vector3(-w * 0.5, 0, 0)
	var p1 := t * Vector3(w * 0.5, 0, 0)
	var p2 := t * Vector3(w * 0.5, h, 0)
	var p3 := t * Vector3(-w * 0.5, h, 0)
	MeshKit.tri(_flat, p0, p1, p2, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), RUNE)
	MeshKit.tri(_flat, p0, p2, p3, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), RUNE)
	_used["flat"] = true


## Turned piece (surface of revolution). `key` caches the mesh between islands.
func turned(profile: PackedVector2Array, pos: Vector3, segs: int = 12, col: Color = STONE, accent: bool = false, radial: Callable = Callable(), key: String = "", basis: Basis = Basis()) -> void:
	var mesh: ArrayMesh
	if key != "" and _cache.has(key):
		mesh = _cache[key]
	else:
		mesh = MeshKit.lathe(profile, segs, radial, col, Vector2(3.0, 0.5))
		if key != "":
			_cache[key] = mesh
	(_around if accent else _round).append_from(mesh, 0, xf * Transform3D(basis, pos))
	_used["around" if accent else "round"] = true


## A ready-made stone mesh (must carry UVs, normals and tangents).
func mesh(m: ArrayMesh, local: Transform3D = Transform3D()) -> void:
	for s in m.get_surface_count():
		_round.append_from(m, s, xf * local)
	_used["round"] = true


## Emissive block (crystal, lantern light). `taper` 0 gives a point.
func glow_box(pos: Vector3, size: Vector3, col: Color, taper: float = 1.0, basis: Basis = Basis()) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var t := xf * Transform3D(basis, pos)
	var c: Array[Vector3] = [
		t * Vector3(-hx, 0, -hz), t * Vector3(hx, 0, -hz), t * Vector3(hx, 0, hz), t * Vector3(-hx, 0, hz),
		t * Vector3(-hx * taper, size.y, -hz * taper), t * Vector3(hx * taper, size.y, -hz * taper),
		t * Vector3(hx * taper, size.y, hz * taper), t * Vector3(-hx * taper, size.y, hz * taper),
	]
	MeshKit.add_hexahedron(_glow, c, col, 1.0)
	_used["glow"] = true


## Tube along points (roots, vines, rails).
func tube(pts: PackedVector3Array, radius: float, col: Color, accent: bool = true, sides: int = 5) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := PackedFloat32Array()
	for i in pts.size():
		radii.append(radius * lerpf(1.0, 0.55, float(i) / float(maxi(pts.size() - 1, 1))))
	MeshKit.add_tube(st, pts, radii, sides, col, 0.5, true)
	st.generate_normals()
	st.generate_tangents()
	st.index()
	(_around if accent else _round).append_from(st.commit(), 0, xf)
	_used["around" if accent else "round"] = true


# --- Columns --------------------------------------------------------------------

## A column of one of the ORDERS, standing on y = 0 (its plinth starts at -0.3).
static func column_mesh(order: String, height: float, radius: float, broken: bool, seed_value: int, segments: int = 14) -> ArrayMesh:
	if order == "classic" or not ORDERS.has(order):
		return WorldMeshes.column(height, radius, broken, seed_value, segments)
	var prof := PackedVector2Array()
	var kinds: Array[int] = [] # 0 square, 1 round, 3 broken edge, 4 petals
	var add := func(r: float, y: float, k: int) -> void:
		prof.append(Vector2(r * radius, y))
		kinds.append(k)
	var top := height
	match order:
		"lotus":
			for p in [[1.36, -0.3], [1.36, 0.1], [1.2, 0.18], [1.3, 0.3], [1.1, 0.42], [1.0, 0.5]]:
				add.call(p[0], p[1], 1)
			var shaft_top := top - 1.15 if not broken else top
			var bands := maxi(int((shaft_top - 0.5) / 1.5), 1)
			for b in bands:
				var y0 := lerpf(0.5, shaft_top, float(b) / float(bands))
				var y1 := lerpf(0.5, shaft_top, float(b + 1) / float(bands))
				var k := 1.0 - 0.1 * (y1 / maxf(height, 1.0))
				add.call(k, y1 - 0.34, 1)
				if b < bands - 1 or not broken:
					add.call(k + 0.1, y1 - 0.28, 1)
					add.call(k + 0.1, y1 - 0.08, 1)
					add.call(k, y1, 1)
				else:
					add.call(k, y1, 1)
				if y0 > y1:
					break
			if broken:
				add.call(0.75, top + 0.06, 3)
				add.call(0.3, top - 0.08, 3)
				add.call(0.0, top - 0.14, 3)
			else:
				for p in [[0.88, top - 1.05, 1], [1.02, top - 0.98, 1], [0.94, top - 0.9, 1], [1.18, top - 0.6, 4], [1.3, top - 0.34, 4],
						[1.14, top - 0.27, 1], [1.3, top - 0.2, 1], [1.3, top, 1], [0.0, top, 1]]:
					add.call(p[0], p[1], p[2])
		"square":
			for p in [[1.42, -0.3], [1.42, 0.24], [1.26, 0.24], [1.26, 0.5], [1.16, 0.5]]:
				add.call(p[0], p[1], 0)
			var shaft_top2 := top - 0.85 if not broken else top
			var panels := maxi(int((shaft_top2 - 0.5) / 1.3), 1)
			for b in panels:
				var y0 := lerpf(0.5, shaft_top2, float(b) / float(panels))
				var y1 := lerpf(0.5, shaft_top2, float(b + 1) / float(panels))
				add.call(1.16, y0 + 0.12, 0)
				add.call(1.04, y0 + 0.18, 0)
				add.call(1.04, y1 - 0.18, 0)
				add.call(1.16, y1 - 0.12, 0)
				add.call(1.16, y1, 0)
			if broken:
				add.call(0.9, top + 0.06, 3)
				add.call(0.35, top - 0.08, 3)
				add.call(0.0, top - 0.14, 3)
			else:
				for p in [[1.26, top - 0.85], [1.26, top - 0.62], [1.34, top - 0.62], [1.34, top - 0.36], [1.42, top - 0.36], [1.42, top], [0.0, top]]:
					add.call(p[0], p[1], 0)
		"ringed":
			for p in [[1.34, -0.3], [1.34, 0.14], [1.12, 0.26], [1.0, 0.34]]:
				add.call(p[0], p[1], 1)
			var shaft_top3 := top - 0.75 if not broken else top
			var drums := maxi(int((shaft_top3 - 0.34) / 0.8), 1)
			for b in drums:
				var y0 := lerpf(0.34, shaft_top3, float(b) / float(drums))
				var y1 := lerpf(0.34, shaft_top3, float(b + 1) / float(drums))
				add.call(1.04, y0 + 0.06, 1)
				add.call(1.04, y1 - 0.08, 1)
				add.call(0.95, y1 - 0.03, 1)
				add.call(0.97, y1, 1)
			if broken:
				add.call(0.75, top + 0.06, 3)
				add.call(0.3, top - 0.08, 3)
				add.call(0.0, top - 0.14, 3)
			else:
				for p in [[0.94, top - 0.72], [1.1, top - 0.55], [1.34, top - 0.3], [1.4, top - 0.2], [1.4, top], [0.0, top]]:
					add.call(p[0], p[1], 1)
		"faceted":
			segments = 8
			for p in [[1.36, -0.3], [1.36, 0.2], [1.02, 0.42]]:
				add.call(p[0], p[1], 1)
			var shaft_top4 := top - 0.95 if not broken else top
			add.call(0.96, shaft_top4 * 0.5, 1)
			add.call(0.8, shaft_top4, 1)
			if broken:
				add.call(0.6, top + 0.08, 3)
				add.call(0.25, top - 0.08, 3)
				add.call(0.0, top - 0.14, 3)
			else:
				for p in [[1.18, top - 0.74], [1.18, top - 0.5], [0.62, top - 0.22], [0.0, top]]:
					add.call(p[0], p[1], 1)
	var radial := func(a: float, row: int) -> float:
		var k: int = kinds[row]
		if k == 0:
			var c := absf(cos(a))
			var s := absf(sin(a))
			return 1.0 / pow(pow(c, 6.0) + pow(s, 6.0), 1.0 / 6.0) * 0.82
		if k == 3:
			return 0.75 + 0.5 * MathUtil.hash01(int(a * 40.0) + seed_value)
		if k == 4:
			return 1.0 + 0.07 * absf(sin(a * 4.0))
		return 1.0
	return MeshKit.lathe(prof, segments, radial, STONE, Vector2(3.0, 0.5), false, false)


func column(order: String, pos: Vector3, height: float, radius: float, broken: bool = false, tilt: Basis = Basis(), variant: int = 0) -> void:
	var key := "col:%s:%.2f:%.2f:%s:%d" % [order, height, radius, broken, variant]
	if not _cache.has(key):
		_cache[key] = column_mesh(order, height, radius, broken, 300 + variant, 12)
	_round.append_from(_cache[key], 0, xf * Transform3D(tilt, pos))
	_used["round"] = true


## A row of columns along local X, some broken, with lintel blocks where two
## neighbours still stand.
func colonnade(order: String, pos: Vector3, count: int, spacing: float, height: float, radius: float, ruin: float = 0.4) -> void:
	var standing: Array[bool] = []
	for i in count:
		var whole := rng.randf() > ruin
		standing.append(whole)
		var x := (float(i) - float(count - 1) * 0.5) * spacing
		column(order, pos + Vector3(x, 0, 0), height if whole else height * rng.randf_range(0.25, 0.6), radius, not whole, Basis(), i % 3)
	for i in count - 1:
		if standing[i] and standing[i + 1]:
			var x := (float(i) - float(count - 1) * 0.5 + 0.5) * spacing
			box(pos + Vector3(x, height, 0), Vector3(spacing + radius * 2.4, radius * 1.3, radius * 2.6), tint(0.96))
			box(pos + Vector3(x, height + radius * 1.3, 0), Vector3(spacing + radius * 2.9, radius * 0.45, radius * 3.0), tint(0.9))


# --- Structure ------------------------------------------------------------------

## Foundation going well below the ground or the water, so a structure can stand
## anywhere. Top at y = 0.
func plinth(half_x: float, half_z: float, depth: float = 2.6, circular: bool = false) -> void:
	if circular:
		turned(PackedVector2Array([Vector2(half_x, -depth), Vector2(half_x, -0.12), Vector2(half_x - 0.12, 0.0), Vector2(0.0, 0.0)]), Vector3.ZERO, 20, tint(0.9))
	else:
		box(Vector3(0, -depth, 0), Vector3(half_x * 2.0, depth, half_z * 2.0), tint(0.9))


## Square stepped base: `tiers` slabs shrinking by `inset`, top at tiers * tier_h.
func stepped_base(half: float, tiers: int, tier_h: float, inset: float, col: Color = STONE) -> float:
	for i in tiers:
		var h := half - inset * float(i)
		box(Vector3(0, tier_h * float(i), 0), Vector3(h * 2.0, tier_h, h * 2.0), col if i % 2 == 0 else Color(col.r * 0.93, col.g * 0.93, col.b * 0.93, 1.0))
	return tier_h * float(tiers)


## Round stepped base (turned), top at steps * step_h.
func round_base(radius: float, steps: int, step_h: float, inset: float) -> float:
	var prof := PackedVector2Array()
	prof.append(Vector2(radius, -2.4))
	for i in steps:
		var r := radius - inset * float(i)
		prof.append(Vector2(r, step_h * float(i + 1)))
		prof.append(Vector2(r - inset, step_h * float(i + 1)))
	prof.append(Vector2(0.0, step_h * float(steps)))
	turned(prof, Vector3.ZERO, 28, tint(0.95))
	return step_h * float(steps)


## Flight of steps rising toward local -Z, starting at `pos` (front, bottom).
func stairs(pos: Vector3, width: float, steps: int, step_h: float, step_d: float, yaw: float = 0.0, rails: bool = true) -> void:
	var fn := func() -> void:
		for i in steps:
			box(Vector3(0, -0.5, -step_d * (float(i) + 0.5)), Vector3(width, step_h * float(i + 1) + 0.5, step_d), tint(0.92 + 0.04 * float(i % 2)))
		if rails:
			var total_h := step_h * float(steps)
			var total_d := step_d * float(steps)
			for s: float in [-1.0, 1.0]:
				var x := s * (width * 0.5 + 0.22)
				block([Vector3(x - 0.22, -0.5, -total_d), Vector3(x + 0.22, -0.5, -total_d), Vector3(x + 0.22, -0.5, 0.3), Vector3(x - 0.22, -0.5, 0.3),
					Vector3(x - 0.22, total_h + 0.45, -total_d), Vector3(x + 0.22, total_h + 0.45, -total_d), Vector3(x + 0.22, 0.5, 0.3), Vector3(x - 0.22, 0.5, 0.3)], tint(0.88))
				box(Vector3(x, 0.5, 0.3), Vector3(0.6, 0.5, 0.6), tint(0.95))
	at(pos, yaw, fn)


## Round arch across local X: two piers and a ring of voussoirs. `sweep` < 1
## leaves the arch broken off part-way.
func arch(pos: Vector3, span: float, pier_h: float, thick: float, depth: float, yaw: float = 0.0, sweep: float = 1.0) -> void:
	var fn := func() -> void:
		for s: float in [-1.0, 1.0]:
			if s < 0.0 or sweep >= 0.5:
				box(Vector3(s * (span + thick) * 0.5, -0.5, 0), Vector3(thick, pier_h + 0.5, depth))
				box(Vector3(s * (span + thick) * 0.5, pier_h, 0), Vector3(thick * 1.3, 0.24, depth * 1.12), tint(0.9))
		ring(Vector3(0, pier_h + 0.24, 0), span * 0.5, thick, depth, 9, PI, PI * (1.0 - sweep))
		if sweep >= 1.0:
			box(Vector3(0, pier_h + 0.24 + span * 0.5 + thick * 0.55, 0), Vector3(thick * 0.9, thick * 0.75, depth * 1.15), tint(1.04), 1.25)
	at(pos, yaw, fn)


## Ring of voussoir blocks in the local XY plane, from angle a_from down to a_to
## (radians, 0 = +X, PI/2 = up). A full circle is a_from = TAU, a_to = 0.
func ring(centre: Vector3, inner: float, thick: float, depth: float, blocks: int, a_from: float = TAU, a_to: float = 0.0, basis: Basis = Basis()) -> void:
	var d := depth * 0.5
	var outer := inner + thick
	var full := absf(a_from - a_to)
	var n := maxi(int(round(float(blocks) * full / PI)), 1) if full < PI * 0.999 else blocks * int(round(full / PI))
	for i in n:
		var a0 := lerpf(a_to, a_from, float(i) / float(n))
		var a1 := lerpf(a_to, a_from, float(i + 1) / float(n)) - 0.012
		var k := 0.94 + 0.1 * rng.randf()
		var p := func(r: float, a: float, z: float) -> Vector3:
			return centre + basis * Vector3(cos(a) * r, sin(a) * r, z)
		block([p.call(inner, a0, -d), p.call(outer, a0, -d), p.call(outer, a0, d), p.call(inner, a0, d),
			p.call(inner, a1, -d), p.call(outer, a1, -d), p.call(outer, a1, d), p.call(inner, a1, d)], tint(k))


## Hip roof tier with a projecting eave slab.
func roof(pos: Vector3, half: float, height: float, top: float = 0.3, col: Color = STONE, accent: bool = false) -> void:
	box(pos, Vector3(half * 2.3, height * 0.16, half * 2.3), Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, 1.0), 0.97, 0.0, accent)
	box(pos + Vector3(0, height * 0.16, 0), Vector3(half * 2.05, height * 0.84, half * 2.05), col, top, 0.0, accent)


## Tiered tower: `tiers` shrinking storeys with cornices, crowned by a finial.
func tower(pos: Vector3, half: float, tiers: int, tier_h: float, shrink: float = 0.8, door: bool = true) -> float:
	var y := pos.y
	var h := half
	for i in tiers:
		box(Vector3(pos.x, y, pos.z), Vector3(h * 2.0, tier_h, h * 2.0), tint(1.0 - 0.03 * float(i)), 0.94)
		if i == 0 and door:
			for a in 4:
				var yaw := PI * 0.5 * float(a)
				var out := Basis(Vector3.UP, yaw) * Vector3(0, 0, h * 0.99)
				box(Vector3(pos.x, y, pos.z) + out, Vector3(h * 0.7, tier_h * 0.78, 0.16), tint(0.32), 1.0, yaw)
				box(Vector3(pos.x, y + tier_h * 0.78, pos.z) + out, Vector3(h * 0.95, tier_h * 0.14, 0.3), tint(1.05), 0.8, yaw)
		elif i > 0:
			for a in 4:
				var yaw := PI * 0.5 * float(a)
				rune_panel(Vector3(pos.x, y + tier_h * 0.2, pos.z) + Basis(Vector3.UP, yaw) * Vector3(0, 0, h * 0.96), h * 0.9, tier_h * 0.5, yaw)
		y += tier_h
		box(Vector3(pos.x, y, pos.z), Vector3(h * 2.2, tier_h * 0.16, h * 2.2), tint(0.86), 1.06)
		y += tier_h * 0.16
		h *= shrink
		tier_h *= 0.9
	turned(PackedVector2Array([Vector2(h * 0.9, 0.0), Vector2(h * 1.05, h * 0.35), Vector2(h * 0.7, h * 0.8), Vector2(h * 0.3, h * 1.5), Vector2(0.0, h * 2.3)]),
		Vector3(pos.x, y, pos.z), 10, tint(1.0), false, func(a: float, _row: int) -> float: return 1.0 + 0.08 * absf(sin(a * 4.0)))
	return y + h * 2.3


## Dome on a short drum, with a finial.
func dome(pos: Vector3, radius: float, col: Color = STONE, accent: bool = false) -> void:
	var prof := PackedVector2Array([Vector2(radius * 1.04, 0.0), Vector2(radius * 1.04, radius * 0.18), Vector2(radius, radius * 0.2)])
	for i in range(1, 7):
		var t := float(i) / 6.0 * PI * 0.5
		prof.append(Vector2(cos(t) * radius, radius * 0.2 + sin(t) * radius * 0.92))
	turned(prof, pos, 18, col, accent)
	turned(PackedVector2Array([Vector2(radius * 0.1, 0.0), Vector2(radius * 0.16, radius * 0.14), Vector2(radius * 0.05, radius * 0.24), Vector2(radius * 0.1, radius * 0.34), Vector2(0.0, radius * 0.55)]),
		pos + Vector3(0, radius * 1.1, 0), 8, GOLD, true)


## Bell-shaped stupa with a ringed spire.
func stupa(pos: Vector3, radius: float) -> void:
	var r := radius
	turned(PackedVector2Array([
		Vector2(r * 1.3, -0.4), Vector2(r * 1.3, r * 0.2), Vector2(r * 1.12, r * 0.2), Vector2(r * 1.12, r * 0.4), Vector2(r, r * 0.4),
		Vector2(r * 1.02, r * 0.75), Vector2(r * 0.92, r * 1.15), Vector2(r * 0.66, r * 1.5), Vector2(r * 0.34, r * 1.68),
		Vector2(r * 0.3, r * 1.72), Vector2(r * 0.3, r * 1.95), Vector2(r * 0.2, r * 1.98), Vector2(r * 0.17, r * 2.3), Vector2(r * 0.22, r * 2.34),
		Vector2(r * 0.12, r * 2.7), Vector2(r * 0.15, r * 2.74), Vector2(r * 0.05, r * 3.1), Vector2(0.0, r * 3.4)]), pos, 16, tint(1.0))


## Tapering obelisk with inscriptions on two faces.
func obelisk(pos: Vector3, height: float, width: float, yaw: float = 0.0) -> void:
	var fn := func() -> void:
		box(Vector3(0, -0.4, 0), Vector3(width * 1.7, 0.75, width * 1.7), tint(0.9))
		box(Vector3(0, 0.35, 0), Vector3(width, height, width), tint(1.0), 0.62)
		box(Vector3(0, 0.35 + height, 0), Vector3(width * 0.62, width * 0.8, width * 0.62), tint(1.08), 0.04)
		for s: float in [0.0, PI]:
			rune_panel(Vector3(0, 0.9, 0) + Basis(Vector3.UP, s) * Vector3(0, 0, width * 0.47), width * 0.5, height * 0.6, s)
	at(pos, yaw, fn)


## Two uprights and a lintel (henge stone). `fallen` drops the lintel.
func trilithon(pos: Vector3, width: float, height: float, yaw: float, fallen: bool = false) -> void:
	var fn := func() -> void:
		for s: float in [-1.0, 1.0]:
			box(Vector3(s * width * 0.5, -0.5, 0), Vector3(width * 0.34, height + 0.5, width * 0.3), tint(0.92 + 0.1 * rng.randf()), 0.82, rng.randf_range(-0.12, 0.12))
		if fallen:
			block([Vector3(-width * 0.7, -0.1, width * 0.5), Vector3(width * 0.7, -0.2, width * 0.7), Vector3(width * 0.7, -0.2, width * 1.1), Vector3(-width * 0.7, -0.1, width * 0.9),
				Vector3(-width * 0.7, 0.4, width * 0.5), Vector3(width * 0.7, 0.25, width * 0.7), Vector3(width * 0.7, 0.25, width * 1.1), Vector3(-width * 0.7, 0.4, width * 0.9)], tint(0.9))
		else:
			box(Vector3(0, height, 0), Vector3(width * 1.5, width * 0.3, width * 0.36), tint(1.0), 0.94)
	at(pos, yaw, fn)


# --- Props ----------------------------------------------------------------------

func pedestal(pos: Vector3, width: float, height: float) -> void:
	box(pos + Vector3(0, -0.3, 0), Vector3(width * 1.3, 0.5, width * 1.3), tint(0.9))
	box(pos + Vector3(0, 0.2, 0), Vector3(width, height - 0.4, width), tint(1.0))
	box(pos + Vector3(0, height - 0.2, 0), Vector3(width * 1.2, 0.2, width * 1.2), tint(0.94))


## Urn or jar; `shape` 0 amphora, 1 squat jar, 2 tall vase.
func urn(pos: Vector3, scale: float = 1.0, col: Color = TERRACOTTA, shape: int = 0, tilt: Basis = Basis()) -> void:
	var p: PackedVector2Array
	match shape:
		1:
			p = PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.4, 0.1), Vector2(0.46, 0.3), Vector2(0.36, 0.5), Vector2(0.24, 0.56), Vector2(0.3, 0.62), Vector2(0.24, 0.62), Vector2(0.0, 0.5)])
		2:
			p = PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.24, 0.12), Vector2(0.28, 0.5), Vector2(0.2, 0.85), Vector2(0.12, 0.98), Vector2(0.2, 1.1), Vector2(0.15, 1.1), Vector2(0.0, 0.95)])
		_:
			p = PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.2, 0.06), Vector2(0.36, 0.34), Vector2(0.34, 0.56), Vector2(0.16, 0.76), Vector2(0.14, 0.9), Vector2(0.2, 0.96), Vector2(0.15, 0.96), Vector2(0.0, 0.8)])
	turned(p, pos, 10, col, true, Callable(), "urn:%d:%s" % [shape, col.to_html()], tilt * Basis().scaled(Vector3.ONE * scale))


## Offering bowl on a foot.
func bowl(pos: Vector3, scale: float = 1.0, col: Color = BRONZE) -> void:
	turned(PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.1, 0.08), Vector2(0.12, 0.18), Vector2(0.38, 0.3), Vector2(0.42, 0.36), Vector2(0.34, 0.33), Vector2(0.0, 0.22)]),
		pos, 10, col, true, Callable(), "bowl:%s" % col.to_html(), Basis().scaled(Vector3.ONE * scale))


## Bronze bell hung in a stone frame (two posts and a beam).
func bell(pos: Vector3, scale: float = 1.0, yaw: float = 0.0) -> void:
	var fn := func() -> void:
		for s: float in [-1.0, 1.0]:
			box(Vector3(s * 0.75, -0.3, 0), Vector3(0.3, 2.3, 0.3), tint(0.95), 0.9)
		box(Vector3(0, 1.95, 0), Vector3(2.1, 0.26, 0.4), tint(0.9), 0.92)
		box(Vector3(0, 2.21, 0), Vector3(2.5, 0.14, 0.5), tint(0.84))
		turned(PackedVector2Array([Vector2(0.44, 0.0), Vector2(0.4, 0.06), Vector2(0.36, 0.3), Vector2(0.3, 0.62), Vector2(0.16, 0.8), Vector2(0.06, 0.84), Vector2(0.06, 0.98), Vector2(0.0, 0.98)]),
			Vector3(0, 0.95, 0), 12, BRONZE.lerp(VERDIGRIS, 0.35), true, Callable(), "bell")
	at(pos, yaw, fn, scale)


## Stone lantern: post, fire box with a light inside, cap.
func lantern(pos: Vector3, scale: float = 1.0, light: Color = Color(1.0, 0.72, 0.36)) -> void:
	var fn := func() -> void:
		turned(PackedVector2Array([Vector2(0.4, -0.3), Vector2(0.4, 0.1), Vector2(0.22, 0.2), Vector2(0.17, 1.0), Vector2(0.36, 1.1), Vector2(0.36, 1.18), Vector2(0.0, 1.18)]),
			Vector3.ZERO, 8, tint(0.96), false, Callable(), "lantern_post")
		for a in 4:
			var o := Basis(Vector3.UP, PI * 0.5 * float(a) + PI * 0.25) * Vector3(0.24, 0, 0)
			box(Vector3(o.x, 1.18, o.z), Vector3(0.1, 0.42, 0.1), tint(0.9))
		glow_box(Vector3(0, 1.22, 0), Vector3(0.3, 0.32, 0.3), light)
		box(Vector3(0, 1.6, 0), Vector3(0.95, 0.12, 0.95), tint(0.85))
		box(Vector3(0, 1.72, 0), Vector3(0.8, 0.3, 0.8), tint(0.95), 0.25)
		box(Vector3(0, 2.02, 0), Vector3(0.16, 0.2, 0.16), tint(1.0), 0.5)
	at(pos, 0.0, fn, scale)


## Altar table with an inscription and offerings.
func altar(pos: Vector3, width: float, yaw: float = 0.0, offerings: bool = true) -> void:
	var fn := func() -> void:
		box(Vector3(0, -0.3, 0), Vector3(width * 1.25, 0.5, 1.5), tint(0.88))
		box(Vector3(0, 0.2, 0), Vector3(width * 0.9, 0.7, 0.95), tint(0.98))
		box(Vector3(0, 0.9, 0), Vector3(width * 1.12, 0.2, 1.25), tint(1.04))
		rune_panel(Vector3(0, 0.3, 0.48), width * 0.7, 0.5)
		if offerings:
			bowl(Vector3(0, 1.1, 0), 0.9)
			urn(Vector3(-width * 0.38, 1.1, 0.1), 0.45, TERRACOTTA, 1)
			urn(Vector3(width * 0.38, 1.1, -0.1), 0.4, BRONZE, 2)
	at(pos, yaw, fn)


## Inscribed standing slab.
func stele(pos: Vector3, height: float, yaw: float = 0.0, lean: float = 0.0) -> void:
	var fn := func() -> void:
		box(Vector3(0, -0.35, 0), Vector3(1.3, 0.55, 0.7), tint(0.88))
		box(Vector3(0, 0.2, 0), Vector3(1.0, height, 0.3), tint(1.0), 0.86)
		box(Vector3(0, 0.2 + height, 0), Vector3(0.86, 0.3, 0.26), tint(1.05), 0.35)
		rune_panel(Vector3(0, 0.45, 0.16), 0.66, height * 0.72)
	at(pos, yaw, fn, 1.0, Basis(Vector3.RIGHT, lean))


## Seated guardian idol on its own base.
func guardian(pos: Vector3, scale: float = 1.0, yaw: float = 0.0) -> void:
	var fn := func() -> void:
		var squarish := func(a: float, row: int) -> float:
			if row <= 5:
				var c := absf(cos(a))
				var s := absf(sin(a))
				return lerpf(1.0, 1.0 / pow(pow(c, 4.0) + pow(s, 4.0), 0.25) * 0.85, 0.7)
			return 1.0
		turned(PackedVector2Array([
			Vector2(1.0, 0.0), Vector2(1.05, 0.28), Vector2(0.8, 0.5), Vector2(0.74, 0.95), Vector2(0.84, 1.35), Vector2(0.98, 1.62),
			Vector2(0.5, 1.84), Vector2(0.4, 1.95), Vector2(0.52, 2.12), Vector2(0.55, 2.38), Vector2(0.46, 2.6),
			Vector2(0.5, 2.66), Vector2(0.3, 2.84), Vector2(0.2, 3.2), Vector2(0.1, 3.28), Vector2(0.0, 3.5)]),
			Vector3.ZERO, 12, tint(1.0), false, squarish, "guardian")
		# Folded arms and knees.
		box(Vector3(0, 0.95, 0.62), Vector3(1.5, 0.3, 0.42), tint(0.95))
		for s: float in [-1.0, 1.0]:
			box(Vector3(s * 0.72, 0.0, 0.5), Vector3(0.6, 0.55, 1.0), tint(0.93), 0.8)
	at(pos, yaw, fn, scale)


## Head of a toppled colossus, half buried.
func fallen_head(pos: Vector3, scale: float = 1.0, yaw: float = 0.0) -> void:
	var fn := func() -> void:
		turned(PackedVector2Array([
			Vector2(0.5, -0.4), Vector2(0.86, 0.1), Vector2(1.0, 0.7), Vector2(0.96, 1.2), Vector2(0.8, 1.55),
			Vector2(0.86, 1.62), Vector2(0.55, 1.9), Vector2(0.36, 2.4), Vector2(0.14, 2.5), Vector2(0.0, 2.75)]),
			Vector3.ZERO, 12, tint(0.98), false, Callable(), "head", Basis(Vector3(0, 0, 1), 0.5) * Basis(Vector3.RIGHT, 0.25))
		box(Vector3(0.1, 0.55, 0.86), Vector3(0.34, 0.6, 0.3), tint(0.9), 0.6) # nose
		box(Vector3(0.1, 1.05, 0.8), Vector3(1.2, 0.14, 0.3), tint(0.82))      # brow
	at(pos, yaw, fn, scale)


## Loose blocks and chips scattered around `pos`.
func rubble(pos: Vector3, radius: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := radius * sqrt(rng.randf())
		var s := rng.randf_range(0.18, 0.55)
		box(pos + Vector3(cos(a) * r, -0.12, sin(a) * r), Vector3(s * rng.randf_range(0.8, 1.6), s * rng.randf_range(0.5, 0.9), s), tint(rng.randf_range(0.8, 1.02)), rng.randf_range(0.7, 0.95), rng.randf() * TAU)


## Cluster of emissive crystals.
func crystals(pos: Vector3, height: float, count: int, col_a: Color, col_b: Color) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.4, 0.4)
		var r := 0.0 if i == 0 else height * rng.randf_range(0.12, 0.3)
		var h := height * (1.0 if i == 0 else rng.randf_range(0.35, 0.75))
		var w := h * rng.randf_range(0.14, 0.2)
		var tilt := Basis(Vector3.UP, a) * Basis(Vector3(0, 0, 1), 0.0 if i == 0 else rng.randf_range(-0.5, -0.15))
		glow_box(pos + Vector3(cos(a) * r, -0.2, sin(a) * r), Vector3(w, h * 0.72, w), col_a.lerp(col_b, rng.randf()), 0.8, tilt)
		glow_box(pos + Vector3(cos(a) * r, -0.2, sin(a) * r) + tilt * Vector3(0, h * 0.72, 0), Vector3(w * 0.8, h * 0.28, w * 0.8), col_a.lerp(col_b, rng.randf()) * 1.25, 0.05, tilt)


## Flame of a brazier or beacon.
func flame(pos: Vector3, scale: float = 1.0) -> void:
	glow_box(pos, Vector3(0.5, 0.55, 0.5) * scale, Color(1.0, 0.5, 0.14), 0.7, Basis(Vector3.UP, 0.4))
	glow_box(pos + Vector3(0, 0.3, 0) * scale, Vector3(0.32, 0.7, 0.32) * scale, Color(1.0, 0.78, 0.3), 0.1, Basis(Vector3.UP, 1.1))


## Wide fire bowl on a foot, lit.
func fire_bowl(pos: Vector3, scale: float = 1.0) -> void:
	var fn := func() -> void:
		turned(PackedVector2Array([Vector2(0.62, -0.2), Vector2(0.62, 0.12), Vector2(0.3, 0.3), Vector2(0.24, 0.9), Vector2(0.55, 1.12), Vector2(0.72, 1.5), Vector2(0.6, 1.5), Vector2(0.0, 1.26)]),
			Vector3.ZERO, 12, tint(1.0), false, Callable(), "fire_bowl")
		flame(Vector3(0, 1.3, 0), 1.3)
	at(pos, 0.0, fn, scale)


## Creeper hanging from `from` down a wall face.
func vine(from: Vector3, length: float) -> void:
	var pts := PackedVector3Array()
	var p := from
	for i in 5:
		pts.append(p)
		p += Vector3(rng.randf_range(-0.25, 0.25), -length / 4.0, rng.randf_range(-0.05, 0.08))
	tube(pts, 0.07, VINE.lerp(Color(0.3, 0.42, 0.14), rng.randf()), true, 4)


# --- Output ---------------------------------------------------------------------

## The three merged surfaces: {"stone", "accent", "glow"} -> ArrayMesh or null.
func commit() -> Dictionary:
	var out := {"stone": null, "accent": null, "glow": null}
	if _used["flat"]:
		_flat.generate_normals()
		_flat.generate_tangents()
		_flat.index() # a merged surface must be indexed throughout
		_round.append_from(_flat.commit(), 0, Transform3D())
		_used["round"] = true
	if _used["round"]:
		out["stone"] = _round.commit()
	if _used["aflat"]:
		_aflat.generate_normals()
		_aflat.generate_tangents()
		_aflat.index()
		_around.append_from(_aflat.commit(), 0, Transform3D())
		_used["around"] = true
	if _used["around"]:
		out["accent"] = _around.commit()
	if _used["glow"]:
		_glow.generate_normals()
		out["glow"] = _glow.commit()
	return out


static func triangle_count(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
