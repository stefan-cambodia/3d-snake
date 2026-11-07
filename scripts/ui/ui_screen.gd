class_name UiScreen
extends Control
## Base class for full-screen menus: animated show/hide, back handling and
## helpers for building consistent, touch-friendly layouts.

signal back_requested

var is_open: bool = false
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	is_open = true
	visible = true
	_on_open()
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(0.97, 0.97)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.28)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.16)
	_tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.16)
	_tween.chain().tween_callback(func() -> void: visible = false)


func _on_open() -> void:
	pass


## A wide, tall button with press animation and click sound.
static func make_button(text: String, primary: bool = false, min_width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 74 if primary else 64)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		var st := UiTheme.box(Color(0.86, 0.66, 0.32, 0.96), 20, Color(1.0, 0.9, 0.62), 2, 14)
		st.content_margin_left = 30
		st.content_margin_right = 30
		var hv := st.duplicate() as StyleBoxFlat
		hv.bg_color = Color(0.95, 0.76, 0.4)
		var pr := st.duplicate() as StyleBoxFlat
		pr.bg_color = Color(0.7, 0.52, 0.22)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", pr)
		b.add_theme_stylebox_override("hover_pressed", pr)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0.1, 0.07, 0.03))
		b.add_theme_font_override("font", UiTheme.font("bold"))
		b.add_theme_font_size_override("font_size", 30)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.18))
	b.pressed.connect(func() -> void: AudioManager.ui_click())
	return b


static func make_title(text: String, size: int = 54) -> Label:
	var l := UiTheme.label(text, size, "title", UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Centered panel with title, returns the content VBox.
func make_panel(title_key: String, width: float = 760.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)
	if title_key != "":
		vb.add_child(make_title(title_key, 44))
		var sep := ColorRect.new()
		sep.color = UiTheme.GOLD_DIM
		sep.custom_minimum_size = Vector2(0, 2)
		vb.add_child(sep)
	center.add_child(panel)
	return vb


## Dimmed backdrop behind panels.
func add_backdrop(alpha: float = 0.55) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.015, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
