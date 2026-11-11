class_name WorldThemes
extends RefCounted
## The sanctuaries: each has its own island (`terrain_seed`: a different
## relief, terraces and shore) and its own light and atmosphere. A theme is only
## parameters, so new ones can be added without touching gameplay code.
## Optional: "leaf_a" and "leaf_b", two colours for the trees' and bushes' leaves.

const THEMES: Array[Dictionary] = [
	{
		"id": "dawn", "name": "THEME_DAWN", "unlock": {}, "terrain_seed": 20241107,
		"sky_top": Color(0.20, 0.42, 0.72), "sky_horizon": Color(0.98, 0.72, 0.48), "sky_ground": Color(0.18, 0.2, 0.22),
		"sun_color": Color(1.0, 0.82, 0.6), "sun_energy": 1.55, "sun_pitch": -24.0, "sun_yaw": 205.0,
		"ambient_energy": 0.55, "fog_color": Color(0.84, 0.70, 0.58), "fog_density": 0.0045,
		"water_deep": Color(0.03, 0.17, 0.22), "water_shallow": Color(0.16, 0.48, 0.46),
		"grass_a": Color(0.33, 0.46, 0.16), "grass_b": Color(0.58, 0.60, 0.24),
		"emissive_boost": 0.6, "motes": Color(1.0, 0.85, 0.5), "night": false, "cloud_tint": Color(1.0, 0.86, 0.76),
		"exposure": 1.0,
	},
	{
		"id": "moon", "name": "THEME_MOON", "unlock": {"stat": "best_score", "value": 600}, "terrain_seed": 20241110,
		"sky_top": Color(0.015, 0.03, 0.08), "sky_horizon": Color(0.10, 0.17, 0.30), "sky_ground": Color(0.02, 0.03, 0.05),
		"sun_color": Color(0.62, 0.74, 1.0), "sun_energy": 0.55, "sun_pitch": -38.0, "sun_yaw": 140.0,
		"ambient_energy": 0.42, "fog_color": Color(0.06, 0.10, 0.18), "fog_density": 0.0065,
		"water_deep": Color(0.01, 0.04, 0.08), "water_shallow": Color(0.04, 0.16, 0.22),
		"grass_a": Color(0.12, 0.24, 0.20), "grass_b": Color(0.20, 0.32, 0.26),
		"emissive_boost": 1.8, "motes": Color(0.55, 1.0, 0.75), "night": true, "cloud_tint": Color(0.35, 0.45, 0.65),
		"exposure": 1.15,
	},
	{
		"id": "mist", "name": "THEME_MIST", "unlock": {"stat": "best_stage", "value": 6}, "terrain_seed": 20241112,
		"sky_top": Color(0.48, 0.60, 0.66), "sky_horizon": Color(0.82, 0.86, 0.84), "sky_ground": Color(0.3, 0.33, 0.33),
		"sun_color": Color(0.95, 0.96, 0.9), "sun_energy": 1.1, "sun_pitch": -50.0, "sun_yaw": 160.0,
		"ambient_energy": 0.75, "fog_color": Color(0.76, 0.82, 0.80), "fog_density": 0.012,
		"water_deep": Color(0.08, 0.22, 0.24), "water_shallow": Color(0.30, 0.55, 0.50),
		"grass_a": Color(0.20, 0.42, 0.22), "grass_b": Color(0.36, 0.55, 0.28),
		"emissive_boost": 0.5, "motes": Color(0.9, 1.0, 0.95), "night": false, "cloud_tint": Color(0.95, 0.97, 0.97),
		"exposure": 0.95,
	},
	{
		"id": "dusk", "name": "THEME_DUSK", "unlock": {"stat": "runs", "value": 25}, "terrain_seed": 20241120,
		"sky_top": Color(0.13, 0.11, 0.38), "sky_horizon": Color(0.96, 0.50, 0.30), "sky_ground": Color(0.14, 0.10, 0.14),
		"sun_color": Color(1.0, 0.68, 0.48), "sun_energy": 1.25, "sun_pitch": -14.0, "sun_yaw": 62.0,
		"ambient_energy": 0.6, "fog_color": Color(0.60, 0.40, 0.44), "fog_density": 0.0042,
		"water_deep": Color(0.06, 0.07, 0.18), "water_shallow": Color(0.36, 0.28, 0.38),
		"grass_a": Color(0.20, 0.38, 0.17), "grass_b": Color(0.42, 0.50, 0.22),
		"emissive_boost": 1.2, "motes": Color(1.0, 0.6, 0.35), "night": false, "cloud_tint": Color(1.0, 0.66, 0.58),
		"exposure": 1.0,
	},
	{
		"id": "monsoon", "name": "THEME_MONSOON", "unlock": {"stat": "total_rare", "value": 15}, "terrain_seed": 20241114,
		"sky_top": Color(0.16, 0.22, 0.27), "sky_horizon": Color(0.52, 0.62, 0.60), "sky_ground": Color(0.10, 0.14, 0.13),
		"sun_color": Color(0.80, 0.92, 0.88), "sun_energy": 0.95, "sun_pitch": -62.0, "sun_yaw": 300.0,
		"ambient_energy": 0.7, "fog_color": Color(0.36, 0.48, 0.47), "fog_density": 0.0085,
		"water_deep": Color(0.03, 0.14, 0.13), "water_shallow": Color(0.16, 0.42, 0.34),
		"grass_a": Color(0.10, 0.26, 0.13), "grass_b": Color(0.22, 0.38, 0.17),
		"emissive_boost": 1.3, "motes": Color(0.7, 1.0, 0.8), "night": false, "cloud_tint": Color(0.42, 0.50, 0.54),
		"exposure": 1.0,
	},
	{
		"id": "frost", "name": "THEME_FROST", "unlock": {"stat": "best_score", "value": 2000}, "terrain_seed": 20241125,
		"sky_top": Color(0.30, 0.48, 0.74), "sky_horizon": Color(0.84, 0.90, 0.96), "sky_ground": Color(0.30, 0.34, 0.40),
		"sun_color": Color(0.94, 0.96, 1.0), "sun_energy": 1.15, "sun_pitch": -28.0, "sun_yaw": 250.0,
		"ambient_energy": 0.7, "fog_color": Color(0.78, 0.85, 0.93), "fog_density": 0.006,
		"water_deep": Color(0.04, 0.14, 0.26), "water_shallow": Color(0.42, 0.64, 0.74),
		"grass_a": Color(0.62, 0.72, 0.78), "grass_b": Color(0.88, 0.92, 0.95),
		"emissive_boost": 0.9, "motes": Color(1.0, 1.0, 1.0), "night": false, "cloud_tint": Color(0.92, 0.95, 1.0),
		"exposure": 0.95,
		"leaf_a": Color(0.62, 0.76, 0.78), "leaf_b": Color(0.88, 0.93, 0.95),
	},
	{
		"id": "lagoon", "name": "THEME_LAGOON", "unlock": {"stat": "near_misses", "value": 100}, "terrain_seed": 20241201,
		"sky_top": Color(0.10, 0.44, 0.86), "sky_horizon": Color(0.62, 0.86, 0.96), "sky_ground": Color(0.20, 0.30, 0.32),
		"sun_color": Color(1.0, 0.97, 0.88), "sun_energy": 1.5, "sun_pitch": -58.0, "sun_yaw": 140.0,
		"ambient_energy": 0.75, "fog_color": Color(0.66, 0.86, 0.92), "fog_density": 0.0028,
		"water_deep": Color(0.02, 0.36, 0.48), "water_shallow": Color(0.22, 0.86, 0.80),
		"grass_a": Color(0.20, 0.44, 0.19), "grass_b": Color(0.50, 0.64, 0.27),
		"emissive_boost": 0.5, "motes": Color(1.0, 1.0, 0.85), "night": false, "cloud_tint": Color(1.0, 1.0, 1.0),
		"exposure": 1.0,
	},
	{
		"id": "autumn", "name": "THEME_AUTUMN", "unlock": {"stat": "total_energy", "value": 60}, "terrain_seed": 20241207,
		"sky_top": Color(0.26, 0.40, 0.62), "sky_horizon": Color(0.96, 0.80, 0.56), "sky_ground": Color(0.24, 0.18, 0.14),
		"sun_color": Color(1.0, 0.86, 0.62), "sun_energy": 1.35, "sun_pitch": -32.0, "sun_yaw": 300.0,
		"ambient_energy": 0.6, "fog_color": Color(0.90, 0.74, 0.54), "fog_density": 0.0042,
		"water_deep": Color(0.05, 0.14, 0.20), "water_shallow": Color(0.30, 0.44, 0.40),
		"grass_a": Color(0.62, 0.30, 0.10), "grass_b": Color(0.86, 0.58, 0.16),
		"emissive_boost": 0.7, "motes": Color(1.0, 0.62, 0.22), "night": false, "cloud_tint": Color(1.0, 0.88, 0.74),
		"exposure": 1.0,
		"leaf_a": Color(0.86, 0.40, 0.08), "leaf_b": Color(0.70, 0.14, 0.08),
	},
	{
		"id": "aurora", "name": "THEME_AURORA", "unlock": {"stat": "best_stage", "value": 10}, "terrain_seed": 20241213,
		"sky_top": Color(0.07, 0.02, 0.16), "sky_horizon": Color(0.08, 0.42, 0.36), "sky_ground": Color(0.03, 0.02, 0.06),
		"sun_color": Color(0.66, 0.84, 1.0), "sun_energy": 0.75, "sun_pitch": -42.0, "sun_yaw": 20.0,
		"ambient_energy": 0.5, "fog_color": Color(0.08, 0.14, 0.22), "fog_density": 0.006,
		"water_deep": Color(0.03, 0.02, 0.10), "water_shallow": Color(0.10, 0.30, 0.34),
		"grass_a": Color(0.07, 0.26, 0.22), "grass_b": Color(0.18, 0.54, 0.42),
		"emissive_boost": 2.0, "motes": Color(0.70, 0.55, 1.0), "night": true, "cloud_tint": Color(0.40, 0.62, 0.60),
		"exposure": 1.15,
		"leaf_a": Color(0.18, 0.56, 0.48), "leaf_b": Color(0.56, 0.34, 0.66),
	},
]


## Seed of the island a sanctuary stands on.
static func terrain_seed(id: String) -> int:
	return int(get_theme(id)["terrain_seed"])


static func get_theme(id: String) -> Dictionary:
	for t in THEMES:
		if t["id"] == id:
			return t
	return THEMES[0]
