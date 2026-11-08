extends TestCase
## Relief: hills, terraces with walls and ramps, and how the snake moves on them.

const DT := 1.0 / 60.0
const SEEDS := [3, 17, 99, 2024, 20241107]


## The snake's head can never reach a steep spot (every one lies within the
## head's collision radius of a wall circle), and every wall circle sits on
## steep ground (no invisible walls on open grass).
func test_walls_match_the_steep_ground() -> void:
	for seed_value in SEEDS:
		var t := TerrainField.new(seed_value)
		var walls := t.cliff_obstacles()
		check(t.terraces.size() >= 2, "seed %d: at least two terraces (%d)" % [seed_value, t.terraces.size()])
		check_eq(walls.size(), t.terraces.size(), "seed %d: one wall per terrace" % seed_value)
		var missed := 0
		var tested := 0
		for ter in t.terraces:
			# Fine grid offset from the scan grid, over the whole terrace footprint
			# and the band where nearby hills fade out.
			var ext := ter.reach + TerrainField.HILL_CLEARANCE
			var x := ter.center.x - ext + 0.13
			while x < ter.center.x + ext:
				var z := ter.center.y - ext + 0.29
				while z < ter.center.y + ext:
					if t.slope(x, z, 0.1) > TerrainField.CLIMB_LIMIT + 0.05:
						tested += 1
						var inside := false
						for w in walls:
							inside = inside or w.edge_distance(Vector2(x, z)) < GameConfig.HEAD_COLLISION_RADIUS
						if not inside:
							missed += 1
					z += 0.31
				x += 0.31
		check(tested > 100, "seed %d: walls exist (%d steep samples)" % [seed_value, tested])
		check_eq(missed, 0, "seed %d: steep samples outside wall collision" % seed_value)
		for w in walls:
			for c in w.circles:
				check(t.slope(c.x, c.y) > 0.5, "seed %d: wall circle at (%.1f, %.1f) is on a slope (%.2f)" % [seed_value, c.x, c.y, t.slope(c.x, c.y)])


## Terraces are real height steps, and everything else stays climbable.
func test_terraces_and_hills_are_climbable_where_open() -> void:
	for seed_value in SEEDS:
		var t := TerrainField.new(seed_value)
		var walls := t.cliff_obstacles()
		for ter in t.terraces:
			var top := t.height(ter.center.x, ter.center.y)
			var foot := ter.ramp_foot(0)
			check(top - t.height(foot.x, foot.y) > 1.4, "seed %d: terrace stands above its ramp foot" % seed_value)
			check(ter.ramps.size() >= 1, "seed %d: terrace has a ramp" % seed_value)
			for i in ter.ramps.size():
				# Walk up the ramp: never steeper than a ramp should be.
				var a := ter.ramp_foot(i)
				var b := ter.ramp_top(i)
				var steepest := 0.0
				for k in 41:
					var p := a.lerp(b, k / 40.0)
					steepest = maxf(steepest, t.slope(p.x, p.y))
				check(steepest < TerrainField.CLIMB_LIMIT * 0.75, "seed %d: ramp %d is gentle (max slope %.2f)" % [seed_value, i, steepest])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var hilly := 0
		for i in 600:
			var p := Vector2(rng.randf_range(-38, 38), rng.randf_range(-38, 38))
			if p.length() > GameConfig.ARENA_RADIUS - 1.0:
				continue
			var near_wall := false
			for w in walls:
				near_wall = near_wall or w.edge_distance(p) < 1.5
			if near_wall:
				continue
			var sl := t.slope(p.x, p.y)
			check(sl <= TerrainField.CLIMB_LIMIT, "seed %d: open ground at (%.1f, %.1f) is climbable (%.2f)" % [seed_value, p.x, p.y, sl])
			if sl > 0.08:
				hilly += 1
		check(hilly > 60, "seed %d: the open ground has real relief (%d sloped samples)" % [seed_value, hilly])


func _session_at(seed_value: int, pos: Vector2, heading: float) -> GameSession:
	var s := GameSession.new(TerrainField.new(seed_value))
	var walls: Array[Obstacle] = []
	walls.assign(s.terrain.cliff_obstacles())
	s.start(seed_value, walls)
	s.items.clear()
	s.snake.reset(pos, heading)
	return s


