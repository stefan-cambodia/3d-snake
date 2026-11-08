class_name GameSession
extends RefCounted
## One run of the game, as pure deterministic logic.
##
## The presentation layer feeds input, calls `step(dt)` and reacts to the
## returned events (sounds, particles, UI). Everything here is testable headless.

enum RunState { RUNNING, DEAD }

const EV_PICKUP := &"pickup"
const EV_SPAWN := &"spawn"
const EV_EXPIRE := &"expire"
const EV_STAGE := &"stage"
const EV_RISE_WARNING := &"rise_warning"
const EV_RISE_START := &"rise_start"
const EV_RISE_DONE := &"rise_done"
const EV_NEAR_MISS := &"near_miss"
const EV_SURGE_END := &"surge_end"
const EV_DEATH := &"death"

const CAUSE_WALL := &"wall"
const CAUSE_OBSTACLE := &"obstacle"
const CAUSE_SELF := &"self"

const RISE_STAGGER := 0.9
const RISE_MIN_HEAD_DIST := 9.0

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var terrain: TerrainField
var snake: SnakeSim
var scores := ScoreKeeper.new()
var obstacles: Array[Obstacle] = []
var items: Array[Collectible] = []

var state: int = RunState.RUNNING
var death_cause: StringName = &""
var stage: int = 1
var food_in_stage: int = 0
var time_alive: float = 0.0
var max_length: float = GameConfig.START_LENGTH
var rising_count: int = 0

var steer_input: float = 0.0
var boost_input: bool = false

var _events: Array[Dictionary] = []
var _next_item_id: int = 1
var _next_obstacle_id: int = 1000
var _energy_timer: float = 0.0
var _rare_timer: float = 0.0
var _pending_rises: int = 0
var _rise_timer: float = 0.0
var _near_cooldown: float = 0.0
var _near_armed: bool = false
var _was_surging: bool = false


func _init(p_terrain: TerrainField) -> void:
	terrain = p_terrain
	snake = SnakeSim.new(terrain)


## Start a new run on the given static layout (obstacle objects are shared, not copied).
func start(p_seed: int, static_obstacles: Array[Obstacle]) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	obstacles = static_obstacles.duplicate()
	items.clear()
	scores.reset()
	state = RunState.RUNNING
	death_cause = &""
	stage = 1
	food_in_stage = 0
	time_alive = 0.0
	rising_count = 0
	_pending_rises = 0
	_rise_timer = 0.0
	_near_cooldown = 0.0
	_near_armed = false
	_was_surging = false
	_next_item_id = 1
	_next_obstacle_id = 1000
	steer_input = 0.0
	boost_input = false
	snake.reset(WorldGenerator.SPAWN_POS, WorldGenerator.SPAWN_HEADING)
	snake.cruise_speed = GameConfig.cruise_speed_for_stage(stage)
	max_length = snake.length
	_energy_timer = rng.randf_range(GameConfig.ENERGY_INTERVAL.x, GameConfig.ENERGY_INTERVAL.y) * 0.6
	_rare_timer = rng.randf_range(GameConfig.RARE_INTERVAL.x, GameConfig.RARE_INTERVAL.y)
	_events.clear()
	# Opening food: one placed invitingly ahead in the spawn corridor.
	_spawn_item(Collectible.Kind.FOOD, Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(12.0, 16.0)))
	for i in GameConfig.FOOD_COUNT - 1:
		_spawn_random(Collectible.Kind.FOOD)


func is_running() -> bool:
	return state == RunState.RUNNING


## Advance the run by `frame_dt` seconds (internally sub-stepped).
## Returns the events produced during this call.
func step(frame_dt: float) -> Array[Dictionary]:
	_events.clear()
	var remaining := frame_dt
	while remaining > 0.0000001 and state == RunState.RUNNING:
		var dt := minf(remaining, GameConfig.MAX_SIM_STEP)
		_substep(dt)
		remaining -= dt
	return _events


func _substep(dt: float) -> void:
	snake.steer_input = steer_input
	snake.boost_input = boost_input
	snake.step(dt)
	time_alive += dt
	max_length = maxf(max_length, snake.length)
	scores.tick(dt)
	if _was_surging and not snake.is_surging():
		_events.append({"type": EV_SURGE_END})
	_was_surging = snake.is_surging()

	_update_items(dt)
	_update_rising(dt)
	_check_collisions()
	if state == RunState.RUNNING:
		_update_near_miss(dt)


