extends TestCase
## End-to-end flow through the real main scene (state machine + camera), driven
## frame by frame without rendering. Uses a throwaway profile file.

const DT := 1.0 / 60.0


func _step(main: Node, seconds: float) -> void:
	for i in int(seconds / DT):
		main._process(DT)
		main.camera._process(DT)


## True when the camera sits behind the head and looks the way the snake travels.
func _camera_behind_snake(main: Node) -> bool:
	var sim: SnakeSim = main.session.snake
	var cam: Camera3D = main.camera
	var fwd := MathUtil.heading_dir(sim.heading)
	var to_head := sim.position - cam.global_position
	to_head.y = 0.0
	var look := -cam.global_transform.basis.z
	look.y = 0.0
	return fwd.dot(to_head.normalized()) > 0.9 and fwd.dot(look.normalized()) > 0.9


func test_run_from_main_menu_gets_chase_camera() -> void:
	var main := make_main()
	check_eq(main.state, main.State.MENU, "boots into the menu")
	check_eq(main.camera.mode, ChaseCamera.Mode.MENU, "menu camera while browsing")
	main._begin_run()
	check_eq(main.state, main.State.INTRO, "run starts with the intro")
	check_eq(main.camera.mode, ChaseCamera.Mode.INTRO, "intro camera (not reset by the menu closing)")
	_step(main, GameConfig.INTRO_DURATION + 1.0)
	check_eq(main.state, main.State.PLAYING, "playing after the intro")
	check_eq(main.camera.mode, ChaseCamera.Mode.CHASE, "chase camera during play")
	check(_camera_behind_snake(main), "camera is behind the snake, looking ahead")
	dispose_main(main)


func test_restart_after_game_over_gets_chase_camera() -> void:
	var main := make_main()
	main._begin_run()
	# No steering: the snake runs straight into the barrier.
	_step(main, 14.0)
	check_eq(main.state, main.State.GAME_OVER, "an unsteered snake eventually crashes")
	main._begin_run()
	check_eq(main.camera.mode, ChaseCamera.Mode.INTRO, "intro camera on restart")
	_step(main, GameConfig.INTRO_DURATION + 1.0)
	check_eq(main.camera.mode, ChaseCamera.Mode.CHASE, "chase camera on restart")
	check(_camera_behind_snake(main), "camera behind the snake on restart")
	dispose_main(main)


func test_menu_screens_drive_camera_only_in_menu() -> void:
	var main := make_main()
	main.ui.push(main.ui.skins)
	check_eq(main.camera.mode, ChaseCamera.Mode.SHOWCASE, "skins screen shows the head close-up")
	main.ui.back()
	check_eq(main.camera.mode, ChaseCamera.Mode.MENU, "back to the menu orbit")
	dispose_main(main)


## A display cut-out on the left (as on phones held with the camera hole on that
## side) must not shift the touch zones away from the drawn buttons, and
## full-screen layers must still cover the whole screen.
func test_safe_area_insets_keep_hud_and_touch_aligned() -> void:
	var main := make_main()
	var ui: UiRoot = main.ui
	var hud: Hud = ui.hud
	ui.set_safe_insets(Vector4(61, 0, 0, 0))
	main._begin_run()
	await tree.create_timer(0.5).timeout # let the main menu finish closing
	var vp: Rect2 = main.get_viewport().get_visible_rect()
	check(hud.get_global_rect().is_equal_approx(vp), "HUD spans the whole screen")
	var xf := hud.get_global_transform_with_canvas()
	check(main.touch.boost_zone.get_center().is_equal_approx(xf * hud.boost_center()), "boost touch zone centred on the drawn button")
	check(main.touch.pause_zone.get_center().is_equal_approx(xf * hud.pause_center()), "pause touch zone centred on the drawn button")
	check(hud.safe_rect().position.x >= 61.0, "HUD safe rect excludes the cut-out")
	check(hud._score_label.get_global_rect().position.x >= 61.0, "score label clear of the cut-out")
	hud.configure(true, 0) # left-handed: boost moves next to the cut-out
	check((xf * hud.boost_center()).x - Hud.BOOST_RADIUS >= 61.0, "left-handed boost button clear of the cut-out")
	check(main.touch.boost_zone.get_center().is_equal_approx(xf * hud.boost_center()), "left-handed boost zone aligned")
	check(tree.get_nodes_in_group(UiRoot.FULL_BLEED_GROUP).size() >= 6, "menu backdrops are full-bleed layers")
	main.pause_game()
	await tree.create_timer(0.5).timeout # pause menu open animation
	var shown := 0
	for n in tree.get_nodes_in_group(UiRoot.FULL_BLEED_GROUP):
		var c := n as Control
		if c.is_visible_in_tree():
			shown += 1
			check(c.get_global_rect().is_equal_approx(vp), "visible backdrop covers the whole screen, cut-out included")
	check_eq(shown, 1, "only the pause menu backdrop is showing")
	main.resume()
	ui.set_safe_insets(Vector4.ZERO)
	dispose_main(main)


