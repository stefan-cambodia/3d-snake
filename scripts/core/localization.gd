extends Node
## Localization (autoload "Localization").
##
## All UI strings live in res://assets/i18n/strings.csv: one row per key, one
## column per locale. Godot imports the CSV into the translations listed in the
## project settings, so any Label/Button whose text is a key is translated
## automatically, and tr("KEY") works everywhere.
##
## To add a language: add a column to the CSV (header = locale code), add the
## code to LOCALES and to internationalization/locale/translations, then run
## tools/build_fonts.py so the fallback fonts cover its characters.

signal language_changed(code: String)

## Locale codes in the order the language picker shows them (CSV column names).
const LOCALES: Array[String] = ["en", "fr", "km", "th", "es", "pt_BR", "de", "it", "tr", "id", "ru", "ja", "ko", "zh_CN"]

var _current: String = "en"


func _ready() -> void:
	var lang := ""
	var profile := get_node_or_null("/root/Profile")
	if profile:
		lang = str(profile.get_setting("language"))
	if not LOCALES.has(lang):
		lang = detect(OS.get_locale())
	apply(lang)


## The supported locale that best matches a system locale such as "fr_BE",
## "km_KH", "pt_PT" or "zh_TW" (falls back to English).
static func detect(system_locale: String) -> String:
	var lang := system_locale.replace("-", "_").get_slice("_", 0).to_lower()
	if lang == "in": # legacy Java code for Indonesian
		lang = "id"
	for code in LOCALES:
		if code.get_slice("_", 0) == lang:
			return code
	return "en"


func apply(code: String) -> void:
	if not LOCALES.has(code):
		code = "en"
	_current = code
	TranslationServer.set_locale(code)
	UiTheme.apply_locale(code)
	language_changed.emit(code)


func current() -> String:
	return _current


## The language's own name ("Français", "ខ្មែរ", "日本語"...), for the picker.
static func language_name(code: String) -> String:
	var t := TranslationServer.get_translation_object(code)
	return str(t.get_message("LANGUAGE_NAME")) if t else code
