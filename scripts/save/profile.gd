extends Node
## Persistent player profile (autoload "Profile"): settings, statistics,
## high-score table and unlocks. Stored as a ConfigFile in user://.
## A corrupt file is backed up and replaced by defaults instead of crashing.

signal setting_changed(key: String, value: Variant)
signal profile_reset

const SAVE_PATH := "user://profile.cfg"
const FORMAT_VERSION := 1
const MAX_HIGH_SCORES := 10

const DEFAULT_SETTINGS := {
	"music_volume": 0.65,
	"sfx_volume": 0.85,
	"quality": -1, # -1 = auto-detect on first launch
	"control_scheme": 0, # 0 drag, 1 tap halves, 2 joystick
	"steer_sensitivity": 1.0,
	"camera_smoothing": 1.0,
	"camera_distance": 1, # 0 near, 1 normal, 2 far
	"left_handed": false,
	"haptics": true,
	"language": "",
	"show_fps": false,
	"reduced_motion": false,
}

const DEFAULT_STATS := {
	"runs": 0,
	"total_food": 0,
	"total_energy": 0,
	"total_rare": 0,
	"best_score": 0,
	"best_length": 0.0,
	"best_stage": 1,
	"best_combo": 0,
	"near_misses": 0,
	"play_time": 0.0,
}

var save_path: String = SAVE_PATH
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var stats: Dictionary = DEFAULT_STATS.duplicate(true)
var high_scores: Array = []
var selected_skin: String = "jade"
var selected_theme: String = "dawn"
var announced_unlocks: Array = []
var tutorial_done: bool = false


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	reset_to_defaults(false)
	if not FileAccess.file_exists(save_path):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(save_path)
	if err != OK:
		push_warning("Profile unreadable (%s); backing up and starting fresh." % error_string(err))
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
		return
	for k in DEFAULT_SETTINGS:
		var v: Variant = cfg.get_value("settings", k, DEFAULT_SETTINGS[k])
		if typeof(v) == typeof(DEFAULT_SETTINGS[k]) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(DEFAULT_SETTINGS[k]) in [TYPE_INT, TYPE_FLOAT]):
			settings[k] = v
	for k in DEFAULT_STATS:
		var v: Variant = cfg.get_value("stats", k, DEFAULT_STATS[k])
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			stats[k] = v
	var hs: Variant = cfg.get_value("records", "high_scores", [])
	if hs is Array:
		for e in hs:
			if e is Dictionary and e.has("score"):
				high_scores.append(e)
	selected_skin = str(cfg.get_value("progress", "selected_skin", "jade"))
	selected_theme = str(cfg.get_value("progress", "selected_theme", "dawn"))
	var au: Variant = cfg.get_value("progress", "announced_unlocks", [])
	if au is Array:
		announced_unlocks = au
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	if not is_skin_unlocked(selected_skin):
		selected_skin = "jade"
	if not is_theme_unlocked(selected_theme):
		selected_theme = "dawn"


func save_profile() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", FORMAT_VERSION)
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for k in stats:
		cfg.set_value("stats", k, stats[k])
	cfg.set_value("records", "high_scores", high_scores)
	cfg.set_value("progress", "selected_skin", selected_skin)
	cfg.set_value("progress", "selected_theme", selected_theme)
	cfg.set_value("progress", "announced_unlocks", announced_unlocks)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	# Write to a temp file then swap, so a crash mid-write never corrupts the profile.
	var tmp := save_path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		push_warning("Could not save profile: %s" % error_string(err))
		return false
	err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	return err == OK


func reset_to_defaults(emit: bool = true) -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	stats = DEFAULT_STATS.duplicate(true)
	high_scores = []
	selected_skin = "jade"
	selected_theme = "dawn"
	announced_unlocks = []
	tutorial_done = false
	if emit:
		profile_reset.emit()


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	setting_changed.emit(key, value)


func best_score() -> int:
	return int(stats["best_score"])


## Fold a finished run into the profile. Returns a summary for the game-over screen:
## {new_best, previous_best, rank (1-based, 0 = not in table), unlocked: [{type, id}]}.
func record_run(run: Dictionary) -> Dictionary:
	var score := int(run.get("score", 0))
	var previous_best := best_score()
	stats["runs"] = int(stats["runs"]) + 1
	stats["total_food"] = int(stats["total_food"]) + int(run.get("food", 0))
	stats["total_energy"] = int(stats["total_energy"]) + int(run.get("energy", 0))
	stats["total_rare"] = int(stats["total_rare"]) + int(run.get("rare", 0))
	stats["near_misses"] = int(stats["near_misses"]) + int(run.get("near_misses", 0))
	stats["play_time"] = float(stats["play_time"]) + float(run.get("time", 0.0))
	stats["best_score"] = maxi(previous_best, score)
	stats["best_length"] = maxf(float(stats["best_length"]), float(run.get("length", 0.0)))
	stats["best_stage"] = maxi(int(stats["best_stage"]), int(run.get("stage", 1)))
	stats["best_combo"] = maxi(int(stats["best_combo"]), int(run.get("combo", 0)))

	var rank := 0
	if score > 0:
		var entry := {
			"score": score,
			"length": snappedf(float(run.get("length", 0.0)), 0.1),
			"stage": int(run.get("stage", 1)),
			"date": Time.get_date_string_from_system(),
		}
		var pos := high_scores.size()
		for i in high_scores.size():
			if score > int(high_scores[i]["score"]):
				pos = i
				break
		if pos < MAX_HIGH_SCORES:
			high_scores.insert(pos, entry)
			rank = pos + 1
		while high_scores.size() > MAX_HIGH_SCORES:
			high_scores.pop_back()

	var newly: Array = []
	for s in SkinCatalog.SKINS:
		var key: String = "skin:" + str(s["id"])
		if is_skin_unlocked(s["id"]) and not announced_unlocks.has(key) and not (s["unlock"] as Dictionary).is_empty():
			announced_unlocks.append(key)
			newly.append({"type": "skin", "id": s["id"], "name": s["name"]})
	for t in WorldThemes.THEMES:
		var key: String = "theme:" + str(t["id"])
		if is_theme_unlocked(t["id"]) and not announced_unlocks.has(key) and not (t["unlock"] as Dictionary).is_empty():
			announced_unlocks.append(key)
			newly.append({"type": "theme", "id": t["id"], "name": t["name"]})
	save_profile()
	return {"new_best": score > previous_best and score > 0, "previous_best": previous_best, "rank": rank, "unlocked": newly}


func requirement_met(rule: Dictionary) -> bool:
	if rule.is_empty():
		return true
	return float(stats.get(rule["stat"], 0)) >= float(rule["value"])


## 0..1 progress toward an unlock rule.
func requirement_progress(rule: Dictionary) -> float:
	if rule.is_empty():
		return 1.0
	return clampf(float(stats.get(rule["stat"], 0)) / float(rule["value"]), 0.0, 1.0)


func is_skin_unlocked(id: String) -> bool:
	return requirement_met(SkinCatalog.get_skin(id)["unlock"])


func is_theme_unlocked(id: String) -> bool:
	return requirement_met(WorldThemes.get_theme(id)["unlock"])
