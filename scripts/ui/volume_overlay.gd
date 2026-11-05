extends PanelContainer
## Ctrl + mouse wheel changes the master volume on any screen, in play too, and saves it
## straight away. This panel shows the new level, then fades out. It sits outside the
## dithered screen, so screen changes don't fade it.

## Volume change per wheel notch.
const STEP := 0.05
## Seconds the panel stays fully shown, then fades out over.
const HOLD := 1.0
const FADE := 0.4

var _fade: Tween


func _ready() -> void:
	modulate.a = 0.0


## Runs before any screen sees the wheel: the screen viewport only gets mouse events in
## the GUI pass, after _input.
func _input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not wheel.ctrl_pressed:
		return
	var step := 0.0
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = STEP
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -STEP
	else:
		return
	get_viewport().set_input_as_handled()
	var volume := clampf(snappedf(float(Settings.get_value("audio", "volume")) + step, STEP), 0.0, 1.0)
	Settings.set_value("audio", "volume", volume)
	Settings.save_settings()
	Settings.apply_audio()
	$Row/Value.text = "%d%%" % roundi(volume * 100.0)
	$Row/Track/Fill.scale.x = volume
	$Row/Track/Fill.color = MapTheme.accent
	if _fade:
		_fade.kill()
	modulate.a = 1.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, FADE).set_delay(HOLD)
