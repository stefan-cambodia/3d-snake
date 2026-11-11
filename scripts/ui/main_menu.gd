class_name MainMenu
extends UiScreen
## Title screen. The left column holds the logo and buttons; the right side
## shows the live 3D sanctuary with the attract-mode serpent.

signal play_requested
signal screen_requested(screen: String)
signal quit_requested

## Top + bottom margins around the column.
const V_MARGINS := 48.0
## Never shrink the menu below this (readability).
const MIN_FIT_SCALE := 0.8

var _best: Label
var _buttons: Array[Button] = []
var _col: VBoxContainer
## Scaled as a whole when the column is too tall (a container would reset the
## scale of its children, so the scale goes on this non-container child).
var _margin: MarginContainer


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
	_margin = margin
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)
	_col = col

	# The game's name, the same in every language.
	var title := UiTheme.label("3D SNAKE", 74, "logo", UiTheme.GOLD)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.7))
	title.add_theme_constant_override("outline_size", 10)
	title.custom_minimum_size = Vector2(0, 70)
	col.add_child(title)
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
		b.custom_minimum_size.y = 52
		var scr: String = entry[1]
		b.pressed.connect(func() -> void: screen_requested.emit(scr))
		col.add_child(b)
		_buttons.append(b)
	# A quit button everywhere except iOS and the web, where apps don't close themselves.
	if not (OS.has_feature("ios") or OS.has_feature("web")):
		var quit := make_button("MENU_QUIT", false, 380)
		quit.name = "QuitButton"
		quit.custom_minimum_size.y = 52
		quit.add_theme_color_override("font_color", UiTheme.MUTED)
		quit.pressed.connect(func() -> void: quit_requested.emit())
		col.add_child(quit)
		_buttons.append(quit)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)
	_best = UiTheme.label("", 22, "semibold", UiTheme.CREAM)
	col.add_child(_best)
	# Scripts with tall lines (Thai, CJK...) can need more height than a phone has.
	col.minimum_size_changed.connect(_fit_column)
	resized.connect(_fit_column)


## Scale that makes the menu fit in the given height (1 when it already fits).
func fit_scale(available_height: float) -> float:
	var need := _col.get_combined_minimum_size().y + V_MARGINS
	return clampf(available_height / need, MIN_FIT_SCALE, 1.0)


func _fit_column() -> void:
	var k := fit_scale(size.y)
	_margin.scale = Vector2(k, k)
	# Keep the scaled menu filling the screen height (its anchors span the menu).
	_margin.size = size / k


func _on_open() -> void:
	_best.text = tr("MENU_BEST") % Profile.best_score() if Profile.best_score() > 0 else tr("MENU_FIRST_RUN")
	# Staggered entrance of the buttons.
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.05 * i + 0.1)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
