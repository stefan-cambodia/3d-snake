class_name Hud
extends Control
## In-game HUD: score, best, stage progress, combo, length, boost/stamina
## button, pause button, steering feedback, popups, banners, off-screen
## markers for special collectibles, speed lines and danger vignette.
##
## The HUD covers the whole viewport, so its local coordinates are viewport
## coordinates (touch positions, Camera3D.unproject_position). Corner widgets are
## placed inside the safe area (display cut-outs) given by set_safe_insets().

const BOOST_RADIUS := 78.0
const PAUSE_RADIUS := 38.0

var touch: TouchController
var camera: Camera3D
var left_handed: bool = false
var scheme: int = 0
## Accessibility: no speed lines (the camera handles the rest of reduced motion).
var reduced_motion: bool = false

var _score_label: Label
var _best_label: Label
var _stage_label: Label
var _length_label: Label
var _combo_label: Label
var _canvas: Control
var _popups: Control
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _tutorial: Label
var _vignette: TextureRect

var _shown_score: float = 0.0
var _target_score: int = 0
var _best: int = 0
var _new_best_announced: bool = false
var _stamina: float = 1.0
var _surge: float = 0.0
var _boosting: bool = false
var _stage_progress: float = 0.0
var _combo_t: float = 0.0
var _combo_mult: float = 1.0
var _markers: Array = [] # [{pos: Vector2, kind: Collectible.Kind, color: Color, angle: float, life: float}]
var _speed_lines: float = 0.0
var _insets := Vector4.ZERO # left, top, right, bottom
var _danger: float = 0.0
var _time: float = 0.0
var _tutorial_t: float = 0.0
var _score_pulse: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.05, 0.02, 0.0))
	g.set_color(1, Color(0.6, 0.05, 0.02, 0.85))
	g.add_point(0.6, Color(0.6, 0.05, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	_vignette.texture = gt
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)

	_score_label = UiTheme.label("0", 56, "title", UiTheme.CREAM)
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_score_label.add_theme_constant_override("outline_size", 8)
	add_child(_score_label)
	_best_label = UiTheme.label("", 20, "semibold", UiTheme.GOLD)
	_best_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_best_label.add_theme_constant_override("outline_size", 5)
	add_child(_best_label)

	_stage_label = UiTheme.label("", 21, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_stage_label.size = Vector2(280, 30)
	_stage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_stage_label.add_theme_constant_override("outline_size", 5)
	add_child(_stage_label)

	_combo_label = UiTheme.label("", 30, "bold", UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_combo_label.size = Vector2(280, 38)
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_combo_label.add_theme_constant_override("outline_size", 6)
	add_child(_combo_label)

	_length_label = UiTheme.label("", 22, "semibold", UiTheme.CREAM)
	_length_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_length_label.add_theme_constant_override("outline_size", 5)
	add_child(_length_label)

	_popups = Control.new()
	_popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)

	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_CENTER)
	_banner_box.offset_left = -400
	_banner_box.offset_right = 400
	_banner_box.offset_top = -170
	_banner_box.offset_bottom = -60
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_banner_box)
	_banner = UiTheme.label("", 54, "title", UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner_box.add_child(_banner)
	_banner_sub = UiTheme.label("", 24, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_banner_sub.add_theme_constant_override("outline_size", 6)
	_banner_box.add_child(_banner_sub)
	_banner_box.modulate.a = 0.0

	_tutorial = UiTheme.label("", 26, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_tutorial.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial.offset_left = -420
	_tutorial.offset_right = 420
	_tutorial.offset_top = -190
	_tutorial.offset_bottom = -120
	_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_tutorial.add_theme_constant_override("outline_size", 8)
	_tutorial.modulate.a = 0.0
	add_child(_tutorial)
	resized.connect(_layout)
	_layout()


func set_safe_insets(insets: Vector4) -> void:
	_insets = insets
	_layout()


## The part of the HUD not covered by display cut-outs, in local coordinates.
func safe_rect() -> Rect2:
	return Rect2(Vector2(_insets.x, _insets.y), size - Vector2(_insets.x + _insets.z, _insets.y + _insets.w))


func _layout() -> void:
	var r := safe_rect()
	_score_label.position = r.position + Vector2(40, 18)
	_best_label.position = r.position + Vector2(44, 88)
	_stage_label.position = Vector2(r.get_center().x - _stage_label.size.x * 0.5, r.position.y + 16)
	_combo_label.position = Vector2(r.get_center().x - _combo_label.size.x * 0.5, r.position.y + 66)
	_length_label.position = Vector2(r.position.x + 44 if not left_handed else r.end.x - 260, r.end.y - 64)
	_length_label.size = Vector2(220, 40)
	_length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if not left_handed else HORIZONTAL_ALIGNMENT_RIGHT
	if touch:
		# Touch zones are compared with event positions, i.e. viewport coordinates.
		var xf := get_global_transform_with_canvas()
		touch.boost_zone = xf * Rect2(boost_center() - Vector2.ONE * (BOOST_RADIUS + 34.0), Vector2.ONE * (BOOST_RADIUS + 34.0) * 2.0)
		touch.pause_zone = xf * Rect2(pause_center() - Vector2.ONE * (PAUSE_RADIUS + 22.0), Vector2.ONE * (PAUSE_RADIUS + 22.0) * 2.0)


func boost_center() -> Vector2:
	var r := safe_rect()
	var x := r.end.x - 150.0 if not left_handed else r.position.x + 150.0
	return Vector2(x, r.end.y - 140.0)


func pause_center() -> Vector2:
	var r := safe_rect()
	return Vector2(r.end.x - 66.0, r.position.y + 62.0)


## Clearance from a button's centre that keeps a whole marker (disc 22 px)
## off the button and its rings (stamina, Surge).
const MARKER_BOOST_CLEARANCE := BOOST_RADIUS + 23.0 + 24.0
const MARKER_PAUSE_CLEARANCE := PAUSE_RADIUS + 26.0


## Slide an off-screen marker sitting on `area`'s border along that border until
## it no longer covers the boost or pause button.
func avoid_buttons(p: Vector2, area: Rect2) -> Vector2:
	for b in [[boost_center(), MARKER_BOOST_CLEARANCE], [pause_center(), MARKER_PAUSE_CLEARANCE]]:
		var c: Vector2 = b[0]
		var r: float = b[1]
		if p.distance_to(c) >= r:
			continue
		var on_side := absf(p.x - area.position.x) < 1.0 or absf(p.x - area.end.x) < 1.0
		if on_side:
			var dy := sqrt(maxf(r * r - (p.x - c.x) * (p.x - c.x), 0.0))
			var up := c.y - dy - 1.0
			var down := c.y + dy + 1.0
			p.y = up if up >= area.position.y and (p.y <= c.y or down > area.end.y) else down
		else:
			var dx := sqrt(maxf(r * r - (p.y - c.y) * (p.y - c.y), 0.0))
			var left := c.x - dx - 1.0
			var right := c.x + dx + 1.0
			p.x = left if left >= area.position.x and (p.x <= c.x or right > area.end.x) else right
	return p


func configure(p_left_handed: bool, p_scheme: int) -> void:
	left_handed = p_left_handed
	scheme = p_scheme
	_layout()


func reset_for_run(best: int) -> void:
	_best = best
	_shown_score = 0.0
	_target_score = 0
	_new_best_announced = best <= 0
	_best_label.text = tr("HUD_BEST") % best if best > 0 else ""
	_score_label.text = "0"
	_combo_label.text = ""
	_banner_box.modulate.a = 0.0
	_markers.clear()
	for c in _popups.get_children():
		c.queue_free()


func show_tutorial(text: String, duration: float = 5.0) -> void:
	_tutorial.text = text
	_tutorial_t = duration


func hide_tutorial() -> void:
	_tutorial_t = minf(_tutorial_t, 0.4)


func update_hud(delta: float, session: GameSession) -> void:
	_time += delta
	var sim := session.snake
	_target_score = session.scores.score
	if _shown_score < _target_score:
		_shown_score = minf(_shown_score + maxf((_target_score - _shown_score) * 10.0, 30.0) * delta, _target_score)
		_score_label.text = str(int(_shown_score))
	_score_pulse = maxf(_score_pulse - delta * 3.0, 0.0)
	_score_label.pivot_offset = Vector2(0, _score_label.size.y * 0.5)
	_score_label.scale = Vector2.ONE * (1.0 + 0.12 * _score_pulse)
	if not _new_best_announced and _target_score > _best:
		_new_best_announced = true
		banner(tr("HUD_NEW_BEST"), "", UiTheme.JADE)
		AudioManager.play("new_best", -3.0)
	if _target_score > _best and _best > 0:
		_best_label.text = tr("HUD_NEW_BEST_SHORT")
	_stage_label.text = tr("HUD_STAGE") % session.stage
	_stage_progress = MathUtil.damp(_stage_progress, float(session.food_in_stage) / float(GameConfig.FOOD_PER_STAGE), 0.12, delta)
	if session.stage >= GameConfig.MAX_STAGE:
		_stage_progress = 1.0
	_length_label.text = tr("HUD_LENGTH") % sim.length
	_combo_mult = session.scores.multiplier
	_combo_t = session.scores.combo_timer / GameConfig.COMBO_WINDOW
	_combo_label.text = ("x%.2f" % _combo_mult).trim_suffix("0").trim_suffix(".0") if _combo_mult > 1.0 else ""
	_combo_label.modulate.a = clampf(_combo_t * 3.0, 0.0, 1.0)
	_stamina = sim.stamina
	_surge = sim.surge_time / GameConfig.SURGE_DURATION
	_boosting = sim.boosting
	var fast := (sim.boosting or sim.is_surging()) and not reduced_motion
	_speed_lines = MathUtil.damp(_speed_lines, 1.0 if fast else 0.0, 0.15, delta)
	# Danger vignette: proximity to wall, obstacles or own body.
	var clear := minf(session.head_clearance(), GameConfig.ARENA_RADIUS - sim.head_tip().length() - GameConfig.HEAD_COLLISION_RADIUS)
	_danger = MathUtil.damp(_danger, clampf(1.0 - clear / 2.2, 0.0, 1.0), 0.1, delta)
	_vignette.modulate.a = _danger * 0.55

	# Off-screen markers for special collectibles.
	_markers.clear()
	if camera:
		var margin := 56.0
		var area := safe_rect().grow(-margin)
		for it in session.items:
			if it.kind == Collectible.Kind.FOOD:
				continue
			var col := CollectibleView.ENERGY_COLOR if it.kind == Collectible.Kind.ENERGY else CollectibleView.RARE_COLOR
			var p := it.pos + Vector3.UP * 0.4
			var behind := camera.is_position_behind(p)
			var sp := camera.unproject_position(p)
			if not behind and area.has_point(sp):
				continue
			var c := area.get_center()
			var dir := sp - c
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2(0, 1)
			var scale_k := minf(area.size.x * 0.5 / maxf(absf(dir.x), 0.001), area.size.y * 0.5 / maxf(absf(dir.y), 0.001))
			var mp := avoid_buttons(c + dir * scale_k, area)
			_markers.append({"pos": mp, "kind": it.kind, "color": col, "angle": dir.angle(), "life": it.time_left()})

	if _tutorial_t > 0.0:
		_tutorial_t -= delta
		_tutorial.modulate.a = clampf(_tutorial_t / 0.4, 0.0, 1.0) * (0.85 + 0.15 * sin(_time * 4.0))
	else:
		_tutorial.modulate.a = 0.0
	_canvas.queue_redraw()


func popup(world_pos: Vector3, text: String, color: Color, size_px: int = 30) -> void:
	if camera == null or camera.is_position_behind(world_pos):
		return
	var sp := camera.unproject_position(world_pos)
	var l := UiTheme.label(text, size_px, "bold", color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(240, 44)
	l.position = sp - Vector2(120, 40)
	l.pivot_offset = Vector2(120, 22)
	l.scale = Vector2(0.6, 0.6)
	_popups.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
	if text.begins_with("+"):
		_score_pulse = 1.0


func banner(text: String, sub: String, color: Color = UiTheme.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_box.pivot_offset = Vector2(400, 55)
	_banner_box.scale = Vector2(0.8, 0.8)
	var tw := _banner_box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner_box, "modulate:a", 1.0, 0.15)
	tw.tween_property(_banner_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.3)
	tw.chain().tween_property(_banner_box, "modulate:a", 0.0, 0.4)


## Outline of the off-screen marker symbol centred on p: a diamond for Surge
## crystals (filled), a closed ring for relics (stroked).
static func marker_symbol(kind: int, p: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if kind == Collectible.Kind.RARE:
		for i in 25:
			var a := TAU * float(i) / 24.0
			pts.append(p + Vector2(cos(a), sin(a)) * 9.5)
	else:
		pts = PackedVector2Array([p + Vector2(0, -15), p + Vector2(10, 0), p + Vector2(0, 15), p + Vector2(-10, 0)])
	return pts


func _draw_canvas() -> void:
	var c := _canvas
	var vs := size
	# Speed lines.
	if _speed_lines > 0.02:
		var centre := vs * 0.5
		var n := 26
		for i in n:
			var a := TAU * float(i) / float(n) + sin(_time * 3.0 + i) * 0.05
			var seed_ := fmod(_time * 2.5 + MathUtil.hash01(i) * 7.0, 1.0)
			var r0 := vs.length() * (0.36 + 0.12 * seed_)
			var r1 := r0 + 60.0 + 80.0 * MathUtil.hash01(i + 31)
			var dir := Vector2(cos(a), sin(a))
			var col := Color(1, 1, 1, 0.16 * _speed_lines * (1.0 - seed_))
			if _surge > 0.0:
				col = Color(0.5, 1.0, 1.0, 0.22 * _speed_lines * (1.0 - seed_))
			c.draw_line(centre + dir * r0, centre + dir * r1, col, 2.0, true)

	# Stage progress bar under the stage label.
	var sr := safe_rect()
	var bw := 220.0
	var bx := sr.get_center().x - bw * 0.5
	var by := sr.position.y + 50.0
	c.draw_rect(Rect2(bx, by, bw, 6), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(bx, by, bw * _stage_progress, 6), UiTheme.GOLD)
	# Combo timer ring.
	if _combo_mult > 1.0 and _combo_t > 0.0:
		var cc := Vector2(sr.get_center().x, sr.position.y + 120.0)
		c.draw_arc(cc, 16, -PI * 0.5, -PI * 0.5 + TAU * _combo_t, 32, Color(UiTheme.GOLD, 0.8), 3.0, true)

	# Pause button.
	var pc := pause_center()
	c.draw_circle(pc, PAUSE_RADIUS, Color(0.03, 0.05, 0.04, 0.55))
	c.draw_arc(pc, PAUSE_RADIUS, 0, TAU, 40, Color(UiTheme.GOLD, 0.6), 2.0, true)
	c.draw_rect(Rect2(pc + Vector2(-10, -13), Vector2(7, 26)), UiTheme.CREAM)
	c.draw_rect(Rect2(pc + Vector2(3, -13), Vector2(7, 26)), UiTheme.CREAM)

	# Boost button with stamina ring and surge ring.
	var bc := boost_center()
	var ready := _stamina >= GameConfig.STAMINA_MIN_TO_START
	var fill := Color(0.86, 0.66, 0.32, 0.85) if _boosting else Color(0.03, 0.05, 0.04, 0.5)
	c.draw_circle(bc, BOOST_RADIUS, fill)
	c.draw_arc(bc, BOOST_RADIUS + 6.0, 0, TAU, 64, Color(1, 1, 1, 0.12), 8.0, true)
	c.draw_arc(bc, BOOST_RADIUS + 6.0, -PI * 0.5, -PI * 0.5 + TAU * _stamina, 64, Color(UiTheme.GOLD, 1.0 if ready else 0.4), 8.0, true)
	if _surge > 0.0:
		c.draw_arc(bc, BOOST_RADIUS + 18.0, -PI * 0.5, -PI * 0.5 + TAU * _surge, 64, Color(0.4, 1.0, 1.0, 0.9), 5.0, true)
	# Double chevron glyph.
	var gcol := Color(0.1, 0.07, 0.03) if _boosting else (UiTheme.CREAM if ready else Color(1, 1, 1, 0.35))
	for k in 2:
		var off := Vector2(0, 12.0 - float(k) * 22.0)
		c.draw_polyline(PackedVector2Array([bc + off + Vector2(-22, 10), bc + off + Vector2(0, -10), bc + off + Vector2(22, 10)]), gcol, 6.0, true)

	# Steering feedback.
	if touch and touch.steer_touch_active:
		var a := touch.steer_anchor
		if scheme == TouchController.Scheme.JOYSTICK:
			c.draw_circle(a, touch.joystick_radius, Color(0, 0, 0, 0.22))
			c.draw_arc(a, touch.joystick_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
			var k := (touch.steer_pos - a).limit_length(touch.joystick_radius)
			c.draw_circle(a + Vector2(k.x, k.y * 0.3), 30, Color(UiTheme.GOLD, 0.8))
		else:
			var r := touch.drag_range()
			c.draw_line(a - Vector2(r, 0), a + Vector2(r, 0), Color(1, 1, 1, 0.22), 4.0, true)
			c.draw_circle(a, 7, Color(1, 1, 1, 0.35))
			c.draw_circle(Vector2(a.x + clampf(touch.steer_pos.x - a.x, -r, r), a.y), 18, Color(UiTheme.GOLD, 0.65))
	elif scheme == TouchController.Scheme.HALVES and touch:
		var s := touch.steer
		if absf(s) > 0.1:
			var x := 0.0 if s < 0.0 else vs.x - 14.0
			c.draw_rect(Rect2(x, vs.y * 0.25, 14, vs.y * 0.5), Color(UiTheme.GOLD, 0.35))

	# Off-screen markers. The symbol repeats the item's 3D shape (crystal = diamond,
	# relic = ring), so they can be told apart without relying on colour.
	for m in _markers:
		var p: Vector2 = m["pos"]
		var col: Color = m["color"]
		var ang: float = m["angle"]
		var blink: float = 1.0 if float(m["life"]) > 3.0 else (0.4 + 0.6 * absf(sin(_time * 8.0)))
		c.draw_circle(p, 22, Color(0, 0, 0, 0.45 * blink))
		var sym := marker_symbol(int(m["kind"]), p)
		if int(m["kind"]) == Collectible.Kind.RARE:
			c.draw_polyline(sym, Color(col, 0.95 * blink), 5.0, true)
		else:
			c.draw_colored_polygon(sym, Color(col, 0.95 * blink))
		var tip := p + Vector2(cos(ang), sin(ang)) * 34.0
		var side := Vector2(-sin(ang), cos(ang)) * 10.0
		c.draw_colored_polygon(PackedVector2Array([tip, p + Vector2(cos(ang), sin(ang)) * 22.0 + side, p + Vector2(cos(ang), sin(ang)) * 22.0 - side]), Color(col, blink))
