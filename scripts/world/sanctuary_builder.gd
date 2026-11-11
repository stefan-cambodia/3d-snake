class_name SanctuaryBuilder
extends RefCounted
## Lays out and builds a sanctuary's architecture from its style: the great
## monument on the north islet, a second landmark on the east islet, shrines and
## props along the shore, ruins standing in the lake, something on every small
## islet and silhouettes on the far shore.
##
## Rules: everything is seeded by the island, nothing is placed inside the
## playfield (the serpent can never touch any of it), and no two pieces overlap
## (each has a footprint radius and a minimum gap to its neighbours).

const FOCAL_POS := Vector2(0.0, -64.0)
const SECOND_POS := Vector2(74.0, 10.0)
## Nearest a footprint may come to the centre: outside the barrier and its lanterns.
const KEEP_OUT := GameConfig.ARENA_RADIUS + 1.6
const SHORE_STATIONS := 16
const MIN_GAP := 1.0
## The shore is cut into sectors so the camera and the shadow pass only draw the
## stretch in view.
const SHORE_SECTORS := 12

## Footprint radius of each kind at scale 1.
const RADII := {
	"shrine": 2.5, "statue": 1.7, "altar": 1.9, "arch": 2.4, "steles": 2.0, "bell": 1.6, "colonnade": 2.7, "urns": 1.5,
	"lanterns": 1.8, "obelisk": 1.4, "crystals": 1.5, "ghat": 2.4, "heads": 2.0, "props": 1.0, "stupa": 1.7, "cairn": 1.3, "gate": 2.2,
	"sunken_arch": 3.0, "sunken_columns": 3.0, "sunken_head": 2.6, "sunken_shrine": 3.2, "pier": 5.5, "sunken_obelisk": 2.0,
	"sunken_crystals": 2.2, "sunken_gate": 3.0,
}


static func _place(kind: String, zone: String, pos: Vector2, yaw: float, radius: float, scale: float = 1.0) -> Dictionary:
	return {"kind": kind, "zone": zone, "pos": pos, "yaw": yaw, "radius": radius, "scale": scale}


## Yaw that turns a piece's front (+Z) toward the centre of the island.
static func facing_centre(p: Vector2) -> float:
	return atan2(-p.x, -p.y)


static func fits(placed: Array[Dictionary], pos: Vector2, radius: float) -> bool:
	for o in placed:
		if pos.distance_to(o["pos"]) < radius + float(o["radius"]) + MIN_GAP:
			return false
	return true


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var x := rng.randf() * total
	for k in weights:
		x -= float(weights[k])
		if x <= 0.0:
			return k
	return weights.keys()[0]