# --- Collectibles -------------------------------------------------------------

func _update_items(dt: float) -> void:
	var tip := snake.head_tip()
	var head3 := Vector3(tip.x, snake.position.y, tip.y)
	var i := items.size() - 1
	while i >= 0:
		var it := items[i]
		it.age += dt
		var p2 := it.pos2()
		var d := p2.distance_to(tip)
		if d < GameConfig.MAGNET_RADIUS and d > 0.001:
			var pull := lerpf(9.0, 2.0, d / GameConfig.MAGNET_RADIUS) * dt
			var np := p2.move_toward(tip, minf(pull, d))
			it.pos = Vector3(np.x, terrain.height(np.x, np.y) + Collectible.HOVER, np.y)
			d = np.distance_to(tip)
		if d < GameConfig.PICKUP_RADIUS:
			items.remove_at(i)
			_on_pickup(it, head3)
		elif it.lifetime > 0.0 and it.age >= it.lifetime:
			items.remove_at(i)
			_events.append({"type": EV_EXPIRE, "id": it.id, "kind": it.kind, "pos": it.pos})
		i -= 1

	if not _has_kind(Collectible.Kind.ENERGY):
		_energy_timer -= dt
		if _energy_timer <= 0.0:
			if _spawn_random(Collectible.Kind.ENERGY):
				_energy_timer = rng.randf_range(GameConfig.ENERGY_INTERVAL.x, GameConfig.ENERGY_INTERVAL.y)
			else:
				_energy_timer = 1.0
	if not _has_kind(Collectible.Kind.RARE):
		_rare_timer -= dt
		if _rare_timer <= 0.0:
			if _spawn_random(Collectible.Kind.RARE):
				_rare_timer = rng.randf_range(GameConfig.RARE_INTERVAL.x, GameConfig.RARE_INTERVAL.y)
			else:
				_rare_timer = 1.0


func _on_pickup(it: Collectible, head_pos: Vector3) -> void:
	var surging := snake.is_surging()
	var pts := scores.award_pickup(Collectible.base_score(it.kind), surging)
	match it.kind:
		Collectible.Kind.FOOD:
			scores.food_eaten += 1
			snake.grow(GameConfig.GROWTH_PER_FOOD)
		Collectible.Kind.ENERGY:
			scores.energy_eaten += 1
			snake.surge_time = GameConfig.SURGE_DURATION
			snake.grow(GameConfig.GROWTH_PER_FOOD * 0.5)
			_was_surging = true
		Collectible.Kind.RARE:
			scores.rare_eaten += 1
			snake.grow(GameConfig.GROWTH_PER_RARE)
	_events.append({
		"type": EV_PICKUP, "id": it.id, "kind": it.kind, "pos": it.pos, "head": head_pos,
		"points": pts, "combo": scores.combo_count, "multiplier": scores.multiplier, "surge": surging,
	})
	if it.kind == Collectible.Kind.FOOD:
		food_in_stage += 1
		_spawn_random(Collectible.Kind.FOOD)
		if food_in_stage >= GameConfig.FOOD_PER_STAGE and stage < GameConfig.MAX_STAGE:
			_advance_stage()


func _has_kind(k: int) -> bool:
	for it in items:
		if it.kind == k:
			return true
	return false


func _spawn_item(k: int, p: Vector2) -> Collectible:
	var it := Collectible.new()
	it.id = _next_item_id
	_next_item_id += 1
	it.kind = k
	it.pos = Vector3(p.x, terrain.height(p.x, p.y) + Collectible.HOVER, p.y)
	match k:
		Collectible.Kind.ENERGY:
			it.lifetime = GameConfig.ENERGY_LIFETIME
		Collectible.Kind.RARE:
			it.lifetime = GameConfig.RARE_LIFETIME
	items.append(it)
	_events.append({"type": EV_SPAWN, "id": it.id, "kind": k, "pos": it.pos})
	return it


func _spawn_random(k: int) -> bool:
	var p: Variant = find_spawn_point(k)
	if p == null:
		return false
	_spawn_item(k, p)
	return true


