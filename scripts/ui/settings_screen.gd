class_name SettingsScreen
extends UiScreen
## Audio, graphics, controls, camera and language settings. Changes apply live
## and are saved when the screen closes.

var _confirm_reset: Button
var _body: VBoxContainer


func _ready() -> void:
	add_backdrop(0.6)
	var vb := make_panel("SET_TITLE", 900)
	_body = MenuScreens.scroll_body(vb, 450)
	_build()
	var back := make_button("COMMON_BACK", true, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_requested.emit())
	vb.add_child(back)
	Profile.profile_reset.connect(_rebuild)


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_build()


func _build() -> void:
	var b := _body
	b.add_child(MenuScreens.section("SET_AUDIO"))
	b.add_child(MenuScreens.setting_row("SET_MUSIC", MenuScreens.slider(Profile.get_setting("music_volume"), 0, 1, 0.05, func(v: float) -> void: Profile.set_setting("music_volume", v))))
	b.add_child(MenuScreens.setting_row("SET_SFX", MenuScreens.slider(Profile.get_setting("sfx_volume"), 0, 1, 0.05, func(v: float) -> void:
		Profile.set_setting("sfx_volume", v)
		AudioManager.play("ui_click", -2.0))))

	b.add_child(MenuScreens.section("SET_CONTROLS"))
	b.add_child(MenuScreens.setting_row("SET_SCHEME", MenuScreens.segmented(["SCHEME_DRAG", "SCHEME_HALVES", "SCHEME_STICK"], int(Profile.get_setting("control_scheme")), func(i: int) -> void: Profile.set_setting("control_scheme", i))))
	var hint := UiTheme.label("SET_SCHEME_HINT", 18, "light", UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(hint)
	b.add_child(MenuScreens.setting_row("SET_SENSITIVITY", MenuScreens.slider(Profile.get_setting("steer_sensitivity"), 0.5, 2.0, 0.05, func(v: float) -> void: Profile.set_setting("steer_sensitivity", v))))
	b.add_child(MenuScreens.setting_row("SET_LEFT_HANDED", MenuScreens.toggle(Profile.get_setting("left_handed"), func(v: bool) -> void: Profile.set_setting("left_handed", v))))
	b.add_child(MenuScreens.setting_row("SET_HAPTICS", MenuScreens.toggle(Profile.get_setting("haptics"), func(v: bool) -> void:
		Profile.set_setting("haptics", v)
		if v:
			Input.vibrate_handheld(30))))

	b.add_child(MenuScreens.section("SET_CAMERA"))
	b.add_child(MenuScreens.setting_row("SET_CAM_DISTANCE", MenuScreens.segmented(["CAM_NEAR", "CAM_NORMAL", "CAM_FAR"], int(Profile.get_setting("camera_distance")), func(i: int) -> void: Profile.set_setting("camera_distance", i))))
	b.add_child(MenuScreens.setting_row("SET_CAM_SMOOTH", MenuScreens.slider(Profile.get_setting("camera_smoothing"), 0.5, 1.5, 0.05, func(v: float) -> void: Profile.set_setting("camera_smoothing", v))))

	b.add_child(MenuScreens.section("SET_ACCESS"))
	b.add_child(MenuScreens.setting_row("SET_REDUCED_MOTION", MenuScreens.toggle(Profile.get_setting("reduced_motion"), func(v: bool) -> void: Profile.set_setting("reduced_motion", v))))
	var motion_hint := UiTheme.label("SET_REDUCED_MOTION_HINT", 18, "light", UiTheme.MUTED)
	motion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(motion_hint)

	b.add_child(MenuScreens.section("SET_GRAPHICS"))
	b.add_child(MenuScreens.setting_row("SET_QUALITY", MenuScreens.segmented(["Q_LOW", "Q_MEDIUM", "Q_HIGH"], int(Profile.get_setting("quality")), func(i: int) -> void: Profile.set_setting("quality", i))))
	b.add_child(MenuScreens.setting_row("SET_FPS", MenuScreens.toggle(Profile.get_setting("show_fps"), func(v: bool) -> void: Profile.set_setting("show_fps", v))))

	b.add_child(MenuScreens.section("SET_LANGUAGE"))
	var codes := Localization.LOCALES
	var names: Array = []
	for code in codes:
		names.append(Localization.language_name(code))
	b.add_child(MenuScreens.choice_grid(names, codes.find(Localization.current()), 4, func(i: int) -> void:
		Profile.set_setting("language", codes[i])
		Profile.save_profile() # keep the choice even if the app is killed in Settings
		Localization.apply(codes[i])))

	b.add_child(MenuScreens.section("SET_DATA"))
	_confirm_reset = make_button("SET_RESET", false, 360)
	_confirm_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MenuScreens.scroll_friendly(_confirm_reset)
	_confirm_reset.pressed.connect(_on_reset)
	b.add_child(_confirm_reset)


var _reset_armed := false


func _on_reset() -> void:
	if MenuScreens.is_scrolling(_confirm_reset):
		return
	if not _reset_armed:
		_reset_armed = true
		_confirm_reset.text = "SET_RESET_CONFIRM"
		_confirm_reset.add_theme_color_override("font_color", UiTheme.DANGER)
		get_tree().create_timer(3.0, true).timeout.connect(func() -> void:
			_reset_armed = false
			if is_instance_valid(_confirm_reset):
				_confirm_reset.text = "SET_RESET"
				_confirm_reset.remove_theme_color_override("font_color"))
		return
	_reset_armed = false
	var keep := Profile.settings.duplicate()
	Profile.reset_to_defaults(true)
	Profile.settings = keep
	Profile.save_profile()


func _on_open() -> void:
	_reset_armed = false
	if _confirm_reset:
		_confirm_reset.text = "SET_RESET"
		_confirm_reset.remove_theme_color_override("font_color")


func close() -> void:
	Profile.save_profile()
	super.close()
