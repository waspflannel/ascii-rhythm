extends Node
## Cross-scene run state: the chosen mode and the last map picked in song select.

var mode := Beatmap.MODE_MANIA
var map_path := ""
## The last played map's background art, behind mode select; null before any play.
var map_art: Texture2D
