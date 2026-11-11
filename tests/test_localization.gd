extends TestCase
## Translations (assets/i18n/strings.csv), language detection, font coverage,
## and that the UI still fits in every language.

const CSV_PATH := "res://assets/i18n/strings.csv"
## Base UI size (project viewport); landscape phones only get wider than this.
const UI_SIZE := Vector2(1280, 720)
## Quoted UPPER_SNAKE strings in scripts that are not translation keys.
const NOT_KEYS := ["SKIN_TEST"]


func _csv() -> Dictionary:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := f.get_csv_line()
	var rows := {}
	var order: Array[String] = []
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 2:
			continue
		rows[line[0]] = line
		order.append(line[0])
	return {"locales": Array(header.slice(1)), "rows": rows, "order": order}


func _placeholders(text: String) -> Array:
	var re := RegEx.create_from_string("%[-+ 0#]*[0-9]*(\\.[0-9]+)?[sdifxXc]")
	return re.search_all(text).map(func(m: RegExMatch) -> String: return m.get_string())


func test_csv_columns_are_the_supported_locales() -> void:
	var data := _csv()
	check_eq(data["locales"], Array(Localization.LOCALES), "CSV columns match Localization.LOCALES (same order)")
	check(Localization.LOCALES.has("km"), "Khmer is supported")
	var loaded := TranslationServer.get_loaded_locales()
	for code in Localization.LOCALES:
		check(loaded.has(code), "translation loaded for %s" % code)


func test_every_key_is_translated_with_the_same_placeholders() -> void:
	var data := _csv()
	var locales: Array = data["locales"]
	for key in data["order"]:
		var row: PackedStringArray = data["rows"][key]
		check_eq(row.size(), locales.size() + 1, "%s has a cell for every locale" % key)
		var en_ph := _placeholders(row[1])
		for i in range(1, row.size()):
			var code: String = locales[i - 1]
			check(row[i].strip_edges() != "", "%s translated in %s" % [key, code])
			check_eq(_placeholders(row[i]), en_ph, "%s placeholders in %s" % [key, code])


func test_godot_serves_the_csv_translations() -> void:
	var data := _csv()
	var locales: Array = data["locales"]
	for i in locales.size():
		var t := TranslationServer.get_translation_object(locales[i])
		check(t != null and t.locale == locales[i], "translation object for %s" % locales[i])
		if t == null:
			continue
		for key in data["order"]:
			var expected: String = data["rows"][key][i + 1]
			if str(t.get_message(key)) != expected:
				check_eq(str(t.get_message(key)), expected, "%s/%s served from the CSV (re-import?)" % [locales[i], key])
				break
	check_eq(Localization.language_name("km"), "ខ្មែរ", "Khmer's own name")
	check_eq(Localization.language_name("fr"), "Français", "French's own name")


func test_keys_used_in_scripts_exist() -> void:
	var keys: Dictionary = _csv()["rows"]
	var re := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var dirs := ["res://scripts"]
	var used := 0
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var da := DirAccess.open(d)
		for sub in da.get_directories():
			dirs.append(d + "/" + sub)
		for fname in da.get_files():
			if not fname.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(d + "/" + fname)
			for m in re.search_all(src):
				var k := m.get_string(1)
				if NOT_KEYS.has(k):
					continue
				used += 1
				check(keys.has(k), "key %s (used in %s) exists in strings.csv" % [k, fname])
	check(used > 100, "found the keys used by the UI (%d)" % used)


func test_detect_device_language() -> void:
	var cases := {
		"fr_BE": "fr", "fr": "fr", "km_KH": "km", "km": "km", "th_TH": "th", "en_GB": "en",
		"pt_PT": "pt_BR", "pt_BR": "pt_BR", "zh_TW": "zh_CN", "zh-Hans-CN": "zh_CN",
		"ja_JP": "ja", "ko_KR": "ko", "in_ID": "id", "id_ID": "id", "ru_RU": "ru",
		"tr_TR": "tr", "de_AT": "de", "es_MX": "es", "it_IT": "it", "vi_VN": "vi", "vi": "vi", "hi_IN": "hi", "ms_MY": "ms", "fil_PH": "fil", "tl_PH": "fil", "nl_NL": "en", "": "en",
	}
	for sys in cases:
		check_eq(Localization.detect(sys), cases[sys], "device locale '%s'" % sys)


