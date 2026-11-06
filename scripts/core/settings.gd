extends Node
## User preferences, persisted to user://settings.cfg.

signal audio_changed
## Emitted after a dither setting changes, so the screen filter and palette reload.
signal dither_changed
## Emitted after a cursor setting changes, so the cursor preview redraws.
signal cursor_changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	## volume is the master volume; music and sfx scale their buses under it, all 0 to 1.
	"audio": {"offset_ms": 0, "volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0},
	## The dither look (see MapTheme.apply_palette and main.gd). accent: the picked dither
	## colour as #rrggbb, Neptune's royal blue (Palette.BLUE) by default. follow_map: the
	## map art's accent drives the dither instead (outside play). tint: how far colours move
	## onto the accent's black-to-white ramp, 0 to 1. mode: a DITHER_MODES name. pattern: a
	## DITHER_PATTERNS name. strength: how far the dots spread, 0 to 1. matrix_size: a
	## MATRIX_SIZES entry (Bayer only). pixel_scale: the cell size at 1280x720, 1 to 8 px.
	## color_levels: levels per channel in rgb mode, 2 to 16. shades: steps of the accent
	## ramp in palette mode, 2 to 7. skin_colours: palette mode keeps Palette.SKIN.
	## scanlines: how much alternate rows darken, 0 to 1. grain: film grain, 0 to 0.2.
	## beat_pulse nudges the brightness on each beat during play.
	"dither": {
		"accent": "#4776ff", "follow_map": false, "tint": 0.2, "mode": "rgb",
		"pattern": "bayer", "strength": 0.6, "matrix_size": 8, "pixel_scale": 2,
		"color_levels": 4, "shades": 5, "skin_colours": true, "scanlines": 0.0,
		"grain": 0.0, "beat_pulse": true,
	},
	## The standard-mode cursor (see CursorView). size: percent of the skin's cursor, 25 to
	## 300. colour: a CURSOR_COLOURS name; skin keeps the ring's own blue, accent is the
	## dither colour and custom is custom_colour (#rrggbb). outline: a thin black ring so it
	## reads on bright notes. opacity: percent, 30 to 100. dithered: draw the cursor under
	## the dither filter like everything else, instead of crisp above it. expand: grow while
	## a hit key is held.
	"cursor": {
		"size": 250, "colour": "white", "custom_colour": "#ffffff", "outline": true,
		"opacity": 100, "dithered": false, "expand": true,
	},
	## osu!lazer-style scroll speed, 1 to 40; F3 and F4 change it in game.
	"mania": {"scroll_speed": 20},
	## The last map selected in song select, so mode select shows its art on the next
	## launch too.
	"history": {"last_map": ""},
}
## Audio buses (default_bus_layout.tres) and the audio setting each one's volume follows.
const BUSES := {"Master": "volume", "Music": "music_volume", "SFX": "sfx_volume"}
## Dither modes: "rgb" dithers each colour channel, "palette" dithers to the accent's
## palette (Palette.dither_palette) and "off" shows the screen's own colours.
const DITHER_MODES := ["rgb", "palette", "off"]
## Dither patterns; the index is the shader's pattern uniform.
const DITHER_PATTERNS := ["bayer", "noise", "grain", "flat"]
## Bayer matrix sizes the shader supports.
const MATRIX_SIZES := [2, 4, 8, 16]
## Cursor colour modes; skin keeps the ring's own colour.
const CURSOR_COLOURS := ["skin", "white", "accent", "custom"]
## Variant types get_value converts between.
const NUMBERS := [TYPE_INT, TYPE_FLOAT]
## The keys that must be one of a list, by section; anything else reads as the default.
const CHOICES := {
	"dither": {"mode": DITHER_MODES, "pattern": DITHER_PATTERNS, "matrix_size": MATRIX_SIZES},
	"cursor": {"colour": CURSOR_COLOURS},
}

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_audio()


func load_settings() -> void:
	var err := _config.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Could not read %s (error %d), using defaults." % [PATH, err])
		_config = ConfigFile.new()
	# The old filter and palette presets give way to the default look (soft bayer, rgb).
	if _config.has_section_key("dither", "filter") or _config.has_section_key("dither", "palette"):
		_clear_dither()
		save_settings()


## Saves on quit too (window close or the Quit button), for live colour drags that only
## save when released.
func _exit_tree() -> void:
	save_settings()


func save_settings() -> void:
	var err := _config.save(PATH)
	if err != OK:
		push_error("Could not save %s (error %d)." % [PATH, err])


## The saved value, or the default when it is missing, of the wrong type or not one of its
## CHOICES (a hand-edited file). Whole and fractional numbers convert to the
## default's type.
func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = DEFAULTS[section][key]
	var value: Variant = _config.get_value(section, key, fallback)
	if typeof(value) in NUMBERS and typeof(fallback) in NUMBERS:
		value = type_convert(value, typeof(fallback))
	if typeof(value) != typeof(fallback):
		return fallback
	if CHOICES.get(section, {}).has(key) and not value in CHOICES[section][key]:
		return fallback
	return value


func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)


## Sets each bus's volume from its audio setting.
func apply_audio() -> void:
	for bus: String in BUSES:
		var volume := clampf(float(get_value("audio", BUSES[bus])), 0.0, 1.0)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), volume)
	audio_changed.emit()


## Restores every dither setting but beat pulse to its default.
func reset_dither() -> void:
	_clear_dither()
	save_settings()
	dither_changed.emit()


## Erases every [dither] key but beat_pulse, so the rest fall back to DEFAULTS.
func _clear_dither() -> void:
	if not _config.has_section("dither"):
		return
	for key in _config.get_section_keys("dither"):
		if key != "beat_pulse":
			_config.erase_section_key("dither", key)
