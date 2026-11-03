extends Control
## Two-stage song select for GameState.mode: a vertical list of map sets (one per
## beatmaps/ folder), then a horizontal carousel of the chosen set's difficulties.
## The root scene handles screen changes.

signal map_chosen(path: String)
signal back_requested

const CARD := preload("res://scenes/ui/map_card.tscn")
## Must match map_card.tscn's minimum width and the Cards separation.
const CARD_WIDTH := 320.0
const CARD_GAP := 24.0
## Must match the Rows separation.
const ROW_HEIGHT := 96.0
const ROW_GAP := 8.0
const DIM := Color(0.55, 0.55, 0.55)

## One Array[Beatmap] per map folder, easiest difficulty (fewest objects) first.
var _sets: Array[Array] = []
## Background textures by file path; difficulties in one set share an image.
var _art := {}
var _set_index := 0
var _index := 0
var _slide: Tween

@onready var _rows: VBoxContainer = $List/Rows
@onready var _cards: HBoxContainer = $Carousel/Cards


func _ready() -> void:
	$Back.pressed.connect(_back)
	$ModeLabel.text = "Mania" if GameState.mode == Beatmap.MODE_MANIA else "Standard"
	# ponytail: parses every .osu on open; add the cached library index from DESIGN.md when folders get big.
	_scan("res://beatmaps")
	if _sets.is_empty():
		$Empty.show()
		$Back.grab_focus()
		return
	_sets.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Beatmap).title.naturalnocasecmp_to((b[0] as Beatmap).title) < 0)
	for i in _sets.size():
		var first: Beatmap = _sets[i][0]
		var row := _make_card(first, "mapped by %s" % first.creator)
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.focus_entered.connect(_select_set.bind(i))
		row.pressed.connect(_open_set.bind(i))
		_rows.add_child(row)
	resized.connect(func() -> void:
		if $Carousel.visible:
			_select(_index)
		else:
			_select_set(_set_index))
	# Coming back from a play: reopen the set on the difficulty just played.
	for i in _sets.size():
		var diff := _sets[i].map(func(map: Beatmap) -> String: return map.path).find(GameState.map_path)
		if diff != -1:
			_open_set(i, diff)
			return
	_rows.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
	elif event is InputEventMouseButton and event.pressed and not _sets.is_empty():
		var step := 0
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				step = -1
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				step = 1
		if step != 0:
			var box: Container = _cards if $Carousel.visible else _rows
			var at := _index if $Carousel.visible else _set_index
			box.get_child(clampi(at + step, 0, box.get_child_count() - 1)).grab_focus()


## Leaves the difficulty carousel for the set list, or the screen from the set list.
func _back() -> void:
	if not $Carousel.visible:
		back_requested.emit()
		return
	$List.show()
	$Carousel.hide()
	_rows.get_child(_set_index).grab_focus()


## Fills the carousel with set i's difficulties and focuses difficulty diff.
func _open_set(i: int, diff := 0) -> void:
	_set_index = i
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	for j in _sets[i].size():
		var map: Beatmap = _sets[i][j]
		var version := "[%s]" % map.version
		if map is ManiaBeatmap:
			version = "%dK %s" % [(map as ManiaBeatmap).key_count(), version]
		var card := _make_card(map, version)
		card.focus_entered.connect(_select.bind(j))
		card.pressed.connect(map_chosen.emit.bind(map.path))
		_cards.add_child(card)
	$Carousel.show()
	$List.hide()
	_cards.get_child(diff).grab_focus()


func _make_card(map: Beatmap, info: String) -> Button:
	var card := CARD.instantiate() as Button
	card.get_node("Art").texture = _load_art(map)
	card.get_node("Info/Title").text = map.title
	card.get_node("Info/Artist").text = map.artist
	card.get_node("Info/Version").text = info
	return card


## Centers row i in the set list.
func _select_set(i: int) -> void:
	_set_index = i
	_focus(_rows, i, "position:y", size.y / 2.0 - (i * (ROW_HEIGHT + ROW_GAP) + ROW_HEIGHT / 2.0))


## Centers card i in the difficulty carousel.
func _select(i: int) -> void:
	_index = i
	_focus(_cards, i, "position:x", size.x / 2.0 - (i * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH / 2.0))


## Brightens child i of box, dims the rest and slides box's property to target.
func _focus(box: Container, i: int, property: String, target: float) -> void:
	for child: Control in box.get_children():
		child.modulate = Color.WHITE if child.get_index() == i else DIM
	if _slide:
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(box, property, target, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Adds one set per folder that has a non-empty .osu of GameState.mode; other modes are skipped.
func _scan(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	var diffs: Array[Beatmap] = []
	for file in dir.get_files():
		if file.get_extension().to_lower() != "osu":
			continue
		var map := Beatmap.from_file(folder.path_join(file))
		if map != null and map.mode == GameState.mode and not map.hit_objects.is_empty():
			diffs.append(map)
	if not diffs.is_empty():
		diffs.sort_custom(func(a: Beatmap, b: Beatmap) -> bool: return a.hit_objects.size() < b.hit_objects.size())
		_sets.append(diffs)
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
