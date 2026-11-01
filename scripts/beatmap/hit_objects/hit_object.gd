class_name HitObject
extends RefCounted
## Something the player has to hit. Pure data: gameplay scenes decide how to draw it.

## Hit time in seconds from the start of the song.
var time: float
## When the object is over, in seconds. Equals time for objects you just tap.
var end_time: float
## Standard combo color index and displayed number, assigned by the parser.
var combo_index := 0
var combo_number := 1


func _init(p_time: float, p_end_time: float) -> void:
	time = p_time
	end_time = p_end_time
