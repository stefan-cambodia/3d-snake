extends TestCase
## The sanctuaries' architecture: every sanctuary has its own style, the layout
## is reproducible and collision-free, and none of it can be touched by the
## serpent (it all stands outside the playfield).


func _horizontal_extent(mesh: ArrayMesh) -> Vector2:
	var lo := INF
	var hi := 0.0
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var r := Vector2(v.x, v.z).length()
			lo = minf(lo, r)
			hi = maxf(hi, r)
	return Vector2(lo, hi)


func test_every_sanctuary_has_its_own_style() -> void:
	var monuments := {}
	var seconds := {}
	var titles := {}
	for t in WorldThemes.THEMES:
		var id: String = t["id"]
		check(SanctuaryStyles.STYLES.has(id), "%s has a style" % id)
		var s := SanctuaryStyles.get_style(id)
		for key in ["order", "monument", "secondary", "shore", "islets", "lake", "far", "roof", "stone_a", "stone_b", "moss", "paving", "wall_a", "wall_b", "ceramic", "timber", "light", "trees", "flowers", "ferns", "special", "weather", "shafts"]:
			check(s.has(key), "%s style defines %s" % [id, key])
		check(SanctuaryKit.ORDERS.has(s["order"]), "%s uses a known column order" % id)
		check_eq((s["trees"] as Array).size(), 4, "%s names four kinds of tree" % id)
		check_eq(str(s["trees"][3]), "bush", "%s keeps the low shrub for the shore" % id)
		monuments[s["monument"]] = true
		seconds[s["secondary"]] = true
		titles[s["title"]] = true
		for kind in (s["shore"] as Dictionary).keys() + (s["islets"] as Array) + (s["lake"] as Array):
			check(SanctuaryBuilder.RADII.has(kind), "%s: '%s' has a footprint" % [id, kind])
	check_eq(monuments.size(), WorldThemes.THEMES.size(), "every sanctuary has a different great monument")
	check_eq(seconds.size(), WorldThemes.THEMES.size(), "every sanctuary has a different second landmark")
	check_eq(titles.size(), WorldThemes.THEMES.size(), "every sanctuary has its own identity")


func test_layout_is_reproducible_and_collision_free() -> void:
	for t in WorldThemes.THEMES:
		var id: String = t["id"]
		var terrain := TerrainField.new(int(t["terrain_seed"]))
		var style := SanctuaryStyles.get_style(id)
		var a := SanctuaryBuilder.plan(terrain, style)
		var b := SanctuaryBuilder.plan(terrain, style)
		check_eq(str(a), str(b), "%s: same island, same layout" % id)
		check(a.size() >= 30, "%s: at least 30 pieces placed (%d)" % [id, a.size()])
		var zones := {}
		for i in a.size():
			var pi: Vector2 = a[i]["pos"]
			var ri := float(a[i]["radius"])
			zones[a[i]["zone"]] = int(zones.get(a[i]["zone"], 0)) + 1
			check(pi.length() - ri >= SanctuaryBuilder.KEEP_OUT - 0.01, "%s: %s stays out of the playfield (%.1f m from the centre)" % [id, a[i]["kind"], pi.length() - ri])
			if a[i]["zone"] == "lake":
				check(terrain.height(pi.x, pi.y) < GameConfig.WATER_LEVEL, "%s: lake ruin %s stands in water" % [id, a[i]["kind"]])
			for j in range(i + 1, a.size()):
				var d := pi.distance_to(a[j]["pos"])
				check(d >= ri + float(a[j]["radius"]), "%s: %s and %s do not overlap (%.1f m apart)" % [id, a[i]["kind"], a[j]["kind"], d])
		for zone in ["focal", "second", "islet", "shore", "lake", "far"]:
			check(int(zones.get(zone, 0)) > 0, "%s: something stands in the '%s' zone" % [id, zone])
		check(int(zones.get("shore", 0)) >= 20, "%s: the shore is furnished (%d pieces)" % [id, int(zones.get("shore", 0))])


func test_architecture_is_built_outside_the_playfield_within_budget() -> void:
	var counts := {}
	for t in WorldThemes.THEMES:
		var id: String = t["id"]
		var terrain := TerrainField.new(int(t["terrain_seed"]))
		var result := SanctuaryBuilder.build(terrain, SanctuaryStyles.get_style(id))
		var tris: int = result["triangles"]
		counts[id] = tris
		check(tris > 12000, "%s: the architecture is rich (%d triangles)" % [id, tris])
		check(tris < 150000, "%s: and stays inside the phone's budget (%d triangles)" % [id, tris])
		var names := {}
		var nearest := INF
		for g: Dictionary in result["groups"]:
			names[g["name"]] = true
			for key in ["stone", "accent", "glow"]:
				if g[key] != null:
					nearest = minf(nearest, _horizontal_extent(g[key]).x)
		# The barrier is at ARENA_RADIUS and the snake's body is 0.5 m wide at most.
		check(nearest >= GameConfig.ARENA_RADIUS + 0.9, "%s: no stone nearer than the lantern ring (%.2f m)" % [id, nearest])
		check(names.has("focal") and names.has("second") and names.has("lake") and names.has("far"), "%s: monument, landmark, lake and far shore are all built" % id)
	print("[sanctuary] architecture triangles: %s" % str(counts))


