class_name TerrainField
extends RefCounted
## Analytic height field of the sanctuary island and its lake.
##
## Gameplay (snake height, collectible placement, walls) and rendering (terrain
## mesh, water depth map, decoration placement) all query this one function, so
## what the player sees is always what the simulation uses.
##
## Relief inside the arena:
## - gentle hills, climbable from any direction;
## - raised terraces with near-vertical stone walls and one or two paved ramps.
##   Ground steeper than CLIMB_LIMIT is a wall: cliff_obstacles() turns it into
##   ordinary collision circles, so collisions, spawning rules, the autopilot
##   and the connectivity guarantee all treat terrace walls like any obstacle.

const PLAZA_RADIUS := 9.5
const SHORE_START := 44.0
const SHORE_END := 57.0
const LAKE_DEPTH := -3.4
const PLAY_AMPLITUDE := 0.4

## Steepest climbable ground (rise over run, about 39 degrees). Steeper is a wall.
const CLIMB_LIMIT := 0.8
## Hills flatten out toward the barrier, which stands on level ground.
const HILL_FADE_START := 32.0
const HILL_FADE_END := 39.0
## Hills fade to nothing over this distance outside a terrace footprint (wide
## enough that the fade itself never makes a slope too steep to climb).
const HILL_CLEARANCE := 6.5

## Terrace wall profile: the wall spans CLIFF_IN inside to CLIFF_OUT outside the rim.
const CLIFF_IN := 0.35
const CLIFF_OUT := 0.8
## Ramps: full-height width, side blend, steepest slope along the ramp.
const RAMP_HALF_WIDTH := 2.4
const RAMP_BLEND := 2.2
const RAMP_MAX_SLOPE := 0.42
## Terrace rims stay inside this radius (keeps the wall gap to the barrier).
const TERRACE_MAX_EXTENT := 36.5

## Wall collision: steep ground is sampled on this grid and covered by circles.
const CLIFF_SCAN_STEP := 0.5
## Half-width of the cross used to measure the local slope.
const SLOPE_PROBE := 0.15
const CLIFF_COVER_RADIUS := 0.6
const CLIFF_COVER_SPACING := 0.52


class Terrace:
	extends RefCounted
	var center := Vector2.ZERO
	var radius := 6.0
	var height := 2.0
	var phase := Vector3.ZERO
	## Unit directions (from the centre) of the ramps leading up.
	var ramps: Array[Vector2] = []
	var ramp_length := 7.0
	## Footprint radius including the ramps.
	var reach := 15.0

	## Rim radius in direction `ang` (gently wobbling outline).
	func rim(ang: float) -> float:
		return radius * (1.0 + 0.07 * sin(2.0 * ang + phase.x) + 0.05 * sin(3.0 * ang + phase.y) + 0.03 * sin(5.0 * ang + phase.z))

	## Where a ramp meets the ground (foot) and the terrace top (top).
	func ramp_foot(i: int) -> Vector2:
		var d := ramps[i]
		return center + d * (rim(d.angle()) + ramp_length + 1.2)

	func ramp_top(i: int) -> Vector2:
		var d := ramps[i]
		return center + d * (rim(d.angle()) - 1.6)


var seed_value: int
## Small islands in the lake: Vector4(x, z, radius, top_height).
var islets: Array[Vector4] = []
var terraces: Array[Terrace] = []
## Gentle mounds: Vector4(x, z, sigma, height).
var hills: Array[Vector4] = []

var _noise := FastNoiseLite.new()
var _shore := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _cliffs: Array[Obstacle] = []


func _init(p_seed: int = 1) -> void:
	seed_value = p_seed
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.045
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.45

	_shore.seed = p_seed + 17
	_shore.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shore.frequency = 0.9
	_shore.fractal_type = FastNoiseLite.FRACTAL_NONE

	_detail.seed = p_seed + 101
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.012
	_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail.fractal_octaves = 2

	_make_islets()
	_make_relief()


