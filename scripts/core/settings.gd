extends Node
## User preferences, persisted to user://settings.cfg.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"audio": {"offset_ms": 0, "volume": 1.0},
	## palette: a Palette.DITHER name ("neptune", "crimson") or "rgb" for per-channel
	## dithering. pixel_scale is the cell size at 1280x720; it grows with the window.
	## beat_pulse nudges the brightness on each beat during play.
	"dither": {"pixel_scale": 3, "matrix_size": 4, "palette": "neptune", "beat_pulse": true},
	## osu!lazer-style scroll speed, 1 to 40; F3 and F4 change it in game.
	"mania": {"scroll_speed": 20},
	## The last map played, so mode select shows its art on the next launch too.
	"history": {"last_map": ""},
}

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


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
