class_name GameOverScreen
extends UiScreen
## End-of-run summary with animated score, comparison with the best score,
## run stats and newly unlocked rewards. Buttons arm after a short delay so a
## finger still on the screen from steering cannot skip the summary by accident.

signal retry_requested
signal menu_requested

const ARM_DELAY := 0.8

var _title: Label
var _cause: Label
var _score: Label
var _compare: Label
var _badge: Label
var _stats: HBoxContainer
var _unlocks: VBoxContainer
var _buttons: Array[Button] = []
var _target_score: int = 0
var _shown_score: float = 0.0
var _armed_in: float = 0.0


func _ready() -> void:
	add_backdrop(0.55)
	var vb := make_panel("", 820)
	vb.add_theme_constant_override("separation", 10)
	_title = make_title("OVER_TITLE", 46)
	vb.add_child(_title)
	_cause = UiTheme.label("", 21, "light", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_cause)
	_score = UiTheme.label("0", 88, "title", UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_score.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_score.add_theme_constant_override("outline_size", 8)
	vb.add_child(_score)
	_badge = UiTheme.label("OVER_NEW_BEST", 26, "bold", Color(0.1, 0.07, 0.02), HORIZONTAL_ALIGNMENT_CENTER)
	var badge_bg := PanelContainer.new()
	badge_bg.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, 14))
	badge_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_bg.add_child(_badge)
	_badge.custom_minimum_size = Vector2(260, 42)
	vb.add_child(badge_bg)
	_compare = UiTheme.label("", 22, "body", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_compare)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	vb.add_child(_stats)
	_unlocks = VBoxContainer.new()
	vb.add_child(_unlocks)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var retry := make_button("OVER_RETRY", true, 340)
	retry.pressed.connect(func() -> void:
		if _armed_in <= 0.0:
			retry_requested.emit())
	var menu := make_button("PAUSE_MENU", false, 300)
	menu.pressed.connect(func() -> void:
		if _armed_in <= 0.0:
			menu_requested.emit())
	row.add_child(menu)
	row.add_child(retry)
	_buttons = [retry, menu]
	vb.add_child(row)


## run: {score, length, stage, food, rare, combo, time, cause}; result from Profile.record_run.
func show_result(run: Dictionary, result: Dictionary) -> void:
	_target_score = int(run["score"])
	_shown_score = 0.0
	_score.text = "0"
	var cause: StringName = run.get("cause", &"")
	_cause.text = tr({&"wall": "CAUSE_WALL", &"obstacle": "CAUSE_OBSTACLE", &"self": "CAUSE_SELF"}.get(cause, "CAUSE_OBSTACLE"))
	var new_best: bool = result.get("new_best", false)
	_badge.get_parent().visible = new_best
	var prev := int(result.get("previous_best", 0))
	if new_best and prev > 0:
		_compare.text = tr("OVER_BEAT_BY") % (_target_score - prev)
	elif new_best:
		_compare.text = tr("OVER_FIRST_BEST")
	else:
		_compare.text = tr("OVER_BEST_IS") % [prev, prev - _target_score]
	for c in _stats.get_children():
		c.queue_free()
	_stats.add_child(MenuScreens.stat_tile("%.1f m" % float(run["length"]), "STAT_LENGTH"))
	_stats.add_child(MenuScreens.stat_tile(str(run["stage"]), "STAT_STAGE"))
	_stats.add_child(MenuScreens.stat_tile(str(run["food"]), "STAT_FOOD"))
	_stats.add_child(MenuScreens.stat_tile("x%d" % int(run["combo"]), "STAT_COMBO"))
	_stats.add_child(MenuScreens.stat_tile(MenuScreens.format_time(float(run["time"])), "STAT_TIME"))
	for c in _unlocks.get_children():
		c.queue_free()
	for u in result.get("unlocked", []):
		var key := "UNLOCK_SKIN" if u["type"] == "skin" else "UNLOCK_THEME"
		var l := UiTheme.label(tr(key) % tr(u["name"]), 22, "semibold", UiTheme.JADE, HORIZONTAL_ALIGNMENT_CENTER)
		_unlocks.add_child(l)
	_armed_in = ARM_DELAY
	for b in _buttons:
		b.modulate.a = 0.35
	open()


func _process(delta: float) -> void:
	if not is_open:
		return
	if _armed_in > 0.0:
		_armed_in -= delta
		if _armed_in <= 0.0:
			for b in _buttons:
				var tw := b.create_tween()
				tw.tween_property(b, "modulate:a", 1.0, 0.2)
	if _shown_score < float(_target_score):
		_shown_score = minf(_shown_score + maxf(float(_target_score) * delta * 1.4, 40.0 * delta), float(_target_score))
		_score.text = str(int(_shown_score))
