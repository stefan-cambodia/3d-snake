class_name ScoreKeeper
extends RefCounted
## Score, combo chain and run statistics.

var score: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var multiplier: float = 1.0
var best_combo: int = 0

var food_eaten: int = 0
var energy_eaten: int = 0
var rare_eaten: int = 0
var near_misses: int = 0


func reset() -> void:
	score = 0
	combo_count = 0
	combo_timer = 0.0
	multiplier = 1.0
	best_combo = 0
	food_eaten = 0
	energy_eaten = 0
	rare_eaten = 0
	near_misses = 0


static func multiplier_for_chain(chain: int) -> float:
	return minf(1.0 + GameConfig.COMBO_STEP * float(maxi(chain, 1) - 1), GameConfig.COMBO_MAX)


## Award a pickup worth `base` points; extends the combo chain.
## Returns the points actually added.
func award_pickup(base: int, surging: bool) -> int:
	combo_count = combo_count + 1 if combo_timer > 0.0 else 1
	combo_timer = GameConfig.COMBO_WINDOW
	best_combo = maxi(best_combo, combo_count)
	multiplier = multiplier_for_chain(combo_count)
	var pts := int(round(float(base) * multiplier))
	if surging:
		pts *= GameConfig.SURGE_SCORE_MULTIPLIER
	score += pts
	return pts


## Flat bonus (stage bonus, near-miss); does not touch the combo.
func add_bonus(points: int) -> int:
	score += points
	return points


func tick(dt: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo_timer = 0.0
			combo_count = 0
			multiplier = 1.0
