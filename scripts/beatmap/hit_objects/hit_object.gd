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
## osu! hitSound flags: 2 whistle, 4 finish, 8 clap; the normal sound always plays.
var hit_sound := 0
## hitSample: normal and addition sample sets (1 normal, 2 soft, 3 drum), custom sample
## index and volume (0 to 100). 0 takes the timing point's (the addition set: the normal set's).
var normal_set := 0
var addition_set := 0
var sample_index := 0
var volume := 0


func _init(p_time: float, p_end_time: float) -> void:
	time = p_time
	end_time = p_end_time
