extends Control
## Settings: volumes, audio offset, mania scroll speed and the dither look, over the last
## selected map's dimmed art and themed from it. Every change applies and saves straight
## away; scroll speed and beat pulse take effect from the next play. The root scene
## handles screen changes.

signal back_requested

## Settings dither/palette choices: Palette.DITHER names, then per-channel "rgb".
const PALETTES := ["neptune", "crimson", "rgb"]

var _master: HSlider

@onready var _rows: VBoxContainer = $Panel/Rows


func _ready() -> void:
	$Art.texture = GameState.map_art
	MapTheme.retarget(GameState.map_art)
	$Back.pressed.connect(back_requested.emit)
	_section("AUDIO")
	_master = _slider("Master volume", "audio", "volume", 0, 100, 100.0, "%d%%")
	_slider("Music volume", "audio", "music_volume", 0, 100, 100.0, "%d%%")
	_slider("SFX volume", "audio", "sfx_volume", 0, 100, 100.0, "%d%%")
	_slider("Audio offset", "audio", "offset_ms", -500, 500, 1.0, "%+d ms")
	_section("MANIA")
	_slider("Scroll speed", "mania", "scroll_speed", 1, 40, 1.0, "%d")
	_section("DITHER")
	_choice("Filter", "dither", "filter", Palette.FILTERS.keys())
	_choice("Palette", "dither", "palette", PALETTES)
	_choice("Beat pulse", "dither", "beat_pulse", [true, false])
	# Ctrl + wheel changes the master volume on this screen too.
	Settings.audio_changed.connect(_sync_master)
	_master.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _sync_master() -> void:
	_master.value = roundf(float(Settings.get_value("audio", "volume")) * 100.0)


func _section(title: String) -> void:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"CaptionBar"
	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.add_theme_font_size_override("font_size", 17)
	label.text = title
	bar.add_child(label)
	_rows.add_child(bar)


## Adds a caption, control and value label row and returns the value label. The caption
## lights up while the control has focus, and hovering focuses it.
func _row(caption: String, control: Control) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.theme_type_variation = &"CaptionLabel"
	title.add_theme_font_size_override("font_size", 18)
	title.custom_minimum_size.x = 200.0
	title.text = caption
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.custom_minimum_size.x = 96.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for child in [title, control, value]:
		row.add_child(child)
	_rows.add_child(row)
	control.mouse_entered.connect(control.grab_focus)
	control.focus_entered.connect(func() -> void: title.add_theme_color_override("font_color", Palette.WHITE))
	control.focus_exited.connect(func() -> void: title.remove_theme_color_override("font_color"))
	return value


## Adds a slider for a number setting, shown as the setting times factor in format.
## Factor 1 keeps the setting a whole number.
func _slider(caption: String, section: String, key: String, low: int, high: int, factor: float, format: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	var value := _row(caption, slider)
	slider.set_value_no_signal(roundf(float(Settings.get_value(section, key)) * factor))
	value.text = format % slider.value
	slider.value_changed.connect(func(at: float) -> void:
		value.text = format % at
		Settings.set_value(section, key, at / factor if factor != 1.0 else int(at))
		Settings.save_settings()
		if section == "audio":
			Settings.apply_audio())
	return slider


## Adds a button that steps through options: Enter for the next, a click on the left or
## right half for the previous or next, or the left and right arrows like the sliders.
## The screen redraws through the new dither setting straight away. True and false show
## as ON and OFF.
func _choice(caption: String, section: String, key: String, options: Array) -> void:
	var button := Button.new()
	_row(caption, button)
	var refresh := func() -> void:
		var option: Variant = Settings.get_value(section, key)
		var label := str(option).to_upper()
		if option is bool:
			label = "ON" if option else "OFF"
		button.text = "‹    %s    ›" % label
	var step := func(by: int) -> void:
		var at := options.find(Settings.get_value(section, key))
		Settings.set_value(section, key, options[posmod(at + by, options.size())])
		Settings.save_settings()
		Settings.dither_changed.emit()
		refresh.call()
	refresh.call()
	button.pressed.connect(step.bind(1))
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.button_index == MOUSE_BUTTON_LEFT:
			# Clicks step here, not through pressed, so each half steps its own way.
			button.accept_event()
			if click.pressed:
				step.call(-1 if click.position.x < button.size.x / 2.0 else 1)
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			button.accept_event()
			step.call(-1 if event.is_action_pressed("ui_left") else 1))
