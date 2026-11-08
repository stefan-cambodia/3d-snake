class_name Autopilot
extends RefCounted
## Simple look-ahead driver: used for the attract-mode snake on the main menu
## and for automated soak tests. Samples a few steering arcs, rejects the ones
## that collide within the horizon and picks the one ending nearest its target.
## Food on (or off) a terrace is reached through a ramp: foot, then top.
## Cost is kept low (runs on phones while the menu is shown): obstacles are
## pre-filtered to the horizon radius once per decision.

const CANDIDATES: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
const HORIZON_STEPS := 10
const HORIZON_DT := 0.1
const DECISION_INTERVAL := 0.12

var steer: float = 0.0
var boost: bool = false
var wander_phase: float = 0.0
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _near: Array[Obstacle] = []


func _init(seed_value: int = 7) -> void:
	_rng.seed = seed_value
	wander_phase = _rng.randf() * 10.0


func update(session: GameSession, dt: float) -> void:
	_timer -= dt
	wander_phase += dt
	if _timer > 0.0:
		return
	_timer = DECISION_INTERVAL
	var sim := session.snake
	var tip := sim.head_tip()
	var reach := sim.speed * HORIZON_DT * HORIZON_STEPS + 3.0
	_near.clear()
	for ob in session.obstacles:
		if ob.state == Obstacle.State.WARNING and ob.timer > 0.8:
			continue
		if ob.position.distance_to(tip) < reach + ob.bounding_radius():
			_near.append(ob)
	var target := route(session.terrain, tip, _pick_target(session))
	var best_score := -INF
	var best_steer := 0.0
	for c in CANDIDATES:
		var sc := _evaluate(session, c, target)
		# Mild preference for smooth steering and a little life-like wander.
		sc -= absf(c - steer) * 0.6
		sc += sin(wander_phase * 0.7) * c * 0.4
		if sc > best_score:
			best_score = sc
			best_steer = c
	steer = best_steer
	var to := target - tip
	var ahead := MathUtil.heading_dir2(sim.heading).dot(to.normalized()) > 0.9
	boost = ahead and to.length() > 14.0 and sim.stamina > 0.45 and best_score > -50.0


## Next point to head for on the way from `from` to `goal`: the goal itself, or
## a ramp's foot or top when one of them is on a terrace the other is not.
static func route(terrain: TerrainField, from: Vector2, goal: Vector2) -> Vector2:
	var here := terrain.terrace_at(from)
	var there := terrain.terrace_at(goal)
	if here == there:
		return goal
	var on_ramp := terrain.ramp_distance(from) <= 0.0
	if here >= 0:
		# Leave this terrace by the ramp that suits the goal best.
		var t: TerrainField.Terrace = terrain.terraces[here]
		var best := 0
		var best_cost := INF
		for i in t.ramps.size():
			var cost := from.distance_to(t.ramp_top(i)) + t.ramp_foot(i).distance_to(goal)
			if cost < best_cost:
				best_cost = cost
				best = i
		if on_ramp or from.distance_to(t.ramp_top(best)) < 2.5:
			return t.ramp_foot(best)
		return t.ramp_top(best)
	# Climb the goal's terrace.
	var g: TerrainField.Terrace = terrain.terraces[there]
	var pick := 0
	var pick_cost := INF
	for i in g.ramps.size():
		var cost := from.distance_to(g.ramp_foot(i)) + g.ramp_top(i).distance_to(goal)
		if cost < pick_cost:
			pick_cost = cost
			pick = i
	if on_ramp or from.distance_to(g.ramp_foot(pick)) < 3.0:
		return g.ramp_top(pick)
	return g.ramp_foot(pick)


func _pick_target(session: GameSession) -> Vector2:
	var tip := session.snake.head_tip()
	var best := Vector2.ZERO
	var best_d := INF
	for it in session.items:
		var d := it.pos2().distance_to(tip)
		if it.kind != Collectible.Kind.FOOD:
			d *= 0.6
		if d < best_d:
			best_d = d
			best = it.pos2()
	return best


func _evaluate(session: GameSession, steer_value: float, target: Vector2) -> float:
	var sim := session.snake
	var h := sim.heading
	var p := sim.head_tip()
	var spd := sim.speed
	var rate := GameConfig.turn_rate_for_speed(spd)
	var hr := GameConfig.HEAD_COLLISION_RADIUS
	var body_r := hr + GameConfig.BODY_COLLISION_RADIUS
	var margin := 0.55
	var min_clear := 99.0
	for k in HORIZON_STEPS:
		var s := steer_value if k < 6 else steer_value * 0.3
		h -= s * rate * HORIZON_DT
		p += MathUtil.heading_dir2(h) * spd * HORIZON_DT
		var clear := GameConfig.ARENA_RADIUS - p.length() - hr
		for ob in _near:
			clear = minf(clear, ob.edge_distance_within(p, 3.0) - hr)
		if k % 2 == 1 or clear < 2.0:
			var body := sim.spine.clearance_xz(Vector3(p.x, 0.0, p.y), GameConfig.NECK_SKIP + 0.5, sim.length, 2.5)
			clear = minf(clear, body - body_r)
		min_clear = minf(min_clear, clear)
		if clear < margin:
			return -1000.0 + float(k) * 40.0 + clear
	return -p.distance_to(target) + minf(min_clear, 3.0) * 1.5
