class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: Array[String] = []
var checks: int = 0
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	checks += 1
	if a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])


func check_near(a: float, b: float, eps: float, msg: String) -> void:
	checks += 1
	if absf(a - b) > eps:
		failures.append("%s (got %f, expected %f ± %f)" % [msg, a, b, eps])


## Utility: a session on a fixed seed with its static obstacles.
func make_session(seed_value: int = 1234) -> GameSession:
	var terrain := TerrainField.new(seed_value)
	var s := GameSession.new(terrain)
	s.start(seed_value, WorldGenerator.generate(seed_value))
	return s
