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
