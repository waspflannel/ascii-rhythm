extends Control
## Placeholder title menu. Play and Settings are wired up in later milestones.


func _ready() -> void:
	$Center/Items/QuitButton.pressed.connect(get_tree().quit)
