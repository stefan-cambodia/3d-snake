class_name WorldThemes
extends RefCounted
## Lighting / atmosphere presets for the sanctuary island. A theme only changes
## parameters, so new themes (or new biomes built on the same generator) can be
## added without touching gameplay code.

const THEMES: Array[Dictionary] = [
	{
		"id": "dawn", "name": "THEME_DAWN", "unlock": {},
		"sky_top": Color(0.20, 0.42, 0.72), "sky_horizon": Color(0.98, 0.72, 0.48), "sky_ground": Color(0.18, 0.2, 0.22),
		"sun_color": Color(1.0, 0.82, 0.6), "sun_energy": 1.55, "sun_pitch": -24.0, "sun_yaw": 205.0,
		"ambient_energy": 0.55, "fog_color": Color(0.84, 0.70, 0.58), "fog_density": 0.0045,
		"water_deep": Color(0.03, 0.17, 0.22), "water_shallow": Color(0.16, 0.48, 0.46),
		"grass_a": Color(0.33, 0.46, 0.16), "grass_b": Color(0.58, 0.60, 0.24),
		"emissive_boost": 0.6, "motes": Color(1.0, 0.85, 0.5), "night": false, "cloud_tint": Color(1.0, 0.86, 0.76),
		"exposure": 1.0,
	},
	{
		"id": "moon", "name": "THEME_MOON", "unlock": {"stat": "best_score", "value": 600},
		"sky_top": Color(0.015, 0.03, 0.08), "sky_horizon": Color(0.10, 0.17, 0.30), "sky_ground": Color(0.02, 0.03, 0.05),
		"sun_color": Color(0.62, 0.74, 1.0), "sun_energy": 0.55, "sun_pitch": -38.0, "sun_yaw": 140.0,
		"ambient_energy": 0.42, "fog_color": Color(0.06, 0.10, 0.18), "fog_density": 0.0065,
		"water_deep": Color(0.01, 0.04, 0.08), "water_shallow": Color(0.04, 0.16, 0.22),
		"grass_a": Color(0.12, 0.24, 0.20), "grass_b": Color(0.20, 0.32, 0.26),
		"emissive_boost": 1.8, "motes": Color(0.55, 1.0, 0.75), "night": true, "cloud_tint": Color(0.35, 0.45, 0.65),
		"exposure": 1.15,
	},
	{
		"id": "mist", "name": "THEME_MIST", "unlock": {"stat": "best_stage", "value": 6},
		"sky_top": Color(0.48, 0.60, 0.66), "sky_horizon": Color(0.82, 0.86, 0.84), "sky_ground": Color(0.3, 0.33, 0.33),
		"sun_color": Color(0.95, 0.96, 0.9), "sun_energy": 1.1, "sun_pitch": -50.0, "sun_yaw": 160.0,
		"ambient_energy": 0.75, "fog_color": Color(0.76, 0.82, 0.80), "fog_density": 0.012,
		"water_deep": Color(0.08, 0.22, 0.24), "water_shallow": Color(0.30, 0.55, 0.50),
		"grass_a": Color(0.20, 0.42, 0.22), "grass_b": Color(0.36, 0.55, 0.28),
		"emissive_boost": 0.5, "motes": Color(0.9, 1.0, 0.95), "night": false, "cloud_tint": Color(0.95, 0.97, 0.97),
		"exposure": 0.95,
	},
]


static func get_theme(id: String) -> Dictionary:
	for t in THEMES:
		if t["id"] == id:
			return t
	return THEMES[0]
