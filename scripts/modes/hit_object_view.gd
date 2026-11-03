class_name HitObjectView
extends Node2D
## Base scene for anything the player hits. Gameplay drives every view the same way:
## 1. setup(object, map), then add it under the playfield.
## 2. Every frame: set holding, then call update_view(song_time).
## 3. On a hit key press: call press(song_time) on the earliest live view until one
##    returns true. On release: call release(song_time).
## 4. Listen to judged for scoring. Free the view once finished is true.

signal judged(judgement: Judgement)

## Hit tiers, best first. Each mode gives them its own values (see RunScore): standard
## uses PERFECT, GREAT and GOOD for 300, 100 and 50; mania uses all five, MAX (320) to MEH (50).
enum Judgement { NONE, MAX, PERFECT, GREAT, GOOD, MEH, MISS }

## The parsed object this view draws.
var data: HitObject
## The map it came from, for difficulty values like circle size.
var map: Beatmap
## Whether this object's hit key is down: the lane key in mania, any hit key in standard.
var holding := false
## Optional simulated aim (renderer preview) in playfield coordinates; null uses the real mouse.
var simulated_cursor: Variant = null
## True once the object has given its last judgement.
var finished := false

@onready var sprite: Sprite2D = $Sprite


func setup(p_data: HitObject, p_map: Beatmap) -> void:
	data = p_data
	map = p_map


## Moves, animates and times out the view for song time t, in seconds.
func update_view(_t: float) -> void:
	pass


## A hit key went down at song time t. Returns true if this object used the press.
func press(_t: float) -> bool:
	return false


## A hit key went up at song time t.
func release(_t: float) -> void:
	pass


## Hit windows in seconds either side of the hit time, one per hit_tiers() entry.
## osu! standard values from OD; modes with their own windows override this.
func hit_windows() -> Array[float]:
	var od := map.overall_difficulty
	return [(80.0 - 6.0 * od) / 1000.0, (140.0 - 8.0 * od) / 1000.0, (200.0 - 10.0 * od) / 1000.0]


## The judgement each hit window gives, best first.
func hit_tiers() -> Array[Judgement]:
	return [Judgement.PERFECT, Judgement.GREAT, Judgement.GOOD]


## How early an input still counts. Inputs inside it but outside every hit window miss.
func miss_window() -> float:
	return hit_windows().back()


## Judges a press at song time t against the hit time.
func judge(t: float) -> Judgement:
	return judge_at(data.time, t)


## Judges an input at song time t against target, with every window scaled by
## lenience. NONE means the input is too early to count, so it should be ignored.
func judge_at(target: float, t: float, lenience := 1.0) -> Judgement:
	if t < target - miss_window() * lenience:
		return Judgement.NONE
	var offset := absf(t - target)
	var windows := hit_windows()
	var tiers := hit_tiers()
	for i in windows.size():
		if offset <= windows[i] * lenience:
			return tiers[i]
	return Judgement.MISS


## True once the last hit window has passed without a hit.
func is_missed(t: float) -> bool:
	return t > data.time + hit_windows().back()


## Cursor in the parent's space. In standard the parent is the playfield, so this is osu! pixels.
func cursor() -> Vector2:
	return simulated_cursor if simulated_cursor is Vector2 else get_parent().get_local_mouse_position()


## Resolve an unfinished object when playback ends before it can be completed.
func miss() -> void:
	_finish(Judgement.MISS)


## Gives the last judgement and marks the view done.
func _finish(judgement: Judgement) -> void:
	if finished:
		return
	finished = true
	judged.emit(judgement)


## Judgement is immediate; keep the visual alive briefly without processing more input.
func play_exit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
