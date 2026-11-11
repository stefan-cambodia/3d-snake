class_name UiTheme
extends RefCounted
## The game's visual language for UI: fonts, palette and styled controls.

const GOLD := Color(0.93, 0.74, 0.38)
const GOLD_DIM := Color(0.93, 0.74, 0.38, 0.45)
const JADE := Color(0.42, 0.88, 0.66)
const CREAM := Color(0.97, 0.94, 0.87)
const MUTED := Color(0.72, 0.76, 0.72)
const PANEL := Color(0.035, 0.055, 0.048, 0.88)
const DANGER := Color(1.0, 0.42, 0.32)

const FONT_TITLE_PATH := "res://assets/fonts/Cinzel.ttf"
const FONT_BODY_PATH := "res://assets/fonts/Outfit.ttf"
## Fallbacks for scripts Cinzel/Outfit lack (built by tools/build_fonts.py).
## Godot sizes every line by the tallest font in a fallback chain, and these
## scripts need taller lines than Latin, so each language only gets the fallback
## for its own script (Latin languages get none and keep their compact layout).
const FALLBACK_DIR := "res://assets/fonts/fallback/"
const FALLBACKS_BY_LANGUAGE := {
	"ru": ["NotoSans-Subset.ttf"],
	"km": ["NotoSansKhmer-Subset.ttf"],
	"th": ["NotoSansThai-Subset.ttf"],
	"ja": ["NotoSansJP-Subset.ttf"],
	"ko": ["NotoSansKR-Subset.ttf"],
	"zh": ["NotoSansSC-Subset.ttf"],
	"hi": ["NotoSansDevanagari-Subset.ttf"],
}
## Languages drawn entirely with one Noto font: Cinzel and Outfit lack many Vietnamese
## letters, and a word that mixes two fonts looks uneven.
const BASE_BY_LANGUAGE := {
	"vi": "NotoSansVi-Subset.ttf",
}
## Every script at once, for the language picker ("picker" font kind).
const FALLBACKS_ALL := ["NotoSans-Subset.ttf", "NotoSansKhmer-Subset.ttf", "NotoSansThai-Subset.ttf",
	"NotoSansSC-Subset.ttf", "NotoSansJP-Subset.ttf", "NotoSansKR-Subset.ttf", "NotoSansDevanagari-Subset.ttf"]

static var _theme: Theme
static var _fonts: Dictionary = {}
static var _weights: Dictionary = {}
static var _default_bases: Dictionary = {}
static var _locale: String = "en"


## Give every UI font the fallbacks the newly selected language needs.
static func apply_locale(code: String) -> void:
	_locale = code
	for kind in _fonts:
		if kind != "picker":
			(_fonts[kind] as FontVariation).base_font = base_font(kind, code)
			(_fonts[kind] as FontVariation).fallbacks = _fallbacks(_weights[kind], fallback_names(code))


## The font file a kind of text ("title", "body"...) is drawn with in a language.
static func base_font(kind: String, code: String) -> Font:
	var own: String = BASE_BY_LANGUAGE.get(code.get_slice("_", 0), "")
	if own != "" and kind != "logo": # the game's name keeps its typeface in every language
		var f: FontFile = load(FALLBACK_DIR + own)
		if f != null:
			return f
	if not _default_bases.has(kind):
		_default_bases[kind] = load(FONT_TITLE_PATH if kind.begins_with("title") or kind == "logo" else FONT_BODY_PATH)
	return _default_bases[kind]


## Fallback font files used for a locale's text.
static func fallback_names(code: String) -> Array:
	return FALLBACKS_BY_LANGUAGE.get(code.get_slice("_", 0), [])


static func _fallbacks(weight: int, names: Array) -> Array[Font]:
	var out: Array[Font] = []
	var ts := TextServerManager.get_primary_interface()
	for n in names:
		var f: FontFile = load(FALLBACK_DIR + n)
		if f == null:
			continue
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		out.append(fv)
	return out


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var fv := FontVariation.new()
	fv.base_font = base_font(kind, "en" if kind == "picker" else _locale)
	var weight := 450
	match kind:
		"title", "logo":
			weight = 700
		"title_light":
			weight = 500
		"bold":
			weight = 700
		"semibold":
			weight = 600
		"light":
			weight = 300
		"picker":
			weight = 600
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	fv.fallbacks = _fallbacks(weight, FALLBACKS_ALL if kind == "picker" else fallback_names(_locale))
	_fonts[kind] = fv
	_weights[kind] = weight
	return fv


