extends Control
## Root scene. Hosts the menu, settings, song select, gameplay and results screens in a
## SubViewport shown through the dither shader, and fades the dither between screens.

const MENU := preload("res://scenes/main_menu.tscn")
const SETTINGS := preload("res://scenes/settings.tscn")
const SONG_SELECT := preload("res://scenes/song_select.tscn")
const MANIA := preload("res://scenes/mania.tscn")
const STANDARD := preload("res://scenes/standard.tscn")
const RESULTS := preload("res://scenes/results.tscn")
## Seconds to dissolve the old screen to black, and the new one back in.
const FADE_OUT := 0.16
const FADE_IN := 0.24
## The layout size every screen is authored at (project.godot viewport size).
const LAYOUT_SIZE := Vector2(1280, 720)

## True while the old screen fades out; screen requests in that window are dropped, so
## repeated keys can't open two screens. Clears one deferred step after the new screen is
## built, so requests queued earlier in that frame are dropped too.
var _leaving := false
var _fade: Tween

@onready var _dither := $Screen.material as ShaderMaterial
@onready var _viewport: SubViewport = $Screen/Viewport


func _ready() -> void:
	# MapTheme loads the dither colour and palette.
	_apply_filter()
	get_window().size_changed.connect(_apply_filter)
	Settings.dither_changed.connect(_apply_filter)
	_connect_menu($Screen/Viewport/MainMenu)
	_dither.set_shader_parameter("brightness", 0.0)
	_fade = create_tween()
	_fade.tween_property(_dither, "shader_parameter/brightness", 1.0, 0.6)


## Loads the Settings dither knobs into the shader, clamped to their ranges so a
## hand-edited file can't break it (MapTheme loads the colour and palette). The dither works
## in window pixels, so its cells grow with the window to keep the same look at 1280x720,
## 1920x1080 and fullscreen.
func _apply_filter() -> void:
	var window := Vector2(get_window().size)
	var scale_factor := minf(window.x / LAYOUT_SIZE.x, window.y / LAYOUT_SIZE.y)
	var cell := clampi(Settings.get_value("dither", "pixel_scale"), 1, 8)
	var knobs := {
		"quantize": Settings.get_value("dither", "mode") != "off",
		"pattern": Settings.DITHER_PATTERNS.find(Settings.get_value("dither", "pattern")),
		"strength": clampf(Settings.get_value("dither", "strength"), 0.0, 1.0),
		"matrix_size": Settings.get_value("dither", "matrix_size"),
		"pixel_scale": maxf(1.0, roundf(cell * scale_factor)),
		"color_levels": clampi(Settings.get_value("dither", "color_levels"), 2, 16),
		"scanlines": clampf(Settings.get_value("dither", "scanlines"), 0.0, 1.0),
		"grain": clampf(Settings.get_value("dither", "grain"), 0.0, 0.2),
		"tint": clampf(Settings.get_value("dither", "tint"), 0.0, 1.0),
	}
	for parameter: String in knobs:
		_dither.set_shader_parameter(parameter, knobs[parameter])


func _connect_menu(menu: Control) -> void:
	menu.mania_selected.connect(_show_song_select.bind(Beatmap.MODE_MANIA), CONNECT_DEFERRED)
	menu.standard_selected.connect(_show_song_select.bind(Beatmap.MODE_STANDARD), CONNECT_DEFERRED)
	menu.settings_selected.connect(_show_settings, CONNECT_DEFERRED)


## Fades the current screen out, lets build swap in the next one, then fades it in.
func _change_screen(build: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	_viewport.gui_disable_input = true
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_dither, "shader_parameter/brightness", 0.0, FADE_OUT)
	_fade.tween_callback(func() -> void:
		build.call()
		set_deferred("_leaving", false)
		_viewport.gui_disable_input = false)
	_fade.tween_property(_dither, "shader_parameter/brightness", 1.0, FADE_IN)


## Swaps in screen. With Follow map on, play screens keep Neptune's blue in the dither, so
## notes and hit objects keep their skin colours (see MapTheme.apply_palette).
func _replace_screen(screen: Control, playing := false) -> Control:
	MapTheme.theme_dither = not playing
	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.queue_free()
	_viewport.add_child(screen)
	return screen


func _show_menu() -> void:
	_change_screen(func() -> void: _connect_menu(_replace_screen(MENU.instantiate())))


func _show_settings() -> void:
	_change_screen(func() -> void:
		_replace_screen(SETTINGS.instantiate()).back_requested.connect(_show_menu, CONNECT_DEFERRED))


func _show_song_select(mode: int) -> void:
	_change_screen(func() -> void:
		GameState.mode = mode
		var select := _replace_screen(SONG_SELECT.instantiate())
		select.map_chosen.connect(_show_play, CONNECT_DEFERRED)
		select.back_requested.connect(_show_menu, CONNECT_DEFERRED))


func _show_play(path: String) -> void:
	_change_screen(func() -> void:
		GameState.map_path = path
		var play := (MANIA if GameState.mode == Beatmap.MODE_MANIA else STANDARD).instantiate()
		play.beatmap_path = path
		# Quitting from the pause menu skips the results; the HUD's end-of-run fade dies
		# with the play screen.
		play.back_requested.connect(_show_song_select.bind(GameState.mode), CONNECT_DEFERRED)
		play.retry_requested.connect(_show_play.bind(path), CONNECT_DEFERRED)
		play.run_finished.connect(_show_results, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		_replace_screen(play, true))


func _show_results(score: RunScore) -> void:
	_change_screen(func() -> void:
		var results := RESULTS.instantiate()
		results.score = score
		_replace_screen(results)
		# Retry replays the same map; Back reopens song select on it (see GameState.map_path).
		results.retry_requested.connect(_show_play.bind(score.map.path), CONNECT_DEFERRED)
		results.back_requested.connect(_show_song_select.bind(GameState.mode), CONNECT_DEFERRED))
