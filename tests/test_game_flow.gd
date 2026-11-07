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
