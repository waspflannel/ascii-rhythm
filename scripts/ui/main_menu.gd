extends Control
## Mode selection: Standard, Mania or Quit under the title. The root scene handles screen
## changes. Mouse hover and keyboard focus share one highlight: the button slides right
## and lights up.

signal mania_selected
signal standard_selected

## Pixels the highlighted button slides right.
const SLIDE := 18.0

@onready var _buttons: Array[Button] = [$Content/Buttons/Standard/Button, $Content/Buttons/Mania/Button, $Content/Buttons/Quit/Button]


func _ready() -> void:
	$Content/Buttons/Standard/Button.pressed.connect(standard_selected.emit)
	$Content/Buttons/Mania/Button.pressed.connect(mania_selected.emit)
	$Content/Buttons/Quit/Button.pressed.connect(get_tree().quit)
	for button in _buttons:
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_highlight.bind(button, true))
		button.focus_exited.connect(_highlight.bind(button, false))
		button.button_down.connect(_squash.bind(button, 0.97))
		button.button_up.connect(_squash.bind(button, 1.0))
	_buttons[0].grab_focus()
	_reveal()


## Fades the title column in while it rises into place.
func _reveal() -> void:
	var content: Control = $Content
	content.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, 0.9)
	tween.tween_property(content, "position:y", content.position.y, 0.9).from(content.position.y + 24.0)


func _highlight(button: Button, on: bool) -> void:
	button.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
		.tween_property(button, "position:x", SLIDE if on else 0.0, 0.18)


func _squash(button: Button, amount: float) -> void:
	button.pivot_offset = button.size / 2.0
	button.create_tween().tween_property(button, "scale", Vector2.ONE * amount, 0.06)