## Where everything goes. Deterministic for an island and a style.
static func plan(terrain: TerrainField, style: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.seed_value * 977 + 11
	var out: Array[Dictionary] = []
	out.append(_place(style["monument"], "focal", FOCAL_POS, facing_centre(FOCAL_POS), 11.0))
	out.append(_place(style["secondary"], "second", SECOND_POS, facing_centre(SECOND_POS), 8.0))
	# Something on every small islet.
	var islet_kinds: Array = style["islets"]
	for i in range(2, terrain.islets.size()):
		var isl: Vector4 = terrain.islets[i]
		var p := Vector2(isl.x, isl.y)
		var kind: String = islet_kinds[rng.randi() % islet_kinds.size()]
		var sc := clampf(isl.z / 5.0, 1.1, 1.7)
		out.append(_place(kind, "islet", p, facing_centre(p) + rng.randf_range(-0.5, 0.5), float(RADII[kind]) * sc, sc))
	# Stations around the shore, just outside the barrier, facing the playfield.
	var start := rng.randf() * TAU
	for i in SHORE_STATIONS:
		var a := start + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(SHORE_STATIONS)
		var kind := _weighted(style["shore"], rng)
		var rad: float = RADII[kind]
		var p := Vector2(cos(a), sin(a)) * (KEEP_OUT + rad + rng.randf_range(0.2, 1.0))
		if fits(out, p, rad):
			out.append(_place(kind, "shore", p, facing_centre(p), rad))
	# Small groups of props between the stations.
	for i in SHORE_STATIONS:
		var a := start + TAU * (float(i) + 0.5 + rng.randf_range(-0.15, 0.15)) / float(SHORE_STATIONS)
		var p := Vector2(cos(a), sin(a)) * (KEEP_OUT + 1.0 + rng.randf_range(0.3, 2.2))
		if fits(out, p, 1.0):
			out.append(_place("props", "shore", p, facing_centre(p) + rng.randf_range(-0.6, 0.6), 1.0))
	# Ruins standing in the lake between the shore and the islets.
	var lake_kinds: Array = style["lake"]
	var tries := 0
	var in_lake := 0
	while in_lake < 9 and tries < 140:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(51.0, 62.0)
		var kind: String = lake_kinds[rng.randi() % lake_kinds.size()]
		var rad: float = RADII[kind]
		if terrain.height(p.x, p.y) > GameConfig.WATER_LEVEL - 0.45:
			continue
		if fits(out, p, rad + 2.0):
			out.append(_place(kind, "lake", p, rng.randf() * TAU, rad))
			in_lake += 1
	# Silhouettes on the far shore, in front of the mountains.
	var far_start := rng.randf() * TAU
	for i in 6:
		var a := far_start + TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / 6.0
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(138.0, 150.0)
		out.append(_place("far_" + str(style["far"]), "far", p, facing_centre(p), 9.0, rng.randf_range(2.2, 3.0)))
	return out


## Build the plan. Returns {"groups": [{"name", "stone", "accent", "glow",
## "shadows", "centre"}...], "plan": [...], "triangles": n}.
static func build(terrain: TerrainField, style: Dictionary) -> Dictionary:
	var placements := plan(terrain, style)
	var kits := {}
	for pl in placements:
		var zone: String = pl["zone"]
		var group := zone
		if zone == "shore":
			var ang := atan2(float(pl["pos"].y), float(pl["pos"].x))
			group = "shore%d" % (int(floor((ang + PI) / TAU * float(SHORE_SECTORS))) % SHORE_SECTORS)
		if not kits.has(group):
			kits[group] = SanctuaryKit.new(terrain.seed_value * 131 + kits.size() * 17 + 3)
		var k: SanctuaryKit = kits[group]
		var p: Vector2 = pl["pos"]
		var ground := terrain.height(p.x, p.y)
		var y := maxf(ground, GameConfig.WATER_LEVEL + 0.3)
		if zone == "lake":
			y = GameConfig.WATER_LEVEL - 0.9
		elif zone == "shore":
			y = maxf(ground + 0.2, GameConfig.WATER_LEVEL + 0.4)
		var sc: float = pl["scale"]
		k.xf = Transform3D(Basis(Vector3.UP, pl["yaw"]).scaled(Vector3.ONE * sc), Vector3(p.x, y, p.y))
		_build_kind(k, style, pl["kind"])
	var groups: Array[Dictionary] = []
	var total := 0
	for name in kits:
		var meshes: Dictionary = (kits[name] as SanctuaryKit).commit()
		for key in meshes:
			total += SanctuaryKit.triangle_count(meshes[key])
		groups.append({"name": name, "stone": meshes["stone"], "accent": meshes["accent"], "glow": meshes["glow"],
			"shadows": name != "far" and name != "islet"})
	return {"groups": groups, "plan": placements, "triangles": total}


static func _build_kind(k: SanctuaryKit, s: Dictionary, kind: String) -> void:
	match kind:
		"prasat": _prasat(k, s)
		"moon_gate": _moon_gate(k, s)
		"pagoda": _pagoda(k, s)
		"rotunda": _rotunda(k, s)
		"ziggurat": _ziggurat(k, s)
		"henge": _henge(k, s)
		"sea_pavilion": _sea_pavilion(k, s)
		"gate_path": _gate_path(k, s)
		"observatory": _observatory(k, s)
		"serpent": _serpent(k, s)
		"stupas": _stupas(k, s)
		"bell_tower": _bell_tower(k, s)
		"colossus": _colossus(k, s)
		"giant_heads": _heads(k, s, kind)
		"obelisks": _obelisks(k, s)
		"lighthouse": _lighthouse(k, s)
		"great_lantern": _great_lantern(k, s)
		"spires": _spires(k, s)
		_:
			if kind.begins_with("far_"):
				_far(k, s, kind.trim_prefix("far_"))
			elif kind.begins_with("sunken_") or kind == "pier":
				_sunken(k, s, kind)
			else:
				_station(k, s, kind)


# --- Great monuments (one per sanctuary) -----------------------------------------

## Temple-mountain: five-tiered tower on a stepped base, four corner towers.
static func _prasat(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(8.6, 8.6, 3.4)
	var top := k.stepped_base(8.5, 3, 0.5, 0.9)
	k.stairs(Vector3(0, 0, 8.5), 3.4, 3, 0.5, 0.9)
	k.tower(Vector3(0, top, -0.8), 3.1, 5, 2.7, 0.8)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.tower(Vector3(c.x * 5.1, top, c.y * 5.1 - 0.4), 1.15, 4, 1.35, 0.8, false)
	# Porch in front of the door.
	for x: float in [-1.6, 1.6]:
		k.column(s["order"], Vector3(x, top, 3.3), 3.4, 0.32)
	k.box(Vector3(0, top + 3.4, 3.3), Vector3(4.4, 0.5, 1.0), SanctuaryKit.tint(0.96))
	k.rune_panel(Vector3(0, top + 3.45, 3.82), 3.4, 0.4)
	k.box(Vector3(0, top + 3.9, 3.3), Vector3(3.6, 1.1, 0.8), SanctuaryKit.tint(1.02), 0.3)
	for x: float in [-1.0, 1.0]:
		k.guardian(Vector3(x * 2.9, 0.5, 7.3), 0.8)
		k.fire_bowl(Vector3(x * 3.2, top, 5.0), 0.9)
		k.urn(Vector3(x * 4.6, top, 2.4), 1.2, s["ceramic"], 0)
		k.urn(Vector3(x * 5.4, top, 1.8), 0.9, s["ceramic"], 1)
	k.altar(Vector3(0, top, 5.4), 1.8)


## A great stone ring through which the moon rises, between two stupas.
static func _moon_gate(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(9.0, 9.0, 3.4, true)
	var top := k.round_base(9.0, 3, 0.4, 0.8)
	k.stairs(Vector3(0, 0, 9.0), 3.2, 3, 0.4, 0.8)
	k.box(Vector3(0, top, 0), Vector3(8.4, 1.5, 2.4), SanctuaryKit.tint(0.94), 0.9)
	k.rune_panel(Vector3(0, top + 0.4, 1.12), 6.4, 0.8)
	k.ring(Vector3(0, top + 6.9, 0), 5.0, 1.3, 1.8, 14)
	k.crystals(Vector3(0, top + 13.3, 0), 1.7, 3, s["light"], Color(1.0, 1.0, 1.0))
	for x: float in [-1.0, 1.0]:
		k.stupa(Vector3(x * 6.8, top, -0.4), 1.25)
		k.lantern(Vector3(x * 3.4, top, 4.4), 1.2, s["light"])
		k.lantern(Vector3(x * 6.2, top, 3.6), 1.0, s["light"])
		k.urn(Vector3(x * 4.9, top, 1.9), 1.1, s["ceramic"], 2)
	k.altar(Vector3(0, top, 3.4), 2.2)
	k.bell(Vector3(-5.4, top, -4.6), 1.3, 0.7)


static func _pagoda_tiers(k: SanctuaryKit, s: Dictionary, base: Vector3, half: float, storeys: int) -> float:
	var y := base.y
	var h := half
	var roof_col: Color = (s["timber"] as Color).lerp(Color(0.16, 0.2, 0.22), 0.7)
	for i in storeys:
		k.box(Vector3(base.x, y, base.z), Vector3(h * 1.5, 2.2, h * 1.5), SanctuaryKit.tint(1.0 - 0.02 * float(i)))
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			k.box(Vector3(base.x + c.x * h * 0.82, y, base.z + c.y * h * 0.82), Vector3(0.28, 2.2, 0.28), s["timber"], 1.0, 0.0, true)
		for a in 4:
			var yaw := PI * 0.5 * float(a)
			var out := Basis(Vector3.UP, yaw) * Vector3(0, 0, h * 0.76)
			if i == 0:
				k.box(Vector3(base.x, y, base.z) + out, Vector3(h * 0.5, 1.7, 0.1), SanctuaryKit.tint(0.3), 1.0, yaw)
			else:
				k.rune_panel(Vector3(base.x, y + 0.5, base.z) + out, h * 0.8, 1.1, yaw)
		y += 2.2
		k.roof(Vector3(base.x, y, base.z), h * 1.25, 1.15, 0.6, roof_col, true)
		y += 1.15
		h *= 0.82
	k.turned(PackedVector2Array([Vector2(0.3, 0.0), Vector2(0.4, 0.3), Vector2(0.16, 0.5), Vector2(0.3, 0.8), Vector2(0.12, 1.0), Vector2(0.22, 1.3), Vector2(0.06, 1.6), Vector2(0.0, 2.6)]),
		Vector3(base.x, y - 0.3, base.z), 8, SanctuaryKit.GOLD, true, Callable(), "", Basis().scaled(Vector3.ONE * h * 0.5))
	return y


## Five-storey pagoda with timber posts and slate roofs.
static func _pagoda(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(7.6, 7.6, 3.4)
	var top := k.stepped_base(7.5, 2, 0.6, 1.0)
	k.stairs(Vector3(0, 0, 7.5), 3.0, 2, 0.6, 1.0)
	_pagoda_tiers(k, s, Vector3(0, top, 0), 3.6, 5)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.lantern(Vector3(c.x * 5.4, top, c.y * 5.4), 1.3, s["light"])
	k.bell(Vector3(5.2, top, 2.2), 1.3, -0.6)
	k.stele(Vector3(-5.0, top, 2.6), 2.4, 0.5)
	k.altar(Vector3(0, top, 4.6), 1.8)


## Ring of columns, half fallen, around a great fire.
static func _rotunda(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(9.0, 9.0, 3.4, true)
	var top := k.round_base(9.0, 3, 0.4, 0.7)
	k.stairs(Vector3(0, 0, 9.0), 3.4, 3, 0.4, 0.7)
	var n := 10
	var ring_r := 6.6
	var standing: Array[bool] = []
	for i in n:
		standing.append(i != 3 and i != 7 and i != 8)
		var a := TAU * (float(i) + 0.5) / float(n)
		var p := Vector3(cos(a) * ring_r, top, sin(a) * ring_r)
		if standing[i]:
			k.column("classic", p, 7.2, 0.5, false, Basis(), i % 3)
		else:
			k.column("classic", p, k.rng.randf_range(1.6, 3.6), 0.5, true, Basis(), i % 3)
			k.rubble(p + Vector3(cos(a), 0, sin(a)) * 1.2, 1.4, 6)
	for i in n:
		var j := (i + 1) % n
		if standing[i] and standing[j]:
			var am := TAU * (float(i) + 1.0) / float(n)
			var mid := Vector3(cos(am) * ring_r * 0.95, top + 7.2, sin(am) * ring_r * 0.95)
			k.box(mid, Vector3(4.6, 0.8, 1.2), SanctuaryKit.tint(0.97), 1.0, PI * 0.5 - am)
			k.box(mid + Vector3(0, 0.8, 0), Vector3(4.9, 0.3, 1.5), SanctuaryKit.tint(0.88), 1.0, PI * 0.5 - am)
	k.turned(PackedVector2Array([Vector2(2.6, 0.0), Vector2(2.6, 0.3), Vector2(2.2, 0.3), Vector2(2.2, 0.6), Vector2(0.0, 0.6)]), Vector3(0, top, 0), 16, SanctuaryKit.tint(0.94))
	k.fire_bowl(Vector3(0, top + 0.6, 0), 2.4)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		k.urn(Vector3(cos(a) * 4.2, top, sin(a) * 4.2), 1.1, s["ceramic"], i % 3)
	k.column("classic", Vector3(-3.0, top + 0.45, 4.8), 3.0, 0.5, true, Basis(Vector3(0, 0, 1), -PI * 0.5) * Basis(Vector3.UP, 0.4))


## Step pyramid with a steep stairway and a shrine on top, taken by the jungle.
static func _ziggurat(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(9.0, 9.0, 3.4)
	var halves: Array[float] = [8.5, 7.0, 5.5, 4.0, 2.8]
	var y := 0.0
	for i in halves.size():
		var h := halves[i]
		k.box(Vector3(0, y, 0), Vector3(h * 2.0, 1.6, h * 2.0), SanctuaryKit.tint(0.98 - 0.03 * float(i)), 0.95)
		k.box(Vector3(0, y + 1.6, 0), Vector3(h * 1.94, 0.12, h * 1.94), SanctuaryKit.tint(0.82))
		for a in 4:
			var yaw := PI * 0.5 * float(a)
			k.rune_panel(Vector3(0, y + 0.5, 0) + Basis(Vector3.UP, yaw) * Vector3(h * 0.5, 0, h * 0.99), h * 0.5, 0.7, yaw)
			for v in 2:
				k.vine(Vector3(0, y + 1.66, 0) + Basis(Vector3.UP, yaw) * Vector3(k.rng.randf_range(-h * 0.8, h * 0.8), 0, h * 0.99), k.rng.randf_range(0.8, 1.5))
		y += 1.6
	k.stairs(Vector3(0, 0, 9.4), 2.6, 20, 0.4, 0.33)
	# Shrine on the summit.
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.column("square", Vector3(c.x * 1.7, y, c.y * 1.7), 2.8, 0.3)
	k.box(Vector3(0, y + 2.8, 0), Vector3(4.8, 0.5, 4.8), SanctuaryKit.tint(0.92))
	k.roof(Vector3(0, y + 3.3, 0), 2.0, 1.6, 0.25, SanctuaryKit.tint(1.0))
	k.fire_bowl(Vector3(0, y, 0), 1.1)
	for x: float in [-1.0, 1.0]:
		k.fallen_head(Vector3(x * 6.4, 0.3, 10.0), 1.1, x * 0.6)
		k.urn(Vector3(x * 6.2, 1.6, 6.4), 1.2, s["ceramic"], 1)
		k.stele(Vector3(x * 3.4, 0.0, 10.4), 2.2, 0.0, x * 0.12)


## Circle of standing stones around a tall obelisk, rimed with ice.
static func _henge(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(9.6, 9.6, 3.2, true)
	var top := k.round_base(9.5, 1, 0.35, 0.6)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		k.trilithon(Vector3(cos(a) * 7.4, top, sin(a) * 7.4), 2.5, 4.6, PI * 0.5 - a, i == 2 or i == 5)
	for i in 3:
		var a := -PI * 0.5 + (float(i) - 1.0) * 0.95
		k.trilithon(Vector3(cos(a) * 3.9, top, sin(a) * 3.9), 2.7, 6.6, PI * 0.5 - a)
	k.obelisk(Vector3(0, top, 0), 11.0, 1.5)
	k.crystals(Vector3(1.6, top, 1.4), 2.2, 4, s["light"], Color(1.0, 1.0, 1.0))
	k.crystals(Vector3(-1.9, top, 0.6), 1.6, 3, s["light"], Color(1.0, 1.0, 1.0))
	k.altar(Vector3(0, top, 4.6), 2.4, 0.0, false)
	_cairn(k, Vector3(4.6, top, 4.0), 1.0)
	_cairn(k, Vector3(-5.0, top, 3.2), 0.8)
	k.rubble(Vector3(0, top, 0), 8.0, 16)
	# Outer circle of small marker stones, each with its shard of ice.
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p := Vector3(cos(a) * 9.0, top - 0.35, sin(a) * 9.0)
		k.box(p, Vector3(0.7, k.rng.randf_range(1.1, 1.9), 0.5), SanctuaryKit.tint(k.rng.randf_range(0.88, 1.04)), 0.7, PI * 0.5 - a)
		if i % 2 == 0:
			k.crystals(p + Vector3(cos(a) * 0.5, 0.3, sin(a) * 0.5), 0.9, 3, s["light"], Color(1.0, 1.0, 1.0))
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		k.lantern(Vector3(cos(a) * 5.6, top, sin(a) * 5.6), 1.1, s["light"])


## Domed marble rotunda on the water, with a stair into the lagoon and two piers.
static func _sea_pavilion(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(7.0, 7.0, 3.4, true)
	var top := k.round_base(7.0, 3, 0.4, 0.6)
	k.stairs(Vector3(0, -2.0, 10.6), 3.8, 8, 0.4, 0.55)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		k.column("classic", Vector3(cos(a) * 4.6, top, sin(a) * 4.6), 5.6, 0.42, false, Basis(), i % 3)
	k.turned(PackedVector2Array([Vector2(4.0, 0.0), Vector2(5.3, 0.0), Vector2(5.3, 0.8), Vector2(5.6, 0.8), Vector2(5.6, 1.1), Vector2(4.6, 1.1)]), Vector3(0, top + 5.6, 0), 24, SanctuaryKit.tint(1.0))
	k.dome(Vector3(0, top + 6.7, 0), 4.8, s["ceramic"], true)
	k.bowl(Vector3(0, top, 0), 3.2, SanctuaryKit.BRONZE.lerp(SanctuaryKit.VERDIGRIS, 0.6))
	for sx: float in [-1.0, 1.0]:
		for i in 3:
			k.arch(Vector3(sx * (8.6 + float(i) * 3.7), -0.7, 0), 2.5, 2.2, 0.6, 1.6, 0.0, 1.0 if i < 2 else 0.6)
			if i < 2:
				k.box(Vector3(sx * (8.6 + float(i) * 3.7), 3.6, 0), Vector3(3.8, 0.3, 2.0), SanctuaryKit.tint(0.92))
		k.urn(Vector3(sx * 5.6, top, 2.6), 1.3, s["ceramic"], 0)
		k.urn(Vector3(sx * 6.0, top, 1.4), 1.0, SanctuaryKit.TERRACOTTA, 2)
		k.fire_bowl(Vector3(sx * 2.6, top, 6.0), 0.8)


static func _timber_gate(k: SanctuaryKit, pos: Vector3, w: float, h: float, col: Color, yaw: float = 0.0) -> void:
	var fn := func() -> void:
		for x: float in [-1.0, 1.0]:
			k.box(Vector3(x * w * 0.5, -0.5, 0), Vector3(w * 0.16, 0.9, w * 0.16), SanctuaryKit.tint(0.9))
			k.turned(PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.88, 1.0), Vector2(0.0, 1.0)]), Vector3(x * w * 0.5, 0.3, 0), 8, col, true, Callable(), "",
				Basis().scaled(Vector3(w * 0.055, h - 0.3, w * 0.055)))
		k.box(Vector3(0, h * 0.76, 0), Vector3(w * 1.12, h * 0.06, w * 0.07), col, 1.0, 0.0, true)
		k.box(Vector3(0, h * 0.82, 0), Vector3(w * 0.12, h * 0.16, w * 0.05), SanctuaryKit.GOLD, 1.0, 0.0, true)
		k.box(Vector3(0, h * 0.97, 0), Vector3(w * 1.36, h * 0.07, w * 0.09), col, 1.04, 0.0, true)
		k.box(Vector3(0, h * 1.04, 0), Vector3(w * 1.42, h * 0.035, w * 0.13), Color(0.1, 0.09, 0.09), 1.1, 0.0, true)
	k.at(pos, yaw, fn)


## A path of vermilion gates leading to a small hall, lined with stone lanterns.
static func _gate_path(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(7.0, 10.0, 3.4)
	k.box(Vector3(0, 0, 0), Vector3(13.4, 0.4, 19.6), SanctuaryKit.tint(0.94))
	var top := 0.4
	k.stairs(Vector3(0, -1.2, 12.4), 4.0, 4, 0.4, 0.6)
	_timber_gate(k, Vector3(0, top, 8.2), 5.6, 6.6, s["timber"])
	_timber_gate(k, Vector3(0, top, 4.8), 5.0, 5.9, s["timber"])
	_timber_gate(k, Vector3(0, top, 1.6), 4.5, 5.3, s["timber"])
	for z: float in [9.6, 6.5, 3.2, 0.2]:
		for x: float in [-1.0, 1.0]:
			k.lantern(Vector3(x * 3.6, top, z), 1.0, s["light"])
	# The hall.
	var roof_col: Color = Color(0.14, 0.16, 0.18)
	k.box(Vector3(0, top, -5.2), Vector3(9.4, 0.8, 6.4), SanctuaryKit.tint(1.0))
	k.stairs(Vector3(0, top, -1.2), 2.6, 2, 0.4, 0.4, 0.0, false)
	for x: float in [-3.6, -1.2, 1.2, 3.6]:
		for z: float in [-3.0, -7.4]:
			k.box(Vector3(x, top + 0.8, z), Vector3(0.32, 3.2, 0.32), s["timber"], 1.0, 0.0, true)
	k.box(Vector3(0, top + 0.8, -7.3), Vector3(7.4, 3.2, 0.2), SanctuaryKit.tint(0.92))
	k.rune_panel(Vector3(0, top + 1.5, -7.18), 3.0, 1.6)
	k.roof(Vector3(0, top + 4.0, -5.2), 4.6, 1.5, 0.66, roof_col, true)
	k.box(Vector3(0, top + 5.5, -5.2), Vector3(4.6, 1.2, 3.4), s["timber"], 1.0, 0.0, true)
	k.roof(Vector3(0, top + 6.7, -5.2), 3.2, 1.7, 0.2, roof_col, true)
	k.altar(Vector3(0, top + 0.8, -5.6), 2.0)
	k.bell(Vector3(5.0, top, 5.0), 1.3, -0.5)
	k.stele(Vector3(-5.0, top, 6.2), 2.4, 0.4)


## Two great stone rings, one inside the other, around a glowing crystal.
static func _observatory(k: SanctuaryKit, s: Dictionary) -> void:
	var la: Color = s["light"]
	var lb: Color = s.get("light_b", s["light"])
	k.plinth(9.0, 9.0, 3.4, true)
	var top := k.round_base(9.0, 2, 0.45, 0.8)
	k.stairs(Vector3(0, 0, 9.0), 3.2, 2, 0.45, 0.8)
	for i in 12:
		var a := TAU * float(i) / 12.0
		k.rune_panel(Vector3(sin(a) * 8.22, 0.5, cos(a) * 8.22), 2.2, 0.36, a)
	for x: float in [-1.0, 1.0]:
		k.box(Vector3(x * 6.4, top, 0), Vector3(1.6, 4.4, 2.4), SanctuaryKit.tint(0.95), 0.8)
	k.ring(Vector3(0, top + 7.4, 0), 5.6, 1.0, 1.3, 16, TAU, 0.0, Basis(Vector3.RIGHT, -0.42))
	k.ring(Vector3(0, top + 7.4, 0), 3.7, 0.6, 0.8, 12, TAU, 0.0, Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, 0.35))
	k.pedestal(Vector3(0, top, 0), 1.7, 1.8)
	k.crystals(Vector3(0, top + 1.8, 0), 4.4, 6, la, lb)
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		k.crystals(Vector3(cos(a) * 7.3, top, sin(a) * 7.3), 2.4, 3, la, lb)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		k.stele(Vector3(sin(a) * 4.6, top, cos(a) * 4.6), 2.6, a + PI)


# --- Second landmarks -------------------------------------------------------------

static func _serpent(k: SanctuaryKit, _s: Dictionary) -> void:
	k.mesh(WorldMeshes.serpent_statue(), Transform3D(Basis(Vector3.UP, 0.9), Vector3(0, -0.4, 0)))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.6
		k.fire_bowl(Vector3(cos(a) * 6.2, 0.0, sin(a) * 6.2), 0.9)


static func _stupas(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(6.4, 6.4, 3.2, true)
	var top := k.round_base(6.4, 2, 0.4, 0.7)
	k.stupa(Vector3(0, top, 0), 2.5)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		k.stupa(Vector3(cos(a) * 4.1, top, sin(a) * 4.1), 0.95)
		k.lantern(Vector3(cos(a + PI * 0.25) * 4.6, top, sin(a + PI * 0.25) * 4.6), 0.9, s["light"])


static func _bell_tower(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(4.0, 4.0, 3.2)
	var top := k.stepped_base(4.0, 2, 0.5, 0.7)
	k.stairs(Vector3(0, 0, 4.0), 2.2, 2, 0.5, 0.7)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.column("square", Vector3(c.x * 2.2, top, c.y * 2.2), 6.4, 0.34)
	var roof_col: Color = (s["timber"] as Color).lerp(Color(0.16, 0.2, 0.22), 0.7)
	k.box(Vector3(0, top + 6.4, 0), Vector3(5.6, 0.4, 5.6), s["timber"], 1.0, 0.0, true)
	k.roof(Vector3(0, top + 6.8, 0), 3.4, 1.6, 0.6, roof_col, true)
	k.roof(Vector3(0, top + 8.4, 0), 2.0, 1.8, 0.1, roof_col, true)
	k.bell(Vector3(0, top + 0.3, 0), 2.4)


static func _colossus(k: SanctuaryKit, _s: Dictionary) -> void:
	k.plinth(4.8, 4.8, 3.2)
	var top := k.stepped_base(4.8, 2, 0.6, 0.6)
	k.box(Vector3(0, top, -0.4), Vector3(5.6, 1.4, 5.6), SanctuaryKit.tint(0.96))
	k.rune_panel(Vector3(0, top + 0.3, 2.42), 4.0, 0.8)
	k.guardian(Vector3(0, top + 1.4, -0.4), 2.6)
	for x: float in [-1.0, 1.0]:
		k.fire_bowl(Vector3(x * 3.4, top, 3.2), 1.0)
	k.stairs(Vector3(0, 0, 4.8), 2.6, 2, 0.6, 0.6)


static func _heads(k: SanctuaryKit, s: Dictionary, _kind: String) -> void:
	k.fallen_head(Vector3(0, 0.0, 0), 2.3, 0.3)
	k.fallen_head(Vector3(4.4, -0.3, 1.6), 1.5, -0.9)
	k.fallen_head(Vector3(-3.8, -0.2, 2.6), 1.1, 1.4)
	k.rubble(Vector3(0, 0, 2.0), 5.5, 18)
	k.column("square", Vector3(-4.6, 0, -1.8), 2.4, 0.4, true)
	k.column("square", Vector3(3.2, 0, -3.0), 3.4, 0.4, true)
	k.urn(Vector3(1.8, 0, 3.6), 1.2, s["ceramic"], 1)


static func _obelisks(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(6.0, 6.0, 3.2, true)
	var top := k.round_base(6.0, 1, 0.3, 0.5)
	k.obelisk(Vector3(0, top, -0.6), 10.0, 1.3)
	k.obelisk(Vector3(-3.2, top, 1.2), 6.8, 1.0, 0.4)
	k.obelisk(Vector3(3.0, top, 1.8), 4.8, 0.85, -0.3)
	_cairn(k, Vector3(0.4, top, 3.6), 1.0)
	k.crystals(Vector3(-1.4, top, 3.0), 1.5, 3, s["light"], Color(1.0, 1.0, 1.0))


static func _lighthouse(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(4.2, 4.2, 3.2, true)
	var top := k.round_base(4.2, 2, 0.4, 0.5)
	k.turned(PackedVector2Array([
		Vector2(2.9, 0.0), Vector2(2.9, 0.6), Vector2(2.6, 0.7), Vector2(2.0, 10.0), Vector2(2.7, 10.3), Vector2(2.7, 10.7), Vector2(2.2, 10.7), Vector2(0.0, 10.7)]),
		Vector3(0, top, 0), 16, SanctuaryKit.tint(1.02))
	for i in 6:
		var a := TAU * float(i) / 6.0
		k.column("classic", Vector3(cos(a) * 1.7, top + 10.7, sin(a) * 1.7), 2.4, 0.16)
	k.dome(Vector3(0, top + 13.1, 0), 2.2, s["ceramic"], true)
	k.flame(Vector3(0, top + 10.9, 0), 3.0)
	k.rune_panel(Vector3(0, top + 1.2, 2.72), 1.4, 2.4)


static func _great_lantern(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(4.6, 4.6, 3.2, true)
	var top := k.round_base(4.6, 2, 0.4, 0.6)
	k.lantern(Vector3(0, top, 0), 4.6, s["light"])
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		k.lantern(Vector3(cos(a) * 3.3, top, sin(a) * 3.3), 1.0, s["light"])
	_timber_gate(k, Vector3(0, 0.0, 4.9), 3.4, 4.0, s["timber"])


static func _spires(k: SanctuaryKit, s: Dictionary) -> void:
	var la: Color = s["light"]
	var lb: Color = s.get("light_b", s["light"])
	for i in 5:
		var a := TAU * float(i) / 5.0
		var r := 0.0 if i == 0 else 3.0
		k.box(Vector3(cos(a) * r, -1.2, sin(a) * r), Vector3(3.6, 2.2 - 0.3 * float(i), 3.2), SanctuaryKit.tint(0.8), 0.6, a)
	k.crystals(Vector3(0, 0.9, 0), 8.5, 7, la, lb)
	k.crystals(Vector3(3.4, 0.2, 1.6), 3.4, 4, la, lb)
	k.crystals(Vector3(-3.2, 0.2, 2.2), 2.6, 3, la, lb)
	k.stele(Vector3(0.6, 0.0, 5.0), 2.6)


# --- Shore stations, islets ---------------------------------------------------------

static func _cairn(k: SanctuaryKit, pos: Vector3, scale: float) -> void:
	var y := -0.2
	var w := 1.3 * scale
	for i in 5:
		k.box(pos + Vector3(k.rng.randf_range(-0.08, 0.08) * scale, y, k.rng.randf_range(-0.08, 0.08) * scale), Vector3(w, 0.34 * scale, w * 0.9), SanctuaryKit.tint(k.rng.randf_range(0.85, 1.05)), 0.86, k.rng.randf() * TAU)
		y += 0.34 * scale
		w *= 0.74


static func _shrine(k: SanctuaryKit, s: Dictionary) -> void:
	k.plinth(2.3, 2.3)
	k.box(Vector3(0, 0, 0), Vector3(4.2, 0.3, 4.2), SanctuaryKit.tint(0.92))
	k.stairs(Vector3(0, -0.4, 2.9), 1.6, 2, 0.35, 0.4, 0.0, false)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		k.column(s["order"], Vector3(c.x * 1.45, 0.3, c.y * 1.45), 3.0, 0.24)
	var y := 3.3
	match str(s["roof"]):
		"dome":
			k.box(Vector3(0, y, 0), Vector3(3.9, 0.3, 3.9), SanctuaryKit.tint(0.94))
			k.dome(Vector3(0, y + 0.3, 0), 1.7, s["ceramic"], true)
		"timber":
			var roof_col: Color = (s["timber"] as Color).lerp(Color(0.16, 0.2, 0.22), 0.7)
			k.box(Vector3(0, y, 0), Vector3(3.7, 0.22, 3.7), s["timber"], 1.0, 0.0, true)
			k.roof(Vector3(0, y + 0.22, 0), 2.3, 1.5, 0.12, roof_col, true)
		"flat":
			k.box(Vector3(0, y, 0), Vector3(3.9, 0.4, 3.9), SanctuaryKit.tint(0.96))
			k.box(Vector3(0, y + 0.4, 0), Vector3(4.3, 0.2, 4.3), SanctuaryKit.tint(0.86))
			for a in 4:
				k.rune_panel(Vector3(0, y + 0.06, 0) + Basis(Vector3.UP, PI * 0.5 * float(a)) * Vector3(0, 0, 1.96), 3.0, 0.3, PI * 0.5 * float(a))
		_:
			k.box(Vector3(0, y, 0), Vector3(3.9, 0.3, 3.9), SanctuaryKit.tint(0.94))
			k.roof(Vector3(0, y + 0.3, 0), 1.9, 1.0, 0.7)
			k.roof(Vector3(0, y + 1.3, 0), 1.35, 1.2, 0.2)
	if k.rng.randf() < 0.5:
		k.guardian(Vector3(0, 0.3, -0.3), 0.55)
	else:
		k.altar(Vector3(0, 0.3, -0.2), 1.3)


static func _station(k: SanctuaryKit, s: Dictionary, kind: String) -> void:
	var cer: Color = s["ceramic"]
	match kind:
		"shrine":
			_shrine(k, s)
		"statue":
			k.plinth(1.6, 1.6, 2.6, true)
			k.pedestal(Vector3.ZERO, 1.5, 1.3)
			k.guardian(Vector3(0, 1.3, 0), 0.72)
			k.bowl(Vector3(0, 0, 1.25), 0.9)
			k.urn(Vector3(-1.1, 0, 0.9), 0.8, cer, 0)
			k.urn(Vector3(1.1, 0, 0.8), 0.7, cer, 2)
		"altar":
			k.plinth(1.9, 1.5)
			k.altar(Vector3.ZERO, 1.9)
			for x: float in [-1.0, 1.0]:
				k.fire_bowl(Vector3(x * 1.5, 0, 0.5), 0.7)
		"arch":
			var broken := k.rng.randf() < 0.45
			k.plinth(2.4, 1.0)
			k.arch(Vector3.ZERO, 2.2, 2.6, 0.55, 0.9, 0.0, 0.62 if broken else 1.0)
			k.stairs(Vector3(0, -0.5, 1.5), 2.0, 1, 0.5, 0.5, 0.0, false)
			if broken:
				k.rubble(Vector3(1.2, 0, 0.4), 1.4, 8)
		"steles":
			k.plinth(2.0, 1.2)
			k.stele(Vector3(0, 0, 0), k.rng.randf_range(2.2, 3.0))
			k.stele(Vector3(-1.4, 0, 0.3), k.rng.randf_range(1.4, 2.0), 0.3, 0.1)
			k.stele(Vector3(1.4, 0, 0.2), k.rng.randf_range(1.2, 1.8), -0.25, -0.16)
			k.rubble(Vector3(0, 0, 0.9), 1.5, 5)
		"bell":
			k.plinth(1.6, 1.2)
			k.bell(Vector3.ZERO, 1.15)
			k.bowl(Vector3(0, 0, 0.9), 0.7)
		"colonnade":
			k.plinth(2.7, 1.0)
			k.colonnade(s["order"], Vector3.ZERO, 4, 1.5, 3.4, 0.28, 0.4)
			k.rubble(Vector3(0, 0, 0.8), 2.2, 6)
		"urns":
			k.plinth(1.5, 1.3)
			k.box(Vector3(0, 0, -0.9), Vector3(2.8, 0.7, 0.4), SanctuaryKit.tint(0.92))
			for i in 5:
				k.urn(Vector3(k.rng.randf_range(-1.1, 1.1), 0, k.rng.randf_range(-0.4, 0.9)), k.rng.randf_range(0.7, 1.3), cer if i % 2 == 0 else SanctuaryKit.TERRACOTTA, i % 3)
			k.urn(Vector3(0.3, 0.25, 1.1), 1.0, cer, 0, Basis(Vector3(0, 0, 1), 1.45))
		"lanterns":
			k.plinth(1.8, 1.1)
			for x: float in [-1.0, 1.0]:
				k.lantern(Vector3(x * 1.2, 0, 0), 1.1, s["light"])
			k.box(Vector3(0, 0, -0.5), Vector3(1.5, 0.5, 0.5), SanctuaryKit.tint(0.94))
			k.rune_panel(Vector3(0, 0.1, -0.24), 1.1, 0.3)
		"obelisk":
			k.plinth(1.4, 1.4, 2.6, true)
			k.obelisk(Vector3.ZERO, k.rng.randf_range(4.2, 5.6), 0.85)
		"crystals":
			k.box(Vector3(0, -1.6, 0), Vector3(2.6, 2.0, 2.4), SanctuaryKit.tint(0.82), 0.6, k.rng.randf() * TAU)
			k.crystals(Vector3(0, 0.3, 0), k.rng.randf_range(2.2, 3.4), 5, s["light"], s.get("light_b", Color(1.0, 1.0, 1.0)))
		"ghat":
			k.plinth(2.4, 1.2)
			k.stairs(Vector3(0, -2.0, -3.6), 3.6, 5, 0.4, 0.5, PI, false)
			for x: float in [-1.0, 1.0]:
				k.pedestal(Vector3(x * 2.0, 0, 0), 0.7, 1.0)
				k.fire_bowl(Vector3(x * 2.0, 1.0, 0), 0.55)
		"heads":
			k.fallen_head(Vector3(0, 0.1, 0), 0.85, k.rng.randf_range(-0.8, 0.8))
			k.rubble(Vector3(0.6, 0.2, 0.6), 1.6, 7)
			k.column(s["order"], Vector3(-1.3, 0, -0.5), 1.4, 0.26, true)
		"stupa":
			k.plinth(1.7, 1.7, 2.6, true)
			k.stupa(Vector3.ZERO, 1.05)
			k.bowl(Vector3(0, 0, 1.5), 0.7)
		"cairn":
			_cairn(k, Vector3(0, 0.2, 0), 1.2)
			_cairn(k, Vector3(1.0, 0.1, 0.6), 0.6)
		"gate":
			k.plinth(2.2, 0.8)
			_timber_gate(k, Vector3.ZERO, 2.8, 3.4, s["timber"])
			k.lantern(Vector3(1.9, 0, 0.5), 0.8, s["light"])
		_:
			# "props": a few small things, a different handful each time.
			match k.rng.randi() % 5:
				0:
					k.urn(Vector3(0, 0.0, 0), 1.1, cer, 0)
					k.urn(Vector3(0.6, 0.0, 0.3), 0.8, SanctuaryKit.TERRACOTTA, 1)
					k.urn(Vector3(-0.3, 0.2, 0.6), 0.9, cer, 2, Basis(Vector3.RIGHT, 1.4))
				1:
					k.column(s["order"], Vector3(0, 0.1, 0), k.rng.randf_range(0.8, 1.5), 0.3, true)
					k.rubble(Vector3(0.3, 0.1, 0.3), 0.9, 6)
				2:
					k.lantern(Vector3(0, 0.1, 0), 0.95, s["light"])
				3:
					k.pedestal(Vector3(0, 0.1, 0), 0.7, 0.9)
					k.bowl(Vector3(0, 1.0, 0), 0.9)
				_:
					k.box(Vector3(0, -0.2, 0), Vector3(1.6, 0.6, 0.6), SanctuaryKit.tint(0.94))
					k.rune_panel(Vector3(0, 0.0, 0.31), 1.2, 0.3)
					k.rubble(Vector3(0, 0, 0.6), 0.8, 4)


# --- Ruins in the lake -------------------------------------------------------------

## Local y = 0 is 0.9 m under the water, so everything here stands half drowned.
static func _sunken(k: SanctuaryKit, s: Dictionary, kind: String) -> void:
	var lean := Basis(Vector3(1, 0, 0.4).normalized(), k.rng.randf_range(0.04, 0.14))
	match kind:
		"sunken_arch":
			var sweep := 1.0 if k.rng.randf() < 0.5 else 0.64
			var arch_fn := func() -> void: k.arch(Vector3.ZERO, 3.0, 3.6, 0.7, 1.2, 0.0, sweep)
			k.at(Vector3(0, -0.6, 0), 0.0, arch_fn, 1.0, lean)
		"sunken_columns":
			for i in 4:
				var broken := k.rng.randf() < 0.6
				var tilt := Basis(Vector3(k.rng.randf_range(-1, 1), 0, k.rng.randf_range(-1, 1)).normalized(), k.rng.randf_range(0.0, 0.16))
				k.column(s["order"], Vector3((float(i) - 1.5) * 1.6, -0.5, k.rng.randf_range(-0.4, 0.4)), k.rng.randf_range(2.2, 3.4) if broken else 5.2, 0.34, broken, tilt, i % 3)
			k.box(Vector3(0, -2.0, 0), Vector3(6.6, 1.9, 2.0), SanctuaryKit.tint(0.86))
		"sunken_head":
			k.fallen_head(Vector3(0, -0.3, 0), 1.9, k.rng.randf() * TAU)
		"sunken_shrine":
			var shrine_fn := func() -> void: _shrine(k, s)
			k.at(Vector3(0, -0.9, 0), 0.0, shrine_fn, 1.15, lean)
		"pier":
			for i in 3:
				k.arch(Vector3((float(i) - 1.0) * 3.5, -0.6, 0), 2.4, 2.4, 0.6, 1.8, 0.0, 1.0 if i < 2 else 0.58)
			k.box(Vector3(-1.75, 3.84, 0), Vector3(7.4, 0.3, 2.2), SanctuaryKit.tint(0.92))
			k.urn(Vector3(-3.0, 4.14, 0.3), 1.1, s["ceramic"], 0)
		"sunken_obelisk":
			var ob_fn := func() -> void: k.obelisk(Vector3.ZERO, 5.6, 0.95)
			k.at(Vector3(0, -0.4, 0), 0.0, ob_fn, 1.0, Basis(Vector3(1, 0, 0.3).normalized(), k.rng.randf_range(0.1, 0.32)))
		"sunken_crystals":
			k.box(Vector3(0, -1.6, 0), Vector3(3.2, 2.2, 3.0), SanctuaryKit.tint(0.8), 0.55)
			k.crystals(Vector3(0, 0.5, 0), k.rng.randf_range(3.2, 4.6), 6, s["light"], s.get("light_b", Color(1.0, 1.0, 1.0)))
		"sunken_gate":
			_timber_gate(k, Vector3(0, 0.3, 0), 4.6, 5.6, s["timber"])


# --- Far shore ---------------------------------------------------------------------

static func _far(k: SanctuaryKit, s: Dictionary, kind: String) -> void:
	k.plinth(4.0, 4.0, 4.0)
	match kind:
		"tower":
			k.tower(Vector3.ZERO, 2.6, 5, 2.3, 0.8, false)
		"stupa":
			k.stupa(Vector3.ZERO, 3.4)
		"pagoda":
			_pagoda_tiers(k, s, Vector3.ZERO, 2.8, 4)
		"rotunda":
			k.colonnade("classic", Vector3.ZERO, 5, 2.0, 6.0, 0.42, 0.3)
		"ziggurat":
			for i in 4:
				k.box(Vector3(0, 1.5 * float(i), 0), Vector3(8.0 - 1.8 * float(i), 1.5, 8.0 - 1.8 * float(i)), SanctuaryKit.tint(0.95), 0.95)
		"obelisk":
			k.obelisk(Vector3.ZERO, 9.0, 1.4)
			k.trilithon(Vector3(3.6, 0, 0.6), 2.4, 4.0, 0.5)
		"dome":
			for i in 6:
				var a := TAU * float(i) / 6.0
				k.column("classic", Vector3(cos(a) * 2.8, 0, sin(a) * 2.8), 4.4, 0.34)
			k.box(Vector3(0, 4.4, 0), Vector3(6.6, 0.6, 6.6), SanctuaryKit.tint(0.96))
			k.dome(Vector3(0, 5.0, 0), 3.0, s["ceramic"], true)
		"gate":
			_timber_gate(k, Vector3.ZERO, 5.0, 6.0, s["timber"])
		_:
			k.crystals(Vector3(0, 0.2, 0), 8.0, 6, s["light"], s.get("light_b", s["light"]))