## Pick a fair spawn point: away from walls, obstacles (incl. warning sites),
## the head, the body and other collectibles. Special items spawn at a
## distance that is reachable within their lifetime.
func find_spawn_point(k: int) -> Variant:
	var min_head := GameConfig.FOOD_MIN_DIST_FROM_HEAD
	var max_head := INF
	if k != Collectible.Kind.FOOD:
		min_head = 10.0
		max_head = 30.0
	for pass_i in 3:
		for attempt in 70:
			var r := sqrt(rng.randf()) * (GameConfig.ARENA_RADIUS - GameConfig.FOOD_MIN_DIST_FROM_WALL)
			var a := rng.randf() * TAU
			var p := Vector2(cos(a), sin(a)) * r
			if is_valid_item_point(p, min_head, max_head, pass_i == 2):
				return p
		# Relax distance constraints progressively, never the safety ones.
		min_head *= 0.6
		max_head = INF
	return null


func is_valid_item_point(p: Vector2, min_head: float, max_head: float = INF, relaxed: bool = false) -> bool:
	if p.length() > GameConfig.ARENA_RADIUS - GameConfig.FOOD_MIN_DIST_FROM_WALL:
		return false
	var hd := p.distance_to(snake.head_tip())
	if hd < min_head or hd > max_head:
		return false
	for o in obstacles:
		if o.edge_distance_within(p, GameConfig.FOOD_MIN_DIST_FROM_OBSTACLE) < GameConfig.FOOD_MIN_DIST_FROM_OBSTACLE:
			return false
	for it in items:
		if it.pos2().distance_to(p) < (2.0 if relaxed else 3.5):
			return false
	var body := snake.spine.clearance_xz(Vector3(p.x, 0.0, p.y), 0.0, snake.length, GameConfig.FOOD_MIN_DIST_FROM_BODY + 0.5)
	return body >= GameConfig.FOOD_MIN_DIST_FROM_BODY


# --- Difficulty ---------------------------------------------------------------

func _advance_stage() -> void:
	stage += 1
	food_in_stage = 0
	snake.cruise_speed = GameConfig.cruise_speed_for_stage(stage)
	var bonus := scores.add_bonus(GameConfig.SCORE_STAGE_BONUS * (stage - 1))
	var add := mini(GameConfig.RISING_OBSTACLES_PER_STAGE, GameConfig.MAX_RISING_OBSTACLES - rising_count - _pending_rises)
	_pending_rises += maxi(add, 0)
	_rise_timer = minf(_rise_timer, 0.6)
	_events.append({"type": EV_STAGE, "stage": stage, "bonus": bonus})


func _update_rising(dt: float) -> void:
	if _pending_rises > 0:
		_rise_timer -= dt
		if _rise_timer <= 0.0:
			var ob := _pick_rise_site()
			if ob != null:
				_pending_rises -= 1
				rising_count += 1
				obstacles.append(ob)
				_events.append({"type": EV_RISE_WARNING, "obstacle": ob})
				_rise_timer = RISE_STAGGER
			else:
				_rise_timer = 0.5
	for ob in obstacles:
		if ob.state == Obstacle.State.WARNING:
			ob.timer -= dt
			if ob.timer <= 0.0:
				ob.timer = 0.0
				if _rise_site_clear(ob):
					ob.state = Obstacle.State.RISING
					ob.timer = GameConfig.RISE_DURATION
					ob.rise = 0.0
					_relocate_items_from(ob)
					_events.append({"type": EV_RISE_START, "obstacle": ob})
		elif ob.state == Obstacle.State.RISING:
			ob.timer -= dt
			ob.rise = clampf(1.0 - ob.timer / GameConfig.RISE_DURATION, 0.0, 1.0)
			if ob.timer <= 0.0:
				ob.state = Obstacle.State.ACTIVE
				ob.rise = 1.0
				_events.append({"type": EV_RISE_DONE, "obstacle": ob})


