class_name UiRoot
extends CanvasLayer
## Owns every UI screen, the safe-area margins, a screen stack for "back",
## toasts, the fade overlay and the FPS counter.

signal play_requested
signal resume_requested
signal restart_requested
signal quit_to_menu_requested
signal skin_previewed(id: String)
signal theme_selected(id: String)
signal screen_changed(name: String)

const FULL_BLEED_GROUP := &"ui_full_bleed"
const SAFE_AREA_POLL := 0.5

## Display cut-out insets currently applied, in UI units (left, top, right, bottom).
static var safe_insets := Vector4.ZERO

var safe_root: MarginContainer
var hud: Hud
var main_menu: MainMenu
var pause_menu: PauseMenu
var game_over: GameOverScreen
var settings: SettingsScreen
var skins: SkinsScreen
var records: RecordsScreen
var about: AboutScreen

var _stack: Array[UiScreen] = []
var _fade: ColorRect
var _fps: Label
var _toast: PanelContainer
var _toast_label: Label
var _safe_poll: float = 0.0
var _last_safe_area := Rect2i()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The HUD spans the whole screen (its local coordinates are viewport coordinates,
	# like touch positions and Camera3D.unproject_position) and insets its own corner
	# widgets. Menus live inside the safe-area margins.
	hud = Hud.new()
	hud.visible = false
	hud.theme = UiTheme.get_theme()
	add_child(hud)
	safe_root = MarginContainer.new()
	safe_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.theme = UiTheme.get_theme()
	add_child(safe_root)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(stack)

	main_menu = MainMenu.new()
	pause_menu = PauseMenu.new()
	game_over = GameOverScreen.new()
	settings = SettingsScreen.new()
	skins = SkinsScreen.new()
	records = RecordsScreen.new()
	about = AboutScreen.new()
	for s in [main_menu, pause_menu, game_over, settings, skins, records, about]:
		stack.add_child(s)
		s.back_requested.connect(back)

	main_menu.play_requested.connect(func() -> void: play_requested.emit())
	main_menu.screen_requested.connect(func(n: String) -> void: push(_screen_by_name(n)))
	pause_menu.resume_requested.connect(func() -> void: resume_requested.emit())
	pause_menu.restart_requested.connect(func() -> void: restart_requested.emit())
	pause_menu.settings_requested.connect(func() -> void: push(settings))
	pause_menu.menu_requested.connect(func() -> void: quit_to_menu_requested.emit())
	game_over.retry_requested.connect(func() -> void: restart_requested.emit())
	game_over.menu_requested.connect(func() -> void: quit_to_menu_requested.emit())
	skins.skin_previewed.connect(func(id: String) -> void: skin_previewed.emit(id))
	skins.theme_selected.connect(func(id: String) -> void: theme_selected.emit(id))

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.08, 0.07, 0.94), 18, UiTheme.JADE, 2, 12))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -330
	_toast.offset_right = 330
	_toast.offset_top = 18
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiTheme.label("", 22, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.custom_minimum_size = Vector2(620, 56)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	add_child(_toast)

	_fps = UiTheme.label("", 16, "semibold", Color(1, 1, 1, 0.75))
	_fps.position = Vector2(8, 4)
	_fps.visible = false
	add_child(_fps)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.03, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _screen_by_name(n: String) -> UiScreen:
	match n:
		"settings":
			return settings
		"skins":
			return skins
		"records":
			return records
		"about":
			return about
	return main_menu


## Respect display cut-outs / rounded corners (Android safe area).
func _apply_safe_area() -> void:
	var insets := Vector4.ZERO
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var vp := get_viewport().get_visible_rect().size
		_last_safe_area = safe
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / Vector2(win)
			insets = Vector4(
				maxf(float(safe.position.x), 0.0) * k.x,
				maxf(float(safe.position.y), 0.0) * k.y,
				maxf(float(win.x - safe.end.x), 0.0) * k.x,
				maxf(float(win.y - safe.end.y), 0.0) * k.y)
	set_safe_insets(insets)


## Apply display cut-out insets (UI units: left, top, right, bottom): menus get
## margins, full-bleed layers extend under the cut-out, the HUD moves its widgets.
func set_safe_insets(insets: Vector4) -> void:
	safe_insets = insets.ceil()
	safe_root.add_theme_constant_override("margin_left", int(safe_insets.x))
	safe_root.add_theme_constant_override("margin_top", int(safe_insets.y))
	safe_root.add_theme_constant_override("margin_right", int(safe_insets.z))
	safe_root.add_theme_constant_override("margin_bottom", int(safe_insets.w))
	for n in get_tree().get_nodes_in_group(FULL_BLEED_GROUP):
		_apply_bleed(n as Control)
	hud.set_safe_insets(safe_insets)


## Make a decorative full-screen layer (backdrop, gradient) that lives inside the
## safe-area margins also cover the area under the display cut-out.
static func full_bleed(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_to_group(FULL_BLEED_GROUP)
	_apply_bleed(c)


static func _apply_bleed(c: Control) -> void:
	c.offset_left = -safe_insets.x
	c.offset_top = -safe_insets.y
	c.offset_right = safe_insets.z
	c.offset_bottom = safe_insets.w


func fade_in(duration: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)


## Fade to black, run `mid`, fade back.
func fade_through(mid: Callable, duration: float = 0.35) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	tw.tween_callback(mid)
	tw.tween_property(_fade, "color:a", 0.0, duration)
	tw.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func toast(text: String) -> void:
	_toast_label.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func top() -> UiScreen:
	return _stack[_stack.size() - 1] if not _stack.is_empty() else null


## Show a screen on top of the stack (hiding the previous one).
func push(s: UiScreen) -> void:
	var t := top()
	if t == s:
		return
	if t:
		t.close()
	_stack.append(s)
	s.open()
	screen_changed.emit(_name_of(s))


## Replace the whole stack with `s` (or nothing).
func show_only(s: UiScreen) -> void:
	for x in _stack:
		x.close()
	_stack.clear()
	if s:
		_stack.append(s)
		s.open()
	screen_changed.emit(_name_of(s))


func back() -> void:
	if _stack.size() <= 1:
		return
	var t: UiScreen = _stack.pop_back()
	t.close()
	var n := top()
	n.open()
	screen_changed.emit(_name_of(n))


func _name_of(s: UiScreen) -> String:
	if s == null:
		return ""
	for pair in [[main_menu, "menu"], [pause_menu, "pause"], [game_over, "game_over"], [settings, "settings"], [skins, "skins"], [records, "records"], [about, "about"]]:
		if pair[0] == s:
			return pair[1]
	return ""


func set_fps_visible(v: bool) -> void:
	_fps.visible = v


func _process(delta: float) -> void:
	# Flipping the phone between the two landscape orientations moves the cut-out
	# without resizing the viewport, so the safe area is re-checked periodically.
	if OS.has_feature("mobile"):
		_safe_poll -= delta
		if _safe_poll <= 0.0:
			_safe_poll = SAFE_AREA_POLL
			if DisplayServer.get_display_safe_area() != _last_safe_area:
				_apply_safe_area()
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
