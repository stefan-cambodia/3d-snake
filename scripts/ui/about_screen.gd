class_name AboutScreen
extends UiScreen


func _ready() -> void:
	add_backdrop(0.6)
	var vb := make_panel("ABOUT_TITLE", 900)
	var body := MenuScreens.scroll_body(vb, 440)
	body.add_child(MenuScreens.section("ABOUT_HOW"))
	for key in ["HOW_1", "HOW_2", "HOW_3", "HOW_4", "HOW_5", "HOW_6"]:
		var l := UiTheme.label(key, 21, "body", UiTheme.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
	body.add_child(MenuScreens.section("ABOUT_CREDITS"))
	var credits := UiTheme.label("ABOUT_TEXT", 19, "light", UiTheme.MUTED)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(credits)
	var ver := UiTheme.label("", 17, "light", UiTheme.MUTED)
	ver.text = "v%s · Godot %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Engine.get_version_info()["string"]]
	body.add_child(ver)
	var back := make_button("COMMON_BACK", true, 300)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_requested.emit())
	vb.add_child(back)
