class_name SkinsScreen
extends UiScreen
## Skin and sanctuary selection. The panel sits on the left so the live serpent
## (shown in a close-up camera) previews the highlighted skin on the right.

signal skin_previewed(id: String)
signal theme_selected(id: String)

var _skin_grid: GridContainer
var _theme_row: HBoxContainer
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(panel)
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 30)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	m.add_child(vb)
	vb.add_child(make_title("SKINS_TITLE", 40))
	var body := MenuScreens.scroll_body(vb, 400)
	body.add_child(MenuScreens.section("SKINS_SERPENTS"))
	_skin_grid = GridContainer.new()
	_skin_grid.columns = 4
	_skin_grid.add_theme_constant_override("h_separation", 10)
	_skin_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_skin_grid)
	_detail = UiTheme.label("", 20, "body", UiTheme.MUTED)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 52)
	body.add_child(_detail)
	body.add_child(MenuScreens.section("SKINS_SANCTUARIES"))
	_theme_row = HBoxContainer.new()
	_theme_row.add_theme_constant_override("separation", 10)
	body.add_child(_theme_row)
	var back := make_button("COMMON_BACK", true, 280)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_requested.emit())
	vb.add_child(back)


func _on_open() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in _skin_grid.get_children():
		c.queue_free()
	for c in _theme_row.get_children():
		c.queue_free()
	for s in SkinCatalog.SKINS:
		_skin_grid.add_child(_skin_card(s))
	for t in WorldThemes.THEMES:
		_theme_row.add_child(_theme_card(t))
	_describe_skin(SkinCatalog.get_skin(Profile.selected_skin))


func _swatch(colors: Array[Color]) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	g.colors = PackedColorArray([colors[0], colors[1], colors[2], colors[3]])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 64
	var tr_ := TextureRect.new()
	tr_.texture = gt
	tr_.custom_minimum_size = Vector2(120, 64)
	tr_.stretch_mode = TextureRect.STRETCH_SCALE
	tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr_


func _card_base(selected: bool, locked: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(132, 124)
	var st := UiTheme.box(Color(0.06, 0.09, 0.08, 0.9), 16, UiTheme.GOLD if selected else Color(1, 1, 1, 0.1), 3 if selected else 1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("hover_pressed", st)
	if locked:
		b.modulate = Color(0.6, 0.6, 0.6)
	return b


func _skin_card(s: Dictionary) -> Button:
	var id: String = s["id"]
	var unlocked := Profile.is_skin_unlocked(id)
	var b := _card_base(id == Profile.selected_skin, not unlocked)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 8
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	v.add_child(_swatch([s["back"], s["pattern"], s["side"], s["belly"]]))
	var name := UiTheme.label(s["name"], 16, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	if not unlocked:
		var lock := UiTheme.label("🔒", 22, "body", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		lock.position = Vector2(96, 6)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	b.pressed.connect(func() -> void:
		AudioManager.ui_click()
		_describe_skin(s)
		skin_previewed.emit(id)
		if unlocked:
			Profile.selected_skin = id
			Profile.save_profile()
			_rebuild_selection())
	return b


func _rebuild_selection() -> void:
	# Cheap refresh of borders without losing scroll position.
	var i := 0
	for c in _skin_grid.get_children():
		var s: Dictionary = SkinCatalog.SKINS[i]
		var sel: bool = s["id"] == Profile.selected_skin
		var st := UiTheme.box(Color(0.06, 0.09, 0.08, 0.9), 16, UiTheme.GOLD if sel else Color(1, 1, 1, 0.1), 3 if sel else 1)
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			(c as Button).add_theme_stylebox_override(k, st)
		i += 1


func _describe_skin(s: Dictionary) -> void:
	var rule: Dictionary = s["unlock"]
	if Profile.requirement_met(rule):
		_detail.text = tr(s["name"]) + " — " + tr("SKINS_UNLOCKED")
	else:
		_detail.text = tr(s["name"]) + " — " + _rule_text(rule)


func _rule_text(rule: Dictionary) -> String:
	var have := float(Profile.stats.get(rule["stat"], 0))
	var need := float(rule["value"])
	var key: String = "REQ_" + str(rule["stat"]).to_upper()
	if rule["stat"] == "best_length":
		return tr(key) % [need, have]
	return tr(key) % [int(need), int(have)]


func _theme_card(t: Dictionary) -> Button:
	var id: String = t["id"]
	var unlocked := Profile.is_theme_unlocked(id)
	var b := _card_base(id == Profile.selected_theme, not unlocked)
	b.custom_minimum_size = Vector2(178, 110)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 8
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var sw := _swatch([t["sky_top"], t["sky_horizon"], t["grass_b"], t["water_deep"]])
	sw.custom_minimum_size = Vector2(160, 54)
	v.add_child(sw)
	var name := UiTheme.label(t["name"], 17, "semibold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	b.pressed.connect(func() -> void:
		AudioManager.ui_click()
		if unlocked:
			Profile.selected_theme = id
			Profile.save_profile()
			theme_selected.emit(id)
			_rebuild()
		else:
			_detail.text = tr(t["name"]) + " — " + _rule_text(t["unlock"]))
	return b
