extends Node
## Game flow controller: owns the session, the 3D views and the UI, and runs the
## state machine MENU -> INTRO -> PLAYING <-> PAUSED -> DYING -> GAME_OVER.
##
## Command-line options (after `--`), used for automated validation:
##   --autoplay           the autopilot plays the game
##   --start=play|over    jump straight into a run / the game-over screen
##   --screen=NAME        open a menu screen (settings, skins, records, about, pause)
##   --shot=PATH --shot-at=SECONDS   save a screenshot then continue
##   --quit-after=SECONDS quit automatically (exit code 0)
##   --quality=0..2       override graphics quality
##   --showcase           demo/screenshot mode (export preset "Android Showcase"): an
##                        empty profile is filled with a demo history, quality is set to
##                        high, and the autopilot plays every run started from the menu

enum State { MENU, INTRO, PLAYING, PAUSED, DYING, GAME_OVER }

const WORLD_SEED := 20241107

var state: int = State.MENU
var terrain: TerrainField
var session: GameSession
var world: WorldView
var snake_view: SnakeView
var items_view: CollectibleView
var effects: Effects
var camera: ChaseCamera
var touch: TouchController
var ui: UiRoot
var autopilot := Autopilot.new(99)

var _quality: int = 2
var _state_time: float = 0.0
var _death_timer: float = 0.0
var _was_boosting: bool = false
var _run_result: Dictionary = {}
var _intro_go_shown: bool = false
var _tutorial_stage: int = 0
var _rng := RandomNumberGenerator.new()

# Automation.
var _args: Dictionary = {}
var _shots: Array = []
var _elapsed_real: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_parse_args()
	if _args.has("showcase"):
		_seed_showcase_profile()
	_quality = int(Profile.get_setting("quality"))
	if _quality < 0:
		_quality = 1 if OS.has_feature("mobile") else 2
		Profile.set_setting("quality", _quality)
	if _args.has("quality"):
		_quality = clampi(int(_args["quality"]), 0, 2)

	terrain = TerrainField.new(WORLD_SEED)
	session = GameSession.new(terrain)

	world = WorldView.new()
	world.name = "World"
	add_child(world)
	world.build(terrain, WorldThemes.get_theme(Profile.selected_theme), _quality)

	snake_view = SnakeView.new()
	snake_view.name = "Snake"
	add_child(snake_view)
	snake_view.setup(session.snake, _quality)
	snake_view.apply_skin(SkinCatalog.get_skin(Profile.selected_skin))

	items_view = CollectibleView.new()
	items_view.name = "Collectibles"
	add_child(items_view)
	items_view.setup(terrain, world.soft_texture())

	effects = Effects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.setup(world.soft_texture())

	camera = ChaseCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.sim = session.snake
	camera.terrain = terrain
	camera.current = true

	for n in [world, snake_view, items_view, effects, camera]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE

	touch = TouchController.new()
	touch.name = "Touch"
	add_child(touch)
	touch.pause_requested.connect(_on_pause_requested)

	ui = UiRoot.new()
	ui.name = "UI"
	add_child(ui)
	ui.hud.touch = touch
	ui.hud.camera = camera
	ui.play_requested.connect(start_run)
	ui.resume_requested.connect(resume)
	ui.restart_requested.connect(start_run)
	ui.quit_to_menu_requested.connect(go_to_menu)
	ui.quit_game_requested.connect(quit_game)
	ui.skin_previewed.connect(func(id: String) -> void: snake_view.apply_skin(SkinCatalog.get_skin(id)))
	ui.theme_selected.connect(func(id: String) -> void: world.apply_theme(WorldThemes.get_theme(id)))
	ui.screen_changed.connect(_on_screen_changed)

	Profile.setting_changed.connect(_on_setting_changed)
	_apply_all_settings()

	_start_attract()
	ui.show_only(ui.main_menu)
	ui.fade_in(0.9)
	AudioManager.play_music("menu", 2.0)
	AudioManager.set_ambient(true)
	_run_automation_start()


# --- Settings ---------------------------------------------------------------------