static func box(bg: Color, radius: int = 16, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


static func _circle_texture(size: int, color: Color, ring: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(size * 0.5 - d, 0.0, 1.0)
			var col := color
			if ring.a > 0.0 and d > size * 0.5 - 3.0:
				col = ring
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


static func _toggle_texture(on: bool) -> ImageTexture:
	var w := 64
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color(0.85, 0.66, 0.32, 0.95) if on else Color(0.25, 0.3, 0.28, 0.9)
	var knob_x := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, h * 0.5, w - h * 0.5)
			var d := p.distance_to(Vector2(cx, h * 0.5))
			var a := clampf(h * 0.5 - d, 0.0, 1.0)
			var col := track
			var dk := p.distance_to(Vector2(knob_x, h * 0.5))
			if dk < h * 0.5 - 3.0:
				col = Color(0.98, 0.96, 0.9)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 24

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)

	var normal := box(Color(0.05, 0.08, 0.07, 0.86), 18, GOLD_DIM, 2, 10)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.09, 0.14, 0.12, 0.92)
	hover.border_color = GOLD
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.86, 0.66, 0.32, 0.95)
	pressed.border_color = Color(1.0, 0.88, 0.6)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.05, 0.06, 0.06, 0.6)
	disabled.border_color = Color(0.4, 0.4, 0.4, 0.3)
	var focus := box(Color(0, 0, 0, 0), 18, Color(1.0, 0.88, 0.6, 0.9), 3)
	for cls in ["Button"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, CREAM)
		t.set_color("font_hover_color", cls, Color(1, 0.97, 0.88))
		t.set_color("font_pressed_color", cls, Color(0.08, 0.06, 0.03))
		t.set_color("font_hover_pressed_color", cls, Color(0.08, 0.06, 0.03))
		t.set_color("font_focus_color", cls, CREAM)
		t.set_color("font_disabled_color", cls, Color(0.6, 0.6, 0.6, 0.6))
		t.set_font("font", cls, font("semibold"))
		t.set_font_size("font_size", cls, 26)
		t.set_constant("h_separation", cls, 12)

	# Panels.
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 26, Color(0.93, 0.74, 0.38, 0.28), 1, 24))
	t.set_stylebox("panel", "Panel", box(PANEL, 26, Color(0.93, 0.74, 0.38, 0.28), 1, 24))

	# Sliders.
	var track := box(Color(1, 1, 1, 0.14), 6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := box(GOLD, 6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _circle_texture(34, Color(0.98, 0.96, 0.9), GOLD)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	# Toggles.
	t.set_icon("checked", "CheckButton", _toggle_texture(true))
	t.set_icon("unchecked", "CheckButton", _toggle_texture(false))
	t.set_icon("checked_mirrored", "CheckButton", _toggle_texture(true))
	t.set_icon("unchecked_mirrored", "CheckButton", _toggle_texture(false))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", empty)
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_hover_color", "CheckButton", CREAM)
	t.set_color("font_pressed_color", "CheckButton", CREAM)
	t.set_color("font_hover_pressed_color", "CheckButton", CREAM)
	t.set_color("font_focus_color", "CheckButton", CREAM)

	# Scrollbars: slim and unobtrusive (touch scrolling is the primary input).
	var sb := box(Color(1, 1, 1, 0.05), 4)
	var sg := box(Color(0.93, 0.74, 0.38, 0.5), 4)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sb)
		t.set_stylebox("grabber", cls, sg)
		t.set_stylebox("grabber_highlight", cls, sg)
		t.set_stylebox("grabber_pressed", cls, sg)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


## Label helper.
static func label(text: String, size: int = 24, kind: String = "body", color: Color = CREAM, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
