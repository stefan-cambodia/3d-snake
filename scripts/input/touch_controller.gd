class_name TouchController
extends Node
## Multi-touch steering for phones (plus keyboard/gamepad for desktop testing).
##
## Schemes:
##  0 DRAG     - touch anywhere and slide horizontally; analog, floating anchor
##               (reversing direction is instant, no dead travel).
##  1 HALVES   - hold the left / right half of the screen to turn.
##  2 JOYSTICK - floating thumb-stick in the lower corner.
## Boost and pause are on-screen zones handled here (not GUI buttons) so they
## work with a second finger while the first one is steering.

signal pause_requested
signal boost_pressed

enum Scheme { DRAG, HALVES, JOYSTICK }

var enabled: bool = false:
	set(v):
		enabled = v
		if not v:
			release_all()
var scheme: int = Scheme.DRAG
var sensitivity: float = 1.0
var left_handed: bool = false

## Outputs.
var steer: float = 0.0
var boost: bool = false

## Hit zones in viewport coordinates (set by the HUD on layout).
var boost_zone: Rect2 = Rect2()
var pause_zone: Rect2 = Rect2()

## State exposed for HUD feedback.
var steer_touch_active: bool = false
var steer_anchor: Vector2 = Vector2.ZERO
var steer_pos: Vector2 = Vector2.ZERO
var joystick_radius: float = 90.0

var _steer_index: int = -1
var _boost_indices: Dictionary = {}
var _half_touches: Dictionary = {}
var _pause_index: int = -1
var _touch_steer: float = 0.0


func release_all() -> void:
	_steer_index = -1
	_boost_indices.clear()
	_half_touches.clear()
	_pause_index = -1
	_touch_steer = 0.0
	steer = 0.0
	boost = false
	steer_touch_active = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func drag_range() -> float:
	return _view_size().y * 0.095 / clampf(sensitivity, 0.3, 3.0)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and not e.canceled:
			_on_press(e.index, e.position)
		else:
			_on_release(e.index, e.position, e.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_drag(d.index, d.position)
		get_viewport().set_input_as_handled()


func _on_press(index: int, pos: Vector2) -> void:
	if pause_zone.has_point(pos):
		_pause_index = index
		return
	if boost_zone.has_point(pos):
		_boost_indices[index] = true
		boost_pressed.emit()
		return
	match scheme:
		Scheme.HALVES:
			_half_touches[index] = -1.0 if pos.x < _view_size().x * 0.5 else 1.0
		Scheme.JOYSTICK:
			var size := _view_size()
			var in_zone := pos.y > size.y * 0.35 and ((pos.x < size.x * 0.5) != left_handed)
			if in_zone and _steer_index == -1:
				_steer_index = index
				steer_anchor = pos
				steer_pos = pos
				steer_touch_active = true
		_:
			if _steer_index == -1:
				_steer_index = index
				steer_anchor = pos
				steer_pos = pos
				steer_touch_active = true
	_recompute()


func _on_drag(index: int, pos: Vector2) -> void:
	if index != _steer_index:
		return
	steer_pos = pos
	var dx := pos.x - steer_anchor.x
	if scheme == Scheme.DRAG:
		var rng := drag_range()
		# Floating anchor: never more than one full range away from the finger.
		if absf(dx) > rng:
			steer_anchor.x = pos.x - signf(dx) * rng
		steer_anchor.y = lerpf(steer_anchor.y, pos.y, 0.15)
	elif scheme == Scheme.JOYSTICK:
		var off := pos - steer_anchor
		if off.length() > joystick_radius * 1.6:
			steer_anchor = pos - off.normalized() * joystick_radius * 1.6
	_recompute()


func _on_release(index: int, pos: Vector2, canceled: bool) -> void:
	if index == _pause_index:
		_pause_index = -1
		if pause_zone.grow(24.0).has_point(pos) and not canceled:
			pause_requested.emit()
		return
	_boost_indices.erase(index)
	_half_touches.erase(index)
	if index == _steer_index:
		_steer_index = -1
		steer_touch_active = false
	_recompute()


func _recompute() -> void:
	var s := 0.0
	match scheme:
		Scheme.HALVES:
			for i in _half_touches:
				s += float(_half_touches[i])
			s = clampf(s, -1.0, 1.0)
		Scheme.JOYSTICK:
			if _steer_index != -1:
				s = _shape((steer_pos.x - steer_anchor.x) / (joystick_radius / clampf(sensitivity, 0.3, 3.0)))
		_:
			if _steer_index != -1:
				s = _shape((steer_pos.x - steer_anchor.x) / drag_range())
	_touch_steer = s


## Small dead zone, then a gentle expo curve for fine control near centre.
static func _shape(v: float) -> float:
	v = clampf(v, -1.0, 1.0)
	var a := absf(v)
	var dz := 0.06
	if a < dz:
		return 0.0
	a = (a - dz) / (1.0 - dz)
	a = a * 0.75 + a * a * a * 0.25
	return signf(v) * a


func _process(_delta: float) -> void:
	if not enabled:
		return
	var key := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		key -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		key += 1.0
	var joy := 0.0
	if Input.get_connected_joypads().size() > 0:
		joy = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		if absf(joy) < 0.15:
			joy = 0.0
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
			joy = -1.0
		if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
			joy = 1.0
	if key != 0.0:
		steer = key
	elif joy != 0.0:
		steer = joy
	else:
		steer = _touch_steer
	var kb_boost := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	if Input.get_connected_joypads().size() > 0:
		kb_boost = kb_boost or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4
	boost = not _boost_indices.is_empty() or kb_boost


func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_P):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
