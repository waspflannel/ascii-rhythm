extends Control
## Root scene. Hosts the menu, song select, gameplay and results screens in a SubViewport
## shown through the dither shader, and fades the dither between screens.

const MENU := preload("res://scenes/main_menu.tscn")
const SONG_SELECT := preload("res://scenes/song_select.tscn")
const MANIA := preload("res://scenes/mania.tscn")
const STANDARD := preload("res://scenes/standard.tscn")
const RESULTS := preload("res://scenes/results.tscn")
## Seconds to dissolve the old screen to black, and the new one back in.
const FADE_OUT := 0.16
const FADE_IN := 0.24
## The layout size every screen is authored at (project.godot viewport size).
const LAYOUT_SIZE := Vector2(1280, 720)
## The shader's palette array length.
const PALETTE_SLOTS := 16

## True while the old screen fades out; screen requests in that window are dropped, so
## repeated keys can't open two screens.
var _leaving := false
var _fade: Tween

@onready var _dither := $Screen.material as ShaderMaterial
@onready var _viewport: SubViewport = $Screen/Viewport


func _ready() -> void:
	_apply_palette()
	_apply_pixel_scale()
	get_window().size_changed.connect(_apply_pixel_scale)
	_connect_menu($Screen/Viewport/MainMenu)
	_dither.set_shader_parameter("brightness", 0.0)
	_fade = create_tween()
	_fade.tween_property(_dither, "shader_parameter/brightness", 1.0, 0.6)


## Loads Settings dither/palette into the shader; an unknown name (such as "rgb") dithers
## each colour channel instead.
func _apply_palette() -> void:
	var colors: Array = Palette.DITHER.get(str(Settings.get_value("dither", "palette")), [])
	var packed := PackedVector3Array()
	for color: Color in colors.slice(0, PALETTE_SLOTS):
		packed.append(Vector3(color.r, color.g, color.b))
	packed.resize(PALETTE_SLOTS)
	_dither.set_shader_parameter("palette", packed)
	_dither.set_shader_parameter("palette_size", mini(colors.size(), PALETTE_SLOTS))
	_dither.set_shader_parameter("matrix_size", Settings.get_value("dither", "matrix_size"))


## The dither works in window pixels, so its cells grow with the window to keep the same
## look at 1280x720, 1920x1080 and fullscreen.
func _apply_pixel_scale() -> void:
	var window := Vector2(get_window().size)
	var scale_factor := minf(window.x / LAYOUT_SIZE.x, window.y / LAYOUT_SIZE.y)
	var cell := maxf(1.0, roundf(float(Settings.get_value("dither", "pixel_scale")) * scale_factor))
	_dither.set_shader_parameter("pixel_scale", cell)


func _connect_menu(menu: Control) -> void:
	menu.mania_selected.connect(_show_song_select.bind(Beatmap.MODE_MANIA), CONNECT_DEFERRED)
	menu.standard_selected.connect(_show_song_select.bind(Beatmap.MODE_STANDARD), CONNECT_DEFERRED)


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
		_leaving = false
		_viewport.gui_disable_input = false)
	_fade.tween_property(_dither, "shader_parameter/brightness", 1.0, FADE_IN)


func _replace_screen(screen: Control) -> Control:
	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.queue_free()
	_viewport.add_child(screen)
	return screen


func _show_menu() -> void:
	_change_screen(func() -> void: _connect_menu(_replace_screen(MENU.instantiate())))


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
		# Back skips the results; the HUD's end-of-run fade dies with the play screen.
		play.back_requested.connect(_show_song_select.bind(GameState.mode), CONNECT_DEFERRED)
		play.run_finished.connect(_show_results, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		_replace_screen(play))


func _show_results(score: RunScore) -> void:
	_change_screen(func() -> void:
		var results := RESULTS.instantiate()
		results.score = score
		_replace_screen(results)
		# Retry replays the same map; Back reopens song select on it (see GameState.map_path).
		results.retry_requested.connect(_show_play.bind(score.map.path), CONNECT_DEFERRED)
		results.back_requested.connect(_show_song_select.bind(GameState.mode), CONNECT_DEFERRED))
