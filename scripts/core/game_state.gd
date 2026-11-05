extends Node
## Cross-scene run state: the chosen mode and the last map picked in song select.

var mode := Beatmap.MODE_MANIA
var map_path := ""
## The last played map's background art, behind mode select; null before any play.
var map_art: Texture2D


func _ready() -> void:
	# Restores the art from the last session; a moved or deleted map leaves the stars.
	var last := str(Settings.get_value("history", "last_map"))
	if FileAccess.file_exists(last):
		var map := Beatmap.from_file(last)
		if map != null:
			map_art = map.load_background()
