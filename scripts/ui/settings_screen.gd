extends Control
## Settings: volumes, audio offset, mania scroll speed and the dither look, over the last
## selected map's dimmed art and themed from it. Every change applies and saves straight
## away; scroll speed and beat pulse take effect from the next play. The Colour and Dither
## rows open a popover beside the panel with the colour picker or the dither knobs. The
## root scene handles screen changes.

signal back_requested

## Caption and value column widths of the panel's rows.
const COLUMNS := Vector2(200, 96)
## The narrower columns of popover rows.
const POPOVER_COLUMNS := Vector2(130, 64)
## Opacity of popover rows the current mode or pattern ignores.
const DIMMED := 0.4
## Seconds Reset to default waits for its confirming second press.
const RESET_CONFIRM := 3.0

var _master: HSlider
## The Colour row's button and the swatch on it, which follow the dither colour.
var _colour: Button
var _swatch: ColorRect
## The row button whose popover is open, so closing returns focus to it; null when closed.
var _opener: Button

@onready var _rows: VBoxContainer = $Panel/Rows
@onready var _popover: PanelContainer = $Popover
@onready var _popover_rows: VBoxContainer = $Popover/Content/Rows


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
	_colour_row()
	var dither := Button.new()
	var strength := _row("Dither", dither)
	_follow_dither(dither, func() -> void:
		dither.text = _dither_summary()
		strength.text = _dither_strength())
	dither.pressed.connect(_open_popover.bind(dither, "DITHER", _build_dither))
	_reset_row()
	_choice("Beat pulse", "dither", "beat_pulse", [true, false])
	# Ctrl + wheel changes the master volume on this screen too.
	Settings.audio_changed.connect(_sync_master)
	_master.grab_focus()


## The swatch and hex follow the dither colour every frame, so Follow map blends show.
func _process(_delta: float) -> void:
	var accent := MapTheme.dither_accent()
	_swatch.color = accent
	_colour.text = AccentPicker.html(accent)


## Esc closes the popover first, then leaves Settings.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _opener:
			_close_popover()
		else:
			back_requested.emit()


## A click on empty space closes the popover.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _opener and click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_close_popover()


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


## Adds a caption, control and value label row to parent (the panel, or popover rows) and
## returns the value label. The caption lights up while the control has focus, and
## hovering focuses it, unless a text field has the focus (a hex being typed) or the
## control is outside an open popover (so the keys stay in the popover).
func _row(caption: String, control: Control, parent := _rows) -> Label:
	var columns := COLUMNS if parent == _rows else POPOVER_COLUMNS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.theme_type_variation = &"CaptionLabel"
	title.add_theme_font_size_override("font_size", 18)
	title.custom_minimum_size.x = columns.x
	title.text = caption
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.custom_minimum_size.x = columns.y
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for child in [title, control, value]:
		row.add_child(child)
	parent.add_child(row)
	control.mouse_entered.connect(func() -> void:
		var typing := get_viewport().gui_get_focus_owner() is LineEdit
		if not typing and (not _opener or _popover.is_ancestor_of(control)):
			control.grab_focus())
	control.focus_entered.connect(func() -> void: title.add_theme_color_override("font_color", Palette.WHITE))
	control.focus_exited.connect(func() -> void: title.remove_theme_color_override("font_color"))
	return value


## Adds a slider for a number setting, shown as the setting times factor in format.
## Factor 1 keeps the setting a whole number. Dither settings redraw the screen at once.
func _slider(caption: String, section: String, key: String, low: int, high: int, factor: float, format: String, parent := _rows) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	var value := _row(caption, slider, parent)
	slider.set_value_no_signal(roundf(float(Settings.get_value(section, key)) * factor))
	value.text = format % slider.value
	slider.value_changed.connect(func(at: float) -> void:
		value.text = format % at
		Settings.set_value(section, key, at / factor if factor != 1.0 else int(at))
		Settings.save_settings()
		if section == "audio":
			Settings.apply_audio()
		elif section == "dither":
			Settings.dither_changed.emit())
	return slider


## Adds a button that steps through options: Enter for the next, a click on the left or
## right half for the previous or next, or the left and right arrows like the sliders.
## The screen redraws through the new dither setting straight away. labels, if given,
## show in place of the options; true and false show as ON and OFF.
func _choice(caption: String, section: String, key: String, options: Array, parent := _rows, labels := []) -> Button:
	var button := Button.new()
	_row(caption, button, parent)
	var refresh := func() -> void:
		var option: Variant = Settings.get_value(section, key)
		var at := options.find(option)
		var label := str(option).to_upper()
		if at >= 0 and not labels.is_empty():
			label = labels[at]
		elif option is bool:
			label = "ON" if option else "OFF"
		button.text = "‹    %s    ›" % label
	var step := func(by: int) -> void:
		var at := options.find(Settings.get_value(section, key))
		Settings.set_value(section, key, options[posmod(at + by, options.size())])
		Settings.save_settings()
		Settings.dither_changed.emit()
	_follow_dither(button, refresh)
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
	return button


## Calls refresh now and after every dither change while node is in the tree, so rows
## follow changes made elsewhere (a picked colour, Reset) and never touch a freed node.
func _follow_dither(node: Node, refresh: Callable) -> void:
	refresh.call()
	Settings.dither_changed.connect(refresh)
	node.tree_exiting.connect(func() -> void: Settings.dither_changed.disconnect(refresh))


## Adds the Colour row: a swatch and hex of the dither colour that opens the picker.
func _colour_row() -> void:
	_colour = Button.new()
	_row("Colour", _colour)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(28.0, 14.0)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colour.add_child(_swatch)
	_swatch.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	_colour.pressed.connect(_open_popover.bind(_colour, "COLOUR", _build_colour))


