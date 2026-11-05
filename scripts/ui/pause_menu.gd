extends CanvasLayer
## Pause overlay for Play. open() freezes Play, its music and its tweens by disabling its
## processing (this layer keeps processing); Esc or Resume continues. A layer, so it stays
## visible while the fail fade dims Play.

signal resumed
signal retry_requested
signal quit_requested

const MENU := preload("res://scripts/ui/main_menu.gd")

@onready var _play: Node = get_parent()
@onready var _resume: Button = $Content/Buttons/Resume/Button


func _ready() -> void:
	_resume.pressed.connect(_continue)
	$Content/Buttons/Retry/Button.pressed.connect(retry_requested.emit)
	$Content/Buttons/Quit/Button.pressed.connect(quit_requested.emit)
	for button: Button in [_resume, $Content/Buttons/Retry/Button, $Content/Buttons/Quit/Button]:
		MENU.animate(button)


func open() -> void:
	_play.process_mode = Node.PROCESS_MODE_DISABLED
	show()
	_resume.grab_focus()
	$Content.modulate.a = 0.0
	create_tween().tween_property($Content, "modulate:a", 1.0, 0.2)


func _continue() -> void:
	# A focused button would take Enter and Space from play.
	_resume.get_viewport().gui_release_focus()
	hide()
	_play.process_mode = Node.PROCESS_MODE_INHERIT
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_continue()
