extends Control
## Editor: open or drop a song (mp3, ogg or wav), pick Mania or Standard, and Generate has
## Mapperatorinator, a local AI mapper, write a map of it for that mode into the song's set
## folder under beatmaps/, with difficulty and the other knobs on the settings panel. Over
## the last selected map's dimmed art and themed from it. The root scene handles screen
## changes.

signal back_requested

const MENU := preload("res://scripts/ui/main_menu.gd")
const GENERATOR := preload("res://scripts/beatmap/beatmap_generator.gd")
const MAPPER := preload("res://scripts/beatmap/mapperatorinator.gd")
## The formats Beatmap.load_audio_file decodes.
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]
## The modes the picker offers, as names by gamemode; the first is the default.
const MODES := {Beatmap.MODE_MANIA: "Mania", Beatmap.MODE_STANDARD: "Standard"}
## The settings panel's rows, under group headings: each the Mapperatorinator (Hydra) key
## it sets, its label and either options (a dropdown, first is the default), spin [min,
## max, step, default] (a number box) or hint (a text field; empty leaves the model's
## default). A row with a mode shows and applies only for that gamemode; the rest are shared.
const SETTINGS: Array[Dictionary] = [
	{group = "Basics"},
	{key = "config_name", label = "Model", options = ["v32-mini", "v32"]},
	{key = "keycount", label = "Keys", spin = [1, 10, 1, 4], mode = Beatmap.MODE_MANIA},
	{key = "year", label = "Style year", spin = [2007, 2023, 1, 2023]},
	{key = "descriptors", label = "Descriptors", hint = "e.g. style/clean, skillset/jumps"},
	{key = "device", label = "Device", options = ["cuda", "cpu", "auto"]},
	{group = "Difficulty numbers"},
	{key = "difficulty", label = "Difficulty", spin = [0, 10, 0.1, 4.5]},
	{key = "hp_drain_rate", label = "HP drain", spin = [0, 10, 0.1, 5]},
	{key = "circle_size", label = "CS", spin = [0, 10, 0.1, 4], mode = Beatmap.MODE_STANDARD},
	{key = "overall_difficulty", label = "OD", spin = [0, 10, 0.1, 8]},
	{key = "approach_rate", label = "AR", spin = [0, 10, 0.1, 9], mode = Beatmap.MODE_STANDARD},
	{key = "slider_multiplier", label = "Slider velocity", hint = "empty = model's", mode = Beatmap.MODE_STANDARD},
	{key = "slider_tick_rate", label = "Slider tick rate", hint = "empty = model's", mode = Beatmap.MODE_STANDARD},
	{key = "hold_note_ratio", label = "Hold notes", spin = [0, 1, 0.05, 0.25], mode = Beatmap.MODE_MANIA},
	{key = "scroll_speed_ratio", label = "Scroll speed changes", hint = "0–1, empty = model's", mode = Beatmap.MODE_MANIA},
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
## Each setting's control by key, and each mode-only setting's row, shown with its mode.
var _controls := {}
var _mode_rows := {}
## The running Mapperatorinator's pid (0 when none), the .osu it writes, and the time to
## the next progress read.
var _pid := 0
var _out := ""
var _poll := 0.0

@onready var _open: Button = $Panel/Rows/OpenWrap/Open
@onready var _generate_button: Button = $Panel/Rows/Options/GenerateWrap/Generate
@onready var _mode: OptionButton = $Panel/Rows/Options/Modes/Mode


func _ready() -> void:
	$Art.texture = GameState.map_art
	MapTheme.retarget(GameState.map_art)
	$Back.pressed.connect(back_requested.emit)
	MENU.animate(_open)
	MENU.animate(_generate_button)
	_open.pressed.connect($Picker.popup_centered)
	$Picker.file_selected.connect(_set_file)
	get_window().files_dropped.connect(_on_dropped)
	for gamemode: int in MODES:
		_mode.add_item(MODES[gamemode], gamemode)
	_mode.item_selected.connect(_refresh.unbind(1))
	_generate_button.pressed.connect(_generate)
	_build_settings()
	_refresh()
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
		_status("Wrote %s to beatmaps/%s" % [_out.get_file(), _out.get_base_dir().get_file()])
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


## Generate needs a song, and turns into Cancel while Mapperatorinator runs. HeroButton has
## no disabled look, so dim it. The settings panel shows with a song, with the picked
## mode's rows; the mode holds still while a run is going.
func _refresh() -> void:
	_generate_button.text = "Cancel" if _pid else "Generate"
	_generate_button.disabled = not _pid and _file.is_empty()
	_generate_button.modulate.a = 0.45 if _generate_button.disabled else 1.0
	_mode.disabled = _pid != 0
	var gamemode := _mode.get_selected_id()
	$ManiaPanel.visible = not _file.is_empty()
	$ManiaPanel/Rows/Title.text = "%s settings · Mapperatorinator" % MODES[gamemode]
	for setting: Dictionary in SETTINGS:
		if _mode_rows.has(setting.get("key")):
			_mode_rows[setting.key].visible = setting.mode == gamemode


func _generate() -> void:
	if _pid:
		OS.kill(_pid)
		_pid = 0
		_status("Cancelled")
		_refresh()
		return
	var overrides: Variant = _overrides()
	if overrides is String:
		_status(overrides, true)
		return
	var song := GENERATOR.prepare_set(_file)
	var run := {error = song.error}
	if song.error.is_empty():
		var version := "AI %.1f★" % overrides.difficulty
		if overrides.gamemode == Beatmap.MODE_MANIA:
			version += " %dK" % overrides.keycount
		run = MAPPER.start(song, version, overrides)
	if run.error.is_empty():
		_pid = run.pid
		_out = run.out
		_poll = 0.0
		_status("Mapperatorinator: starting…")
	else:
		_status(run.error, true)
	_refresh()


## Fills the settings panel from SETTINGS, in the Editor's caption style.
func _build_settings() -> void:
	var rows: VBoxContainer = $ManiaPanel/Rows/Scroll/Settings
	for setting: Dictionary in SETTINGS:
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
		_controls[setting.key] = control
		if setting.has("mode"):
			_mode_rows[setting.key] = row


## The picked mode and its settings as Mapperatorinator overrides, or the error for a field
## that isn't a number. Whole-number boxes give ints, as its config wants for keys, year
## and seed.
func _overrides() -> Variant:
	var gamemode := _mode.get_selected_id()
	var overrides := {gamemode = gamemode}
	for setting: Dictionary in SETTINGS:
		if not setting.has("key") or setting.get("mode", gamemode) != gamemode:
			continue
		var control: Control = _controls[setting.key]
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