func _chain(base: Font, fallback_files: Array) -> Array[Font]:
	var chain: Array[Font] = [base]
	for n in fallback_files:
		chain.append(load(UiTheme.FALLBACK_DIR + n))
	return chain


func _missing_chars(chain: Array[Font], texts: Array) -> Dictionary:
	var missing := {}
	for text in texts:
		for ch in str(text):
			if ch.strip_edges() == "" or missing.has(ch):
				continue
			var cp := ch.unicode_at(0)
			if not chain.any(func(f: Font) -> bool: return f.has_char(cp)):
				missing[ch] = str(text).left(40)
	return missing


## Every character of every translation must exist in the title and body fonts
## plus the fallbacks of that language (re-run tools/build_fonts.py if not).
func test_fonts_cover_every_translation() -> void:
	var data := _csv()
	var locales: Array = data["locales"]
	for i in locales.size():
		var code: String = locales[i]
		var texts: Array = []
		for key in data["order"]:
			texts.append(data["rows"][key][i + 1])
		for kind in ["title", "body"]:
			var chain := _chain(UiTheme.base_font(kind, code), UiTheme.fallback_names(code))
			var missing := _missing_chars(chain, texts)
			check(missing.is_empty(), "%s %s font covers all text; missing: %s" % [code, kind, str(missing).left(300)])
	# The language picker shows every language's own name, whatever the locale.
	var names: Array = Array(data["rows"]["LANGUAGE_NAME"]).slice(1)
	var picker := _chain(UiTheme.base_font("picker", "en"), UiTheme.FALLBACKS_ALL)
	check(_missing_chars(picker, names).is_empty(), "picker font shows every language name")
	check(UiTheme.fallback_names("en").is_empty(), "Latin languages keep the compact primary fonts")
	check_eq(UiTheme.fallback_names("km"), ["NotoSansKhmer-Subset.ttf"], "Khmer uses Noto Sans Khmer")
	check_eq(UiTheme.fallback_names("hi"), ["NotoSansDevanagari-Subset.ttf"], "Hindi uses Noto Sans Devanagari")
	check_eq(UiTheme.base_font("logo", "vi"), UiTheme.base_font("title", "en"), "the game's name keeps Cinzel in Vietnamese")
	# Vietnamese is drawn with one font, so no word mixes two typefaces.
	var vi_font := UiTheme.base_font("body", "vi")
	check(vi_font != UiTheme.base_font("body", "en"), "Vietnamese has a font of its own")
	check(_missing_chars([vi_font], ["0123456789 x+-.,:;!?%()/&", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "·—•"]).is_empty(), "the Vietnamese font has digits, Latin letters and punctuation")
	var before := Localization.current()
	Localization.apply("vi")
	check_eq((UiTheme.font("body") as FontVariation).base_font, vi_font, "choosing Vietnamese switches the body font")
	check_eq((UiTheme.font("title") as FontVariation).base_font, vi_font, "and the title font")
	Localization.apply("en")
	check_eq((UiTheme.font("body") as FontVariation).base_font, UiTheme.base_font("body", "en"), "English gets Outfit back")
	Localization.apply(before)


