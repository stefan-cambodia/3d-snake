class_name MainMenu
extends UiScreen
## Title screen. The left column holds the logo and buttons; the right side
## shows the live 3D sanctuary with the attract-mode serpent.

signal play_requested
signal screen_requested(screen: String)

var _best: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.02, 0.02, 0.82))
	g.set_color(1, Color(0.01, 0.02, 0.02, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(0.62, 0.5)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	UiRoot.full_bleed(grad)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)

	var t1 := UiTheme.label("SERPENT", 66, "title", UiTheme.GOLD)
	var t2 := UiTheme.label("SANCTUM", 66, "title", UiTheme.GOLD)
	for t in [t1, t2]:
		t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.7))
		t.add_theme_constant_override("outline_size", 10)
		t.custom_minimum_size = Vector2(0, 62)
		col.add_child(t)
	var tag := UiTheme.label("MENU_TAGLINE", 22, "light", UiTheme.MUTED)
	col.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer)

	var play := make_button("MENU_PLAY", true, 380)
	play.pressed.connect(func() -> void: play_requested.emit())
	col.add_child(play)
	_buttons.append(play)
	for entry in [["MENU_SKINS", "skins"], ["MENU_RECORDS", "records"], ["MENU_SETTINGS", "settings"], ["MENU_ABOUT", "about"]]:
		var b := make_button(entry[0], false, 380)
		b.custom_minimum_size.y = 56
		var scr: String = entry[1]
		b.pressed.connect(func() -> void: screen_requested.emit(scr))
		col.add_child(b)
		_buttons.append(b)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)
	_best = UiTheme.label("", 22, "semibold", UiTheme.CREAM)
	col.add_child(_best)


func _on_open() -> void:
	_best.text = tr("MENU_BEST") % Profile.best_score() if Profile.best_score() > 0 else tr("MENU_FIRST_RUN")
	# Staggered entrance of the buttons.
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.05 * i + 0.1)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