func _make_islets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 3
	islets.clear()
	# Fixed landmark islets (temple gate north, serpent statue east) + random ones.
	islets.append(Vector4(0.0, -64.0, 11.0, 0.55))
	islets.append(Vector4(74.0, 10.0, 10.0, 0.9))
	var tries := 0
	while islets.size() < 7 and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(66.0, 112.0)
		var p := Vector2(cos(a), sin(a)) * r
		var rad := rng.randf_range(4.5, 9.0)
		var ok := true
		for o in islets:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + rad + 8.0:
				ok = false
				break
		if ok:
			islets.append(Vector4(p.x, p.y, rad, rng.randf_range(0.2, 1.4)))


# --- Relief layout ------------------------------------------------------------------

func _make_relief() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 11
	terraces.clear()
	hills.clear()
	var want := rng.randi_range(2, 3)
	var tries := 0
	var placed_walls := _cliffs
	while terraces.size() < want and tries < 400:
		tries += 1
		var t := _try_terrace(rng)
		if t == null:
			continue
		# Check the walls this terrace really produces.
		terraces.append(t)
		var wall := _build_cliff(t)
		if _walls_fit(wall, placed_walls):
			placed_walls.append(wall)
		else:
			terraces.pop_back()
	tries = 0
	var want_hills := rng.randi_range(4, 6)
	while hills.size() < want_hills and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(13.0, 33.0)
		var p := Vector2(cos(a), sin(a)) * r
		var sigma := rng.randf_range(3.6, 6.0)
		var hh := rng.randf_range(0.9, 2.0)
		var ok := true
		for t in terraces:
			if p.distance_to(t.center) < t.reach + sigma + 1.0:
				ok = false
				break
		for o in hills:
			if p.distance_to(Vector2(o.x, o.y)) < (sigma + o.z) * 1.4:
				ok = false
				break
		if ok:
			hills.append(Vector4(p.x, p.y, sigma, hh))


func _try_terrace(rng: RandomNumberGenerator) -> Terrace:
	var t := Terrace.new()
	t.radius = rng.randf_range(5.2, 7.4)
	t.height = rng.randf_range(1.7, 2.5)
	t.phase = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var outer := t.radius * 1.15
	var dist := rng.randf_range(GameConfig.SPAWN_CLEAR_RADIUS + outer + 3.0, TERRACE_MAX_EXTENT - outer)
	var a := rng.randf() * TAU
	t.center = Vector2(cos(a), sin(a)) * dist
	t.ramp_length = 1.5 * t.height / RAMP_MAX_SLOPE - CLIFF_IN
	t.reach = outer + t.ramp_length + 1.5
	# Keep the spawn corridor (straight ahead along +Z) and other terraces clear.
	if _distance_to_corridor(t.center) < outer + 3.0:
		return null
	for o in terraces:
		if t.center.distance_to(o.center) < outer + o.radius * 1.15 + 11.0:
			return null
	# First ramp faces the middle of the island; a second one is optional.
	var to_mid := (-t.center).normalized().rotated(rng.randf_range(-0.6, 0.6))
	if not _ramp_fits(t, to_mid):
		return null
	t.ramps.append(to_mid)
	if rng.randf() < 0.65:
		for k in 6:
			var d := to_mid.rotated((1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.6, 2.6))
			if _ramp_fits(t, d):
				t.ramps.append(d)
				break
	return t


## A terrace's walls must leave the spawn area, the spawn corridor and the
## barrier gap free, and keep the obstacle gap to the other terraces' walls.
func _walls_fit(wall: Obstacle, others: Array[Obstacle]) -> bool:
	if wall.max_radius_from_origin() > GameConfig.ARENA_RADIUS - GameConfig.OBSTACLE_MIN_GAP - 0.3:
		return false
	if wall.edge_distance(Vector2.ZERO) < GameConfig.SPAWN_CLEAR_RADIUS + 0.5:
		return false
	var z := 0.0
	while z <= GameConfig.SPAWN_CORRIDOR_LENGTH + 2.0:
		if wall.edge_distance_within(Vector2(0.0, z), 3.0) < 3.0:
			return false
		z += 0.5
	for other in others:
		if wall.edge_distance_to(other, GameConfig.OBSTACLE_MIN_GAP + 1.0) < GameConfig.OBSTACLE_MIN_GAP + 1.0:
			return false
	return true


