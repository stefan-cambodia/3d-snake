extends TestCase


func test_deterministic_for_same_seed() -> void:
	var a := WorldGenerator.generate(42)
	var b := WorldGenerator.generate(42)
	check_eq(a.size(), b.size(), "same obstacle count")
	for i in mini(a.size(), b.size()):
		check(a[i].kind == b[i].kind and a[i].position.is_equal_approx(b[i].position), "obstacle %d identical" % i)
	var c := WorldGenerator.generate(43)
	var differs := c.size() != a.size()
	for i in mini(a.size(), c.size()):
		differs = differs or not a[i].position.is_equal_approx(c[i].position)
	check(differs, "different seed gives different layout")


func test_layout_constraints_over_many_seeds() -> void:
	for seed_value in range(1, 41):
		var obs := WorldGenerator.generate(seed_value)
		check(obs.size() >= 18, "seed %d: enough obstacles (%d)" % [seed_value, obs.size()])
		for i in obs.size():
			var o := obs[i]
			check(o.max_radius_from_origin() <= GameConfig.ARENA_RADIUS - GameConfig.OBSTACLE_MIN_GAP + 0.0001, "seed %d: wall gap" % seed_value)
			check(o.edge_distance(WorldGenerator.SPAWN_POS) >= GameConfig.SPAWN_CLEAR_RADIUS, "seed %d: spawn clear" % seed_value)
			for j in range(i + 1, obs.size()):
				check(o.edge_distance_to(obs[j]) >= GameConfig.OBSTACLE_MIN_GAP - 0.0001, "seed %d: gap %d-%d" % [seed_value, i, j])
			# Spawn corridor straight ahead (+Z) must be free.
			var z := 0.0
			while z < GameConfig.SPAWN_CORRIDOR_LENGTH:
				if o.edge_distance(Vector2(0, z)) < minf(2.0, GameConfig.SPAWN_CORRIDOR_LENGTH - z):
					check(false, "seed %d: corridor blocked at z=%.1f" % [seed_value, z])
				z += 0.5


func test_free_space_fully_connected() -> void:
	for seed_value in [3, 17, 99, 2024]:
		var obs := WorldGenerator.generate(seed_value)
		var frac := WorldGenerator.reachable_fraction(obs, 0.6)
		check_near(frac, 1.0, 0.0001, "seed %d reachable fraction" % seed_value)


func test_terrain_is_deterministic_and_playable() -> void:
	var a := TerrainField.new(9)
	var b := TerrainField.new(9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		var x := rng.randf_range(-60, 60)
		var z := rng.randf_range(-60, 60)
		check_eq(a.height(x, z), b.height(x, z), "same height")
		if Vector2(x, z).length() < GameConfig.ARENA_RADIUS:
			check(a.height(x, z) > GameConfig.WATER_LEVEL + 0.1, "arena above water at (%.1f, %.1f)" % [x, z])
			check(a.normal(x, z).y > 0.93, "arena slopes gentle")
	check_near(a.height(0, 0), a.height(3, 4), 0.06, "plaza is flat")
	check(a.height(0, 90) < GameConfig.WATER_LEVEL, "lake is under water")


func test_rising_obstacles_keep_layout_connected() -> void:
	var s := make_session(77)
	var bot := Autopilot.new(1)
	# Force many stages quickly to accumulate rising obstacles.
	var guard := 0
	while s.rising_count < 10 and guard < 40:
		guard += 1
		s._advance_stage()
		for i in 240:
			bot.update(s, 1.0 / 60.0)
			s.steer_input = bot.steer
			s.step(1.0 / 60.0)
			if not s.is_running():
				break
		if not s.is_running():
			s.state = GameSession.RunState.RUNNING
	check(s.rising_count >= 6, "rising obstacles were placed (%d)" % s.rising_count)
	for ob in s.obstacles:
		ob.state = Obstacle.State.ACTIVE
	for i in s.obstacles.size():
		for j in range(i + 1, s.obstacles.size()):
			check(s.obstacles[i].edge_distance_to(s.obstacles[j]) >= GameConfig.OBSTACLE_MIN_GAP - 0.0001, "gap kept %d-%d" % [i, j])
	check_near(WorldGenerator.reachable_fraction(s.obstacles, 0.6), 1.0, 0.0001, "still connected")
