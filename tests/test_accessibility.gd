extends TestCase
## Accessibility options: "Reduced motion" and off-screen markers that do not
## rely on colour alone.

const DT := 1.0 / 60.0


func _step(main: Node, seconds: float) -> void:
	for i in int(seconds / DT):
		main._process(DT)
		main.camera._process(DT)


## With "Reduced motion" the camera keeps a level horizon and a fixed field of
## view and does not shake, and the HUD draws no speed lines. The same run with
## the option off must show every one of those effects, so the checks cannot
## pass just because nothing happened.
func test_reduced_motion_removes_camera_and_hud_effects() -> void:
	for reduced: bool in [false, true]:
		var main := make_main()
		var profile := tree.root.get_node("Profile")
		var tag := "reduced" if reduced else "normal"
		profile.set_setting("reduced_motion", reduced)
		check_eq(main.camera.reduced_motion, reduced, "%s: setting reaches the camera" % tag)
		check_eq(main.ui.hud.reduced_motion, reduced, "%s: setting reaches the HUD" % tag)
		main._begin_run()
		_step(main, GameConfig.INTRO_DURATION + 0.5)
		check_eq(main.state, main.State.PLAYING, "%s: playing after the intro" % tag)

		main.camera.add_trauma(0.8)
		var shook: bool = main.camera._trauma > 0.0
		# Surge (faster, wider FOV, speed lines) while turning (banking).
		main.touch.steer = 0.6
		var max_fov := 0.0
		var max_roll := 0.0
		for i in 60:
			main.session.snake.surge_time = GameConfig.SURGE_DURATION
			main._process(DT)
			main.camera._process(DT)
			max_fov = maxf(max_fov, main.camera.fov)
			max_roll = maxf(max_roll, absf(main.camera._roll))
		check_eq(main.state, main.State.PLAYING, "%s: still alive after a second of Surge" % tag)
		var lines: float = main.ui.hud._speed_lines
		if reduced:
			check(not shook, "reduced: shake is ignored")
			check(max_fov <= ChaseCamera.BASE_FOV + 0.01, "reduced: field of view stays fixed during Surge (max %.2f)" % max_fov)
			check_eq(max_roll, 0.0, "reduced: no banking in turns")
			check(lines < 0.01, "reduced: no speed lines")
		else:
			check(shook, "normal: impacts shake the camera")
			check(max_fov > ChaseCamera.BASE_FOV + 2.0, "normal: Surge widens the field of view (max %.2f)" % max_fov)
			check(max_roll > 0.005, "normal: the camera banks into turns")
			check(lines > 0.3, "normal: speed lines during Surge")
		dispose_main(main)


