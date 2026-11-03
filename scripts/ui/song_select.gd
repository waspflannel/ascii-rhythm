extends Control
## Horizontal carousel of the beatmaps/ maps for GameState.mode. The root scene handles screen changes.

signal map_chosen(path: String)
signal back_requested

const CARD := preload("res://scenes/ui/map_card.tscn")
## Must match map_card.tscn's minimum width and the Cards separation.
const CARD_WIDTH := 320.0
const CARD_GAP := 24.0

var _maps: Array[Beatmap] = []
## Background textures by file path; difficulties in one set share an image.
var _art := {}
var _index := 0
var _slide: Tween

@onready var _cards: HBoxContainer = $Carousel/Cards


func _ready() -> void:
	$Back.pressed.connect(back_requested.emit)
	$ModeLabel.text = "Mania" if GameState.mode == Beatmap.MODE_MANIA else "Standard"
	# ponytail: parses every .osu on open; add the cached library index from DESIGN.md when folders get big.
	_scan("res://beatmaps")
	# Group by map folder, easiest difficulty (fewest objects) first.
	_maps.sort_custom(func(a: Beatmap, b: Beatmap) -> bool:
		var a_set := a.path.get_base_dir()
		var b_set := b.path.get_base_dir()
		return a_set < b_set if a_set != b_set else a.hit_objects.size() < b.hit_objects.size())
	if _maps.is_empty():
		$Empty.show()
		$Back.grab_focus()
		return
	for i in _maps.size():
		var map := _maps[i]
		var card := CARD.instantiate() as Button
		card.get_node("Art").texture = _load_art(map)
		card.get_node("Info/Title").text = map.title
		card.get_node("Info/Artist").text = map.artist
		card.get_node("Info/Version").text = "[%s]" % map.version
		card.focus_entered.connect(_select.bind(i))
		card.pressed.connect(map_chosen.emit.bind(map.path))
		_cards.add_child(card)
	resized.connect(func() -> void: _select(_index))
	var last := _maps.map(func(map: Beatmap) -> String: return map.path).find(GameState.map_path)
	_cards.get_child(maxi(last, 0)).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event is InputEventMouseButton and event.pressed and not _maps.is_empty():
		var step := 0
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				step = -1
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				step = 1
		if step != 0:
			_cards.get_child(clampi(_index + step, 0, _maps.size() - 1)).grab_focus()


## Centers card i and dims the rest.
func _select(i: int) -> void:
	_index = i
	for card: Control in _cards.get_children():
		card.modulate = Color.WHITE if card.get_index() == i else Color(0.55, 0.55, 0.55)
	if _slide:
		_slide.kill()
	_slide = create_tween()
	var x := size.x / 2.0 - (i * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH / 2.0)
	_slide.tween_property(_cards, "position:x", x, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Adds every unpacked .osu under folder whose osu! mode matches; other modes are skipped.
func _scan(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension().to_lower() != "osu":
			continue
		var map := Beatmap.from_file(folder.path_join(file))
		if map != null and map.mode == GameState.mode and not map.hit_objects.is_empty():
			_maps.append(map)
	for child in dir.get_directories():
		_scan(folder.path_join(child))


func _load_art(map: Beatmap) -> Texture2D:
	var path := map.path.get_base_dir().path_join(map.background)
	if map.background.is_empty() or not FileAccess.file_exists(path):
		return null
	if not _art.has(path):
		# beatmaps/ is not imported, so decode the file directly. Maps often name PNGs .jpg,
		# so trust the PNG signature over the extension.
		var bytes := FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var png := bytes.slice(0, 4) == PackedByteArray([0x89, 0x50, 0x4E, 0x47])
		var err := image.load_png_from_buffer(bytes) if png else image.load_jpg_from_buffer(bytes)
		_art[path] = ImageTexture.create_from_image(image) if err == OK else null
	return _art[path]
