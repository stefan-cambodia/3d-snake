class_name ChaseCamera
extends Camera3D
## Third-person chase camera with spring-damped yaw/position, predictive turning,
## speed-dependent distance and FOV, subtle banking, trauma shake, obstacle
## avoidance, and cinematic modes for intro, death and the main menu.

enum Mode { MENU, INTRO, CHASE, DEATH, SHOWCASE }

const BASE_FOV := 64.0

var mode: int = Mode.MENU
var sim: SnakeSim
var obstacles: Array[Obstacle] = []
var terrain: TerrainField

## Player settings.
var smoothing: float = 1.0 # 0.5 (snappy) .. 1.5 (smooth)
var distance_pref: int = 1

var _yaw: float = 0.0
var _pos: Vector3 = Vector3(0, 10, -20)
var _look: Vector3 = Vector3.ZERO
var _fov: float = BASE_FOV
var _roll: float = 0.0
var _trauma: float = 0.0
var _pull: float = 1.0
var _mode_time: float = 0.0
var _orbit: float = 0.0
var _from_pos: Vector3
var _from_look: Vector3
var _death_pos: Vector3
var _shake_t: float = 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = 3.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fov = BASE_FOV
	near = 0.1
	far = 600.0


func set_mode(m: int) -> void:
	_from_pos = global_position
	_from_look = _look
	mode = m
	_mode_time = 0.0
	if m == Mode.DEATH and sim:
		_death_pos = sim.position
		_orbit = _yaw
	if m == Mode.INTRO and sim:
		_yaw = sim.heading


## Jump straight to the chase framing (no blend).
func snap_to_chase() -> void:
	if sim == null:
		return
	_yaw = sim.heading
	var t := _chase_target(0.0)
	_pos = t[0]
	_look = t[1]
	_pull = 1.0
	global_position = _pos
	look_at(_look, Vector3.UP)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _dist_params() -> Vector2:
	match distance_pref:
		0:
			return Vector2(4.3, 2.25)
		2:
			return Vector2(6.6, 3.2)
	return Vector2(5.3, 2.7)


## Returns [position, look_at] for the chase framing at the current smoothed yaw.
func _chase_target(delta: float) -> Array:
	var head := sim.position
	var dp := _dist_params()
	var speed_k := clampf((sim.speed - GameConfig.BASE_SPEED) / 10.0, 0.0, 1.0)
	var len_k := clampf(sim.length / 70.0, 0.0, 1.0)
	var dist := dp.x * (1.0 + speed_k * 0.18 + len_k * 0.22)
	var height := dp.y * (1.0 + len_k * 0.3) + speed_k * 0.2
	var back := -MathUtil.heading_dir(_yaw)
	var desired := head + back * dist + Vector3.UP * height
	# Pull in when an obstacle stands between the head and the camera.
	var pull := _obstruction(head, desired)
	if delta > 0.0:
		_pull = MathUtil.damp(_pull, pull, 0.05 if pull < _pull else 0.45, delta)
	else:
		_pull = pull
	desired = head + back * dist * _pull + Vector3.UP * (height + (1.0 - _pull) * 1.2)
	if terrain:
		desired.y = maxf(desired.y, terrain.height(desired.x, desired.z) + 0.8)
	var ahead := 2.6 + sim.speed * 0.16
	var look := head + MathUtil.heading_dir(_yaw) * ahead + Vector3.UP * 0.55
	return [desired, look]


func _obstruction(head: Vector3, cam: Vector3) -> float:
	var a := Vector2(head.x, head.z)
	var b := Vector2(cam.x, cam.z)
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return 1.0
	var best := 1.0
	for ob in obstacles:
		if not ob.is_solid() or ob.height < 1.6:
			continue
		for c in ob.circles:
			var center := Vector2(c.x, c.y)
			var t := clampf((center - a).dot(ab) / len2, 0.0, 1.0)
			var closest := a + ab * t
			var r := c.z + 0.45
			var d := closest.distance_to(center)
			if d < r and t > 0.15:
				# Back off to just in front of the obstacle.
				var tt := t - sqrt(maxf(r * r - d * d, 0.0)) / sqrt(len2)
				best = minf(best, clampf(tt - 0.05, 0.35, 1.0))
	return best


