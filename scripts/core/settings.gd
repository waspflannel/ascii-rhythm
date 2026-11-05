extends Node
## User preferences, persisted to user://settings.cfg.

signal audio_changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	## volume is the master volume; music and sfx scale their buses under it, all 0 to 1.
	"audio": {"offset_ms": 0, "volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0},
	## palette: a Palette.DITHER name ("neptune", "crimson") or "rgb" for per-channel
	## dithering. pixel_scale is the cell size at 1280x720; it grows with the window.
	## beat_pulse nudges the brightness on each beat during play.
	"dither": {"pixel_scale": 3, "matrix_size": 4, "palette": "neptune", "beat_pulse": true},
	## osu!lazer-style scroll speed, 1 to 40; F3 and F4 change it in game.
	"mania": {"scroll_speed": 20},
	## The last map selected in song select, so mode select shows its art on the next
	## launch too.
	"history": {"last_map": ""},
}
## Audio buses (default_bus_layout.tres) and the audio setting each one's volume follows.
const BUSES := {"Master": "volume", "Music": "music_volume", "SFX": "sfx_volume"}

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_audio()


func load_settings() -> void:
	var err := _config.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Could not read %s (error %d), using defaults." % [PATH, err])
		_config = ConfigFile.new()


func save_settings() -> void:
	var err := _config.save(PATH)
	if err != OK:
		push_error("Could not save %s (error %d)." % [PATH, err])


func get_value(section: String, key: String) -> Variant:
	return _config.get_value(section, key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)


## Sets each bus's volume from its audio setting.
func apply_audio() -> void:
	for bus: String in BUSES:
		var volume := clampf(float(get_value("audio", BUSES[bus])), 0.0, 1.0)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), volume)
	audio_changed.emit()
