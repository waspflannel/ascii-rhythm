extends Control
## Mode selection. The root scene handles screen changes.

signal mania_selected
signal standard_selected


func _ready() -> void:
	$Center/Items/ManiaButton.pressed.connect(mania_selected.emit)
	$Center/Items/StandardButton.pressed.connect(standard_selected.emit)
	$Center/Items/ManiaButton.grab_focus()
	$Center/Items/Autoplay.button_pressed = bool(Settings.get_value("gameplay", "autoplay"))
	$Center/Items/Autoplay.toggled.connect(_on_autoplay_toggled)


func _on_autoplay_toggled(enabled: bool) -> void:
	Settings.set_value("gameplay", "autoplay", enabled)
	Settings.save_settings()
