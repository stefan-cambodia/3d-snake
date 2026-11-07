extends Node
## Localization (autoload "Localization"). Registers English and French string
## tables with the TranslationServer so every Label/Button text that is a key
## is translated automatically, and switches locale at runtime.

const LANGUAGES := [["en", "English"], ["fr", "Français"]]

const STRINGS := {
	"MENU_TAGLINE": ["A living serpent. An ancient isle.", "Un serpent vivant. Une île ancienne."],
	"MENU_PLAY": ["PLAY", "JOUER"],
	"MENU_SKINS": ["Skins & Sanctuaries", "Apparences & Sanctuaires"],
	"MENU_RECORDS": ["Records", "Records"],
	"MENU_SETTINGS": ["Settings", "Paramètres"],
	"MENU_ABOUT": ["How to play · About", "Comment jouer · À propos"],
	"MENU_BEST": ["Best score  %d", "Meilleur score  %d"],
	"MENU_FIRST_RUN": ["Your first journey awaits", "Votre premier voyage vous attend"],
	"PAUSE_TITLE": ["Paused", "Pause"],
	"PAUSE_RESUME": ["RESUME", "REPRENDRE"],
	"PAUSE_RESTART": ["Restart", "Recommencer"],
	"PAUSE_MENU": ["Main menu", "Menu principal"],
	"PAUSE_INFO": ["Score %d  ·  Stage %d  ·  %.1f m", "Score %d  ·  Niveau %d  ·  %.1f m"],
	"OVER_TITLE": ["The serpent rests", "Le serpent se repose"],
	"OVER_NEW_BEST": ["NEW BEST!", "NOUVEAU RECORD !"],
	"OVER_BEAT_BY": ["You beat your best by %d", "Record battu de %d points"],
	"OVER_FIRST_BEST": ["Your first record is set", "Votre premier record est établi"],
	"OVER_BEST_IS": ["Best %d  ·  %d to go", "Record %d  ·  encore %d"],
	"OVER_RETRY": ["PLAY AGAIN", "REJOUER"],
	"CAUSE_WALL": ["You touched the sanctuary barrier.", "Vous avez touché la barrière du sanctuaire."],
	"CAUSE_OBSTACLE": ["You struck the ancient stones.", "Vous avez heurté les pierres anciennes."],
	"CAUSE_SELF": ["You bit your own tail.", "Vous vous êtes mordu la queue."],
	"STAT_LENGTH": ["Length", "Longueur"],
	"STAT_STAGE": ["Stage", "Niveau"],
	"STAT_FOOD": ["Fruit", "Fruits"],
	"STAT_COMBO": ["Best combo", "Meilleur combo"],
	"STAT_TIME": ["Time", "Temps"],
	"UNLOCK_SKIN": ["New skin unlocked: %s", "Nouvelle apparence : %s"],
	"UNLOCK_THEME": ["New sanctuary unlocked: %s", "Nouveau sanctuaire : %s"],
	"SET_TITLE": ["Settings", "Paramètres"],
	"SET_AUDIO": ["AUDIO", "AUDIO"],
	"SET_MUSIC": ["Music", "Musique"],
	"SET_SFX": ["Sound effects", "Effets sonores"],
	"SET_CONTROLS": ["CONTROLS", "COMMANDES"],
	"SET_SCHEME": ["Steering", "Direction"],
	"SCHEME_DRAG": ["Drag", "Glisser"],
	"SCHEME_HALVES": ["Tap sides", "Côtés"],
	"SCHEME_STICK": ["Joystick", "Joystick"],
	"SET_SCHEME_HINT": ["Drag: slide a finger left/right anywhere. Tap sides: hold the left or right half. Joystick: thumb-stick in the lower corner. Boost with the button opposite your steering hand.", "Glisser : faites glisser un doigt n'importe où. Côtés : maintenez la moitié gauche ou droite. Joystick : manette virtuelle en bas. Accélérez avec le bouton opposé."],
	"SET_SENSITIVITY": ["Steering sensitivity", "Sensibilité de direction"],
	"SET_LEFT_HANDED": ["Left-handed layout", "Disposition gaucher"],
	"SET_HAPTICS": ["Haptic feedback", "Retour haptique"],
	"SET_CAMERA": ["CAMERA", "CAMÉRA"],
	"SET_CAM_DISTANCE": ["Distance", "Distance"],
	"CAM_NEAR": ["Near", "Proche"],
	"CAM_NORMAL": ["Normal", "Normale"],
	"CAM_FAR": ["Far", "Loin"],
	"SET_CAM_SMOOTH": ["Camera smoothing", "Fluidité caméra"],
	"SET_GRAPHICS": ["GRAPHICS", "GRAPHISMES"],
	"SET_QUALITY": ["Quality", "Qualité"],
	"Q_LOW": ["Low", "Basse"],
	"Q_MEDIUM": ["Medium", "Moyenne"],
	"Q_HIGH": ["High", "Haute"],
	"SET_FPS": ["Show FPS", "Afficher les FPS"],
	"SET_LANGUAGE": ["LANGUAGE", "LANGUE"],
	"SET_LANGUAGE_LABEL": ["Language", "Langue"],
	"SET_DATA": ["DATA", "DONNÉES"],
	"SET_RESET": ["Reset progress", "Réinitialiser la progression"],
	"SET_RESET_CONFIRM": ["Tap again to confirm", "Touchez à nouveau pour confirmer"],
	"COMMON_BACK": ["BACK", "RETOUR"],
	"SKINS_TITLE": ["Skins & Sanctuaries", "Apparences & Sanctuaires"],
	"SKINS_SERPENTS": ["SERPENTS", "SERPENTS"],
	"SKINS_SANCTUARIES": ["SANCTUARIES", "SANCTUAIRES"],
	"SKINS_UNLOCKED": ["unlocked", "débloqué"],
	"SKIN_JADE": ["Jade Viper", "Vipère de jade"],
	"SKIN_EMBER": ["Ember Python", "Python de braise"],
	"SKIN_AZURE": ["Azure Naga", "Naga d'azur"],
	"SKIN_SAND": ["Dune Adder", "Vipère des dunes"],
	"SKIN_CORAL": ["Coral Bands", "Corail annelé"],
	"SKIN_OBSIDIAN": ["Obsidian King", "Roi d'obsidienne"],
	"SKIN_GOLDEN": ["Golden Idol", "Idole d'or"],
	"SKIN_SPECTRAL": ["Spectral Wyrm", "Wyrm spectral"],
	"THEME_DAWN": ["Golden Dawn", "Aube dorée"],
	"THEME_MOON": ["Moonlit Shrine", "Sanctuaire lunaire"],
	"THEME_MIST": ["Misty Morning", "Matin brumeux"],
	"REQ_BEST_SCORE": ["Score %d in one run (best %d)", "Marquez %d points en une partie (record %d)"],
	"REQ_TOTAL_FOOD": ["Eat %d fruit in total (%d so far)", "Mangez %d fruits au total (%d)"],
	"REQ_BEST_STAGE": ["Reach stage %d (best %d)", "Atteignez le niveau %d (record %d)"],
	"REQ_RUNS": ["Play %d runs (%d so far)", "Jouez %d parties (%d)"],
	"REQ_TOTAL_RARE": ["Collect %d relics (%d so far)", "Récupérez %d reliques (%d)"],
	"REQ_BEST_LENGTH": ["Grow to %.0f m (best %.1f m)", "Atteignez %.0f m (record %.1f m)"],
	"REC_TITLE": ["Records", "Records"],
	"REC_TOP": ["HALL OF FAME", "TABLEAU D'HONNEUR"],
	"REC_LIFETIME": ["LIFETIME", "CARRIÈRE"],
	"REC_RANK": ["Rank", "Rang"],
	"REC_SCORE": ["Score", "Score"],
	"REC_DATE": ["Date", "Date"],
	"REC_EMPTY": ["No runs yet — the sanctuary awaits.", "Aucune partie — le sanctuaire vous attend."],
	"REC_RUNS": ["Runs", "Parties"],
	"REC_FOOD": ["Fruit eaten", "Fruits mangés"],
	"REC_RELICS": ["Relics", "Reliques"],
	"REC_CRYSTALS": ["Crystals", "Cristaux"],
	"REC_BEST_LENGTH": ["Longest", "Plus long"],
	"REC_BEST_STAGE": ["Best stage", "Meilleur niveau"],
	"REC_BEST_COMBO": ["Best combo", "Meilleur combo"],
	"REC_PLAYTIME": ["Play time", "Temps de jeu"],
	"ABOUT_TITLE": ["How to play", "Comment jouer"],
	"ABOUT_HOW": ["THE PATH OF THE SERPENT", "LA VOIE DU SERPENT"],
	"HOW_1": ["• Steer the serpent by sliding your finger left and right (change the style in Settings).", "• Dirigez le serpent en glissant le doigt à gauche et à droite (style modifiable dans les Paramètres)."],
	"HOW_2": ["• Eat golden sunfruit to grow. Chain them quickly for a combo multiplier.", "• Mangez les fruits solaires pour grandir. Enchaînez-les vite pour un multiplicateur."],
	"HOW_3": ["• Cyan crystals grant a Surge: extra speed and double points for a few seconds.", "• Les cristaux cyan donnent une Ruée : vitesse accrue et points doublés quelques secondes."],
	"HOW_4": ["• Violet relics are rare and fleeting — follow the beam of light. Huge bonus!", "• Les reliques violettes sont rares et éphémères — suivez le rayon de lumière !"],
	"HOW_5": ["• Hold Boost to sprint (uses stamina). Graze obstacles for Close Call bonuses.", "• Maintenez Accélérer pour sprinter (endurance). Frôlez les obstacles pour des bonus."],
	"HOW_6": ["• Avoid the stones, the barrier and your own body. Each stage brings speed and rising monoliths — watch for the glowing warning circles.", "• Évitez les pierres, la barrière et votre propre corps. Chaque niveau apporte vitesse et monolithes surgissants — attention aux cercles lumineux."],
	"ABOUT_CREDITS": ["CREDITS", "CRÉDITS"],
	"ABOUT_TEXT": ["Serpent Sanctum — an immersive 3D serpent game. Every model, texture, sound and piece of music in this game is generated procedurally. Built with the Godot Engine (MIT licence). Fonts: Cinzel and Outfit (SIL Open Font License).", "Serpent Sanctum — un jeu de serpent 3D immersif. Chaque modèle, texture, son et musique est généré de façon procédurale. Réalisé avec le moteur Godot (licence MIT). Polices : Cinzel et Outfit (SIL Open Font License)."],
	"HUD_BEST": ["BEST %d", "RECORD %d"],
	"HUD_NEW_BEST": ["NEW BEST!", "NOUVEAU RECORD !"],
	"HUD_NEW_BEST_SHORT": ["NEW BEST", "NOUVEAU RECORD"],
	"HUD_STAGE": ["STAGE %d", "NIVEAU %d"],
	"HUD_LENGTH": ["%.1f m", "%.1f m"],
	"HUD_STAGE_UP": ["Stage %d", "Niveau %d"],
	"HUD_STAGE_SUB": ["Faster — the stones awaken", "Plus vite — les pierres s'éveillent"],
	"HUD_SURGE": ["SURGE!", "RUÉE !"],
	"HUD_SURGE_SUB": ["Double points", "Points doublés"],
	"HUD_RELIC": ["RELIC!", "RELIQUE !"],
	"HUD_CLOSE_CALL": ["CLOSE CALL", "DE JUSTESSE"],
	"HUD_GO": ["GO!", "PARTEZ !"],
	"TUT_DRAG": ["Slide your finger left / right to steer", "Glissez le doigt à gauche / droite pour tourner"],
	"TUT_HALVES": ["Hold the left or right side to turn", "Maintenez le côté gauche ou droit pour tourner"],
	"TUT_STICK": ["Use the thumb-stick to steer", "Utilisez le joystick pour tourner"],
	"TUT_BOOST": ["Hold the boost button to sprint", "Maintenez le bouton pour accélérer"],
	"TUT_FOOD": ["Eat the golden fruit to grow", "Mangez les fruits dorés pour grandir"],
	"TOAST_PAUSED_BG": ["Paused while the app was in the background", "Mis en pause pendant que l'appli était en arrière-plan"],
}

var _translations: Dictionary = {}


func _ready() -> void:
	for li in LANGUAGES.size():
		var code: String = LANGUAGES[li][0]
		var t := Translation.new()
		t.locale = code
		for key in STRINGS:
			t.add_message(key, STRINGS[key][li])
		TranslationServer.add_translation(t)
		_translations[code] = t
	var lang := ""
	var profile := get_node_or_null("/root/Profile")
	if profile:
		lang = str(profile.get_setting("language"))
	if lang == "":
		lang = "fr" if OS.get_locale_language() == "fr" else "en"
	apply(lang)


func apply(code: String) -> void:
	TranslationServer.set_locale(code)


func current() -> String:
	var loc := TranslationServer.get_locale()
	for l in LANGUAGES:
		if loc.begins_with(l[0]):
			return l[0]
	return "en"
