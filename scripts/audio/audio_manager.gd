extends Node
## Audio manager (autoload "AudioManager"): music crossfades, pooled SFX,
## ambience, the speed-driven slither loop, and bus volumes from the profile.

const SFX_PATH := "res://assets/audio/sfx/%s.ogg"
const MUSIC := {
	"menu": "res://assets/audio/music/menu_theme.ogg",
	"game": "res://assets/audio/music/game_theme.ogg",
}
const SFX_NAMES := [
	"pickup_food", "pickup_energy", "pickup_rare", "boost", "surge_end", "stage_up", "near_miss",
	"rise_warning", "rise_stone", "death", "game_over", "new_best", "unlock", "start",
	"ui_click", "ui_back", "ui_toggle",
]
const POOL := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: String = ""
var _ambient: AudioStreamPlayer
var _slither: AudioStreamPlayer
var _slither_target: float = 0.0
var _lowpass: AudioEffectLowPassFilter
var _music_bus: int
var _sfx_bus: int
var _amb_bus: int
var _last_play: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = _ensure_bus("Music")
	_sfx_bus = _ensure_bus("SFX")
	_amb_bus = _ensure_bus("Ambient")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 900.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)
	for n in SFX_NAMES:
		var s: AudioStream = load(SFX_PATH % n)
		if s:
			_streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_ambient = _make_player("Ambient")
	var amb: AudioStreamOggVorbis = load(SFX_PATH % "ambient_lake")
	if amb:
		amb.loop = true
		_ambient.stream = amb
	_slither = _make_player("SFX")
	var sl: AudioStreamOggVorbis = load(SFX_PATH % "slither_loop")
	if sl:
		sl.loop = true
		_slither.stream = sl
	_slither.volume_db = -80.0
	apply_volumes()
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.setting_changed.connect(_on_setting_changed)


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "music_volume" or key == "sfx_volume":
		apply_volumes()


static func _vol_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


func apply_volumes() -> void:
	var profile := get_node_or_null("/root/Profile")
	var mv := 0.65
	var sv := 0.85
	if profile:
		mv = float(profile.get_setting("music_volume"))
		sv = float(profile.get_setting("sfx_volume"))
	AudioServer.set_bus_volume_db(_music_bus, _vol_db(mv) - 4.0)
	AudioServer.set_bus_volume_db(_sfx_bus, _vol_db(sv))
	AudioServer.set_bus_volume_db(_amb_bus, _vol_db(sv) - 6.0)
	AudioServer.set_bus_mute(_music_bus, mv <= 0.001)
	AudioServer.set_bus_mute(_sfx_bus, sv <= 0.001)
	AudioServer.set_bus_mute(_amb_bus, sv <= 0.001)


## Play a one-shot effect. Rapid repeats of the same sound are rate-limited.
func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = _streams.get(sfx_name)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sfx_name, -1000)) < 35:
		return
	_last_play[sfx_name] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func ui_click() -> void:
	play("ui_click", -4.0, randf_range(0.96, 1.04))


func play_music(track: String, fade_time: float = 1.2) -> void:
	if track == _music_current:
		return
	_music_current = track
	var stream: AudioStreamOggVorbis = load(MUSIC[track]) if MUSIC.has(track) else null
	# _music_a is always the current/most recent player.
	if _music_a.playing:
		_fade(_music_a, -60.0, fade_time, true)
	var tmp := _music_a
	_music_a = _music_b
	_music_b = tmp
	if stream:
		stream.loop = true
		_music_a.stream = stream
		_music_a.volume_db = -40.0
		_music_a.play()
		_fade(_music_a, 0.0, fade_time, false)


func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	var old: Tween = _tweens.get(p)
	if old and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, time)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[p] = tw


func stop_music(fade_time: float = 1.0) -> void:
	_music_current = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			_fade(p, -60.0, fade_time, true)


func set_ambient(on: bool) -> void:
	if on and not _ambient.playing and _ambient.stream:
		_ambient.play()
	elif not on and _ambient.playing:
		_ambient.stop()


## Muffle music (pause menu / death).
func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_music_bus, 0, on)


## Continuous slither rustle; amount 0..1 follows speed.
func set_slither(amount: float, pitch: float = 1.0) -> void:
	_slither_target = clampf(amount, 0.0, 1.0)
	_slither.pitch_scale = clampf(pitch, 0.5, 2.0)
	if _slither_target > 0.01 and not _slither.playing and _slither.stream:
		_slither.play()


func _process(delta: float) -> void:
	var target_db := -80.0 if _slither_target <= 0.01 else linear_to_db(_slither_target) - 12.0
	_slither.volume_db = move_toward(_slither.volume_db, target_db, delta * 60.0)
	if _slither_target <= 0.01 and _slither.volume_db <= -79.0 and _slither.playing:
		_slither.stop()