func _distance_to_corridor(p: Vector2) -> float:
	var z := clampf(p.y, -2.0, GameConfig.SPAWN_CORRIDOR_LENGTH + 4.0)
	return p.distance_to(Vector2(0.0, z))


## A ramp must land on open ground inside the arena, clear of other terraces.
func _ramp_fits(t: Terrace, d: Vector2) -> bool:
	var foot := t.center + d * (t.radius * 1.15 + t.ramp_length + 1.5)
	if foot.length() > GameConfig.ARENA_RADIUS - 6.0:
		return false
	if foot.distance_to(Vector2.ZERO) < PLAZA_RADIUS:
		return false
	for o in terraces:
		if foot.distance_to(o.center) < o.radius * 1.15 + 4.5:
			return false
	return true


# --- Height ---------------------------------------------------------------------------

## Ground height at world (x, z).
func height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var n := _noise.get_noise_2d(x, z)
	# Playable ground: rolling relief, perfectly flat stone plaza at the centre.
	var play := 0.0
	if r > PLAZA_RADIUS - 0.5:
		play = n * PLAY_AMPLITUDE * _ss(PLAZA_RADIUS - 0.5, PLAZA_RADIUS + 5.0, r)
	if r < PLAZA_RADIUS + 0.4:
		play += 0.05 * _ss(PLAZA_RADIUS + 0.4, PLAZA_RADIUS - 0.2, r) # raised plaza lip
	if r < SHORE_END:
		play += _relief(x, z, r, false).x
	if r < SHORE_START - 6.0:
		return play
	# Irregular shoreline.
	var ang := atan2(z, x)
	var wobble := _shore.get_noise_2d(cos(ang) * 3.0, sin(ang) * 3.0) * 3.2
	var t := MathUtil.smooth01(SHORE_START + wobble, SHORE_END + wobble, r)
	var lake := LAKE_DEPTH + n * 0.8 + _detail.get_noise_2d(x, z) * 0.9
	var h := lerpf(play, lake, t)
	if r > 52.0:
		for isl in islets:
			var dx := x - isl.x
			var dz := z - isl.y
			var d := sqrt(dx * dx + dz * dz)
			if d < isl.z * 1.9:
				var k := MathUtil.smooth01(isl.z * 1.9, isl.z * 0.55, d)
				h = maxf(h, lerpf(LAKE_DEPTH, isl.w + n * 0.4, k))
	# Far shore rises out of the lake toward the mountains.
	if r > 130.0:
		h = lerpf(h, 2.0 + n * 3.0, MathUtil.smooth01(130.0, 175.0, r))
	return h


## Height and paving together (one relief evaluation): x = height, y = paved.
func sample(x: float, z: float) -> Vector2:
	var r := sqrt(x * x + z * z)
	if r >= SHORE_START - 6.0:
		return Vector2(height(x, z), _relief(x, z, r, true).y if r < SHORE_END else 0.0)
	var n := _noise.get_noise_2d(x, z)
	var play := 0.0
	if r > PLAZA_RADIUS - 0.5:
		play = n * PLAY_AMPLITUDE * _ss(PLAZA_RADIUS - 0.5, PLAZA_RADIUS + 5.0, r)
	if r < PLAZA_RADIUS + 0.4:
		play += 0.05 * _ss(PLAZA_RADIUS + 0.4, PLAZA_RADIUS - 0.2, r)
	var rel := _relief(x, z, r, true)
	return Vector2(play + rel.x, rel.y)


