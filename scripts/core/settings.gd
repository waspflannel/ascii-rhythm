extends Node
## User preferences, persisted to user://settings.cfg.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"gameplay": {"autoplay": false},
	"audio": {"offset_ms": 0, "volume": 1.0},
	"dither": {"pixel_scale": 3, "matrix_size": 4},
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
