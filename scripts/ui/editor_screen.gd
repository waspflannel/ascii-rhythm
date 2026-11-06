extends Control
## Editor: open or drop a song (mp3, ogg or wav), pick Mania, Standard or both, and
## Generate writes maps of it into one set folder under beatmaps/: Mania by
## Mapperatorinator, a local AI mapper, with difficulty and the other knobs on the Mania
## settings panel, and Standard by the heuristic BeatmapGenerator. Over the last selected
## map's dimmed art and themed from it. The root scene handles screen changes.

signal back_requested

const MENU := preload("res://scripts/ui/main_menu.gd")
const GENERATOR := preload("res://scripts/beatmap/beatmap_generator.gd")
const MAPPER := preload("res://scripts/beatmap/mapperatorinator.gd")
## The formats Beatmap.load_audio_file decodes.
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]
## The Mania settings panel's rows, under group headings: each the Mapperatorinator
## (Hydra) key it sets, its label and either options (a dropdown, first is the default),
## spin [min, max, step, default] (a number box) or hint (a text field; empty leaves the
## model's default).
const MANIA_SETTINGS: Array[Dictionary] = [
	{group = "Basics"},
	{key = "config_name", label = "Model", options = ["v32-mini", "v32"]},
	{key = "keycount", label = "Keys", spin = [1, 10, 1, 4]},
	{key = "year", label = "Style year", spin = [2007, 2023, 1, 2023]},
	{key = "descriptors", label = "Descriptors", hint = "e.g. style/clean, skillset/jumps"},
	{key = "device", label = "Device", options = ["cuda", "cpu", "auto"]},
	{group = "Difficulty numbers"},
	{key = "difficulty", label = "Difficulty", spin = [0, 10, 0.1, 4.5]},
	{key = "hp_drain_rate", label = "HP drain", spin = [0, 10, 0.1, 5]},
	{key = "overall_difficulty", label = "OD", spin = [0, 10, 0.1, 8]},
	{key = "hold_note_ratio", label = "Hold notes", spin = [0, 1, 0.05, 0.25]},
	{key = "scroll_speed_ratio", label = "Scroll speed changes", hint = "0–1, empty = model's"},
	{group = "Generation"},
	{key = "temperature", label = "Temperature", spin = [0, 2, 0.05, 0.9]},
	{key = "top_p", label = "Top P", spin = [0, 1, 0.05, 0.9]},
	{key = "cfg_scale", label = "CFG scale", hint = "empty = model's"},
	{key = "seed", label = "Seed", hint = "empty = random"},
]
## Seconds between progress reads of a running Mapperatorinator.
const POLL := 0.5

## The chosen song's path, empty before one is chosen.
var _file := ""
## Each Mania setting's control, by key.
var _mania_controls := {}
## The running Mapperatorinator's pid (0 when none), the .osu it writes, the maps already
## written this Generate, and the time to the next progress read.
var _pid := 0
var _out := ""
var _written: Array[String] = []
var _poll := 0.0

@onready var _open: Button = $Panel/Rows/OpenWrap/Open
@onready var _generate_button: Button = $Panel/Rows/Options/GenerateWrap/Generate
@onready var _mania: CheckBox = $Panel/Rows/Options/Modes/Mania
@onready var _standard: CheckBox = $Panel/Rows/Options/Modes/Standard


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
	_build_mania_settings()
	_open.grab_focus()