func test_every_column_order_fits_the_pillar_collision() -> void:
	# A pillar's collision circle is 0.78 m; the classic column's plinth corners
	# reach 0.81 m, which has always been the look. No order may be wider.
	for order in SanctuaryKit.ORDERS:
		for broken in [false, true]:
			var m := SanctuaryKit.column_mesh(order, 2.5 if broken else 5.5, 0.55, broken, 10)
			check(m.get_surface_count() == 1, "%s column builds" % order)
			var ext := _horizontal_extent(m)
			check(ext.y <= 0.815, "%s column (broken %s) is no wider than the classic one (%.3f m)" % [order, broken, ext.y])
			var aabb := m.get_aabb()
			check(aabb.end.y <= (2.5 if broken else 5.5) + 0.2, "%s column keeps its height (%.2f m)" % [order, aabb.end.y])


## The playfield's own stones change shape with the sanctuary but never outgrow
## their collision: a monolith is two 0.5 m circles at +-0.38 m, a brazier one of 0.62 m.
func test_monolith_and_brazier_shapes_fit_their_collision() -> void:
	for shape in 4:
		var m := WorldMeshes.monolith(3.2, 40, shape)
		var worst := 0.0
		for v: Vector3 in m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := Vector2(v.x, v.z)
			worst = maxf(worst, minf(p.distance_to(Vector2(-0.38, 0)), p.distance_to(Vector2(0.38, 0))))
			check(v.y <= 3.2 + 0.25, "monolith shape %d keeps its height (%.2f)" % [shape, v.y])
		# The plain slab's corners have always stuck out to 0.58 m.
		check(worst <= 0.6, "monolith shape %d stays inside the slab's footprint (%.3f m from a circle centre)" % [shape, worst])
	for shape in 3:
		var b := WorldMeshes.brazier(shape)
		var ext := _horizontal_extent(b)
		check(ext.y <= 0.73, "brazier shape %d is no wider than the bowl (%.3f m)" % [shape, ext.y])
		check(absf(b.get_aabb().end.y - 1.5) < 0.02, "brazier shape %d keeps the fire at the same height" % shape)
	for t in WorldThemes.THEMES:
		var s := SanctuaryStyles.get_style(t["id"])
		check(int(s["monolith"]) >= 0 and int(s["monolith"]) < 4 and int(s["brazier"]) >= 0 and int(s["brazier"]) < 3, "%s names real shapes" % t["id"])


func test_the_island_wears_its_sanctuarys_style() -> void:
	var main := make_main()
	var world: WorldView = main.world
	check_eq(world.style["monument"], "prasat", "Golden Dawn starts with its temple-mountain")
	check(world.architecture_plan.size() >= 30, "the architecture is laid out (%d pieces)" % world.architecture_plan.size())
	var arch := world._terrain_root.get_node_or_null("Architecture")
	check(arch != null and arch.get_child_count() >= 8, "and built as a handful of merged meshes")
	var dawn_pillar: ArrayMesh = world._mesh_cache["%s:0" % Obstacle.KIND_PILLAR]
	main._switch_island(WorldThemes.terrain_seed("frost"), WorldThemes.get_theme("frost"))
	check_eq(world.style["monument"], "henge", "Silver Frost gets its henge")
	check(world._mesh_cache["%s:0" % Obstacle.KIND_PILLAR] != dawn_pillar, "and its own order of pillars")
	check(world._terrain_root.get_node_or_null("Ice") != null, "and ice on the ground")
	check(world._terrain_root.get_node_or_null("Flowers0") == null, "but no flowers")
	check_eq(world._weather_kind, "snow", "and snow in the air")
	check_eq(world._stone_mat.get_shader_parameter("tint_a"), SanctuaryStyles.get_style("frost")["stone_a"], "and its own stone")
	# Trees keep clear of the buildings.
	for k in 4:
		var trees := world._terrain_root.get_node_or_null("Trees%d" % k) as MultiMeshInstance3D
		if trees == null:
			continue
		for i in trees.multimesh.instance_count:
			var o := trees.multimesh.get_instance_transform(i).origin
			check(not world.in_architecture(Vector2(o.x, o.z)), "no tree grows through a building")
	main._switch_island(WorldThemes.terrain_seed("aurora"), WorldThemes.get_theme("aurora"))
	check_eq(float(world._sky_mat.get_shader_parameter("aurora")), 1.0, "Violet Aurora lights the northern lights")
	check(world._terrain_root.get_node_or_null("Mushrooms") != null, "and grows glowing mushrooms")
	check(world._terrain_root.get_node_or_null("SunShafts") == null, "night sanctuaries have no sun shafts")
	dispose_main(main)
