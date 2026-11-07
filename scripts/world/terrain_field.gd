class_name TerrainField
extends RefCounted
## Analytic height field of the sanctuary island and its lake.
##
## Gameplay (snake height, collectible placement) and rendering (terrain mesh,
## water depth map, decoration placement) all query this one function, so what
## the player sees is always what the simulation uses.

const PLAZA_RADIUS := 9.5
const SHORE_START := 44.0
const SHORE_END := 57.0
const LAKE_DEPTH := -3.4
const PLAY_AMPLITUDE := 0.34

var seed_value: int
## Small islands in the lake: Vector4(x, z, radius, top_height).
var islets: Array[Vector4] = []

var _noise := FastNoiseLite.new()
var _shore := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


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


## Ground height at world (x, z).
func height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var n := _noise.get_noise_2d(x, z)
	# Playable plateau: gentle rolling ground, perfectly flat stone plaza at the centre.
	var play := n * PLAY_AMPLITUDE * MathUtil.smooth01(PLAZA_RADIUS - 0.5, PLAZA_RADIUS + 5.0, r)
	play += 0.05 * MathUtil.smooth01(PLAZA_RADIUS + 0.4, PLAZA_RADIUS - 0.2, r) # raised plaza lip
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


## Surface normal by central differences.
func normal(x: float, z: float, e: float = 0.35) -> Vector3:
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## 0..1 dryness-independent "wildness" used to vary decoration density.
func variation(x: float, z: float) -> float:
	return _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
