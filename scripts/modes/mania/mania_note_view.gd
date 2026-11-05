class_name ManiaNoteView
extends HitObjectView
## A mania note. Its parent is the playfield, with the origin on the judgement line,
## and the note falls down towards it. A hold note is judged twice: its head on press
## and its tail on release (or as MAX if the key is still down when the hold ends).

## osu!lazer judges hold releases with windows 1.5 times wider.
const TAIL_LENIENCE := 1.5

## Pixels the note travels per second. Play sets this from the scroll speed setting.
var scroll_speed := 800.0

## Hold notes only: the head was hit and the key is being held.
var _held := false

@onready var body: Sprite2D = $Body
@onready var tail: Sprite2D = $Tail


func _ready() -> void:
	var note := data as ManiaNote
	if ManiaStage.is_inner(note.column, (map as ManiaBeatmap).key_count()):
		sprite.texture = preload(SkinAssets.DIR + "mania/note2.png")
		body.texture = preload(SkinAssets.DIR + "mania/LN2.png")
		tail.texture = preload(SkinAssets.DIR + "mania/T2.png")
	for part in [sprite, body, tail]:
		part.offset = Vector2(-part.texture.get_width() / 2.0, -part.texture.get_height())
		part.scale = Vector2.ONE * ManiaStage.COLUMN_WIDTH / part.texture.get_width()
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
		# Holding through the end is a perfect tail, as in osu!lazer.
		if t >= note.end_time:
			_finish(Judgement.MAX)
		return
	if is_missed(t):
		miss()


func press(t: float) -> bool:
	if _held or finished:
		return false
	var judgement := judge(t)
	if judgement == Judgement.NONE:
		return false
	if not (data as ManiaNote).is_hold():
		_finish(judgement)
	elif judgement == Judgement.MISS:
		miss()
	else:
		_held = true
		judged.emit(judgement) # The head; the tail is judged on release.
	return true


func release(t: float) -> void:
	if not _held or finished:
		return
	var judgement := judge_at(data.end_time, t, TAIL_LENIENCE)
	# NONE here means the key came up before the tail window opened.
	_finish(Judgement.MISS if judgement == Judgement.NONE else judgement)


## A hold that was never hit misses both its head and its tail.
func miss() -> void:
	if (data as ManiaNote).is_hold() and not _held and not finished:
		judged.emit(Judgement.MISS)
	_finish(Judgement.MISS)


## osu!mania windows from OD: MAX, 300, 200, 100 and 50.
func hit_windows() -> Array[float]:
	var od := map.overall_difficulty
	return [0.016, (64.0 - 3.0 * od) / 1000.0, (97.0 - 3.0 * od) / 1000.0, (127.0 - 3.0 * od) / 1000.0, (151.0 - 3.0 * od) / 1000.0]


func hit_tiers() -> Array[Judgement]:
	return [Judgement.MAX, Judgement.PERFECT, Judgement.GREAT, Judgement.GOOD, Judgement.MEH]


## Presses up to this early are misses rather than ignored.
func miss_window() -> float:
	return (188.0 - 3.0 * map.overall_difficulty) / 1000.0