## Choosing another sanctuary moves the game to that sanctuary's island: the
## terrain, the 3D island and the menu's background run all change together.
func test_switching_sanctuary_rebuilds_the_island() -> void:
	var main := make_main()
	var dawn := WorldThemes.terrain_seed("dawn")
	check_eq(main.terrain.seed_value, dawn, "starts on the Golden Dawn island")
	var old_island: Node = main.world._terrain_root
	main.ui.push(main.ui.skins)
	main._switch_island(WorldThemes.terrain_seed("moon"), WorldThemes.get_theme("moon"))
	check_eq(main.terrain.seed_value, WorldThemes.terrain_seed("moon"), "terrain regenerated in place")
	check(main.session.terrain == main.terrain and main.camera.terrain == main.terrain, "everyone still shares the one terrain")
	check(not is_instance_valid(old_island), "the old island's nodes are gone")
	check(main.world._terrain_root != null and main.world._terrain_root.get_child_count() > 5, "a new island was built")
	var walls := 0
	for ob in main.session.obstacles:
		if ob.kind == Obstacle.KIND_CLIFF:
			walls += 1
			check(main.terrain.cliff_obstacles().has(ob), "the run's walls are the new island's walls")
	check_eq(walls, main.terrain.terraces.size(), "one wall per terrace of the new island")
	check_eq(main.state, main.State.MENU, "still in the menu")
	check_eq(main.camera.mode, ChaseCamera.Mode.SHOWCASE, "the skins close-up is kept")
	dispose_main(main)


## A sanctuary can give the trees its own leaf colours (Silver Frost, Amber Autumn, Violet
## Aurora); the others keep the green built into the tree meshes.
func test_sanctuaries_colour_the_leaves() -> void:
	var main := make_main()
	var mat: ShaderMaterial = main.world._foliage_mat
	var coloured := 0
	for t in WorldThemes.THEMES:
		check_eq(t.has("leaf_a"), t.has("leaf_b"), "%s: both leaf colours or none" % t["id"])
		main.world.apply_theme(t)
		check_eq(float(mat.get_shader_parameter("leaf_mix")), 1.0 if t.has("leaf_a") else 0.0, "%s: leaf colours switched %s" % [t["id"], "on" if t.has("leaf_a") else "off"])
		if t.has("leaf_a"):
			coloured += 1
			check_eq(mat.get_shader_parameter("leaf_col"), t["leaf_a"], "%s: first leaf colour reaches the shader" % t["id"])
			check_eq(mat.get_shader_parameter("leaf_col_b"), t["leaf_b"], "%s: second leaf colour reaches the shader" % t["id"])
	check(coloured >= 3, "frost, autumn and aurora colour their leaves")
	check(not WorldThemes.get_theme("dawn").has("leaf_a"), "Golden Dawn keeps the green trees")
	main.world.apply_theme(WorldThemes.get_theme(Profile.selected_theme))
	dispose_main(main)
