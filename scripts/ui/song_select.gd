extends Control
## Two-stage song select for GameState.mode: a vertical list of map sets (one per
## beatmaps/ folder), then a horizontal carousel of the chosen set's difficulties.
## The focused map's background art fills the screen, dimmed, MapTheme tints the UI to
## its colours, its song plays from the preview point, and a panel describes the focused
## set or difficulty. The focused map is remembered for mode select. The root scene
## handles screen changes.

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
## Seconds to cross-fade the background art.
const ART_FADE := 0.35
## Seconds to fade a song preview in.
const PREVIEW_FADE := 0.6
const LIST_HINT := "↑ ↓  select      ENTER  open      ESC  back"
const CAROUSEL_HINT := "← →  select      ENTER  play      ESC  back"

## One Array[Beatmap] per map folder, easiest difficulty (fewest objects) first.
var _sets: Array[Array] = []
## Background textures by file path; difficulties in one set share an image.
var _art := {}
var _set_index := 0
var _index := 0
var _slide: Tween
var _art_fade: Tween
## The art rect shown on top; the other one fades out under it.
var _art_front: TextureRect
## The previewed song's file and start; difficulties sharing a song keep it playing.
var _preview_file := ""
var _preview_at := 0.0
var _preview := AudioStreamPlayer.new()
var _preview_fade: Tween

@onready var _rows: VBoxContainer = $List/Rows
@onready var _cards: HBoxContainer = $Carousel/Cards


func _ready() -> void:
	$Back.pressed.connect(_back)
	$ModeLabel.text = "MANIA" if GameState.mode == Beatmap.MODE_MANIA else "STANDARD"
	_art_front = $ArtFront
	_preview.bus = &"Music"
	add_child(_preview)
	_preview.finished.connect(func() -> void: _preview.play(_preview_at))
	# ponytail: parses every .osu on open; add the cached library index from DESIGN.md when folders get big.
	_scan("res://beatmaps")
	if _sets.is_empty():
		$Empty.show()
		$List/SetInfo.hide()
		$Hint.text = "ESC  back"
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
	_show_stage(false)
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
	var first: Beatmap = _sets[i][0]
	$Carousel/SetTitle/Title.text = first.title
	$Carousel/SetTitle/Artist.text = first.artist
	_show_stage(true)
	_cards.get_child(diff).grab_focus()


## Shows the difficulty carousel or the set list, with that stage's key hints.
func _show_stage(carousel: bool) -> void:
	$Carousel.visible = carousel
	$List.visible = not carousel
	$Hint.text = CAROUSEL_HINT if carousel else LIST_HINT


func _make_card(map: Beatmap, info: String) -> Button:
	var card := CARD.instantiate() as Button
	card.get_node("Art").texture = _load_art(map)
	card.get_node("Info/Title").text = map.title
	card.get_node("Info/Artist").text = map.artist
	card.get_node("Info/Version").text = info
	return card


## Centers row i in the set list and describes its set.
func _select_set(i: int) -> void:
	_set_index = i
	_focus(_rows, i, "position:y", size.y / 2.0 - (i * (ROW_HEIGHT + ROW_GAP) + ROW_HEIGHT / 2.0))
	var maps: Array = _sets[i]
	var first: Beatmap = maps[0]
	$List/SetInfo/Items/Title.text = first.title
	$List/SetInfo/Items/Artist.text = first.artist
	$List/SetInfo/Items/Mapper.text = "mapped by %s" % first.creator
	$List/SetInfo/Items/Count.text = "%d %s" % [maps.size(), "DIFFICULTY" if maps.size() == 1 else "DIFFICULTIES"]
	_show_map(first)


## Centers card i in the difficulty carousel and describes its difficulty.
func _select(i: int) -> void:
	_index = i
	_focus(_cards, i, "position:x", size.x / 2.0 - (i * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH / 2.0))
	var map: Beatmap = _sets[_set_index][i]
	$Carousel/DiffInfo/Items/Version.text = map.version
	$Carousel/DiffInfo/Items/Stats.text = _difficulty_stats(map)
	_show_map(map)


## One line of difficulty settings, object count and length for the info panel.
func _difficulty_stats(map: Beatmap) -> String:
	var size_stat := "CS %.1f   AR %.1f" % [map.circle_size, map.approach_rate]
	if map is ManiaBeatmap:
		size_stat = "%dK" % (map as ManiaBeatmap).key_count()
	var end := 0.0
	for object in map.hit_objects:
		end = maxf(end, maxf(object.time, object.end_time))
	var seconds := int(end)
	return "%s   HP %.1f   OD %.1f   ·   %d objects   ·   %d:%02d" % [
		size_stat, map.hp_drain, map.overall_difficulty, map.hit_objects.size(), seconds / 60, seconds % 60]


## Shows map's art, plays its song and remembers it as the last selected map.
func _show_map(map: Beatmap) -> void:
	var art := _load_art(map)
	_show_art(art)
	_play_preview(map)
	GameState.map_art = art
	Settings.set_value("history", "last_map", map.path)


func _exit_tree() -> void:
	Settings.save_settings()


## Loops map's song from its preview point, fading in; maps without playable audio go quiet.
func _play_preview(map: Beatmap) -> void:
	var file := map.path.get_base_dir().path_join(map.audio_filename)
	if file == _preview_file:
		return
	_preview_file = file
	_preview_at = map.preview_time
	if _preview_fade:
		_preview_fade.kill()
	_preview.stream = map.load_audio()
	if _preview.stream == null:
		_preview.stop()
		return
	_preview.volume_linear = 0.0
	_preview.play(_preview_at)
	_preview_fade = create_tween()
	_preview_fade.tween_property(_preview, "volume_linear", 1.0, PREVIEW_FADE)


## Cross-fades the backdrop to texture and blends the theme to its colours; maps without
## art fade out to the stars and Neptune's blue.
func _show_art(texture: Texture2D) -> void:
	if _art_front.texture == texture and _art_front.modulate.a > 0.0:
		return
	MapTheme.retarget(texture)
	if _art_fade:
		_art_fade.kill()
	var back := _art_front
	_art_front = $ArtBack if _art_front == $ArtFront else $ArtFront
	move_child(_art_front, back.get_index())
	_art_front.texture = texture
	_art_fade = create_tween().set_parallel()
	_art_fade.tween_property(_art_front, "modulate:a", 1.0 if texture else 0.0, ART_FADE)
	_art_fade.tween_property(back, "modulate:a", 0.0, ART_FADE)


## Brightens child i of box, dims the rest and slides box's property to target.
func _focus(box: Container, i: int, property: String, target: float) -> void:
	for child: Control in box.get_children():
		var selected := child.get_index() == i
		child.modulate = Color.WHITE if selected else DIM
		child.get_node("Accent").visible = selected
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
	if not _art.has(path):
		_art[path] = map.load_background()
	return _art[path]
