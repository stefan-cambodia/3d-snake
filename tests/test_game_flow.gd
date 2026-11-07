extends TestCase
## End-to-end flow through the real main scene (state machine + camera), driven
## frame by frame without rendering. Uses a throwaway profile file.

const DT := 1.0 / 60.0


func _make_main() -> Node:
	Profile.save_path = "user://test_flow_profile_%d.cfg" % randi()
	Profile.reset_to_defaults(false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	return main


func _dispose(main: Node) -> void:
	tree.root.remove_child(main)
	main.free()
	Engine.time_scale = 1.0
	for path in [Profile.save_path, Profile.save_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.save_path = Profile.SAVE_PATH
	Profile.load_profile()


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
	var main := _make_main()
	check_eq(main.state, main.State.MENU, "boots into the menu")
	check_eq(main.camera.mode, ChaseCamera.Mode.MENU, "menu camera while browsing")
	main._begin_run()
	check_eq(main.state, main.State.INTRO, "run starts with the intro")
	check_eq(main.camera.mode, ChaseCamera.Mode.INTRO, "intro camera (not reset by the menu closing)")
	_step(main, GameConfig.INTRO_DURATION + 1.0)
	check_eq(main.state, main.State.PLAYING, "playing after the intro")
	check_eq(main.camera.mode, ChaseCamera.Mode.CHASE, "chase camera during play")
	check(_camera_behind_snake(main), "camera is behind the snake, looking ahead")
	_dispose(main)


func test_restart_after_game_over_gets_chase_camera() -> void:
	var main := _make_main()
	main._begin_run()
	# No steering: the snake runs straight into the barrier.
	_step(main, 14.0)
	check_eq(main.state, main.State.GAME_OVER, "an unsteered snake eventually crashes")
	main._begin_run()
	check_eq(main.camera.mode, ChaseCamera.Mode.INTRO, "intro camera on restart")
	_step(main, GameConfig.INTRO_DURATION + 1.0)
	check_eq(main.camera.mode, ChaseCamera.Mode.CHASE, "chase camera on restart")
	check(_camera_behind_snake(main), "camera behind the snake on restart")
	_dispose(main)


func test_menu_screens_drive_camera_only_in_menu() -> void:
	var main := _make_main()
	main.ui.push(main.ui.skins)
	check_eq(main.camera.mode, ChaseCamera.Mode.SHOWCASE, "skins screen shows the head close-up")
	main.ui.back()
	check_eq(main.camera.mode, ChaseCamera.Mode.MENU, "back to the menu orbit")
	_dispose(main)