func _pick_rise_site() -> Obstacle:
	var tip := snake.head_tip()
	var fwd := MathUtil.heading_dir2(snake.heading)
	for attempt in 60:
		var r := sqrt(rng.randf()) * (GameConfig.ARENA_RADIUS - GameConfig.OBSTACLE_MIN_GAP - 1.5)
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * r
		var to := p - tip
		var d := to.length()
		if d < RISE_MIN_HEAD_DIST:
			continue
		# Never drop an obstacle right into the player's line of travel.
		if d < 24.0 and fwd.dot(to / d) > cos(deg_to_rad(42.0)):
			continue
		var ob := Obstacle.create(Obstacle.KIND_RISING, p, rng.randf() * TAU, rng)
		if not WorldGenerator.respects_gaps(ob, obstacles) or not WorldGenerator.clear_of_ramps(ob, terrain):
			continue
		var blocked := false
		for c in ob.circles:
			if snake.spine.clearance_xz(Vector3(c.x, 0.0, c.y), 0.0, snake.length, c.z + 3.0) < c.z + 2.5:
				blocked = true
				break
		if blocked:
			continue
		for it in items:
			if ob.edge_distance(it.pos2()) < 1.2:
				blocked = true
				break
		if blocked:
			continue
		ob.id = _next_obstacle_id
		_next_obstacle_id += 1
		ob.state = Obstacle.State.WARNING
		ob.timer = GameConfig.RISE_WARNING_TIME
		ob.rise = 0.0
		return ob
	return null


## A rise is held back while any part of the snake is on the site.
func _rise_site_clear(ob: Obstacle) -> bool:
	if ob.edge_distance(snake.head_tip()) < 1.6:
		return false
	for c in ob.circles:
		if snake.spine.clearance_xz(Vector3(c.x, 0.0, c.y), 0.0, snake.length, c.z + 2.0) < c.z + GameConfig.BODY_RADIUS + 0.35:
			return false
	return true


func _relocate_items_from(ob: Obstacle) -> void:
	for it in items.duplicate():
		if ob.edge_distance(it.pos2()) < GameConfig.FOOD_MIN_DIST_FROM_OBSTACLE:
			items.erase(it)
			_events.append({"type": EV_EXPIRE, "id": it.id, "kind": it.kind, "pos": it.pos})
			if it.kind == Collectible.Kind.FOOD:
				_spawn_random(Collectible.Kind.FOOD)


# --- Collisions ---------------------------------------------------------------

func _check_collisions() -> void:
	var tip := snake.head_tip()
	var hr := GameConfig.HEAD_COLLISION_RADIUS
	if tip.length() + hr > GameConfig.ARENA_RADIUS:
		_die(CAUSE_WALL)
		return
	for ob in obstacles:
		if ob.is_solid() and ob.edge_distance_within(tip, hr) < hr:
			_die(CAUSE_OBSTACLE)
			return
	var body := snake.spine.clearance_xz(Vector3(tip.x, 0.0, tip.y), GameConfig.NECK_SKIP, snake.length, hr + GameConfig.BODY_COLLISION_RADIUS + 0.01)
	if body < hr + GameConfig.BODY_COLLISION_RADIUS:
		_die(CAUSE_SELF)


func _die(cause: StringName) -> void:
	state = RunState.DEAD
	death_cause = cause
	_events.append({"type": EV_DEATH, "cause": cause, "pos": snake.position})


## Head clearance to the nearest solid obstacle or own body (not the wall).
func head_clearance() -> float:
	var tip := snake.head_tip()
	var cap := GameConfig.HEAD_COLLISION_RADIUS + GameConfig.NEAR_MISS_DISTANCE + 1.0
	var best := cap
	for ob in obstacles:
		if ob.is_solid():
			best = minf(best, ob.edge_distance_within(tip, cap + GameConfig.HEAD_COLLISION_RADIUS) - GameConfig.HEAD_COLLISION_RADIUS)
	var body := snake.spine.clearance_xz(Vector3(tip.x, 0.0, tip.y), GameConfig.NECK_SKIP + 0.6, snake.length, cap + 1.0)
	best = minf(best, body - GameConfig.HEAD_COLLISION_RADIUS - GameConfig.BODY_COLLISION_RADIUS)
	return best


func _update_near_miss(dt: float) -> void:
	_near_cooldown = maxf(_near_cooldown - dt, 0.0)
	var c := head_clearance()
	if c < GameConfig.NEAR_MISS_DISTANCE:
		_near_armed = true
	elif _near_armed and c > GameConfig.NEAR_MISS_DISTANCE + 0.25:
		_near_armed = false
		if _near_cooldown <= 0.0:
			_near_cooldown = GameConfig.NEAR_MISS_COOLDOWN
			scores.near_misses += 1
			var pts := scores.add_bonus(GameConfig.NEAR_MISS_SCORE)
			_events.append({"type": EV_NEAR_MISS, "points": pts, "pos": snake.position})
