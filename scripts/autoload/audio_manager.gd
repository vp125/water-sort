extends Node
## Autoload: sound effects (small player pool) and looping background music, on their own
## "SFX" and "Music" buses. Mute toggles persist in user://settings.cfg.
##
## Missing audio files are skipped with a warning, so the game still runs without assets.

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_NAMES: Array[String] = [
	"select", "pour_1", "pour_2", "pour_3", "pour_4", "progress", "tube_complete",
	"level_complete", "undo", "restart", "hint", "add_tube",
]
const MUSIC_PATHS: Array[String] = [
	"res://assets/audio/music/ambient_loop.ogg",
	"res://assets/audio/music/ambient_loop.wav",
]
const SETTINGS_PATH := "user://settings.cfg"
const POOL_SIZE := 8
const MUSIC_BUS_DB := -9.0  # keep the bed well under the effects
const SFX_BUS_DB := 0.0

var sfx_enabled := true
var music_enabled := true

var _streams: Dictionary = {}  # name -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _next_steal := 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_ensure_bus("Music", MUSIC_BUS_DB)
	_ensure_bus("SFX", SFX_BUS_DB)
	_load_settings()
	_apply_mutes()

	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for sfx_name in SFX_NAMES:
		var path := SFX_DIR + sfx_name + ".wav"
		if ResourceLoader.exists(path):
			_streams[sfx_name] = load(path)
		else:
			push_warning("Missing sound effect: %s" % path)
	_start_music()


## Plays a sound effect by file name (without extension). Does nothing if muted or missing.
func play(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_enabled or not _streams.has(sfx_name):
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:  # all busy: steal the oldest slot round-robin
		player = _pool[_next_steal]
		_next_steal = (_next_steal + 1) % _pool.size()
	player.stream = _streams[sfx_name]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func pour_sound_name(units: int) -> String:
	return "pour_%d" % clampi(units, 1, 4)


func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_mutes()
	_save_settings()


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_apply_mutes()
	_save_settings()


func _start_music() -> void:
	var stream: AudioStream = null
	for path in MUSIC_PATHS:
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		push_warning("No background music found (run tools/generate_audio.py)")
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, 4.0)  # gentle fade-in


func _ensure_bus(bus_name: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, volume_db)


func _apply_mutes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_enabled)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "music_enabled", music_enabled)
	if cfg.save(SETTINGS_PATH) != OK:
		push_warning("Could not save settings to %s" % SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sfx_enabled = cfg.get_value("audio", "sfx_enabled", true)
	music_enabled = cfg.get_value("audio", "music_enabled", true)
