extends Control
## Editor: open or drop a song (mp3, ogg or wav), pick Mania, Standard or both and a star
## rating, and Generate writes heuristic maps of it into beatmaps/ (see BeatmapGenerator),
## over the last selected map's dimmed art and themed from it. The root scene handles
## screen changes.

signal back_requested

const MENU := preload("res://scripts/ui/main_menu.gd")
## The formats Beatmap.load_audio_file decodes.
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]

## The chosen song's path, empty before one is chosen.
var _file := ""

@onready var _open: Button = $Panel/Rows/OpenWrap/Open
@onready var _generate_button: Button = $Panel/Rows/Options/GenerateWrap/Generate
@onready var _mania: CheckBox = $Panel/Rows/Options/Modes/Mania
@onready var _standard: CheckBox = $Panel/Rows/Options/Modes/Standard
@onready var _rating: SpinBox = $Panel/Rows/Options/Stars/Rating


func _ready() -> void:
	$Art.texture = GameState.map_art
	MapTheme.retarget(GameState.map_art)
	$Back.pressed.connect(back_requested.emit)
	MENU.animate(_open)
	MENU.animate(_generate_button)
	_open.pressed.connect($Picker.popup_centered)
	$Picker.file_selected.connect(_set_file)
	get_window().files_dropped.connect(_on_dropped)
	_mania.toggled.connect(_refresh.unbind(1))
	_standard.toggled.connect(_refresh.unbind(1))
	_generate_button.pressed.connect(_generate)
	_open.grab_focus()


## The window outlives this screen, so let go of its drop signal.
func _exit_tree() -> void:
	get_window().files_dropped.disconnect(_on_dropped)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _on_dropped(files: PackedStringArray) -> void:
	_set_file(files[0])


## Chooses path as the song if it's a format the game plays; otherwise keeps the old one.
func _set_file(path: String) -> void:
	if path.get_extension().to_lower() not in AUDIO_EXTENSIONS:
		_status("Use an mp3, ogg or wav file", true)
		return
	_file = path
	$Panel/Rows/File.text = path.get_file()
	$Panel/Rows/Options.show()
	_status("")
	_refresh()


## Generate needs a song and at least one mode. HeroButton has no disabled look, so dim it.
func _refresh() -> void:
	_generate_button.disabled = _file.is_empty() or not (_mania.button_pressed or _standard.button_pressed)
	_generate_button.modulate.a = 0.45 if _generate_button.disabled else 1.0


func _generate() -> void:
	_status("Analysing…")
	_generate_button.disabled = true
	# Let the status paint before the analysis blocks the frame.
	await get_tree().process_frame
	var result := BeatmapGenerator.generate(_file, _mania.button_pressed, _standard.button_pressed, _rating.value)
	if result.error.is_empty():
		_status("Wrote %d map(s) to beatmaps/%s" % [result.paths.size(), result.folder])
	else:
		# The same song would fail again, so it has to be chosen anew.
		_status(result.error, true)
		_file = ""
		$Panel/Rows/File.text = ""
	_refresh()


func _status(text: String, error := false) -> void:
	var label: Label = $Panel/Rows/Status
	label.text = text
	if error:
		label.add_theme_color_override("font_color", Palette.CRIMSON)
	else:
		label.remove_theme_color_override("font_color")
