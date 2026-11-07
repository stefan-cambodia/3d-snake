extends TestCase


func _fresh_profile() -> Node:
	var p: Node = load("res://scripts/save/profile.gd").new()
	p.save_path = "user://test_profile_%d.cfg" % randi()
	p.reset_to_defaults(false)
	return p


func test_save_and_load_roundtrip() -> void:
	var p := _fresh_profile()
	p.set_setting("music_volume", 0.25)
	p.set_setting("left_handed", true)
	p.set_setting("control_scheme", 2)
	p.selected_skin = "jade"
	var r: Dictionary = p.record_run({"score": 420, "length": 23.4, "stage": 4, "food": 30, "rare": 1, "time": 61.0})
	check(r["new_best"], "first run is a best")
	check_eq(r["rank"], 1, "ranked first")
	check(p.save_profile(), "saved")
	var q := _fresh_profile()
	q.save_path = p.save_path
	q.load_profile()
	check_near(q.get_setting("music_volume"), 0.25, 0.0001, "setting restored")
	check_eq(q.get_setting("left_handed"), true, "bool restored")
	check_eq(q.get_setting("control_scheme"), 2, "int restored")
	check_eq(q.best_score(), 420, "best score restored")
	check_eq(int(q.stats["total_food"]), 30, "stats restored")
	check_eq(q.high_scores.size(), 1, "high score table restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path))
	p.free()
	q.free()


func test_high_score_table_order_and_cap() -> void:
	var p := _fresh_profile()
	for s in [50, 300, 120, 999, 10, 400, 77, 650, 205, 88, 501, 3]:
		p.record_run({"score": s, "length": 6.0, "stage": 1})
	check_eq(p.high_scores.size(), Profile.MAX_HIGH_SCORES, "capped")
	for i in p.high_scores.size() - 1:
		check(int(p.high_scores[i]["score"]) >= int(p.high_scores[i + 1]["score"]), "sorted descending")
	check_eq(int(p.high_scores[0]["score"]), 999, "best first")
	var r: Dictionary = p.record_run({"score": 1, "length": 6.0, "stage": 1})
	check_eq(r["rank"], 0, "low score not ranked")
	check(not r["new_best"], "not a best")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path))
	p.free()


func test_unlocks_are_announced_once() -> void:
	var p := _fresh_profile()
	var r: Dictionary = p.record_run({"score": 700, "length": 10.0, "stage": 2})
	var ids: Array = []
	for u in r["unlocked"]:
		ids.append(u["id"])
	check(ids.has("ember"), "ember skin unlocked at 300")
	check(ids.has("moon"), "moon theme unlocked at 600")
	check(p.is_skin_unlocked("ember"), "ember usable")
	check(not p.is_skin_unlocked("obsidian"), "obsidian still locked")
	var r2: Dictionary = p.record_run({"score": 710, "length": 10.0, "stage": 2})
	check_eq((r2["unlocked"] as Array).size(), 0, "not announced twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path))
	p.free()


func test_corrupt_file_falls_back_to_defaults() -> void:
	var p := _fresh_profile()
	var f := FileAccess.open(p.save_path, FileAccess.WRITE)
	f.store_string("[[[ this is not a config file ")
	f.store_buffer(PackedByteArray([0, 1, 255, 254]))
	f.close()
	p.load_profile()
	check_eq(p.best_score(), 0, "defaults after corruption")
	check_eq(p.selected_skin, "jade", "default skin")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path + ".bak"))
	p.free()