## The window outlives this screen, so let go of its drop signal, and of a running mapper.
func _exit_tree() -> void:
	get_window().files_dropped.disconnect(_on_dropped)
	if _pid:
		OS.kill(_pid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Follows a running Mapperatorinator: shows its progress, then its map or its error.
func _process(delta: float) -> void:
	if not _pid:
		return
	if OS.is_process_running(_pid):
		_poll -= delta
		if _poll <= 0.0:
			_poll = POLL
			_status("Mapperatorinator: %s" % MAPPER.progress())
		return
	_pid = 0
	if FileAccess.file_exists(_out):
		_written.append(_out)
		_status("Wrote %d map(s) to beatmaps/%s" % [_written.size(), _out.get_base_dir().get_file()])
	else:
		_status("Mapperatorinator failed: %s" % MAPPER.progress(), true)
	_refresh()


func _on_dropped(files: PackedStringArray) -> void:
	_set_file(files[0])


## Chooses path as the song if it's a format the game plays; otherwise keeps the old one.
func _set_file(path: String) -> void:
	if _pid:
		return
	if path.get_extension().to_lower() not in AUDIO_EXTENSIONS:
		_status("Use an mp3, ogg or wav file", true)
		return
	_file = path
	$Panel/Rows/File.text = path.get_file()
	$Panel/Rows/Options.show()
	_status("")
	_refresh()


## Generate needs a song and at least one mode, and turns into Cancel while Mapperatorinator
## runs. HeroButton has no disabled look, so dim it. The Mania settings show with Mania.
func _refresh() -> void:
	_generate_button.text = "Cancel" if _pid else "Generate"
	_generate_button.disabled = not _pid and (_file.is_empty() or not (_mania.button_pressed or _standard.button_pressed))
	_generate_button.modulate.a = 0.45 if _generate_button.disabled else 1.0
	$ManiaPanel.visible = not _file.is_empty() and _mania.button_pressed


func _generate() -> void:
	if _pid:
		OS.kill(_pid)
		_pid = 0
		_status("Cancelled")
		_refresh()
		return
	var overrides: Variant = _mania_overrides() if _mania.button_pressed else {}
	if overrides is String:
		_status(overrides, true)
		return
	_written.clear()
	_generate_button.disabled = true
	if _standard.button_pressed:
		_status("Analysing…")
		# Let the status paint before the analysis blocks the frame.
		await get_tree().process_frame
		# Standard heuristic has no model knobs; Mania difficulty lives on the Mania panel.
		var result := GENERATOR.generate(_file, false, true, 4.5)
		if not result.error.is_empty():
			# The same song would fail again, so it has to be chosen anew.
			_status(result.error, true)
			_file = ""
			$Panel/Rows/File.text = ""
			_refresh()
			return
		_written.assign(result.paths)
		_status("Wrote %d map(s) to beatmaps/%s" % [_written.size(), result.folder])
	if _mania.button_pressed:
		var song := GENERATOR.prepare_set(_file)
		var run := {error = song.error}
		if song.error.is_empty():
			var version := "AI %.1f★ %dK" % [overrides.difficulty, overrides.keycount]
			run = MAPPER.start(song, version, overrides)
		if run.error.is_empty():
			_pid = run.pid
			_out = run.out
			_poll = 0.0
			_status("Mapperatorinator: starting…")
		else:
			_status(run.error, true)
	_refresh()


## Fills the Mania settings panel from MANIA_SETTINGS, in the Editor's caption style.
func _build_mania_settings() -> void:
	var rows: VBoxContainer = $ManiaPanel/Rows/Scroll/Settings
	for setting: Dictionary in MANIA_SETTINGS:
		if setting.has("group"):
			var heading := Label.new()
			heading.theme_type_variation = &"AccentLabel"
			heading.text = setting.group
			rows.add_child(heading)
			continue
		var caption := Label.new()
		caption.custom_minimum_size.x = 200
		caption.theme_type_variation = &"CaptionLabel"
		caption.add_theme_font_size_override("font_size", 18)
		caption.text = setting.label
		var control: Control
		if setting.has("options"):
			var pick := OptionButton.new()
			for option: String in setting.options:
				pick.add_item(option)
			control = pick
		elif setting.has("spin"):
			var spin := SpinBox.new()
			spin.min_value = setting.spin[0]
			spin.max_value = setting.spin[1]
			spin.step = setting.spin[2]
			spin.value = setting.spin[3]
			control = spin
		else:
			var field := LineEdit.new()
			field.placeholder_text = setting.hint
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control = field
		control.custom_minimum_size.x = 160
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.add_child(caption)
		row.add_child(control)
		rows.add_child(row)
		_mania_controls[setting.key] = control


## The Mania settings as Mapperatorinator overrides, or the error for a field that isn't
## a number. Whole-number boxes give ints, as its config wants for keys, year and seed.
func _mania_overrides() -> Variant:
	var overrides := {}
	for setting: Dictionary in MANIA_SETTINGS:
		if not setting.has("key"):
			continue
		var control: Control = _mania_controls[setting.key]
		if control is OptionButton:
			var pick := control as OptionButton
			overrides[setting.key] = pick.get_item_text(pick.selected)
		elif control is SpinBox:
			var spin := control as SpinBox
			overrides[setting.key] = int(spin.value) if spin.step >= 1.0 else spin.value
		else:
			var text := (control as LineEdit).text.strip_edges()
			if text.is_empty():
				continue
			if setting.key == "descriptors":
				overrides["descriptors"] = Array(text.split(",", false)).map(func(d: String) -> String: return d.strip_edges())
			elif setting.key == "seed" and text.is_valid_int():
				overrides["seed"] = text.to_int()
			elif setting.key != "seed" and text.is_valid_float():
				overrides[setting.key] = text.to_float()
			else:
				return "%s must be a %snumber" % [setting.label, "whole " if setting.key == "seed" else ""]
	return overrides


func _status(text: String, error := false) -> void:
	var label: Label = $Panel/Rows/Status
	label.text = text
	if error:
		label.add_theme_color_override("font_color", Palette.CRIMSON)
	else:
		label.remove_theme_color_override("font_color")
