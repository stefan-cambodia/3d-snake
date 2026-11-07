class_name Obstacle
extends RefCounted
## Gameplay description of one obstacle: a union of ground-plane circles.
##
## Rendering builds a matching 3D model from `kind`, `variant`, `rotation` and
## `height`; collision only ever uses `circles`.

enum State { ACTIVE, WARNING, RISING }

const KIND_PILLAR := &"pillar"
const KIND_BROKEN_PILLAR := &"broken_pillar"
const KIND_MONOLITH := &"monolith"
const KIND_ROCKS := &"rocks"
const KIND_BRAZIER := &"brazier"
const KIND_WALL := &"wall"
const KIND_FALLEN_COLUMN := &"fallen_column"
const KIND_RISING := &"rising_monolith"

var id: int = -1
var kind: StringName = KIND_PILLAR
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var height: float = 3.0
var variant: int = 0
## World-space circles: x, y = ground-plane position (world x, z), z = radius.
var circles: Array[Vector3] = []
var state: int = State.ACTIVE
var timer: float = 0.0
## Visual rise progress 0..1 (static obstacles are always 1).
var rise: float = 1.0


func is_solid() -> bool:
	return state != State.WARNING


func bounding_radius() -> float:
	var r := 0.0
	for c in circles:
		r = maxf(r, Vector2(c.x - position.x, c.y - position.y).length() + c.z)
	return r


## Signed distance from point to the nearest circle edge (negative = inside).
func edge_distance(p: Vector2) -> float:
	var best := INF
	for c in circles:
		var dx := c.x - p.x
		var dy := c.y - p.y
		best = minf(best, sqrt(dx * dx + dy * dy) - c.z)
	return best


func edge_distance_to(other: Obstacle) -> float:
	var best := INF
	for a in circles:
		for b in other.circles:
			best = minf(best, Vector2(a.x - b.x, a.y - b.y).length() - a.z - b.z)
	return best


## Furthest extent from the arena centre.
func max_radius_from_origin() -> float:
	var best := 0.0
	for c in circles:
		best = maxf(best, Vector2(c.x, c.y).length() + c.z)
	return best


## Build an obstacle of `kind` at `pos` with circles laid out from local offsets.
static func create(kind_name: StringName, pos: Vector2, rot: float, rng: RandomNumberGenerator) -> Obstacle:
	var o := Obstacle.new()
	o.kind = kind_name
	o.position = pos
	o.rotation = rot
	o.variant = rng.randi() % 4
	var local: Array[Vector3] = []
	match kind_name:
		KIND_PILLAR:
			o.height = rng.randf_range(4.2, 6.8)
			local.append(Vector3(0, 0, 0.78))
		KIND_BROKEN_PILLAR:
			o.height = rng.randf_range(1.6, 3.4)
			local.append(Vector3(0, 0, 0.78))
		KIND_MONOLITH, KIND_RISING:
			o.height = rng.randf_range(2.6, 3.8)
			local.append(Vector3(-0.38, 0, 0.5))
			local.append(Vector3(0.38, 0, 0.5))
		KIND_ROCKS:
			o.height = rng.randf_range(1.0, 2.0)
			var big := rng.randf_range(1.0, 1.5)
			local.append(Vector3(0, 0, big))
			local.append(Vector3(big * 0.9, rng.randf_range(-0.4, 0.4), big * 0.6))
		KIND_BRAZIER:
			o.height = 1.5
			local.append(Vector3(0, 0, 0.62))
		KIND_WALL:
			o.height = rng.randf_range(1.2, 2.2)
			for i in 3:
				local.append(Vector3((float(i) - 1.0) * 1.0, 0, 0.6))
		KIND_FALLEN_COLUMN:
			o.height = 1.0
			for i in 4:
				local.append(Vector3((float(i) - 1.5) * 1.05, 0, 0.55))
		_:
			local.append(Vector3(0, 0, 0.8))
	var c := cos(rot)
	var s := sin(rot)
	for l in local:
		var wx := pos.x + l.x * c - l.y * s
		var wz := pos.y + l.x * s + l.y * c
		o.circles.append(Vector3(wx, wz, l.z))
	return o
