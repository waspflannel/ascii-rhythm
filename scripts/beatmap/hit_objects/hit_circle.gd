class_name HitCircle
extends HitObject
## An osu! standard hit circle.

## Centre in osu! pixels (the playfield is 512x384).
var position: Vector2


func _init(p_time: float, p_position: Vector2) -> void:
	super(p_time, p_time)
	position = p_position
