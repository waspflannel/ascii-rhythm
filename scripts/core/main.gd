extends Control
## Root scene. Hosts the menu, song select and gameplay screens in a SubViewport
## shown through the dither shader.

const MENU := preload("res://scenes/main_menu.tscn")
const SONG_SELECT := preload("res://scenes/song_select.tscn")
const MANIA := preload("res://scenes/mania.tscn")
const STANDARD := preload("res://scenes/standard.tscn")


func _ready() -> void:
	var dither := $Screen.material as ShaderMaterial
	dither.set_shader_parameter("pixel_scale", float(Settings.get_value("dither", "pixel_scale")))
	dither.set_shader_parameter("matrix_size", Settings.get_value("dither", "matrix_size"))
	_connect_menu($Screen/Viewport/MainMenu)


func _connect_menu(menu: Control) -> void:
	menu.mania_selected.connect(_show_song_select.bind(Beatmap.MODE_MANIA), CONNECT_DEFERRED)
	menu.standard_selected.connect(_show_song_select.bind(Beatmap.MODE_STANDARD), CONNECT_DEFERRED)


func _replace_screen(screen: Control) -> Control:
	var viewport := $Screen/Viewport
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()
	viewport.add_child(screen)
	return screen


func _show_menu() -> void:
	_connect_menu(_replace_screen(MENU.instantiate()))


func _show_song_select(mode: int) -> void:
	GameState.mode = mode
	var select := _replace_screen(SONG_SELECT.instantiate())
	select.map_chosen.connect(_show_play, CONNECT_DEFERRED)
	select.back_requested.connect(_show_menu, CONNECT_DEFERRED)


func _show_play(path: String) -> void:
	GameState.map_path = path
	var play := (MANIA if GameState.mode == Beatmap.MODE_MANIA else STANDARD).instantiate()
	play.beatmap_path = path
	# Back, fail and song end can all ask to leave; only the first one counts.
	play.back_requested.connect(_show_song_select.bind(GameState.mode), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	_replace_screen(play)
