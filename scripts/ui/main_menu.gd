extends Control
## Mode selection: Standard, Mania, Editor, Settings or Quit under the title, over the last
## selected map's dimmed art (or just the stars before any) and themed from it. The root
## scene handles screen changes.

signal mania_selected
signal standard_selected
signal editor_selected
signal settings_selected

## Pixels the highlighted button slides right.
const SLIDE := 18.0
## The highlighted button's caret: pixels left of the button, and its font size.
const CARET_GAP := 26.0
const CARET_SIZE := 20

@onready var _buttons: Array[Button] = [$Content/Buttons/Standard/Button, $Content/Buttons/Mania/Button, $Content/Buttons/Editor/Button, $Content/Buttons/Settings/Button, $Content/Buttons/Quit/Button]


func _ready() -> void:
	$Art.texture = GameState.map_art
	MapTheme.retarget(GameState.map_art)
	$Content/Buttons/Standard/Button.pressed.connect(standard_selected.emit)
	$Content/Buttons/Mania/Button.pressed.connect(mania_selected.emit)
	$Content/Buttons/Editor/Button.pressed.connect(editor_selected.emit)
	$Content/Buttons/Settings/Button.pressed.connect(settings_selected.emit)
	$Content/Buttons/Quit/Button.pressed.connect(get_tree().quit)
	for button in _buttons:
		animate(button)
	_buttons[0].grab_focus()
	_reveal()


## Mouse hover and keyboard focus share one highlight on a hero button: it slides right,
## lights up and an ASCII caret fades in at its left. It squashes a little while pressed.
## The pause menu and editor use this too.
static func animate(button: Button) -> void:
	var caret := Label.new()
	caret.theme_type_variation = &"WideLabel"
	caret.add_theme_font_size_override("font_size", CARET_SIZE)
	caret.text = ">"
	caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The button's full height at its left, so the caret centres on any button size.
	caret.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	caret.offset_left = -CARET_GAP
	caret.offset_right = 0.0
	caret.modulate.a = 0.0
	caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caret)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void: _slide(button, caret, SLIDE))
	button.focus_exited.connect(func() -> void: _slide(button, caret, 0.0))
	button.button_down.connect(func() -> void: _squash(button, 0.97))
	button.button_up.connect(func() -> void: _squash(button, 1.0))


## Fades the title column in while it rises into place.
func _reveal() -> void:
	var content: Control = $Content
	content.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, 0.9)
	tween.tween_property(content, "position:y", content.position.y, 0.9).from(content.position.y + 24.0)


static func _slide(button: Button, caret: Label, x: float) -> void:
	var tween := button.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", x, 0.18)
	tween.tween_property(caret, "modulate:a", 1.0 if x > 0.0 else 0.0, 0.18)


static func _squash(button: Button, amount: float) -> void:
	button.pivot_offset = button.size / 2.0
	button.create_tween().tween_property(button, "scale", Vector2.ONE * amount, 0.06)
