class_name SliderView
extends HitCircleView
## An osu! standard slider. The head is hit like a circle, then the ball has to
## be followed with a hit key held through the tail. Breaking tracking misses.

## Follow area around the ball, relative to the circle radius.
const FOLLOW_SCALE := 2.4
## The follow circle grows in over FOLLOW_IN seconds when tracking starts, then breathes
## FOLLOW_BREATHE of its size every BREATHE_TIME seconds.
const FOLLOW_IN := 0.12
const FOLLOW_BREATHE := 0.04
const BREATHE_TIME := 0.6

var track_color := Color.BLACK
var border_color := Color.WHITE
var tint_ball := true

var _tick_times: Array[float] = []
var _tick_sprites: Array[Sprite2D] = []
var _head_done := false
var _head_judgement := Judgement.NONE
## Spans (slides) the ball has been followed to their end, each popped once.
var _spans_done := 0
## Song time the follow circle last appeared, or -1 while hidden.
var _follow_since := -1.0
var _follow_scale: Vector2

@onready var track: Node2D = $Track
@onready var tail: Sprite2D = $Tail
@onready var tail_overlay: Sprite2D = $TailOverlay
@onready var repeat_arrow: Sprite2D = $RepeatArrow
@onready var follow: Sprite2D = $Follow
@onready var tick_template: Sprite2D = $Tick
@onready var ball: Sprite2D = $Ball


func setup(p_data: HitObject, p_map: Beatmap) -> void:
	super(p_data, p_map)
	var slider := data as HitSlider
	var span := (slider.end_time - slider.time) / slider.slides
	for s in slider.slides:
		var span_start := slider.time + s * span
		if slider.tick_interval > 0.0:
			var tick := span_start + slider.tick_interval
			while tick < span_start + span - 0.01:
				_tick_times.append(tick)
				tick += slider.tick_interval


func _ready() -> void:
	super()
	track.radius = radius
	track.border_color = border_color
	track.track_color = track_color
	var points := (data as HitSlider).curve.get_baked_points()
	for i in points.size():
		if track.points.is_empty() or track.points[-1].distance_to(points[i] - position) >= 3.0 or i == points.size() - 1:
			track.points.append(points[i] - position)
	track.queue_redraw()
	var slider := data as HitSlider
	var endpoint := slider.curve.sample_baked(slider.curve.get_baked_length()) - position
	tail.position = endpoint
	tail_overlay.position = endpoint
	tail.scale = sprite.scale
	tail_overlay.scale = overlay.scale
	tail.self_modulate = combo_color
	repeat_arrow.scale = Vector2.ONE * radius * 1.1 / repeat_arrow.texture.get_width()
	_follow_scale = Vector2.ONE * radius * FOLLOW_SCALE * 2.0 / follow.texture.get_width()
	follow.scale = _follow_scale
	follow.self_modulate = combo_color
	follow.self_modulate.a = 0.35
	move_child(follow, 1)
	for tick_time in _tick_times:
		var tick := tick_template.duplicate() as Sprite2D
		tick.position = slider.position_at(tick_time) - position
		tick.scale = Vector2.ONE * radius * 0.18 / tick.texture.get_width()
		add_child(tick)
		move_child(tick, 1)
		_tick_sprites.append(tick)
	ball.scale = Vector2.ONE * radius * 2.0 / 256.0
	ball.self_modulate = combo_color if tint_ball else Color.WHITE
	ball.visible = false


func update_view(t: float) -> void:
	var slider := data as HitSlider
	modulate.a = clampf((t - data.time + preempt) / minf(0.4, preempt), 0.0, 1.0)
	if not _head_done:
		_update_approach(t)
		if is_missed(t):
			_finish(Judgement.MISS)
			return
	var ball_position := slider.position_at(t)
	ball.visible = t >= slider.time
	ball.position = ball_position - position
	follow.position = ball.position
	follow.visible = ball.visible and holding
	_breathe_follow(t)
	var span_duration := (slider.end_time - slider.time) / slider.slides
	var span_index := clampi(floori((t - slider.time) / span_duration), 0, slider.slides - 1)
	for i in _tick_sprites.size():
		var tick_span := floori((_tick_times[i] - slider.time) / span_duration)
		_tick_sprites[i].visible = tick_span == span_index and t < _tick_times[i]
	repeat_arrow.visible = span_index < slider.slides - 1
	if repeat_arrow.visible:
		var at_end := span_index % 2 == 0
		var length := slider.curve.get_baked_length()
		var destination := slider.curve.sample_baked(length if at_end else 0.0)
		var inward := slider.curve.sample_baked(maxf(0.0, length - 5.0) if at_end else minf(5.0, length))
		repeat_arrow.position = destination - position
		repeat_arrow.rotation = (inward - destination).angle()
	var tracking := holding and t >= slider.time and cursor().distance_to(ball_position) <= radius * FOLLOW_SCALE
	if _head_done and t >= slider.time:
		if not tracking:
			_finish(Judgement.MISS)
			return
		# Pop each repeat and the tail as the followed ball reaches them.
		while _spans_done < mini(floori((t - slider.time) / span_duration), slider.slides):
			_pop_end(_spans_done % 2 == 0)
			_spans_done += 1
		if t >= slider.end_time:
			_finish(_head_judgement)


func press(t: float) -> bool:
	if finished or _head_done or not contains(cursor()):
		return false
	var judgement := judge(t)
	if judgement == Judgement.NONE:
		shake()
		return false
	if judgement == Judgement.MISS:
		_finish(Judgement.MISS)
	else:
		_head_judgement = judgement
		_resolve_head()
	return true


## Grows the follow circle in as tracking starts, then breathes it gently.
func _breathe_follow(t: float) -> void:
	if not follow.visible:
		_follow_since = -1.0
		return
	if _follow_since < 0.0:
		_follow_since = t
	var grow := ease(clampf((t - _follow_since) / FOLLOW_IN, 0.0, 1.0), 0.3)
	var breathe := 1.0 + FOLLOW_BREATHE * sin((t - _follow_since) * TAU / BREATHE_TIME)
	follow.scale = _follow_scale * lerpf(0.7, 1.0, grow) * breathe


## A small flash-and-pop on a ghost of the end circle where a followed span finishes:
## the tail (at_end) or, for a repeat back, the head.
func _pop_end(at_end: bool) -> void:
	var curve := (data as HitSlider).curve
	var ghost := tail.duplicate() as Sprite2D
	ghost.position = curve.sample_baked(curve.get_baked_length() if at_end else 0.0) - position
	add_child(ghost)
	_pop(ghost).chain().tween_callback(ghost.queue_free)


func _resolve_head() -> void:
	_head_done = true
	_dismiss_approach(_head_judgement)
	for part: Node2D in [sprite, overlay, number]:
		_pop(part)


func release(t: float) -> void:
	if _head_done and not finished and t < data.end_time:
		_finish(Judgement.MISS)


func play_exit() -> void:
	follow.hide()
	repeat_arrow.hide()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