func _apply_all_settings() -> void:
	for k in Profile.settings:
		_on_setting_changed(k, Profile.settings[k])


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"quality":
			if not _args.has("quality"):
				_quality = clampi(int(value), 0, 2)
			_apply_quality()
		"control_scheme":
			touch.scheme = int(value)
			ui.hud.configure(bool(Profile.get_setting("left_handed")), int(value))
		"steer_sensitivity":
			touch.sensitivity = float(value)
		"left_handed":
			touch.left_handed = bool(value)
			ui.hud.configure(bool(value), int(Profile.get_setting("control_scheme")))
		"camera_distance":
			camera.distance_pref = int(value)
		"camera_smoothing":
			camera.smoothing = float(value)
		"show_fps":
			ui.set_fps_visible(bool(value))


func _apply_quality() -> void:
	var vp := get_viewport()
	var win_h := float(DisplayServer.window_get_size().y)
	var target_h: float = [560.0, 760.0, 1080.0][_quality]
	var base: float = [0.75, 0.9, 1.0][_quality]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(minf(base, target_h / maxf(win_h, 1.0)), 0.4, 1.0)
	vp.msaa_3d = Viewport.MSAA_2X if _quality >= 2 else Viewport.MSAA_DISABLED
	world.set_quality(_quality)
	snake_view.set_quality(_quality)
	effects.quality = _quality


# --- Flow -----------------------------------------------------------------------

func _set_state(s: int) -> void:
	state = s
	_state_time = 0.0


func _start_attract() -> void:
	var seed_value := _rng.randi()
	var layout := WorldGenerator.generate(seed_value)
	world.set_obstacles(layout)
	session.start(seed_value, layout)
	camera.obstacles = session.obstacles
	items_view.clear()
	for it in session.items:
		items_view.spawn(it.id, it.kind, it.pos)
	snake_view.idle_amount = 1.0
	camera.set_mode(ChaseCamera.Mode.MENU)
	touch.enabled = false
	ui.hud.visible = false
	_set_state(State.MENU)


func start_run() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
	ui.fade_through(_begin_run)


func _begin_run() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	AudioManager.set_muffled(false)
	var seed_value := _rng.randi()
	var layout := WorldGenerator.generate(seed_value)
	world.set_obstacles(layout)
	session.start(seed_value, layout)
	camera.obstacles = session.obstacles
	items_view.clear()
	for it in session.items:
		items_view.spawn(it.id, it.kind, it.pos)
	snake_view.idle_amount = 0.0
	snake_view.apply_skin(SkinCatalog.get_skin(Profile.selected_skin))
	# Hide menus first: show_only() emits screen_changed, which must not be able to
	# put the camera back into a menu framing after the intro has been set up.
	ui.show_only(null)
	# Intro: sweep in from a high establishing shot behind the spawn.
	camera.snap_to_chase()
	camera.global_position = Vector3(-14, 15, -26)
	camera.set_mode(ChaseCamera.Mode.INTRO)
	ui.hud.visible = true
	ui.hud.reset_for_run(Profile.best_score())
	ui.hud.configure(bool(Profile.get_setting("left_handed")), int(Profile.get_setting("control_scheme")))
	touch.release_all()
	touch.enabled = false
	_was_boosting = false
	_intro_go_shown = false
	_tutorial_stage = 0 if not Profile.tutorial_done else 99
	AudioManager.play_music("game", 1.0)
	AudioManager.play("start", -4.0)
	_set_state(State.INTRO)


func go_to_menu() -> void:
	ui.fade_through(func() -> void:
		Engine.time_scale = 1.0
		get_tree().paused = false
		AudioManager.set_muffled(false)
		AudioManager.set_slither(0.0)
		_start_attract()
		ui.show_only(ui.main_menu)
		AudioManager.play_music("menu", 1.5))


## Save and close the app (main menu "Quit" button, or Back on the main menu).
func quit_game() -> void:
	Profile.save_profile()
	get_tree().quit()


func pause_game() -> void:
	if state != State.PLAYING and state != State.INTRO:
		return
	_set_state(State.PAUSED)
	get_tree().paused = true
	touch.enabled = false
	AudioManager.set_muffled(true)
	AudioManager.set_slither(0.0)
	ui.pause_menu.set_info(session.scores.score, session.stage, session.snake.length)
	ui.show_only(ui.pause_menu)


func resume() -> void:
	if state != State.PAUSED:
		return
	ui.show_only(null)
	get_tree().paused = false
	AudioManager.set_muffled(false)
	touch.release_all()
	touch.enabled = true
	_set_state(State.PLAYING)


func _on_pause_requested() -> void:
	if state == State.PLAYING or state == State.INTRO:
		AudioManager.ui_click()
		pause_game()


