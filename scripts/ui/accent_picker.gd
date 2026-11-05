class_name AccentPicker
extends VBoxContainer
## The Settings picker for the dither colour: a saturation x value square, a hue strip and
## a hex field. Plain Controls drawing GradientTexture2D, because Godot's ColorPicker opens
## popup windows, which would draw outside the dithered SubViewport. Keys: Left and Right
## change the square's saturation or the strip's hue; Enter grabs the square's dot so all
## four arrows move it, and Enter or Esc lets go.

## Fires on every change, each drag motion included, so the screen follows live.
signal changed(color: Color)
## Fires when a change is done (drag release, key step or hex submit), so it can be saved.
signal committed

## Saturation or value change per arrow key on the square.
const STEP := 0.02
## Hue change per arrow key on the strip.
const HUE_STEP := 1.0 / 180.0
## The hue strip, red round to red again.
const HUES := [Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA, Color.RED]

## Width of the Hex caption, so the field lines up with the rows around the picker.
var caption_width: float

## The colour as hue, saturation and value, kept apart so a grey keeps its hue.
var _hue := 0.0
var _saturation := 0.0
var _value := 1.0
## True while Enter holds the square's dot, so Up and Down move it instead of the focus.
var _grabbed := false
## The saturation x value square, with the dot at the colour.
var _square := Control.new()
## The square's two layers: white to the pure hue across, then a fade to black down.
var _hue_fill := _gradient([Color.WHITE, Color.RED], Vector2.RIGHT)
var _black_fade := _gradient([Color(0.0, 0.0, 0.0, 0.0), Color.BLACK], Vector2.DOWN)
## The hue strip, with a marker at the hue.
var _strip := Control.new()
var _strip_fill := _gradient(HUES, Vector2.RIGHT)
## The colour as #RRGGBB; typing a hex applies it.
var _hex := LineEdit.new()


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_square.custom_minimum_size.y = 170.0
	_strip.custom_minimum_size.y = 18.0
	for area: Control in [_square, _strip]:
		area.focus_mode = Control.FOCUS_ALL
		area.focus_entered.connect(area.queue_redraw)
		area.focus_exited.connect(area.queue_redraw)
		add_child(area)
	_square.draw.connect(_draw_square)
	_square.gui_input.connect(_square_input)
	_square.focus_exited.connect(func() -> void: _grabbed = false)
	_strip.draw.connect(_draw_strip)
	_strip.gui_input.connect(_strip_input)
	add_child(_hex_row())


## Shows color, without emitting changed. The colour already shown is left alone, so the
## picker's own changes coming back through Settings keep the hue and the typed hex.
func set_color(color: Color) -> void:
	if _hex.text.to_upper() == html(color):
		return
	_set_hsv(color)
	_hex.text = html(color)


