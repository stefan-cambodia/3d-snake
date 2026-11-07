extends TestCase


func _run(s: GameSession, seconds: float, steer: float = 0.0) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var t := 0.0
	while t < seconds and s.is_running():
		s.steer_input = steer
		all.append_array(s.step(1.0 / 60.0))
		t += 1.0 / 60.0
	return all


func _events_of(events: Array[Dictionary], type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == type:
			out.append(e)
	return out


func test_start_state() -> void:
	var s := make_session()
	check(s.is_running(), "running")
	check_eq(s.stage, 1, "stage 1")
	check_eq(s.scores.score, 0, "score 0")
	var food := 0
	for it in s.items:
		if it.kind == Collectible.Kind.FOOD:
			food += 1
			check(it.pos2().distance_to(s.snake.head_tip()) >= 7.0, "food not on top of the head")
	check_eq(food, GameConfig.FOOD_COUNT, "food count")


func test_eating_food_scores_and_grows() -> void:
	var s := make_session()
	# The first food is placed straight ahead in the spawn corridor.
	var ev := _run(s, 3.0)
	var picks := _events_of(ev, GameSession.EV_PICKUP)
	check(picks.size() >= 1, "ate the corridor food")
	check_eq(s.scores.food_eaten, picks.size(), "food stat")
	check(s.scores.score >= GameConfig.SCORE_FOOD, "score increased")
	check(s.snake.target_length > GameConfig.START_LENGTH, "target length grew")
	var food := 0
	for it in s.items:
		if it.kind == Collectible.Kind.FOOD:
			food += 1
	check_eq(food, GameConfig.FOOD_COUNT, "food replenished")


func test_combo_multiplier() -> void:
	var k := ScoreKeeper.new()
	check_eq(k.award_pickup(10, false), 10, "first pickup x1")
	k.tick(1.0)
	check_eq(k.award_pickup(10, false), 13, "chain x1.25 (rounded)")
	k.tick(1.0)
	check_eq(k.award_pickup(10, false), 15, "chain x1.5")
	k.tick(GameConfig.COMBO_WINDOW + 0.01)
	check_eq(k.combo_count, 0, "combo expired")
	check_eq(k.award_pickup(10, true), 20, "surge doubles, chain reset")
	for i in 20:
		k.award_pickup(10, false)
	check_near(k.multiplier, GameConfig.COMBO_MAX, 0.0001, "multiplier capped")
	check_eq(k.best_combo, 21, "best combo tracked")


func test_wall_collision_kills() -> void:
	var s := make_session()
	s.obstacles.clear()
	s.items.clear()
	var ev := _run(s, 20.0)
	check(not s.is_running(), "died")
	check_eq(s.death_cause, GameSession.CAUSE_WALL, "cause = wall")
	check_eq(_events_of(ev, GameSession.EV_DEATH).size(), 1, "one death event")
	check(s.snake.head_tip().length() <= GameConfig.ARENA_RADIUS, "stopped at the wall")


func test_obstacle_collision_kills() -> void:
	var s := make_session()
	s.obstacles.clear()
	s.items.clear()
	var rng := RandomNumberGenerator.new()
	var ob := Obstacle.create(Obstacle.KIND_PILLAR, Vector2(0, 15), 0.0, rng)
	s.obstacles.append(ob)
	_run(s, 5.0)
	check(not s.is_running(), "died")
	check_eq(s.death_cause, GameSession.CAUSE_OBSTACLE, "cause = obstacle")
	check(ob.edge_distance(s.snake.head_tip()) > -0.25, "no deep penetration")


func test_self_collision_when_circling() -> void:
	var s := make_session()
	s.obstacles.clear()
	s.items.clear()
	s.snake.length = 30.0
	s.snake.target_length = 30.0
	var ev := _run(s, 12.0, 1.0)
	check(not s.is_running(), "a long snake turning in place bites itself")
	check_eq(s.death_cause, GameSession.CAUSE_SELF, "cause = self")


func test_short_snake_can_circle_safely() -> void:
	var s := make_session()
	s.obstacles.clear()
	s.items.clear()
	_run(s, 8.0, 1.0)
	check(s.is_running(), "a 5 m snake turning full lock never hits its own neck")


func test_stage_progression_and_speed() -> void:
	var s := make_session()
	var start_speed := s.snake.cruise_speed
	for i in GameConfig.FOOD_PER_STAGE:
		var it := s.items[0]
		s.items.remove_at(0)
		s._on_pickup(it, s.snake.position)
	check_eq(s.stage, 2, "stage advanced")
	check(s.snake.cruise_speed > start_speed, "faster at stage 2")
	check_eq(s._pending_rises, GameConfig.RISING_OBSTACLES_PER_STAGE, "rising obstacles scheduled")
	for st in range(1, 40):
		check(GameConfig.cruise_speed_for_stage(st) <= GameConfig.MAX_CRUISE_SPEED, "speed cap")
		check(GameConfig.cruise_speed_for_stage(st + 1) >= GameConfig.cruise_speed_for_stage(st), "monotonic")


func test_rising_obstacle_lifecycle() -> void:
	var s := make_session(5)
	s._advance_stage()
	var ev: Array[Dictionary] = []
	var bot := Autopilot.new(2)
	var t := 0.0
	while t < 6.0 and s.is_running():
		bot.update(s, 1.0 / 60.0)
		s.steer_input = bot.steer
		ev.append_array(s.step(1.0 / 60.0))
		t += 1.0 / 60.0
	var warn := _events_of(ev, GameSession.EV_RISE_WARNING)
	check(warn.size() >= 1, "warning emitted")
	check(_events_of(ev, GameSession.EV_RISE_START).size() >= 1, "rise started")
	check(_events_of(ev, GameSession.EV_RISE_DONE).size() >= 1, "rise finished")
	for e in warn:
		var ob: Obstacle = e["obstacle"]
		check(ob.state == Obstacle.State.ACTIVE or ob.state == Obstacle.State.RISING, "obstacle solid after warning")


func test_rise_waits_for_snake_to_leave() -> void:
	var s := make_session()
	s.obstacles.clear()
	var rng := RandomNumberGenerator.new()
	var ob := Obstacle.create(Obstacle.KIND_RISING, Vector2(0, -2.0), 0.0, rng)
	ob.state = Obstacle.State.WARNING
	ob.timer = 0.01
	s.obstacles.append(ob)
	s.steer_input = 0.0
	s.step(1.0 / 60.0)
	check_eq(ob.state, Obstacle.State.WARNING, "held while the body lies on the site")
	s.items.clear()
	_run(s, 2.0)
	check(ob.state != Obstacle.State.WARNING, "rises once the tail has passed")


func test_collectible_spawn_rules() -> void:
	var s := make_session(11)
	for i in 300:
		var p: Variant = s.find_spawn_point(Collectible.Kind.FOOD)
		check(p != null, "found a spawn point")
		if p == null:
			continue
		var v: Vector2 = p
		check(v.length() <= GameConfig.ARENA_RADIUS - GameConfig.FOOD_MIN_DIST_FROM_WALL, "inside arena")
		for ob in s.obstacles:
			check(ob.edge_distance(v) >= GameConfig.FOOD_MIN_DIST_FROM_OBSTACLE, "not inside / next to an obstacle")
		var body := s.snake.spine.clearance_xz(Vector3(v.x, 0, v.y), 0.0, s.snake.length, 5.0)
		check(body >= GameConfig.FOOD_MIN_DIST_FROM_BODY, "not on the body")
	for i in 50:
		var p: Variant = s.find_spawn_point(Collectible.Kind.RARE)
		if p != null:
			var d: float = (p as Vector2).distance_to(s.snake.head_tip())
			check(d >= 6.0 and d <= 30.0, "rare reachable but not trivial (%f)" % d)


func test_energy_and_rare_spawn_and_expire() -> void:
	var s := make_session(21)
	var bot := Autopilot.new(3)
	var ev: Array[Dictionary] = []
	var t := 0.0
	while t < 75.0 and s.is_running():
		bot.update(s, 1.0 / 30.0)
		s.steer_input = bot.steer
		ev.append_array(s.step(1.0 / 30.0))
		t += 1.0 / 30.0
	var kinds := {}
	for e in _events_of(ev, GameSession.EV_SPAWN):
		kinds[e["kind"]] = true
	check(kinds.has(Collectible.Kind.ENERGY), "energy crystal spawned")
	check(kinds.has(Collectible.Kind.RARE), "rare relic spawned (alive %.1fs)" % t)


func test_session_restart_resets_everything() -> void:
	var s := make_session(8)
	_run(s, 30.0, 0.4)
	var static_count := WorldGenerator.generate(8).size()
	s.start(8, WorldGenerator.generate(8))
	check(s.is_running(), "running again")
	check_eq(s.scores.score, 0, "score reset")
	check_eq(s.stage, 1, "stage reset")
	check_eq(s.obstacles.size(), static_count, "rising obstacles removed")
	check_near(s.snake.length, GameConfig.START_LENGTH, 0.0001, "length reset")
	check_eq(s.snake.position, Vector3(0, s.snake.ground_y(0, 0), 0), "back at spawn")


func test_near_miss_awards_bonus() -> void:
	var s := make_session()
	s.obstacles.clear()
	s.items.clear()
	var rng := RandomNumberGenerator.new()
	# Pillar edge passes 0.5 m from the head path: inside the near-miss band, no hit.
	var ob := Obstacle.create(Obstacle.KIND_PILLAR, Vector2(0.78 + GameConfig.HEAD_COLLISION_RADIUS + 0.3, 12.0), 0.0, rng)
	s.obstacles.append(ob)
	var ev := _run(s, 3.0)
	check(s.is_running(), "survived the close call")
	check_eq(_events_of(ev, GameSession.EV_NEAR_MISS).size(), 1, "one near-miss")
	check_eq(s.scores.score, GameConfig.NEAR_MISS_SCORE, "near-miss score")


func test_autopilot_survives() -> void:
	# The look-ahead bot should survive a while on several layouts: a sanity
	# check that layouts are fair and the simulation is stable.
	var total := 0.0
	for seed_value in [1, 2, 3]:
		var s := make_session(seed_value)
		var bot := Autopilot.new(seed_value)
		var t := 0.0
		while t < 45.0 and s.is_running():
			bot.update(s, 1.0 / 30.0)
			s.steer_input = bot.steer
			s.boost_input = bot.boost
			s.step(1.0 / 30.0)
			t += 1.0 / 30.0
		total += t
		check(s.scores.food_eaten >= 3, "seed %d: bot eats (%d)" % [seed_value, s.scores.food_eaten])
	check(total > 60.0, "bot survives on average (%.1f s total)" % total)
