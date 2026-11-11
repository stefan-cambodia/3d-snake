class_name SanctuaryStyles
extends RefCounted
## The architectural identity of each sanctuary: its column order, its great
## monument and second landmark, what stands along the shore and in the lake, its
## stone, paving, timber and ceramics, its trees and ground plants, its weather.
## Keyed by the WorldThemes id. Everything here is looks only: gameplay never
## reads it.

const STYLES := {
	# Sandstone temple-mountain in the morning sun.
	"dawn": {
		"title": "Temple of the rising sun", "monolith": 1, "brazier": 0, "order": "lotus", "monument": "prasat", "secondary": "serpent",
		"shore": {"shrine": 3, "statue": 3, "altar": 2, "colonnade": 2, "urns": 2, "steles": 1, "ghat": 1},
		"islets": ["shrine", "stupa"], "lake": ["sunken_columns", "sunken_head", "sunken_arch"], "far": "tower", "roof": "tiers",
		"stone_a": Color(1.25, 1.1, 0.88), "stone_b": Color(1.05, 0.82, 0.58), "moss": 0.9,
		"paving": Color(0.8, 0.7, 0.56), "wall_a": Color(0.7, 0.6, 0.46), "wall_b": Color(0.56, 0.38, 0.28),
		"ceramic": Color(0.7, 0.36, 0.2), "timber": Color(0.34, 0.2, 0.12), "light": Color(1.0, 0.72, 0.36),
		"trees": ["broadleaf", "broadleaf_b", "palm", "bush"],
		"flowers": [Color(1.0, 0.86, 0.3), Color(1.0, 0.98, 0.9)], "ferns": 0.5, "special": "", "weather": "pollen", "shafts": true,
	},
	# Blue-grey moon shrine: a great stone ring, stupas and lit lanterns.
	"moon": {
		"title": "Shrine of the moon gate", "monolith": 2, "brazier": 2, "order": "ringed", "monument": "moon_gate", "secondary": "stupas",
		"shore": {"stupa": 3, "lanterns": 3, "bell": 2, "steles": 2, "altar": 2, "arch": 1},
		"islets": ["stupa", "lanterns"], "lake": ["sunken_arch", "sunken_columns", "sunken_obelisk"], "far": "stupa", "roof": "dome",
		"stone_a": Color(1.0, 1.08, 1.3), "stone_b": Color(0.76, 0.84, 1.1), "moss": 0.7,
		"paving": Color(0.5, 0.56, 0.7), "wall_a": Color(0.44, 0.5, 0.64), "wall_b": Color(0.32, 0.36, 0.5),
		"ceramic": Color(0.3, 0.4, 0.66), "timber": Color(0.2, 0.2, 0.28), "light": Color(0.7, 0.86, 1.0),
		"trees": ["broadleaf", "cypress", "cypress", "bush"],
		"flowers": [Color(0.7, 0.86, 1.0), Color(0.9, 0.9, 1.0)], "ferns": 0.4, "special": "mushrooms", "weather": "", "shafts": false,
	},
	# Grey-green mountain pagoda in the fog.
	"mist": {
		"title": "Pagoda in the clouds", "monolith": 3, "brazier": 2, "order": "square", "monument": "pagoda", "secondary": "bell_tower",
		"shore": {"lanterns": 3, "bell": 2, "steles": 3, "shrine": 2, "cairn": 2, "gate": 1, "ghat": 1},
		"islets": ["shrine", "cairn"], "lake": ["sunken_gate", "sunken_columns", "sunken_obelisk"], "far": "pagoda", "roof": "timber",
		"stone_a": Color(1.05, 1.1, 1.05), "stone_b": Color(0.8, 0.88, 0.82), "moss": 1.3,
		"paving": Color(0.62, 0.66, 0.62), "wall_a": Color(0.54, 0.58, 0.54), "wall_b": Color(0.4, 0.44, 0.4),
		"ceramic": Color(0.36, 0.46, 0.42), "timber": Color(0.36, 0.14, 0.12), "light": Color(1.0, 0.8, 0.5),
		"trees": ["pine", "pine", "broadleaf", "bush"],
		"flowers": [Color(0.94, 0.94, 0.98)], "ferns": 1.0, "special": "", "weather": "mist", "shafts": false,
	},
	# Rose-red rotunda around a great fire, at sunset.
	"dusk": {
		"title": "Rotunda of the last fire", "monolith": 1, "brazier": 1, "order": "classic", "monument": "rotunda", "secondary": "colossus",
		"shore": {"colonnade": 3, "arch": 3, "urns": 2, "statue": 2, "altar": 2, "heads": 1},
		"islets": ["colonnade", "arch"], "lake": ["sunken_arch", "pier", "sunken_head"], "far": "rotunda", "roof": "flat",
		"stone_a": Color(1.2, 0.95, 0.84), "stone_b": Color(0.96, 0.6, 0.52), "moss": 0.5,
		"paving": Color(0.74, 0.56, 0.5), "wall_a": Color(0.66, 0.46, 0.4), "wall_b": Color(0.5, 0.3, 0.28),
		"ceramic": Color(0.5, 0.2, 0.18), "timber": Color(0.3, 0.16, 0.12), "light": Color(1.0, 0.56, 0.26),
		"trees": ["broadleaf", "cypress", "dead", "bush"],
		"flowers": [Color(0.95, 0.3, 0.26), Color(1.0, 0.6, 0.3)], "ferns": 0.3, "special": "", "weather": "embers", "shafts": true,
	},
	# Dark, overgrown step pyramid in the rains.
	"monsoon": {
		"title": "Pyramid of the rains", "monolith": 0, "brazier": 0, "order": "square", "monument": "ziggurat", "secondary": "giant_heads",
		"shore": {"heads": 3, "steles": 3, "statue": 2, "urns": 2, "shrine": 2, "cairn": 1, "ghat": 1},
		"islets": ["shrine", "heads"], "lake": ["sunken_head", "sunken_shrine", "sunken_columns"], "far": "ziggurat", "roof": "flat",
		"stone_a": Color(0.82, 0.9, 0.78), "stone_b": Color(0.52, 0.6, 0.5), "moss": 1.8,
		"paving": Color(0.46, 0.5, 0.42), "wall_a": Color(0.4, 0.44, 0.36), "wall_b": Color(0.3, 0.32, 0.26),
		"ceramic": Color(0.4, 0.34, 0.22), "timber": Color(0.22, 0.18, 0.12), "light": Color(1.0, 0.76, 0.4),
		"trees": ["broadleaf", "broadleaf_b", "palm", "bush"],
		"flowers": [Color(0.9, 0.3, 0.5), Color(1.0, 0.9, 0.4)], "ferns": 1.2, "special": "", "weather": "rain", "shafts": false,
	},
	# Pale standing stones and ice under a winter sky.
	"frost": {
		"title": "Henge of the north wind", "monolith": 2, "brazier": 1, "order": "faceted", "monument": "henge", "secondary": "obelisks",
		"shore": {"obelisk": 3, "cairn": 2, "steles": 3, "crystals": 2, "arch": 2, "altar": 2, "lanterns": 2, "colonnade": 2},
		"islets": ["obelisk", "colonnade"], "lake": ["sunken_obelisk", "sunken_crystals", "sunken_arch"], "far": "obelisk", "roof": "flat",
		"stone_a": Color(1.4, 1.45, 1.5), "stone_b": Color(1.05, 1.12, 1.25), "moss": 1.5, "moss_col": Color(0.92, 0.96, 1.0),
		"paving": Color(0.74, 0.8, 0.86), "wall_a": Color(0.66, 0.72, 0.8), "wall_b": Color(0.5, 0.56, 0.64),
		"ceramic": Color(0.5, 0.6, 0.7), "timber": Color(0.3, 0.3, 0.34), "light": Color(0.7, 0.92, 1.0),
		"trees": ["pine", "pine", "dead", "bush"],
		"flowers": [], "ferns": 0.0, "special": "ice", "weather": "snow", "shafts": true,
	},
	# White marble sea temple with a turquoise dome.
	"lagoon": {
		"title": "Temple of the tides", "monolith": 1, "brazier": 1, "order": "classic", "monument": "sea_pavilion", "secondary": "lighthouse",
		"shore": {"colonnade": 3, "urns": 3, "statue": 2, "ghat": 2, "arch": 2, "altar": 1},
		"islets": ["colonnade", "shrine"], "lake": ["pier", "sunken_columns", "sunken_arch"], "far": "dome", "roof": "dome",
		"stone_a": Color(1.55, 1.5, 1.4), "stone_b": Color(1.28, 1.22, 1.1), "moss": 0.35,
		"paving": Color(0.9, 0.86, 0.76), "wall_a": Color(0.84, 0.8, 0.7), "wall_b": Color(0.7, 0.62, 0.5),
		"ceramic": Color(0.12, 0.56, 0.62), "timber": Color(0.4, 0.26, 0.14), "light": Color(1.0, 0.8, 0.46),
		"trees": ["palm", "palm", "broadleaf", "bush"],
		"flowers": [Color(1.0, 0.4, 0.6), Color(1.0, 0.95, 0.5), Color(1.0, 1.0, 1.0)], "ferns": 0.6, "special": "shells", "weather": "", "shafts": true,
	},
	# Vermilion timber gates and stone lanterns among red leaves.
	"autumn": {
		"title": "Shrine of the thousand gates", "monolith": 3, "brazier": 2, "order": "square", "monument": "gate_path", "secondary": "great_lantern",
		"shore": {"gate": 4, "lanterns": 3, "bell": 2, "shrine": 2, "steles": 1, "altar": 1},
		"islets": ["gate", "lanterns"], "lake": ["sunken_gate", "sunken_gate", "sunken_columns"], "far": "gate", "roof": "timber",
		"stone_a": Color(1.12, 1.04, 0.94), "stone_b": Color(0.86, 0.77, 0.67), "moss": 0.8, "moss_col": Color(0.5, 0.36, 0.12),
		"paving": Color(0.7, 0.62, 0.52), "wall_a": Color(0.6, 0.52, 0.44), "wall_b": Color(0.46, 0.36, 0.3),
		"ceramic": Color(0.2, 0.2, 0.24), "timber": Color(0.72, 0.16, 0.08), "light": Color(1.0, 0.7, 0.36),
		"trees": ["broadleaf", "broadleaf_b", "pine", "bush"],
		"flowers": [Color(1.0, 0.95, 0.9)], "ferns": 0.3, "special": "leaves", "weather": "leaves", "shafts": true,
	},
	# Basalt observatory rings and glowing crystals under the aurora.
	"aurora": {
		"title": "Observatory of the sky fire", "monolith": 2, "brazier": 1, "order": "faceted", "monument": "observatory", "secondary": "spires",
		"shore": {"crystals": 4, "steles": 3, "obelisk": 2, "arch": 2, "altar": 1, "lanterns": 3, "colonnade": 2, "stupa": 1},
		"islets": ["crystals", "colonnade"], "lake": ["sunken_crystals", "sunken_obelisk", "sunken_arch"], "far": "spire", "roof": "flat",
		"stone_a": Color(0.64, 0.7, 0.92), "stone_b": Color(0.42, 0.44, 0.66), "moss": 0.4, "rune_col": Color(0.4, 1.0, 0.86),
		"paving": Color(0.36, 0.4, 0.54), "wall_a": Color(0.3, 0.34, 0.48), "wall_b": Color(0.22, 0.22, 0.36),
		"ceramic": Color(0.3, 0.2, 0.5), "timber": Color(0.16, 0.14, 0.24), "light": Color(0.36, 1.0, 0.84), "light_b": Color(0.72, 0.42, 1.0),
		"trees": ["broadleaf", "cypress", "dead", "bush"],
		"flowers": [Color(0.5, 1.0, 0.9)], "ferns": 0.3, "special": "mushrooms", "weather": "", "shafts": false, "aurora": 1.0,
	},
}


static func get_style(theme_id: String) -> Dictionary:
	return STYLES.get(theme_id, STYLES["dawn"])