## A texture of colors spread evenly from the top left corner along direction.
static func _gradient(colors: Array, direction: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(range(colors.size()).map(func(i: int) -> float: return i / (colors.size() - 1.0)))
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = direction
	return texture


## color as the hex field shows it, #RRGGBB.
static func html(color: Color) -> String:
	return "#" + color.to_html(false).to_upper()


## -1 or 1 when event presses the negative or positive action (key repeats too), else 0.
static func _axis(event: InputEvent, negative: StringName, positive: StringName) -> int:
	return int(event.is_action_pressed(positive, true)) - int(event.is_action_pressed(negative, true))


## The Hex caption and field, styled like the Settings rows around the picker.
func _hex_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var caption := Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.add_theme_font_size_override("font_size", 18)
	caption.custom_minimum_size.x = caption_width
	caption.text = "Hex"
	_hex.max_length = 7
	# The field is always full, so the first key typed replaces the whole hex.
	_hex.select_all_on_focus = true
	_hex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex.gui_input.connect(_hex_input)
	_hex.text_changed.connect(_hex_changed)
	_hex.text_submitted.connect(_submit_hex.unbind(1))
	_hex.focus_entered.connect(func() -> void: caption.add_theme_color_override("font_color", Palette.WHITE))
	_hex.focus_exited.connect(func() -> void: caption.remove_theme_color_override("font_color"))
	_hex.focus_exited.connect(_submit_hex)
	row.add_child(caption)
	row.add_child(_hex)
	return row


## The colour the square, strip and hex show.
func _color() -> Color:
	return Color.from_hsv(_hue, _saturation, _value)


## Takes color's hue, saturation and value. Greys keep the current hue and black the
## current saturation too, so the strip and dot stay put.
func _set_hsv(color: Color) -> void:
	if color.s > 0.0 and color.v > 0.0:
		_hue = color.h
	if color.v > 0.0:
		_saturation = color.s
	_value = color.v
	_redraw()


## Recolours the square for the hue and redraws the dot and marker.
func _redraw() -> void:
	_hue_fill.gradient.set_color(1, Color.from_hsv(_hue, 1.0, 1.0))
	_square.queue_redraw()
	_strip.queue_redraw()


## After a change on the square or strip: redraws, shows the hex and tells the screen.
func _moved() -> void:
	_redraw()
	_hex.text = html(_color())
	changed.emit(_color())


## A key step on area: applies it, commits it and keeps the key from moving the focus.
func _step(area: Control) -> void:
	_moved()
	committed.emit()
	area.accept_event()


## Mouse picking for the square and strip: a left press or drag (held outside area too)
## calls pick with the pointer's position in area, 0 to 1 on each axis; the release commits.
func _mouse(event: InputEvent, area: Control, pick: Callable) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	var left := button != null and button.button_index == MOUSE_BUTTON_LEFT
	if left and not button.pressed:
		committed.emit()
	elif left or (motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		area.grab_focus()
		var at := (event as InputEventMouse).position / area.size
		pick.call(at.clamp(Vector2.ZERO, Vector2.ONE))
		_moved()
	else:
		return
	area.accept_event()


## The square: mouse, Left and Right for saturation, Enter to grab the dot, and while
## grabbed Up and Down for value and Enter or Esc to let go.
func _square_input(event: InputEvent) -> void:
	_mouse(event, _square, func(at: Vector2) -> void:
		_saturation = at.x
		_value = 1.0 - at.y)
	var across := _axis(event, "ui_left", "ui_right")
	var up := _axis(event, "ui_down", "ui_up") if _grabbed else 0
	if across != 0 or up != 0:
		_saturation = clampf(_saturation + across * STEP, 0.0, 1.0)
		_value = clampf(_value + up * STEP, 0.0, 1.0)
		_step(_square)
	elif event.is_action_pressed("ui_accept") or (_grabbed and event.is_action_pressed("ui_cancel")):
		_grabbed = not _grabbed
		_square.queue_redraw()
		_square.accept_event()


## The strip: mouse, and Left and Right for hue.
func _strip_input(event: InputEvent) -> void:
	_mouse(event, _strip, func(at: Vector2) -> void: _hue = at.x)
	var across := _axis(event, "ui_left", "ui_right")
	if across != 0:
		_hue = fposmod(_hue + across * HUE_STEP, 1.0)
		_step(_strip)


## Up and Down move the focus on from the hex field like from any row; LineEdit would
## take them as Home and End. Esc stops editing and goes on to close the popover, and Left
## and Right outside editing stay put instead of moving the focus out of the popover.
func _hex_input(event: InputEvent) -> void:
	var down := _axis(event, "ui_up", "ui_down")
	if event.is_action_pressed("ui_cancel") and _hex.is_editing():
		_hex.unedit()
	elif _axis(event, "ui_left", "ui_right") != 0 and not _hex.is_editing():
		_hex.accept_event()
	elif down != 0:
		_hex.accept_event()
		var next := _hex.find_valid_focus_neighbor(SIDE_BOTTOM if down > 0 else SIDE_TOP)
		if next:
			next.grab_focus()


## Applies a full six-digit hex as it is typed; shorter text waits for submit.
func _hex_changed(text: String) -> void:
	if text.trim_prefix("#").length() == 6 and Color.html_is_valid(text):
		var color := Color.html(text)
		_set_hsv(color)
		changed.emit(color)


## On Enter or leaving the field: applies an edited hex if valid (#RGB too) or puts back
## the current colour, then commits.
func _submit_hex() -> void:
	var color := _color()
	if _hex.text != html(color) and Color.html_is_valid(_hex.text):
		color = Color(Color.html(_hex.text), 1.0)
		_set_hsv(color)
		changed.emit(color)
	_hex.text = html(color)
	committed.emit()


## The two square layers, a ringed dot, and a focus border (light blue while grabbed).
func _draw_square() -> void:
	var rect := Rect2(Vector2.ZERO, _square.size)
	_square.draw_texture_rect(_hue_fill, rect, false)
	_square.draw_texture_rect(_black_fade, rect, false)
	var dot := Vector2(_saturation, 1.0 - _value) * _square.size
	_square.draw_arc(dot, 7.0, 0.0, TAU, 24, Palette.BLACK, 4.0)
	_square.draw_arc(dot, 7.0, 0.0, TAU, 24, Palette.WHITE, 2.0)
	if _square.has_focus():
		_square.draw_rect(rect, Palette.SKY if _grabbed else Palette.WHITE, false, 3.0 if _grabbed else 2.0)


## The hue strip, an outlined marker and a focus border.
func _draw_strip() -> void:
	var rect := Rect2(Vector2.ZERO, _strip.size)
	_strip.draw_texture_rect(_strip_fill, rect, false)
	var x := _hue * _strip.size.x
	_strip.draw_rect(Rect2(x - 3.0, -3.0, 6.0, _strip.size.y + 6.0), Palette.BLACK)
	_strip.draw_rect(Rect2(x - 1.5, -2.0, 3.0, _strip.size.y + 4.0), Palette.WHITE)
	if _strip.has_focus():
		_strip.draw_rect(rect, Palette.WHITE, false, 2.0)