func _process(delta: float) -> void:
	if sim == null:
		return
	_mode_time += delta
	var target_pos: Vector3
	var target_look: Vector3
	var target_fov := BASE_FOV
	var pos_tau := 0.05
	var look_tau := 0.05
	var roll_target := 0.0
	match mode:
		Mode.CHASE, Mode.INTRO:
			# Predictive yaw: lead slightly into the turn to reveal the path ahead.
			var target_yaw := sim.heading + sim.yaw_rate * 0.14
			_yaw = MathUtil.damp_angle(_yaw, target_yaw, 0.15 * smoothing, delta)
			var t := _chase_target(delta)
			target_pos = t[0]
			target_look = t[1]
			pos_tau = 0.045 * smoothing
			look_tau = 0.035 * smoothing
			var speed_k := clampf((sim.speed - sim.cruise_speed) / 6.0, 0.0, 1.0)
			target_fov = BASE_FOV + speed_k * 9.0 + (4.0 if sim.is_surging() else 0.0)
			roll_target = clampf(sim.yaw_rate * 0.025, -0.06, 0.06)
			if mode == Mode.INTRO:
				var k := MathUtil.smooth01(0.0, GameConfig.INTRO_DURATION, _mode_time)
				target_pos = _from_pos.lerp(target_pos, k)
				target_look = _from_look.lerp(target_look, k)
				pos_tau = 0.0
				look_tau = 0.0
				if _mode_time >= GameConfig.INTRO_DURATION:
					mode = Mode.CHASE
		Mode.DEATH:
			_orbit += delta * 0.35
			var k := MathUtil.smooth01(0.0, 1.5, _mode_time)
			var r := lerpf(5.0, 8.5, k)
			var h := lerpf(2.6, 5.5, k)
			target_pos = _death_pos + Vector3(-sin(_orbit), 0, -cos(_orbit)) * r + Vector3.UP * h
			target_look = _death_pos + Vector3.UP * 0.3
			pos_tau = 0.25
			look_tau = 0.12
			target_fov = BASE_FOV - 6.0
		Mode.MENU:
			# Slow cinematic orbit around the attract-mode snake, framed right of centre.
			_orbit += delta * 0.07
			var head := sim.position
			var rr := 9.0 + sin(_mode_time * 0.13) * 1.5
			target_pos = head + Vector3(sin(_orbit), 0, cos(_orbit)) * rr + Vector3.UP * (3.2 + sin(_mode_time * 0.21) * 0.8)
			target_look = head + Vector3.UP * 0.4
			pos_tau = 0.9
			look_tau = 0.35
			target_fov = 52.0
		Mode.SHOWCASE:
			# Close beauty shot of the head for the skin selector.
			_orbit += delta * 0.25
			var hd := sim.position
			var fwd := sim.forward()
			var side := MathUtil.heading_right(sim.heading)
			target_pos = hd + fwd * 2.4 + side * (1.6 + sin(_orbit) * 0.6) + Vector3.UP * 1.1
			target_look = hd + fwd * -1.2 + Vector3.UP * 0.2
			pos_tau = 0.4
			look_tau = 0.25
			target_fov = 50.0
	if terrain:
		target_pos.y = maxf(target_pos.y, terrain.height(target_pos.x, target_pos.z) + 0.6)
	_pos = target_pos if pos_tau <= 0.0 else MathUtil.damp_v3(_pos, target_pos, pos_tau, delta)
	_look = target_look if look_tau <= 0.0 else MathUtil.damp_v3(_look, target_look, look_tau, delta)
	_fov = MathUtil.damp(_fov, target_fov, 0.35, delta)
	_roll = MathUtil.damp(_roll, roll_target, 0.25, delta)
	h_offset = MathUtil.damp(h_offset, -1.6 if mode == Mode.MENU else 0.0, 0.6, delta)

	# Trauma-based shake (squared for a nice falloff).
	_trauma = maxf(_trauma - delta * 1.4, 0.0)
	_shake_t += delta
	var sh := _trauma * _trauma
	var shake := Vector3(_noise.get_noise_2d(_shake_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _shake_t * 60.0), 0.0) * sh * 0.35

	global_position = _pos + shake
	if global_position.distance_squared_to(_look) > 0.0001:
		look_at(_look, Vector3.UP)
		rotate_object_local(Vector3.FORWARD, _roll + shake.x * 0.1)
	fov = _fov
