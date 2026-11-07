class_name PauseMenu
extends UiScreen

signal resume_requested
signal restart_requested
signal settings_requested
signal menu_requested

var _info: Label


func _ready() -> void:
	add_backdrop(0.5)
	var vb := make_panel("PAUSE_TITLE", 560)
	_info = UiTheme.label("", 22, "body", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_info)
	var resume := make_button("PAUSE_RESUME", true, 480)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	vb.add_child(resume)
	var restart := make_button("PAUSE_RESTART", false, 480)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	vb.add_child(restart)
	var settings := make_button("MENU_SETTINGS", false, 480)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	vb.add_child(settings)
	var menu := make_button("PAUSE_MENU", false, 480)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	vb.add_child(menu)


func set_info(score: int, stage: int, length: float) -> void:
	_info.text = tr("PAUSE_INFO") % [score, stage, length]
