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


## The real main scene, using a throwaway profile file. Pair with dispose_main().
## (TestCase is compiled before autoloads exist, so Profile is looked up by path.)
func make_main() -> Node:
	var profile := tree.root.get_node("Profile")
	profile.save_path = "user://test_main_profile_%d.cfg" % randi()
	profile.reset_to_defaults(false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	return main


func dispose_main(main: Node) -> void:
	tree.root.remove_child(main)
	main.free()
	Engine.time_scale = 1.0
	var profile := tree.root.get_node("Profile")
	for path in [profile.save_path, profile.save_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.save_path = profile.SAVE_PATH
	profile.load_profile()


## Utility: a session on a fixed seed with its static obstacles.
func make_session(seed_value: int = 1234) -> GameSession:
	var terrain := TerrainField.new(seed_value)
	var s := GameSession.new(terrain)
	s.start(seed_value, WorldGenerator.generate(seed_value, terrain))
	return s
