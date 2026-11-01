extends Control
## Root scene. Hosts full-resolution menu and gameplay screens.

const MENU := preload("res://scenes/main_menu.tscn")
const MANIA := preload("res://scenes/mania.tscn")
const STANDARD := preload("res://scenes/standard.tscn")

func _ready() -> void:
	_connect_menu($Screen/Viewport/MainMenu)


func _connect_menu(menu: Control) -> void:
	menu.mania_selected.connect(_show_play.bind(MANIA), CONNECT_DEFERRED)
	menu.standard_selected.connect(_show_play.bind(STANDARD), CONNECT_DEFERRED)


func _replace_screen(scene: PackedScene) -> Control:
	var viewport := $Screen/Viewport
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()
	var screen := scene.instantiate() as Control
	viewport.add_child(screen)
	return screen


func _show_play(scene: PackedScene) -> void:
	var play := _replace_screen(scene)
	play.back_requested.connect(_show_menu, CONNECT_DEFERRED)


func _show_menu() -> void:
	_connect_menu(_replace_screen(MENU))
