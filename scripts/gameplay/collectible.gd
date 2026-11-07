class_name Collectible
extends RefCounted
## One collectible on the field (pure data).

enum Kind { FOOD, ENERGY, RARE }

const HOVER := 0.62

var id: int = 0
var kind: int = Kind.FOOD
var pos: Vector3 = Vector3.ZERO
var age: float = 0.0
## Seconds before it disappears (0 = never).
var lifetime: float = 0.0


func pos2() -> Vector2:
	return Vector2(pos.x, pos.z)


func time_left() -> float:
	return INF if lifetime <= 0.0 else maxf(lifetime - age, 0.0)


static func base_score(k: int) -> int:
	match k:
		Kind.ENERGY:
			return GameConfig.SCORE_ENERGY
		Kind.RARE:
			return GameConfig.SCORE_RARE
	return GameConfig.SCORE_FOOD
