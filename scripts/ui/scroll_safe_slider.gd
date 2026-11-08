class_name ScrollSafeSlider
extends HSlider
## A slider for scrolling lists. A plain HSlider jumps to the point where a
## finger lands, so swiping the settings list up or down from a slider changed
## its value (music volume, steering sensitivity...). Here a transparent layer
## on top reads the gesture first: a mostly horizontal drag moves the slider, a
## vertical one is left to the ScrollContainer, and a tap still sets the value
## where it lands.

## Finger travel (UI px) before a drag counts as horizontal.
const SLOP := 12.0

var _catcher := Control.new()
var _down := false
var _dragging := false
var _start := Vector2.ZERO


func _init() -> void:
	# The slider itself never sees the pointer; the catcher does, and lets
	# whatever it does not use reach the ScrollContainer.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher.name = "TouchCatcher"
	_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(handle_input)
	add_child(_catcher, false, Node.INTERNAL_MODE_FRONT)


func handle_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_down = true
			_dragging = false
			_start = mb.position
		else:
			# A short tap jumps to the point, like a plain slider. The release is
			# not accepted, so the ScrollContainer still ends its own touch.
			if _down and not _dragging and mb.position.distance_to(_start) < SLOP and not MenuScreens.is_scrolling(self):
				set_from_position(mb.position.x)
			_down = false
			_dragging = false
		return
	var mm := event as InputEventMouseMotion
	if mm and _down:
		var d := mm.position - _start
		if not _dragging and absf(d.x) > SLOP and absf(d.x) > absf(d.y) and not MenuScreens.is_scrolling(self):
			_dragging = true
		if _dragging:
			set_from_position(mm.position.x)
			_catcher.accept_event() # keep the list still while adjusting


## Same mapping as Godot's slider: the grabber's centre follows the finger.
func set_from_position(x: float) -> void:
	var gw := float(get_theme_icon("grabber").get_width())
	var span := maxf(size.x - gw, 1.0)
	set_as_ratio(clampf((x - gw * 0.5) / span, 0.0, 1.0))