func _on_screen_changed(screen: String) -> void:
	# "" = no menu screen (a run is starting): the run owns the camera then.
	if state != State.MENU or screen == "":
		return
	camera.set_mode(ChaseCamera.Mode.SHOWCASE if screen == "skins" else ChaseCamera.Mode.MENU)
	if screen != "skins":
		snake_view.apply_skin(SkinCatalog.get_skin(Profile.selected_skin))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if state == State.PLAYING or state == State.INTRO:
				pause_game()
				ui.toast(tr("TOAST_PAUSED_BG"))
			if is_inside_tree():
				Profile.save_profile()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Profile.save_profile()


func _on_back() -> void:
	match state:
		State.PLAYING, State.INTRO:
			pause_game()
		State.PAUSED:
			if ui.top() == ui.pause_menu:
				resume()
			else:
				ui.back()
		State.GAME_OVER:
			go_to_menu()
		State.MENU:
			if ui.top() != ui.main_menu:
				ui.back()
			else:
				quit_game()


# --- Frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	_elapsed_real += real_dt
	_state_time += delta
	_run_automation(real_dt)
	match state:
		State.MENU:
			autopilot.update(session, delta)
			session.steer_input = autopilot.steer
			session.boost_input = false
			var ev := session.step(delta)
			_handle_events(ev, true)
			if not session.is_running():
				_start_attract()
			AudioManager.set_slither(0.08)
		State.INTRO:
			if _state_time >= GameConfig.INTRO_DURATION:
				touch.enabled = true
				_set_state(State.PLAYING)
				if not _intro_go_shown:
					_intro_go_shown = true
					ui.hud.banner(tr("HUD_GO"), "", UiTheme.CREAM)
		State.PLAYING:
			_update_tutorial()
			if _args.has("autoplay") or _args.has("showcase"):
				autopilot.update(session, delta)
				session.steer_input = autopilot.steer
				session.boost_input = autopilot.boost
			else:
				session.steer_input = touch.steer
				session.boost_input = touch.boost
			var ev := session.step(delta)
			_handle_events(ev, false)
			var sim := session.snake
			if sim.boosting and not _was_boosting:
				AudioManager.play("boost", -5.0)
				_haptic(12)
			_was_boosting = sim.boosting
			var sk := clampf((sim.speed - 5.0) / 14.0, 0.0, 1.0)
			AudioManager.set_slither(0.25 + sk * 0.6, 0.85 + sk * 0.5)
		State.DYING:
			_death_timer -= real_dt
			if _death_timer <= 0.0:
				_finish_death()
		State.GAME_OVER:
			pass
	if state != State.PAUSED:
		_update_views(delta)


func _update_views(delta: float) -> void:
	var nearest: Variant = null
	var best := 6.0
	for it in session.items:
		var d := it.pos.distance_to(session.snake.position)
		if d < best:
			best = d
			nearest = it.pos
	snake_view.look_target = nearest
	if nearest != null and best < 4.0:
		snake_view.flick_tongue()
	snake_view.update_view(delta)
	items_view.update_view(delta, session.items)
	world.update_view(delta, session.snake.position, camera.global_position)
	if ui.hud.visible and (state == State.PLAYING or state == State.INTRO or state == State.DYING):
		ui.hud.update_hud(delta, session)


func _update_tutorial() -> void:
	if _tutorial_stage >= 99:
		return
	if _tutorial_stage == 0:
		var key: String = ["TUT_DRAG", "TUT_HALVES", "TUT_STICK"][clampi(touch.scheme, 0, 2)]
		ui.hud.show_tutorial(tr(key), 6.0)
		_tutorial_stage = 1
	elif _tutorial_stage == 1 and (_state_time > 6.5 or (absf(touch.steer) > 0.3 and _state_time > 2.5)):
		ui.hud.show_tutorial(tr("TUT_BOOST"), 4.5)
		_tutorial_stage = 2
	elif _tutorial_stage == 2 and (_state_time > 12.0 or touch.boost):
		ui.hud.show_tutorial(tr("TUT_FOOD"), 4.0)
		_tutorial_stage = 3
	elif _tutorial_stage == 3 and _state_time > 16.0:
		_tutorial_stage = 99


