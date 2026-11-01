class_name ManiaNote
extends HitObject
## A mania tap note, or a hold note when end_time is after time.

## Lane index, 0 is the leftmost.
var column: int


func _init(p_time: float, p_column: int, p_end_time: float) -> void:
	super(p_time, p_end_time)
	column = p_column


func is_hold() -> bool:
	return end_time > time
