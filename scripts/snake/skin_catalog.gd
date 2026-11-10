class_name SkinCatalog
extends RefCounted
## Snake skins. Each skin is a set of shader parameters plus an unlock rule.
## Unlock rules reference Profile stats: {"stat": <name>, "value": <threshold>}.

enum Pattern { DIAMONDS, BANDS, STRIPES, SADDLES, SOLID, RUNES }

const SKINS: Array[Dictionary] = [
	{
		"id": "jade", "name": "SKIN_JADE",
		"back": Color(0.07, 0.30, 0.17), "side": Color(0.22, 0.52, 0.27), "belly": Color(0.86, 0.80, 0.50),
		"pattern": Color(0.02, 0.08, 0.05), "accent": Color(1.0, 0.72, 0.18),
		"pattern_type": Pattern.DIAMONDS, "gloss": 0.55, "metallic": 0.0, "iridescence": 0.15, "emission": 0.0,
		"unlock": {},
	},
	{
		"id": "ember", "name": "SKIN_EMBER",
		"back": Color(0.22, 0.04, 0.03), "side": Color(0.78, 0.25, 0.06), "belly": Color(0.95, 0.72, 0.42),
		"pattern": Color(0.03, 0.01, 0.01), "accent": Color(1.0, 0.45, 0.08),
		"pattern_type": Pattern.BANDS, "gloss": 0.5, "metallic": 0.0, "iridescence": 0.0, "emission": 0.9,
		"unlock": {"stat": "best_score", "value": 300},
	},
	{
		"id": "azure", "name": "SKIN_AZURE",
		"back": Color(0.03, 0.10, 0.36), "side": Color(0.08, 0.50, 0.70), "belly": Color(0.78, 0.92, 0.95),
		"pattern": Color(0.95, 0.78, 0.30), "accent": Color(0.55, 0.95, 1.0),
		"pattern_type": Pattern.STRIPES, "gloss": 0.7, "metallic": 0.0, "iridescence": 0.6, "emission": 0.0,
		"unlock": {"stat": "total_food", "value": 60},
	},
	{
		"id": "sand", "name": "SKIN_SAND",
		"back": Color(0.62, 0.47, 0.27), "side": Color(0.80, 0.67, 0.45), "belly": Color(0.93, 0.87, 0.70),
		"pattern": Color(0.30, 0.17, 0.08), "accent": Color(0.95, 0.55, 0.15),
		"pattern_type": Pattern.SADDLES, "gloss": 0.3, "metallic": 0.0, "iridescence": 0.0, "emission": 0.0,
		"unlock": {"stat": "best_stage", "value": 4},
	},
	{
		"id": "coral", "name": "SKIN_CORAL",
		"back": Color(0.72, 0.07, 0.06), "side": Color(0.85, 0.12, 0.08), "belly": Color(0.95, 0.85, 0.55),
		"pattern": Color(0.03, 0.03, 0.03), "accent": Color(1.0, 0.85, 0.2),
		"pattern_type": Pattern.BANDS, "gloss": 0.65, "metallic": 0.0, "iridescence": 0.05, "emission": 0.0,
		"unlock": {"stat": "runs", "value": 10},
	},
	{
		"id": "obsidian", "name": "SKIN_OBSIDIAN",
		"back": Color(0.015, 0.015, 0.025), "side": Color(0.05, 0.04, 0.08), "belly": Color(0.25, 0.22, 0.3),
		"pattern": Color(0.35, 0.12, 0.6), "accent": Color(0.75, 0.35, 1.0),
		"pattern_type": Pattern.DIAMONDS, "gloss": 0.9, "metallic": 0.1, "iridescence": 1.0, "emission": 0.35,
		"unlock": {"stat": "best_score", "value": 1200},
	},
	{
		"id": "golden", "name": "SKIN_GOLDEN",
		"back": Color(0.80, 0.55, 0.14), "side": Color(0.98, 0.78, 0.32), "belly": Color(1.0, 0.92, 0.65),
		"pattern": Color(0.35, 0.18, 0.04), "accent": Color(0.3, 0.9, 1.0),
		"pattern_type": Pattern.SADDLES, "gloss": 0.85, "metallic": 0.85, "iridescence": 0.0, "emission": 0.0,
		"unlock": {"stat": "total_rare", "value": 5},
	},
	{
		"id": "spectral", "name": "SKIN_SPECTRAL",
		"back": Color(0.55, 0.75, 0.85), "side": Color(0.78, 0.92, 0.96), "belly": Color(0.95, 0.98, 1.0),
		"pattern": Color(0.2, 0.95, 0.85), "accent": Color(0.3, 1.0, 0.85),
		"pattern_type": Pattern.RUNES, "gloss": 0.75, "metallic": 0.0, "iridescence": 0.8, "emission": 1.4,
		"unlock": {"stat": "best_length", "value": 45},
	},
	{
		"id": "lotus", "name": "SKIN_LOTUS",
		"back": Color(0.80, 0.30, 0.52), "side": Color(0.96, 0.66, 0.78), "belly": Color(1.0, 0.95, 0.90),
		"pattern": Color(0.99, 0.93, 0.95), "accent": Color(0.45, 0.85, 0.35),
		"pattern_type": Pattern.STRIPES, "gloss": 0.6, "metallic": 0.0, "iridescence": 0.35, "emission": 0.0,
		"unlock": {"stat": "total_food", "value": 300},
	},
]


static func get_skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for s in SKINS:
		out.append(s["id"])
	return out
