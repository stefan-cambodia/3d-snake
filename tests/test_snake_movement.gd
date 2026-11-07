extends TestCase


func _sim() -> SnakeSim:
	var sim := SnakeSim.new(TerrainField.new(3))
	sim.reset(Vector2.ZERO, 0.0)
	return sim


func test_moves_forward_at_cruise_speed() -> void:
	var sim := _sim()
	for i in 90:
		sim.step(1.0 / 90.0)
	check_near(sim.position.z, GameConfig.BASE_SPEED, 0.05, "travels ~BASE_SPEED in 1 s")
	check_near(sim.position.x, 0.0, 0.0001, "no drift without steering")
	check_near(sim.distance_travelled, GameConfig.BASE_SPEED, 0.05, "distance accumulates")


func test_steering_direction_and_rate() -> void:
	var sim := _sim()
	sim.steer_input = 1.0 # right
	for i in 45:
		sim.step(1.0 / 90.0)
	# Facing +Z, the snake's right side is -X.
	check(sim.position.x < -0.1, "steer right moves toward -X (snake's right)")
	check(sim.heading < 0.0, "steer right decreases heading")
	var rate := GameConfig.turn_rate_for_speed(sim.speed)
	check(absf(sim.yaw_rate) <= rate + 0.0001, "yaw rate bounded")


func test_frame_rate_independence() -> void:
	var a := _sim()
	var b := _sim()
	a.steer_input = 0.7
	b.steer_input = 0.7
	for i in 180:
		a.step(1.0 / 90.0)
	for i in 120:
		b.step(1.0 / 60.0)
	check(a.position.distance_to(b.position) < 0.15, "same path at 90 vs 60 Hz (diff %f)" % a.position.distance_to(b.position))


func test_boost_drains_and_regenerates_stamina() -> void:
	var sim := _sim()
	sim.boost_input = true
	for i in 90:
		sim.step(1.0 / 90.0)
	check(sim.boosting, "boosting while held")
	check(sim.speed > GameConfig.BASE_SPEED * 1.3, "boost raises speed")
	check_near(sim.stamina, 1.0 - GameConfig.STAMINA_DRAIN, 0.02, "drain per second")
	for i in 120:
		sim.step(1.0 / 90.0)
	check_near(sim.stamina, 0.0, 0.0001, "stamina depleted")
	check(not sim.boosting, "boost stops when empty")
	check(sim.exhausted, "exhausted flag set")
	for i in 300:
		sim.step(1.0 / 90.0)
	check(not sim.boosting, "holding the button does not stutter-boost after depletion")
	sim.boost_input = false
	for i in 450:
		sim.step(1.0 / 90.0)
	check(sim.stamina > 0.4, "stamina regenerates after delay")
	sim.boost_input = true
	sim.stamina = GameConfig.STAMINA_MIN_TO_START * 0.5
	sim.step(1.0 / 90.0)
	check(not sim.boosting, "cannot start boost below minimum stamina")


func test_growth_is_gradual_and_capped() -> void:
	var sim := _sim()
	sim.grow(2.0)
	sim.step(0.1)
	check_near(sim.length, GameConfig.START_LENGTH + GameConfig.GROWTH_RATE * 0.1, 0.001, "grows at GROWTH_RATE")
	for i in 100:
		sim.step(0.1)
	check_near(sim.length, GameConfig.START_LENGTH + 2.0, 0.001, "reaches target length")
	sim.grow(1000.0)
	check_near(sim.target_length, GameConfig.MAX_LENGTH, 0.001, "capped at MAX_LENGTH")


func test_follows_terrain_height() -> void:
	var sim := _sim()
	sim.steer_input = 0.3
	for i in 300:
		sim.step(1.0 / 60.0)
		var expect := sim.terrain.height(sim.position.x, sim.position.z) + SnakeSim.GROUND_OFFSET
		if absf(sim.position.y - expect) > 0.0001:
			check(false, "height mismatch at step %d" % i)
			return
	check(true, "on ground")


func test_surge_speed_and_timeout() -> void:
	var sim := _sim()
	sim.surge_time = 1.0
	for i in 60:
		sim.step(1.0 / 120.0)
	check(sim.speed > GameConfig.BASE_SPEED * 1.15, "surge accelerates")
	for i in 120:
		sim.step(1.0 / 120.0)
	check_near(sim.surge_time, 0.0, 0.0001, "surge expires")
