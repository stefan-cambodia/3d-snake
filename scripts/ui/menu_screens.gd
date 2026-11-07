class_name MenuScreens
extends RefCounted
## Factory for the menu screens (keeps each screen compact and consistent).


## Options are translation keys (re-translated automatically on language change).
static func segmented(options: Array, selected: int, on_select: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.button_pressed = i == selected
		var idx := i
		scroll_friendly(b)
		b.pressed.connect(func() -> void:
			if is_scrolling(b):
				return
			AudioManager.play("ui_toggle", -6.0)
			on_select.call(idx))
		row.add_child(b)
	return row


## A grid of mutually exclusive toggle buttons (e.g. the language picker).
## Option texts are shown as given (not translated).
static func choice_grid(options: Array, selected: int, columns: int, on_select: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_font_override("font", UiTheme.font("picker"))
		b.button_pressed = i == selected
		var idx := i
		scroll_friendly(b)
		b.pressed.connect(func() -> void:
			if is_scrolling(b):
				return
			AudioManager.play("ui_toggle", -6.0)
			on_select.call(idx))
		grid.add_child(b)
	return grid


static func setting_row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var l := UiTheme.label(label_key, 24, "body", UiTheme.CREAM)
	l.custom_minimum_size = Vector2(250, 56)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


static func slider(value: float, min_v: float, max_v: float, step: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 48)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_change)
	return s


static func toggle(on: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(0, 52)
	c.toggled.connect(func(v: bool) -> void:
		AudioManager.play("ui_toggle", -6.0)
		on_change.call(v))
	return c


static func section(title_key: String) -> Label:
	var l := UiTheme.label(title_key, 22, "semibold", UiTheme.GOLD)
	l.custom_minimum_size = Vector2(0, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## Let a touch drag that starts on this button scroll the ScrollContainer around
## it (by default the button swallows the drag and the list cannot be scrolled
## from there). Pair with is_scrolling() in the button's pressed handler.
static func scroll_friendly(b: BaseButton) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS


## True while the ScrollContainer holding this control is being drag-scrolled:
## a press released at the end of a swipe must not count as a tap.
static func is_scrolling(c: Control) -> bool:
	var n := c.get_parent()
	while n:
		if n is ScrollContainer:
			return bool(n.get_meta("dragging", false))
		n = n.get_parent()
	return false


static func scroll_body(vb: VBoxContainer, max_height: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_started.connect(func() -> void: sc.set_meta("dragging", true))
	sc.scroll_ended.connect(func() -> void: sc.set_meta("dragging", false))
	sc.custom_minimum_size = Vector2(0, max_height)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	sc.add_child(inner)
	return inner


static func stat_tile(value: String, caption_key: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := UiTheme.label(value, 30, "bold", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	a.name = "Value"
	v.add_child(a)
	v.add_child(UiTheme.label(caption_key, 17, "body", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return v


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]