## Smoothstep, inlined for the hot paths (a static call costs as much as the maths).
static func _ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Hills and terraces at (x, z): x = height, y = paved amount (only computed
## when `want_paved`).
func _relief(x: float, z: float, r: float, want_paved: bool) -> Vector2:
	var h := 0.0
	var paved := 0.0
	# Hills fade out before any terrace footprint, so they never change a wall
	# (walls are computed once, when terraces are placed).
	var fade := 1.0
	if r < PLAZA_RADIUS + 4.0:
		fade = _ss(PLAZA_RADIUS, PLAZA_RADIUS + 4.0, r)
	elif r > HILL_FADE_START:
		fade = 1.0 - _ss(HILL_FADE_START, HILL_FADE_END, r)
	for t in terraces:
		var qx := x - t.center.x
		var qz := z - t.center.y
		var tr2 := qx * qx + qz * qz
		var far := t.reach + HILL_CLEARANCE
		if tr2 >= far * far:
			continue
		var tr := sqrt(tr2)
		if tr > t.reach + 0.5:
			fade *= _ss(t.reach + 0.5, far, tr)
			continue
		fade = 0.0
		if tr > t.reach:
			continue
		var e := _terrace_eval(t, Vector2(qx, qz), tr, want_paved)
		h += e.x
		paved = maxf(paved, e.y)
	if fade > 0.0:
		for hl in hills:
			var dx := x - hl.x
			var dz := z - hl.y
			var d2 := dx * dx + dz * dz
			var s2 := hl.z * hl.z
			if d2 < 9.0 * s2:
				h += hl.w * exp(-d2 / (2.0 * s2)) * fade
	return Vector2(h, paved)


## One terrace at offset q (distance tr) from its centre: x = height, y = paved.
func _terrace_eval(t: Terrace, q: Vector2, tr: float, want_paved: bool = true) -> Vector2:
	var rim := t.rim(atan2(q.y, q.x))
	var k := 0.0
	for d in t.ramps:
		var u := q.x * d.x + q.y * d.y
		if u <= 0.0:
			continue
		var v := absf(d.x * q.y - d.y * q.x)
		if v < RAMP_HALF_WIDTH + RAMP_BLEND:
			k = maxf(k, 1.0 - _ss(RAMP_HALF_WIDTH, RAMP_HALF_WIDTH + RAMP_BLEND, v))
	# Wall profile, blended toward the long ramp profile across the ramp's sides:
	# the sides are as tall as the ramp is high, so they are steep only near the top.
	var s := clampf((rim + CLIFF_OUT - tr) / (CLIFF_OUT + CLIFF_IN), 0.0, 1.0)
	var hh := t.height * s * s * (3.0 - 2.0 * s)
	if k > 0.0:
		var sr := clampf((rim + t.ramp_length - tr) / (t.ramp_length + CLIFF_IN), 0.0, 1.0)
		hh = lerpf(hh, t.height * sr * sr * (3.0 - 2.0 * sr), k)
	if not want_paved:
		return Vector2(hh, 0.0)
	# Paving: the ramp surface, and a band of coping stones along the wall top.
	var top_edge := rim - CLIFF_IN
	var paved := 0.85 * _ss(top_edge - 1.1, top_edge - 0.8, tr) * _ss(top_edge + 0.6, top_edge + 0.2, tr)
	if k > 0.5:
		var end := rim + t.ramp_length
		paved = maxf(paved, _ss(0.55, 0.9, k) * _ss(end + 0.4, end - 0.3, tr) * _ss(rim - 2.6, rim - 1.4, tr))
	return Vector2(hh, paved)


## 0..1: how much of a paved ramp surface lies at (x, z).
func paved(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	if r >= SHORE_END:
		return 0.0
	return _relief(x, z, r, true).y


## Surface normal by central differences.
func normal(x: float, z: float, e: float = 0.35) -> Vector3:
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Steepness (rise over run) at (x, z).
func slope(x: float, z: float, e: float = 0.2) -> float:
	var gx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
	var gz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
	return sqrt(gx * gx + gz * gz)


## 0..1 dryness-independent "wildness" used to vary decoration density.
func variation(x: float, z: float) -> float:
	return _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5


## Index of the terrace whose top contains p (inside the wall line), or -1.
func terrace_at(p: Vector2) -> int:
	for i in terraces.size():
		var t := terraces[i]
		var q := p - t.center
		if q.length() < t.rim(q.angle()) - CLIFF_IN:
			return i
	return -1


## Distance from p to the nearest ramp surface (0 on a ramp), from its landing
## on the terrace top down to just past its foot.
func ramp_distance(p: Vector2) -> float:
	var best := INF
	for t in terraces:
		if p.distance_to(t.center) > t.reach + RAMP_HALF_WIDTH + 4.0:
			continue
		for i in t.ramps.size():
			var a := t.ramp_top(i)
			var b := t.ramp_foot(i)
			var ab := b - a
			var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, maxf(p.distance_to(a + ab * k) - RAMP_HALF_WIDTH, 0.0))
	return best


# --- Walls ----------------------------------------------------------------------------

## Collision for every terrace wall: one obstacle per terrace whose circles cover
## all ground steeper than CLIMB_LIMIT around it. Built when the terrace is
## placed (hills never reach a terrace, so nothing changes them afterwards).
func cliff_obstacles() -> Array[Obstacle]:
	return _cliffs


func _may_be_steep(t: Terrace, q: Vector2) -> bool:
	var tr := q.length()
	var rim := t.rim(atan2(q.y, q.x))
	if tr > rim - CLIFF_IN - 0.5 and tr < rim + CLIFF_OUT + 0.5:
		return true
	for d in t.ramps:
		var u := q.dot(d)
		if u <= 0.0 or u > rim + t.ramp_length * 0.7 + 1.0:
			continue
		var v := absf(d.x * q.y - d.y * q.x)
		if v > RAMP_HALF_WIDTH - 0.5 and v < RAMP_HALF_WIDTH + RAMP_BLEND + 0.5:
			return true
	return false


func _build_cliff(t: Terrace) -> Obstacle:
	var step := CLIFF_SCAN_STEP
	var ext := t.reach + 1.0
	var n := int(ceil(2.0 * ext / step)) + 1
	var origin := t.center - Vector2(ext, ext)
	var e := SLOPE_PROBE
	var limit2 := CLIMB_LIMIT * CLIMB_LIMIT * (4.0 * e * e)
	var circles: Array[Vector3] = []
	var cells := {}
	var cell := CLIFF_COVER_SPACING
	var spacing2 := CLIFF_COVER_SPACING * CLIFF_COVER_SPACING
	for i in n * n:
		var p := origin + Vector2(i % n, i / n) * step
		if not _may_be_steep(t, p - t.center):
			continue
		# Local slope from a small cross of samples: a wall is steep, the grass
		# at its foot is not, even half a metre away.
		var gx := height(p.x + e, p.y) - height(p.x - e, p.y)
		var gz := height(p.x, p.y + e) - height(p.x, p.y - e)
		if gx * gx + gz * gz <= limit2:
			continue
		var key := Vector2i(floori(p.x / cell), floori(p.y / cell))
		var covered := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for c: Vector2 in cells.get(key + Vector2i(dx, dz), []):
					if c.distance_squared_to(p) <= spacing2:
						covered = true
						break
				if covered:
					break
			if covered:
				break
		if covered:
			continue
		circles.append(Vector3(p.x, p.y, CLIFF_COVER_RADIUS))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(p)
	var ob := Obstacle.new()
	ob.kind = Obstacle.KIND_CLIFF
	ob.position = t.center
	ob.height = t.height
	ob.top_y = height(t.center.x, t.center.y) + 0.3
	ob.circles = circles
	return ob