func _haptic(ms: int, amp: float = -1.0) -> void:
	if bool(Profile.get_setting("haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amp)


func _handle_events(events: Array[Dictionary], quiet: bool) -> void:
	for e in events:
		match e["type"]:
			GameSession.EV_SPAWN:
				items_view.spawn(e["id"], e["kind"], e["pos"])
			GameSession.EV_EXPIRE:
				items_view.remove(e["id"], true)
			GameSession.EV_PICKUP:
				_on_pickup(e, quiet)
			GameSession.EV_STAGE:
				if not quiet:
					ui.hud.banner(tr("HUD_STAGE_UP") % e["stage"], tr("HUD_STAGE_SUB"))
					ui.hud.popup(session.snake.position + Vector3.UP * 1.5, "+%d" % e["bonus"], UiTheme.GOLD, 34)
					AudioManager.play("stage_up", -3.0)
					_haptic(30)
			GameSession.EV_RISE_WARNING:
				var ob: Obstacle = e["obstacle"]
				world.on_rise_warning(ob)
				if not quiet:
					var d := ob.position.distance_to(session.snake.head_tip())
					AudioManager.play("rise_warning", clampf(-4.0 - d * 0.35, -22.0, -4.0))
			GameSession.EV_RISE_START:
				var ob2: Obstacle = e["obstacle"]
				world.on_rise_start(ob2)
				var p := Vector3(ob2.position.x, terrain.height(ob2.position.x, ob2.position.y) + 0.3, ob2.position.y)
				effects.dust(p)
				if not quiet:
					var d2 := ob2.position.distance_to(session.snake.head_tip())
					AudioManager.play("rise_stone", clampf(-2.0 - d2 * 0.3, -20.0, -2.0))
					camera.add_trauma(clampf(0.35 - d2 * 0.015, 0.0, 0.3))
			GameSession.EV_NEAR_MISS:
				if not quiet:
					ui.hud.popup(session.snake.position + Vector3.UP * 1.2, tr("HUD_CLOSE_CALL") + "  +%d" % e["points"], UiTheme.JADE, 26)
					AudioManager.play("near_miss", -4.0)
					_haptic(8)
			GameSession.EV_SURGE_END:
				if not quiet:
					AudioManager.play("surge_end", -6.0)
			GameSession.EV_DEATH:
				if not quiet:
					_on_death(e)


func _on_pickup(e: Dictionary, quiet: bool) -> void:
	var kind: int = e["kind"]
	var pos: Vector3 = e["pos"]
	items_view.remove(e["id"], false)
	snake_view.on_pickup(kind)
	var col := CollectibleView.FOOD_COLOR
	match kind:
		Collectible.Kind.ENERGY:
			col = CollectibleView.ENERGY_COLOR
		Collectible.Kind.RARE:
			col = CollectibleView.RARE_COLOR
	effects.burst(pos, col, 1.6 if kind == Collectible.Kind.RARE else 1.0)
	effects.ring(Vector3(pos.x, terrain.height(pos.x, pos.z) + 0.1, pos.z), col, 3.4 if kind != Collectible.Kind.FOOD else 2.2)
	effects.flash(pos, col, 3.0 if kind == Collectible.Kind.FOOD else 5.0)
	if quiet:
		return
	var combo: int = e["combo"]
	ui.hud.popup(pos + Vector3.UP * 0.6, "+%d" % e["points"], col.lightened(0.2), 30 if kind == Collectible.Kind.FOOD else 38)
	match kind:
		Collectible.Kind.FOOD:
			AudioManager.play("pickup_food", -3.0, 1.0 + minf(combo - 1, 10) * 0.055)
			_haptic(10)
		Collectible.Kind.ENERGY:
			AudioManager.play("pickup_energy", -2.0)
			ui.hud.banner(tr("HUD_SURGE"), tr("HUD_SURGE_SUB"), CollectibleView.ENERGY_COLOR)
			camera.add_trauma(0.18)
			_haptic(25)
		Collectible.Kind.RARE:
			AudioManager.play("pickup_rare", -1.0)
			ui.hud.banner(tr("HUD_RELIC"), "+%d" % e["points"], CollectibleView.RARE_COLOR)
			camera.add_trauma(0.28)
			_haptic(45)


func _on_death(e: Dictionary) -> void:
	_set_state(State.DYING)
	touch.enabled = false
	_death_timer = GameConfig.DEATH_SEQUENCE_DURATION
	Engine.time_scale = GameConfig.DEATH_TIME_SCALE
	camera.add_trauma(0.75)
	camera.set_mode(ChaseCamera.Mode.DEATH)
	snake_view.flash(1.0)
	var p: Vector3 = e["pos"]
	effects.burst(p + Vector3.UP * 0.3, Color(1.0, 0.45, 0.25), 1.3)
	effects.dust(p)
	effects.flash(p, Color(1.0, 0.5, 0.3), 6.0, 0.5)
	AudioManager.play("death", 0.0)
	AudioManager.set_slither(0.0)
	AudioManager.set_muffled(true)
	_haptic(160, 1.0)
	ui.hud.hide_tutorial()


func _finish_death() -> void:
	Engine.time_scale = 1.0
	AudioManager.play("game_over", -3.0)
	var s := session.scores
	var run := {
		"score": s.score, "length": session.max_length, "stage": session.stage, "food": s.food_eaten,
		"energy": s.energy_eaten, "rare": s.rare_eaten, "combo": s.best_combo, "near_misses": s.near_misses,
		"time": session.time_alive, "cause": session.death_cause,
	}
	Profile.tutorial_done = true
	var result := Profile.record_run(run)
	_run_result = result
	ui.hud.visible = false
	ui.game_over.show_result(run, result)
	ui.show_only(ui.game_over)
	if (result["unlocked"] as Array).size() > 0:
		AudioManager.play("unlock", -2.0)
	_set_state(State.GAME_OVER)


# --- Automation (validation & screenshots) ------------------------------------------

## Demo history for --showcase: a believable records table and lifetime stats that
## unlock every skin and sanctuary. Only applied to an empty profile.
func _seed_showcase_profile() -> void:
	if int(Profile.stats["runs"]) > 0:
		return
	Profile.stats["runs"] = 77
	Profile.stats["total_food"] = 1180
	Profile.stats["total_energy"] = 96
	Profile.stats["total_rare"] = 11
	Profile.stats["near_misses"] = 214
	Profile.stats["play_time"] = 14200.0
	# score, length, stage, food, relics, seconds
	for r in [[2480, 58.4, 7, 61, 3, 412.0], [1935, 47.1, 6, 48, 2, 344.0], [1610, 41.8, 5, 42, 2, 301.0],
			[1288, 35.0, 5, 36, 1, 266.0], [1040, 30.2, 4, 30, 1, 228.0], [870, 26.9, 4, 27, 1, 197.0],
			[655, 22.3, 3, 21, 0, 160.0], [520, 19.6, 3, 18, 1, 131.0], [410, 16.4, 2, 15, 0, 104.0],
			[260, 12.5, 2, 10, 0, 77.0]]:
		Profile.record_run({"score": r[0], "length": r[1], "stage": r[2], "food": r[3], "rare": r[4],
			"time": r[5], "energy": 3, "combo": 9, "near_misses": 6})
	Profile.tutorial_done = true
	Profile.set_setting("quality", 2)
	Profile.save_profile()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("shot"):
		var at := float(_args.get("shot-at", "3"))
		var paths := str(_args["shot"]).split(",")
		var times := str(_args.get("shot-at", "3")).split(",")
		for i in paths.size():
			_shots.append([float(times[mini(i, times.size() - 1)]) if times.size() > 0 else at, paths[i]])


func _run_automation_start() -> void:
	if _args.has("seed"):
		_rng.seed = int(_args["seed"])
	if _args.get("start", "") == "play" or _args.has("autoplay"):
		_begin_run()
	elif _args.get("start", "") == "over":
		_begin_run()
		session.scores.score = 1234
		_on_death({"pos": session.snake.position, "cause": &"obstacle"})
	if _args.has("screen"):
		var n: String = _args["screen"]
		if n == "pause":
			get_tree().create_timer(2.5).timeout.connect(pause_game)
		else:
			ui.push(ui._screen_by_name(n))


func _run_automation(real_dt: float) -> void:
	if _shots.size() > 0 and _elapsed_real >= float(_shots[0][0]):
		var path: String = _shots[0][1]
		_shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png(path)
		print("[auto] screenshot saved: ", path, " state=", State.keys()[state], " score=", session.scores.score)
	if _args.has("quit-after") and _elapsed_real >= float(_args["quit-after"]):
		print("[auto] quitting: state=%s score=%d stage=%d length=%.1f alive=%.1fs fps=%d" % [State.keys()[state], session.scores.score, session.stage, session.snake.length, session.time_alive, Engine.get_frames_per_second()])
		_args.erase("quit-after")
		get_tree().quit(0)
	if _args.has("autoplay") and state == State.GAME_OVER and _state_time > 1.5:
		start_run()
