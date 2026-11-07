class_name SnakeSim
extends RefCounted
## Kinematic simulation of the snake head (movement, steering, boost, growth).
## Pure logic: no nodes, deterministic for a given input sequence.

const GROUND_OFFSET := GameConfig.BODY_RADIUS * 0.82
const HEAD_FORWARD_OFFSET := 0.22 ## Collision point sits slightly ahead of the skull centre.

var terrain: TerrainField
var spine: Spine

var position: Vector3 = Vector3.ZERO
var heading: float = 0.0
var speed: float = GameConfig.BASE_SPEED
var cruise_speed: float = GameConfig.BASE_SPEED
var yaw_rate: float = 0.0

## Inputs (set every frame by the controller).
var steer_input: float = 0.0
var boost_input: bool = false

var steer: float = 0.0
var boosting: bool = false
## Set when stamina runs dry; boost re-arms only after the button is released.
var exhausted: bool = false
var stamina: float = 1.0
var _regen_delay: float = 0.0
var surge_time: float = 0.0

var length: float = GameConfig.START_LENGTH
var target_length: float = GameConfig.START_LENGTH
var distance_travelled: float = 0.0


func _init(p_terrain: TerrainField) -> void:
	terrain = p_terrain
	spine = Spine.new()


func reset(pos: Vector2, p_heading: float) -> void:
	heading = p_heading
	position = Vector3(pos.x, ground_y(pos.x, pos.y), pos.y)
	speed = GameConfig.BASE_SPEED
	cruise_speed = GameConfig.BASE_SPEED
	yaw_rate = 0.0
	steer_input = 0.0
	boost_input = false
	steer = 0.0
	boosting = false
	exhausted = false
	stamina = 1.0
	_regen_delay = 0.0
	surge_time = 0.0
	length = GameConfig.START_LENGTH
	target_length = GameConfig.START_LENGTH
	distance_travelled = 0.0
	spine.reset(position, -forward(), GameConfig.START_LENGTH + 2.0, ground_y)


func ground_y(x: float, z: float) -> float:
	return terrain.height(x, z) + GROUND_OFFSET


func forward() -> Vector3:
	return MathUtil.heading_dir(heading)


## Ground-plane collision point of the head.
func head_tip() -> Vector2:
	return Vector2(position.x, position.z) + MathUtil.heading_dir2(heading) * HEAD_FORWARD_OFFSET


func is_surging() -> bool:
	return surge_time > 0.0


func step(dt: float) -> void:
	steer = MathUtil.damp(steer, clampf(steer_input, -1.0, 1.0), GameConfig.STEER_RESPONSE, dt)

	# Boost / stamina.
	if not boost_input:
		exhausted = false
	var want := boost_input and not exhausted and stamina > 0.0 and (boosting or stamina >= GameConfig.STAMINA_MIN_TO_START)
	if want:
		stamina = maxf(stamina - GameConfig.STAMINA_DRAIN * dt, 0.0)
		_regen_delay = GameConfig.STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			want = false
			exhausted = true
	else:
		if _regen_delay > 0.0:
			_regen_delay -= dt
		else:
			stamina = minf(stamina + GameConfig.STAMINA_REGEN * dt, 1.0)
	boosting = want

	var target_speed := cruise_speed
	if boosting:
		target_speed *= GameConfig.BOOST_MULTIPLIER
	if surge_time > 0.0:
		target_speed *= GameConfig.SURGE_MULTIPLIER
		surge_time = maxf(surge_time - dt, 0.0)
	speed = MathUtil.damp(speed, target_speed, GameConfig.SPEED_RESPONSE, dt)

	# Positive steer = turn right = decreasing heading.
	yaw_rate = -steer * GameConfig.turn_rate_for_speed(speed)
	heading = wrapf(heading + yaw_rate * dt, -PI, PI)

	var f := forward()
	var np := position + f * (speed * dt)
	np.y = ground_y(np.x, np.z)
	position = np
	distance_travelled += speed * dt
	length = move_toward(length, target_length, GameConfig.GROWTH_RATE * dt)
	spine.advance(position)


func grow(amount: float) -> void:
	target_length = minf(target_length + amount, GameConfig.MAX_LENGTH)
