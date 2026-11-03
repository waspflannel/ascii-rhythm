extends Control
## Mode selection. The root scene handles screen changes.

signal mania_selected
signal standard_selected


func _ready() -> void:
	$Center/Items/ManiaButton.pressed.connect(mania_selected.emit)
	$Center/Items/StandardButton.pressed.connect(standard_selected.emit)
	$Center/Items/ManiaButton.grab_focus()