## Adds Reset to default: the first press asks for a second within RESET_CONFIRM seconds,
## which restores every dither setting but beat pulse.
func _reset_row() -> void:
	var reset := Button.new()
	reset.text = "RESET"
	_row("Reset to default", reset)
	var confirm := Timer.new()
	confirm.one_shot = true
	confirm.wait_time = RESET_CONFIRM
	confirm.timeout.connect(func() -> void: reset.text = "RESET")
	reset.add_child(confirm)
	reset.pressed.connect(func() -> void:
		if confirm.is_stopped():
			reset.text = "PRESS AGAIN"
			confirm.start()
			return
		confirm.stop()
		reset.text = "RESET"
		Settings.reset_dither()
		if _opener:
			# Reopens the popover, so it shows the restored values.
			_opener.pressed.emit()
			reset.grab_focus())


## The Dither row's summary, such as RGB · BAYER 8×8, or OFF.
func _dither_summary() -> String:
	var mode := str(Settings.get_value("dither", "mode"))
	if mode == "off":
		return "OFF"
	var pattern := str(Settings.get_value("dither", "pattern"))
	var summary := "%s · %s" % [mode.to_upper(), pattern.to_upper()]
	if pattern == "bayer":
		var size: int = Settings.get_value("dither", "matrix_size")
		summary += " %d×%d" % [size, size]
	return summary


## The Dither row's value: the strength, such as 60%, or nothing when the mode or pattern
## ignores it.
func _dither_strength() -> String:
	if Settings.get_value("dither", "mode") == "off" or Settings.get_value("dither", "pattern") == "flat":
		return ""
	return "%d%%" % roundi(clampf(Settings.get_value("dither", "strength"), 0.0, 1.0) * 100.0)


## Opens a popover beside the panel with build's rows and focuses its first control; Up
## and Down wrap within it. Replaces any open popover.
func _open_popover(opener: Button, title: String, build: Callable) -> void:
	_clear_popover()
	_opener = opener
	$Popover/Content/Title/Label.text = title
	build.call(_popover_rows)
	_popover.show()
	# Shrink to the new content.
	_popover.size.y = 0.0
	var focusable := _popover_rows.find_children("*", "Control", true, false).filter(func(node: Control) -> bool:
		return node.focus_mode == Control.FOCUS_ALL)
	var first: Control = focusable.front()
	var last: Control = focusable.back()
	first.focus_neighbor_top = first.get_path_to(last)
	last.focus_neighbor_bottom = last.get_path_to(first)
	first.grab_focus()


## Closes the popover and returns focus to the row that opened it.
func _close_popover() -> void:
	# Focus first, so a hex being typed submits while the picker is still there.
	_opener.grab_focus()
	_opener = null
	_clear_popover()
	_popover.hide()


## Frees the popover's rows; their dither_changed connections go with them.
func _clear_popover() -> void:
	for child in _popover_rows.get_children():
		_popover_rows.remove_child(child)
		child.queue_free()


## The Colour popover: the picker, Follow map and Tint. Picking a colour turns Follow map
## off, so the picked colour shows on every screen.
func _build_colour(rows: VBoxContainer) -> void:
	var picker := AccentPicker.new()
	picker.caption_width = POPOVER_COLUMNS.x
	rows.add_child(picker)
	_follow_dither(picker, func() -> void: picker.set_color(MapTheme.dither_accent()))
	picker.changed.connect(func(color: Color) -> void:
		Settings.set_value("dither", "accent", "#" + color.to_html(false))
		Settings.set_value("dither", "follow_map", false)
		Settings.dither_changed.emit())
	picker.committed.connect(Settings.save_settings)
	_choice("Follow map", "dither", "follow_map", [true, false], rows)
	_slider("Tint", "dither", "tint", 0, 100, 100.0, "%d%%", rows)


## The Dither popover: every shader knob. Rows the current mode or pattern ignores are
## dimmed but stay editable.
func _build_dither(rows: VBoxContainer) -> void:
	var sizes := Settings.MATRIX_SIZES.map(func(size: int) -> String: return "%d×%d" % [size, size])
	var mode := _choice("Mode", "dither", "mode", Settings.DITHER_MODES, rows)
	var pattern := _choice("Pattern", "dither", "pattern", Settings.DITHER_PATTERNS, rows)
	var strength := _slider("Strength", "dither", "strength", 0, 100, 100.0, "%d%%", rows)
	var matrix := _choice("Matrix", "dither", "matrix_size", Settings.MATRIX_SIZES, rows, sizes)
	_slider("Cell size", "dither", "pixel_scale", 1, 8, 1.0, "%d px", rows)
	var levels := _slider("Colour levels", "dither", "color_levels", 2, 16, 1.0, "%d", rows)
	var shades := _slider("Shades", "dither", "shades", 2, 7, 1.0, "%d", rows)
	var skin := _choice("Skin colours", "dither", "skin_colours", [true, false], rows)
	_slider("Scanlines", "dither", "scanlines", 0, 100, 100.0, "%d%%", rows)
	_slider("Film grain", "dither", "grain", 0, 20, 100.0, "%d%%", rows)
	_follow_dither(mode, func() -> void:
		var chosen := str(Settings.get_value("dither", "pattern"))
		var off: bool = Settings.get_value("dither", "mode") == "off"
		var palette: bool = Settings.get_value("dither", "mode") == "palette"
		var dims := {
			pattern: off, strength: off or chosen == "flat", matrix: off or chosen != "bayer",
			levels: off or palette, shades: not palette, skin: not palette,
		}
		for control: Control in dims:
			control.get_parent().modulate.a = DIMMED if dims[control] else 1.0)
