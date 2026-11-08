extends SceneTree
## Top-down map of the arena for checking the relief: height shading, ground
## too steep to climb (red), wall collision circles (white), ramps (blue) and
## the run's ruins (dark).
##   tools/godot/godot --headless --path . -s tools/terrain_map.gd -- --seed=N --out=map.png [--layout=S]

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := str(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var seed_value := int(args.get("seed", "20241107"))
	var out := str(args.get("out", "terrain_map.png"))
	var t0 := Time.get_ticks_msec()
	var terrain := TerrainField.new(seed_value)
	var walls := terrain.cliff_obstacles()
	var t1 := Time.get_ticks_msec()
	var layout := WorldGenerator.generate(int(args.get("layout", "1")), terrain)
	var t2 := Time.get_ticks_msec()
	var px := int(args.get("px", "4")) # pixels per metre
	var r := GameConfig.ARENA_RADIUS + 2.0
	var size := int(2.0 * r * px)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var max_slope := 0.0
	for iy in size:
		for ix in size:
			var x := -r + (float(ix) + 0.5) / px
			var z := -r + (float(iy) + 0.5) / px
			var h := terrain.height(x, z)
			var s := terrain.slope(x, z)
			var nrm := terrain.normal(x, z)
			var shade := clampf(0.55 + nrm.dot(Vector3(-0.5, 0.7, -0.5).normalized()) * 0.45, 0.0, 1.0)
			var col := Color(0.25, 0.45, 0.2).lerp(Color(0.85, 0.8, 0.6), clampf(h / 2.8, 0.0, 1.0)) * shade
			if Vector2(x, z).length() > GameConfig.ARENA_RADIUS:
				col = col.darkened(0.5)
			elif s > TerrainField.CLIMB_LIMIT:
				col = Color(0.9, 0.15, 0.1)
			else:
				max_slope = maxf(max_slope, s)
			var pv := terrain.paved(x, z)
			if pv > 0.05:
				col = col.lerp(Color(0.3, 0.5, 1.0), pv * 0.6)
			img.set_pixel(ix, iy, col)
	for ob in layout:
		for c in ob.circles:
			var cx := (c.x + r) * px
			var cy := (c.y + r) * px
			var rad := c.z * px
			for k in 24:
				var a := TAU * k / 24.0
				var qx := int(cx + cos(a) * rad)
				var qy := int(cy + sin(a) * rad)
				if qx >= 0 and qy >= 0 and qx < size and qy < size:
					img.set_pixel(qx, qy, Color.WHITE if ob.kind == Obstacle.KIND_CLIFF else Color(0.1, 0.1, 0.1))
	img.save_png(out)
	var n := 0
	for w in walls:
		n += w.circles.size()
	print("terraces=%d hills=%d wall_circles=%d (%d ms) layout=%d obstacles (%d ms) max_climbable_slope=%.2f reachable=%.4f" % [
		terrain.terraces.size(), terrain.hills.size(), n, t1 - t0, layout.size(), t2 - t1, max_slope,
		WorldGenerator.reachable_fraction(layout, 0.6)])
	quit(0)
