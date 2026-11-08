extends TestCase
## Touch gestures in the scrolling Settings list, fed through the real viewport
## (picking, propagation to the ScrollContainer) of the real main scene.


func _settings(main: Node) -> Control:
	var ui: UiRoot = main.ui
	ui.push(ui.settings)
	return ui.settings


func _sliders(screen: Control) -> Array:
	return screen.find_children("*", "HSlider", true, false)


func _scroll(screen: Control) -> ScrollContainer:
	return screen.find_children("*", "ScrollContainer", true, false)[0]


func _press(vp: Viewport, p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	vp.push_input(ev, true)


## A finger drag from a to b in small steps, then lift.
func _swipe(vp: Viewport, a: Vector2, b: Vector2, steps: int = 12) -> void:
	_press(vp, a, true)
	var prev := a
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		var ev := InputEventMouseMotion.new()
		ev.position = p
		ev.global_position = p
		ev.relative = p - prev
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(ev, true)
		prev = p
	_press(vp, b, false)


func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func test_vertical_swipe_from_a_slider_scrolls_and_keeps_its_value() -> void:
	var main := make_main()
	var screen := _settings(main)
	await tree.create_timer(0.6).timeout # open animation + layout
	var vp := main.get_viewport()
	var sliders := _sliders(screen)
	check_eq(sliders.size(), 4, "settings have four sliders (music, effects, sensitivity, camera)")
	var s: HSlider = sliders[2]
	var before := s.value
	var sc := _scroll(screen)
	var scroll_before := sc.scroll_vertical
	# Start right of the grabber, far from the current value, and swipe up.
	var start := _centre(s) + Vector2(s.size.x * 0.35, 0)
	_swipe(vp, start, start + Vector2(6, -220))
	await tree.process_frame
	check_eq(s.value, before, "slider value unchanged by a vertical swipe")
	if DisplayServer.is_touchscreen_available():
		check(sc.scroll_vertical > scroll_before, "the list scrolled (%d -> %d)" % [scroll_before, sc.scroll_vertical])
	dispose_main(main)


func test_horizontal_drag_and_tap_still_set_a_slider() -> void:
	var main := make_main()
	var screen := _settings(main)
	await tree.create_timer(0.6).timeout
	var vp := main.get_viewport()
	var s: HSlider = _sliders(screen)[0] # music, 0..1
	var r := s.get_global_rect()
	s.value = 0.5
	_swipe(vp, r.get_center(), Vector2(r.position.x + 2.0, r.get_center().y + 4.0))
	check(s.value < 0.08, "dragging left turns the music down (%.2f)" % s.value)
	_press(vp, Vector2(r.end.x - 2.0, r.get_center().y), true)
	_press(vp, Vector2(r.end.x - 2.0, r.get_center().y), false)
	check(s.value > 0.92, "a tap near the right end sets it near the top (%.2f)" % s.value)
	var profile := tree.root.get_node("Profile")
	check_near(float(profile.get_setting("music_volume")), s.value, 0.001, "the setting follows the slider")
	dispose_main(main)


func test_swipe_from_a_toggle_does_not_flip_it() -> void:
	var main := make_main()
	var screen := _settings(main)
	await tree.create_timer(0.6).timeout
	var vp := main.get_viewport()
	var toggles := screen.find_children("*", "CheckButton", true, false)
	check(toggles.size() >= 4, "settings have toggles")
	var t: CheckButton = toggles[0]
	var sc := _scroll(screen)
	sc.ensure_control_visible(t)
	await tree.process_frame
	await tree.process_frame
	var was := t.button_pressed
	var c := _centre(t)
	check(sc.get_global_rect().has_point(c), "toggle is on screen")
	if DisplayServer.is_touchscreen_available():
		# Swipe the list up starting on the toggle. The content follows the finger,
		# so the finger is lifted over the toggle again: a scroll, not a tap.
		var scroll_before := sc.scroll_vertical
		_swipe(vp, c, c + Vector2(0, -80), 8)
		check(sc.scroll_vertical > scroll_before, "a swipe starting on the toggle scrolls the list (%d -> %d)" % [scroll_before, sc.scroll_vertical])
		check_eq(t.button_pressed, was, "a swipe starting on the toggle does not flip it")
		# Let the inertial scroll finish (a tap during it only stops it).
		for i in 180:
			if not sc.get_meta("dragging", false):
				break
			await tree.process_frame
		check(not sc.get_meta("dragging", false), "the list comes to rest after the swipe")
		c = _centre(t)
	_press(vp, c, true)
	_press(vp, c, false)
	check_eq(t.button_pressed, not was, "a tap still flips it")
	dispose_main(main)
