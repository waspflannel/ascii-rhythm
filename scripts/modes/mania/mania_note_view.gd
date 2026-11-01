class_name ManiaNoteView
extends HitObjectView
## A mania note. Its parent is the lane, with the origin on the hit line, and
## the note falls down towards it. A hold note is judged twice: once on press
## and once on release.

## Pixels the note travels per second. The playfield sets this from settings.
var scroll_speed := 800.0

## Hold notes only: the head was hit and the key is being held.
var _held := false

@onready var body: Sprite2D = $Body
@onready var tail: Sprite2D = $Tail


func _ready() -> void:
	var note := data as ManiaNote
	# Neptune's four-key skin uses blue outer lanes and white inner lanes.
	if note.column > 0 and note.column < int(map.circle_size) - 1:
		sprite.texture = preload("res://assets/skins/neptune/mania/note2.png")
		body.texture = preload("res://assets/skins/neptune/mania/LN2.png")
		tail.texture = preload("res://assets/skins/neptune/mania/T2.png")
	for part in [sprite, body, tail]:
		part.offset = Vector2(-part.texture.get_width() / 2.0, -part.texture.get_height())
		part.scale = Vector2.ONE * 64.0 / part.texture.get_width()
	body.visible = note.is_hold()
	tail.visible = note.is_hold()
	update_view(note.time - 1.0)


func update_view(t: float) -> void:
	var note := data as ManiaNote
	position.y = 0.0 if _held else (t - note.time) * scroll_speed
	if note.is_hold():
		var duration := maxf(0.0, note.end_time - t) if _held else note.end_time - note.time
		var length := duration * scroll_speed
		body.scale.y = length / body.texture.get_height()
		tail.position.y = -length
	if _held:
		if t > note.end_time + hit_windows()[2]:
			# ponytail: holding past the tail window counts as a late release.
			_finish(Judgement.GOOD)
		return
	if is_missed(t):
		_finish(Judgement.MISS) # A missed hold head misses the whole hold.


func press(t: float) -> bool:
	if _held or finished:
		return false
	var judgement := judge(t)
	if judgement == Judgement.NONE:
		return false
	if (data as ManiaNote).is_hold():
		_held = true
		judged.emit(judgement)
	else:
		_finish(judgement)
	return true


func release(t: float) -> void:
	if not _held or finished:
		return
	var judgement := judge_at(data.end_time, t)
	# NONE here means the key came up before the tail window opened.
	_finish(Judgement.MISS if judgement == Judgement.NONE else judgement)


## osu!mania windows: 300, 200 and 100, which are tighter than standard.
func hit_windows() -> Array[float]:
	var od := map.overall_difficulty
	return [(64.0 - 3.0 * od) / 1000.0, (97.0 - 3.0 * od) / 1000.0, (127.0 - 3.0 * od) / 1000.0]