func test_reduced_motion_is_off_by_default_and_saved() -> void:
	var profile := tree.root.get_node("Profile")
	check_eq(profile.DEFAULT_SETTINGS["reduced_motion"], false, "off by default")
	var path := "user://test_access_profile_%d.cfg" % randi()
	profile.save_path = path
	profile.reset_to_defaults(false)
	profile.set_setting("reduced_motion", true)
	profile.save_profile()
	profile.reset_to_defaults(false)
	profile.load_profile()
	check_eq(profile.get_setting("reduced_motion"), true, "survives a save and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.save_path = profile.SAVE_PATH
	profile.load_profile()


## Surge crystals and relics are cyan and violet, which some colour-blind
## players cannot tell apart, so their off-screen markers also differ in shape
## (the item's own silhouette: a diamond and a ring).
func test_offscreen_markers_differ_in_shape() -> void:
	var p := Vector2(100, 200)
	var diamond := Hud.marker_symbol(Collectible.Kind.ENERGY, p)
	var ring := Hud.marker_symbol(Collectible.Kind.RARE, p)
	check_eq(diamond.size(), 4, "crystal marker is a diamond")
	check(diamond[0].distance_to(p) > diamond[1].distance_to(p) + 3.0, "diamond is taller than wide, like the crystal")
	check(ring.size() > 12, "relic marker is a round ring")
	check(ring[0].is_equal_approx(ring[ring.size() - 1]), "ring outline is closed")
	for q in ring:
		check_near(q.distance_to(p), 9.5, 0.01, "ring points sit on one circle")


## The HUD records each marker's item kind so it can draw the right symbol.
func test_markers_carry_the_item_kind() -> void:
	var main := make_main()
	main._begin_run()
	_step(main, GameConfig.INTRO_DURATION + 0.2)
	var s: GameSession = main.session
	# Put a relic and a crystal straight behind the camera, so both are off-screen.
	var back := -MathUtil.heading_dir(s.snake.heading)
	var kinds := [Collectible.Kind.ENERGY, Collectible.Kind.RARE]
	for i in kinds.size():
		var it := Collectible.new()
		it.id = 9000 + i
		it.kind = kinds[i]
		it.lifetime = 30.0
		it.pos = s.snake.position + back * 12.0 + MathUtil.heading_right(s.snake.heading) * (float(i) * 4.0 - 2.0)
		s.items.append(it)
	main.ui.hud.update_hud(DT, s)
	var seen := []
	for m in main.ui.hud._markers:
		seen.append(int(m["kind"]))
	check(seen.has(Collectible.Kind.ENERGY), "crystal behind the camera gets a marker")
	check(seen.has(Collectible.Kind.RARE), "relic behind the camera gets a marker")
	dispose_main(main)


## Markers never sit on the boost or pause button: one that would is slid along
## the screen edge, right- or left-handed.
func test_markers_keep_clear_of_hud_buttons() -> void:
	var main := make_main()
	var hud: Hud = main.ui.hud
	for left_handed in [false, true]:
		hud.configure(left_handed, 0)
		var area := hud.safe_rect().grow(-56.0)
		var y := area.position.y
		while y <= area.end.y:
			for x in [area.position.x, area.end.x]:
				var p := hud.avoid_buttons(Vector2(x, y), area)
				check(p.distance_to(hud.boost_center()) >= Hud.MARKER_BOOST_CLEARANCE - 0.01, "side marker clear of boost (%s, y=%.0f)" % [left_handed, y])
				check(p.distance_to(hud.pause_center()) >= Hud.MARKER_PAUSE_CLEARANCE - 0.01, "side marker clear of pause (y=%.0f)" % y)
				check(area.grow(0.5).has_point(p), "side marker stays on the edge (y=%.0f)" % y)
			y += 7.0
		var x2 := area.position.x
		while x2 <= area.end.x:
			for yy in [area.position.y, area.end.y]:
				var q := hud.avoid_buttons(Vector2(x2, yy), area)
				check(q.distance_to(hud.boost_center()) >= Hud.MARKER_BOOST_CLEARANCE - 0.01, "edge marker clear of boost (x=%.0f)" % x2)
				check(q.distance_to(hud.pause_center()) >= Hud.MARKER_PAUSE_CLEARANCE - 0.01, "edge marker clear of pause (x=%.0f)" % x2)
				check(area.grow(0.5).has_point(q), "edge marker stays on the edge (x=%.0f)" % x2)
			x2 += 9.0
	hud.configure(false, 0)
	dispose_main(main)


## "Larger HUD text" scales every HUD text, keeps them apart and on screen, and
## switching it off restores the normal sizes.
func test_larger_hud_text_scales_and_stays_tidy() -> void:
	var main := make_main()
	var profile := tree.root.get_node("Profile")
	var hud: Hud = main.ui.hud
	check_eq(profile.DEFAULT_SETTINGS["hud_large"], false, "off by default")
	var normal := []
	for e in hud._scaled_labels:
		normal.append((e[0] as Label).get_theme_font_size("font_size"))
	profile.set_setting("hud_large", true)
	check(hud.large_text, "setting reaches the HUD")
	main._begin_run()
	_step(main, GameConfig.INTRO_DURATION + 0.3)
	hud.reset_for_run(123456)
	hud._score_label.text = "123456"
	hud._combo_label.text = "x2.75"
	hud._layout()
	for i in hud._scaled_labels.size():
		var l: Label = hud._scaled_labels[i][0]
		var now := l.get_theme_font_size("font_size")
		check_eq(now, roundi(normal[i] * Hud.LARGE_TEXT_SCALE), "label %d is %.1f times bigger" % [i, Hud.LARGE_TEXT_SCALE])
		check(l.size.y >= l.get_minimum_size().y - 0.5, "label %d box is tall enough for its text" % i)
	var safe := hud.safe_rect()
	var corner: Array[Label] = [hud._score_label, hud._best_label, hud._stage_label, hud._combo_label, hud._length_label]
	for i in corner.size():
		var a := Rect2(corner[i].position, corner[i].size)
		check(safe.encloses(a), "label %d inside the safe area (%s)" % [i, str(a)])
		for j in range(i + 1, corner.size()):
			if i == 0 and j == 1:
				# "Best" sits under the score's digits, inside the line's empty descent.
				var baseline := a.position.y + UiTheme.font("title").get_ascent(corner[0].get_theme_font_size("font_size"))
				check(corner[1].position.y >= baseline, "best score below the score's digits")
				continue
			check(not a.intersects(Rect2(corner[j].position, corner[j].size)), "labels %d and %d do not overlap" % [i, j])
		for b in [[hud.boost_center(), Hud.BOOST_RADIUS + 24.0], [hud.pause_center(), Hud.PAUSE_RADIUS]]:
			var c: Vector2 = b[0]
			var nearest := Vector2(clampf(c.x, a.position.x, a.end.x), clampf(c.y, a.position.y, a.end.y))
			check(nearest.distance_to(c) > float(b[1]), "label %d clear of the buttons" % i)
	check(hud._stage_label.position.y + hud._stage_label.size.y <= hud._bar_y + 0.5, "stage bar below the stage text")
	hud.popup(main.session.snake.position + Vector3.UP, "+10", UiTheme.GOLD, 30)
	var pops := hud._popups.get_children()
	check(pops.size() > 0, "a popup was shown")
	if pops.size() > 0:
		check_eq((pops[-1] as Label).get_theme_font_size("font_size"), roundi(30 * Hud.LARGE_TEXT_SCALE), "popups are bigger too")
	profile.set_setting("hud_large", false)
	for i in hud._scaled_labels.size():
		check_eq((hud._scaled_labels[i][0] as Label).get_theme_font_size("font_size"), normal[i], "label %d back to normal" % i)
	check_near(hud._bar_y, 50.0, 0.01, "stage bar back in place")
	dispose_main(main)


## The danger vignette's colour can be changed (dark red is hard to see with
## red-blind vision); the choice reaches the HUD and is saved.
func test_danger_colour_setting() -> void:
	var main := make_main()
	var profile := tree.root.get_node("Profile")
	var hud: Hud = main.ui.hud
	check_eq(profile.DEFAULT_SETTINGS["danger_color"], 0, "red by default")
	check(hud._vignette.self_modulate.is_equal_approx(Hud.DANGER_COLORS[0]), "starts red")
	for i in Hud.DANGER_COLORS.size():
		profile.set_setting("danger_color", i)
		check(hud._vignette.self_modulate.is_equal_approx(Hud.DANGER_COLORS[i]), "colour %d reaches the vignette" % i)
	# The alternatives are much brighter than the red, and differ in the blue channel.
	check(Hud.DANGER_COLORS[1].get_luminance() > Hud.DANGER_COLORS[0].get_luminance() * 2.0, "blue is brighter than the red")
	check(Hud.DANGER_COLORS[2].get_luminance() > Hud.DANGER_COLORS[1].get_luminance(), "yellow is the brightest")
	profile.set_setting("danger_color", 99)
	check(hud._vignette.self_modulate.is_equal_approx(Hud.DANGER_COLORS[2]), "an out-of-range value is clamped")
	var path := "user://test_danger_profile_%d.cfg" % randi()
	profile.save_path = path
	profile.set_setting("danger_color", 1)
	profile.set_setting("hud_large", true)
	profile.save_profile()
	profile.reset_to_defaults(false)
	profile.load_profile()
	check_eq(profile.get_setting("danger_color"), 1, "colour survives a save and reload")
	check_eq(profile.get_setting("hud_large"), true, "larger text survives a save and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.save_path = profile.SAVE_PATH
	profile.load_profile()
	dispose_main(main)