## Long or tall translations must not push menus off screen.
func test_ui_fits_in_every_language() -> void:
	var main := make_main()
	var ui: UiRoot = main.ui
	var before := Localization.current()
	var quit: Button = ui.main_menu.find_child("QuitButton", true, false)
	check(quit != null, "main menu has a Quit button")
	var col := quit.get_parent() as Control if quit else null
	# The fit scale must sit on a node whose parent is not a Container (containers
	# reset their children's scale), and must really be applied at phone height.
	var scaled: Control = ui.main_menu._margin
	check(not (scaled.get_parent() is Container), "main menu scales a node containers leave alone")
	# Give the (headless) window a phone's landscape proportions.
	var old_size := tree.root.size
	tree.root.size = Vector2i(UI_SIZE)
	var screens: Array[UiScreen] = [ui.pause_menu, ui.game_over, ui.settings, ui.records, ui.about, ui.skins]
	for code in Localization.LOCALES:
		Localization.apply(code)
		for s in screens:
			s._on_open()
		await tree.process_frame
		await tree.process_frame
		if col:
			var vis := tree.root.get_visible_rect()
			var menu_bottom := _content_bottom(col)
			check(menu_bottom <= vis.end.y + 0.5, "%s: last menu line on screen (%.0f / %.0f)" % [code, menu_bottom, vis.end.y])
			var need := col.get_combined_minimum_size()
			var k: float = ui.main_menu.fit_scale(UI_SIZE.y)
			check((need.y + MainMenu.V_MARGINS) * k <= UI_SIZE.y + 0.5, "%s: main menu fits vertically (needs %.0f px, scale %.2f)" % [code, need.y + MainMenu.V_MARGINS, k])
			check(need.x * k <= UI_SIZE.x * 0.5, "%s: main menu column stays on the left half (%.0f px)" % [code, need.x * k])
		for s in screens:
			var panel := s.find_children("*", "PanelContainer", true, false)
			if panel.is_empty():
				continue
			var need := (panel[0] as Control).get_combined_minimum_size()
			check(need.x <= UI_SIZE.x - 40.0 and need.y <= UI_SIZE.y, "%s: %s panel fits (%s)" % [code, s.get_script().get_global_name(), str(need)])
		for key in ["HUD_GO", "HUD_SURGE", "HUD_RELIC", "HUD_NEW_BEST", "HUD_CLOSE_CALL"]:
			var w := UiTheme.font("title").get_string_size(tr(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
			check(w <= 800.0, "%s: banner %s fits (%.0f px)" % [code, key, w])
	tree.root.size = old_size
	Localization.apply(before)
	dispose_main(main)


## In Skins & Sanctuaries a name can take two lines (and Khmer lines are tall): the swatch
## and the name must stay inside their card in every language.
func test_skin_and_sanctuary_names_stay_inside_their_cards() -> void:
	var main := make_main()
	var ui: UiRoot = main.ui
	var before := Localization.current()
	var old_size := tree.root.size
	tree.root.size = Vector2i(UI_SIZE)
	ui.show_only(ui.skins)
	for code in Localization.LOCALES:
		Localization.apply(code)
		ui.skins._on_open()
		await tree.process_frame
		await tree.process_frame
		var cards: Array[Node] = []
		cards.append_array(ui.skins._skin_grid.get_children())
		cards.append_array(ui.skins._theme_row.get_children())
		check_eq(cards.size(), SkinCatalog.SKINS.size() + WorldThemes.THEMES.size(), "%s: one card per skin and sanctuary" % code)
		for c in cards:
			var card := c as Control
			var box := card.get_child(0) as Control
			# The box is anchored inside the card with a top and bottom inset; a Button
			# does not grow with its children, so compare with the card's own height.
			var room := card.size.y - box.offset_top + box.offset_bottom
			var need := box.get_combined_minimum_size().y
			var label := box.get_child(box.get_child_count() - 1) as Label
			check(need <= room + 0.5, "%s: card content of '%s' fits (%.0f px in %.0f)" % [code, tr(label.text), need, room])
	tree.root.size = old_size
	Localization.apply(before)
	dispose_main(main)


## Bottom edge on screen of the lowest visible control in a column.
func _content_bottom(col: Control) -> float:
	var bottom := 0.0
	for c in col.get_children():
		if c is Control and (c as Control).visible and (c as Control).get_combined_minimum_size().y > 0.0:
			bottom = maxf(bottom, (c as Control).get_global_rect().end.y)
	return bottom
