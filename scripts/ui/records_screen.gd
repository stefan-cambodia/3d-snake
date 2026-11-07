class_name RecordsScreen
extends UiScreen

var _table: VBoxContainer
var _stats: GridContainer


func _ready() -> void:
	add_backdrop(0.6)
	var vb := make_panel("REC_TITLE", 960)
	var body := MenuScreens.scroll_body(vb, 450)
	body.add_child(MenuScreens.section("REC_TOP"))
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 4)
	body.add_child(_table)
	body.add_child(MenuScreens.section("REC_LIFETIME"))
	_stats = GridContainer.new()
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", 8)
	_stats.add_theme_constant_override("v_separation", 14)
	body.add_child(_stats)
	var back := make_button("COMMON_BACK", true, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_requested.emit())
	vb.add_child(back)


func _row(cells: Array, header: bool, highlight: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.93, 0.74, 0.38, 0.14) if highlight else Color(1, 1, 1, 0.03 if not header else 0.0), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var widths := [80, 190, 170, 120, 220]
	for i in cells.size():
		var l := UiTheme.label(str(cells[i]), 18 if header else 22, "semibold" if not header else "body", UiTheme.GOLD if header else UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(widths[i], 44)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	return p


func _on_open() -> void:
	for c in _table.get_children():
		c.queue_free()
	for c in _stats.get_children():
		c.queue_free()
	_table.add_child(_row([tr("REC_RANK"), tr("REC_SCORE"), tr("STAT_LENGTH"), tr("STAT_STAGE"), tr("REC_DATE")], true, false))
	if Profile.high_scores.is_empty():
		var l := UiTheme.label("REC_EMPTY", 22, "light", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(0, 80)
		_table.add_child(l)
	for i in Profile.high_scores.size():
		var e: Dictionary = Profile.high_scores[i]
		_table.add_child(_row(["#%d" % (i + 1), e["score"], "%.1f m" % float(e["length"]), e["stage"], e.get("date", "")], false, i == 0))
	var s := Profile.stats
	var tiles := [
		[str(s["runs"]), "REC_RUNS"], [str(s["total_food"]), "REC_FOOD"], [str(s["total_rare"]), "REC_RELICS"], [str(s["total_energy"]), "REC_CRYSTALS"],
		["%.1f m" % float(s["best_length"]), "REC_BEST_LENGTH"], [str(s["best_stage"]), "REC_BEST_STAGE"], ["x%d" % int(s["best_combo"]), "REC_BEST_COMBO"], [MenuScreens.format_time(float(s["play_time"])), "REC_PLAYTIME"],
	]
	for t in tiles:
		_stats.add_child(MenuScreens.stat_tile(t[0], t[1]))
