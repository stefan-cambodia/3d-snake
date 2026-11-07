class_name WorldGenerator
extends RefCounted
## Deterministic, seed-based obstacle layout generation.
##
## Playability guarantee: every obstacle keeps at least OBSTACLE_MIN_GAP of free
## space to every other obstacle and to the arena wall. Disjoint, non-touching
## obstacles inside a disc leave the free space connected, so every collectible
## spawn point is reachable and no pocket can trap the snake. The spawn area and
## a corridor ahead of the spawn heading are always kept clear.

const SPAWN_POS := Vector2.ZERO
const SPAWN_HEADING := 0.0 # facing +Z
const CORRIDOR_HALF_WIDTH := 3.5

const KIND_TABLE: Array = [
	[Obstacle.KIND_PILLAR, 30],
	[Obstacle.KIND_BROKEN_PILLAR, 16],
	[Obstacle.KIND_ROCKS, 18],
	[Obstacle.KIND_MONOLITH, 10],
	[Obstacle.KIND_BRAZIER, 12],
	[Obstacle.KIND_WALL, 9],
	[Obstacle.KIND_FALLEN_COLUMN, 5],
]


static func generate(seed_value: int) -> Array[Obstacle]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var target := rng.randi_range(22, 30)
	var result: Array[Obstacle] = []
	var attempts := 0
	while result.size() < target and attempts < 4000:
		attempts += 1
		var kind := _pick_kind(rng)
		var r := sqrt(rng.randf()) * (GameConfig.ARENA_RADIUS - 4.0)
		var a := rng.randf() * TAU
		var pos := Vector2(cos(a), sin(a)) * r
		var ob := Obstacle.create(kind, pos, rng.randf() * TAU, rng)
		if is_valid_static_placement(ob, result):
			ob.id = result.size()
			result.append(ob)
	return result


static func _pick_kind(rng: RandomNumberGenerator) -> StringName:
	var total := 0
	for e in KIND_TABLE:
		total += int(e[1])
	var pick := rng.randi_range(0, total - 1)
	for e in KIND_TABLE:
		pick -= int(e[1])
		if pick < 0:
			return e[0]
	return Obstacle.KIND_PILLAR


## Gap to the wall and to other obstacles (shared by static and rising obstacles).
static func respects_gaps(ob: Obstacle, existing: Array[Obstacle]) -> bool:
	if ob.max_radius_from_origin() > GameConfig.ARENA_RADIUS - GameConfig.OBSTACLE_MIN_GAP:
		return false
	for other in existing:
		if ob.edge_distance_to(other) < GameConfig.OBSTACLE_MIN_GAP:
			return false
	return true


static func is_valid_static_placement(ob: Obstacle, existing: Array[Obstacle]) -> bool:
	for c in ob.circles:
		var p := Vector2(c.x, c.y)
		if p.distance_to(SPAWN_POS) - c.z < GameConfig.SPAWN_CLEAR_RADIUS:
			return false
		# Corridor ahead of the spawn heading (+Z).
		if absf(p.x) < CORRIDOR_HALF_WIDTH + c.z and p.y > -c.z and p.y < GameConfig.SPAWN_CORRIDOR_LENGTH + c.z + 2.0:
			return false
	return respects_gaps(ob, existing)


## Free-space connectivity check on a grid (used by tests and debug builds).
## Returns the fraction of free cells reachable from the spawn point.
static func reachable_fraction(obstacles: Array[Obstacle], cell: float = 0.5) -> float:
	var clearance := GameConfig.BODY_RADIUS
	var r := GameConfig.ARENA_RADIUS
	var n := int(ceil(2.0 * r / cell))
	var free := PackedByteArray()
	free.resize(n * n)
	var free_count := 0
	for iz in n:
		for ix in n:
			var p := Vector2(-r + (float(ix) + 0.5) * cell, -r + (float(iz) + 0.5) * cell)
			var ok := p.length() < r - clearance
			if ok:
				for o in obstacles:
					if o.is_solid() and o.edge_distance(p) < clearance:
						ok = false
						break
			free[iz * n + ix] = 1 if ok else 0
			if ok:
				free_count += 1
	if free_count == 0:
		return 0.0
	var start_ix := int((SPAWN_POS.x + r) / cell)
	var start_iz := int((SPAWN_POS.y + r) / cell)
	var seen := PackedByteArray()
	seen.resize(n * n)
	var stack: Array[int] = [start_iz * n + start_ix]
	seen[stack[0]] = 1
	var reached := 0
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if free[idx] == 0:
			continue
		reached += 1
		var ix := idx % n
		var iz := idx / n
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var jx: int = ix + d.x
			var jz: int = iz + d.y
			if jx < 0 or jz < 0 or jx >= n or jz >= n:
				continue
			var j := jz * n + jx
			if seen[j] == 0:
				seen[j] = 1
				stack.append(j)
	return float(reached) / float(free_count)