## Driving straight up a ramp lifts the snake onto the terrace without a crash.
func test_snake_climbs_a_ramp() -> void:
	var s0 := TerrainField.new(20241107)
	var ter: TerrainField.Terrace = s0.terraces[0]
	var foot := ter.ramp_foot(0)
	var dir := (ter.ramp_top(0) - foot).normalized()
	var s := _session_at(20241107, foot, atan2(dir.x, dir.y))
	var y0 := s.snake.position.y
	var top_y := s0.height(ter.center.x, ter.center.y) + SnakeSim.GROUND_OFFSET
	var t := 0.0
	var tail_below := false
	while t < 2.2 and s.is_running():
		s.step(DT)
		t += DT
		# Just as the head reaches the top, the body still lies on the ramp.
		if not tail_below and s0.terrace_at(s.snake.head_tip()) == 0:
			tail_below = s.snake.spine.point_at(s.snake.length).y < s.snake.position.y - 0.5
	check(s.is_running(), "no crash on the ramp (%s)" % s.death_cause)
	check(s.snake.position.y > y0 + ter.height * 0.8, "the snake climbed (%.2f -> %.2f)" % [y0, s.snake.position.y])
	check_near(s.snake.position.y, top_y, 0.35, "the snake is on the terrace top")
	check(s0.terrace_at(s.snake.head_tip()) == 0, "the head is on the terrace")
	check(tail_below, "the body trails down the ramp behind the head")


## A terrace wall stops the snake: it crashes into it instead of climbing it.
func test_wall_cannot_be_climbed() -> void:
	var tf := TerrainField.new(20241107)
	var ter: TerrainField.Terrace = tf.terraces[0]
	# Approach the wall head-on from outside, away from any ramp.
	var best_a := 0.0
	var best_gap := -INF
	for k in 36:
		var a := TAU * k / 36.0
		var d := Vector2(cos(a), sin(a))
		var gap := INF
		for r in ter.ramps:
			gap = minf(gap, absf(angle_difference(d.angle(), r.angle())))
		var start := ter.center + d * (ter.rim(a) + 5.0)
		if gap > best_gap and start.length() < GameConfig.ARENA_RADIUS - 3.0:
			best_gap = gap
			best_a = a
	var d := Vector2(cos(best_a), sin(best_a))
	var start := ter.center + d * (ter.rim(best_a) + 5.0)
	var s := _session_at(20241107, start, atan2(-d.x, -d.y))
	var y0 := s.snake.position.y
	var max_y := y0
	var t := 0.0
	while t < 3.0 and s.is_running():
		s.step(DT)
		max_y = maxf(max_y, s.snake.position.y)
		t += DT
	check(not s.is_running(), "the snake hits the wall")
	check_eq(s.death_cause, GameSession.CAUSE_OBSTACLE, "killed by the wall")
	check(max_y < y0 + ter.height * 0.5, "it did not get up the wall (%.2f -> %.2f)" % [y0, max_y])


## The autopilot's route to food on a terrace goes through a ramp.
func test_route_uses_ramps() -> void:
	var tf := TerrainField.new(20241107)
	var ter: TerrainField.Terrace = tf.terraces[0]
	var goal := ter.center
	var from := Vector2.ZERO
	check_eq(tf.terrace_at(goal), 0, "the goal is on the terrace")
	var wp := Autopilot.route(tf, from, goal)
	var feet := []
	for i in ter.ramps.size():
		feet.append(ter.ramp_foot(i))
	check(feet.has(wp), "from the plaza, head for a ramp foot")
	var i0: int = feet.find(wp)
	check(Autopilot.route(tf, ter.ramp_foot(i0) + (ter.ramp_top(i0) - ter.ramp_foot(i0)) * 0.4, goal) == ter.ramp_top(i0), "on the ramp, head for the top")
	check(Autopilot.route(tf, ter.center + Vector2(0.5, 0.5), goal) == goal, "on the terrace, head for the food")
	check(Autopilot.route(tf, goal, Vector2.ZERO) in [ter.ramp_top(0), ter.ramp_top(ter.ramps.size() - 1)], "leaving: head for a ramp top")


## Food and relics may appear on terrace tops, never on walls.
func test_items_reach_terrace_tops() -> void:
	var s := make_session(20241107)
	var on_top := 0
	for i in 400:
		var p: Variant = s.find_spawn_point(Collectible.Kind.FOOD)
		if p == null:
			continue
		if s.terrain.terrace_at(p) >= 0:
			on_top += 1
		check(s.terrain.slope(p.x, p.y) < TerrainField.CLIMB_LIMIT, "item not on a wall")
	check(on_top > 4, "some food appears on terrace tops (%d of 400)" % on_top)
