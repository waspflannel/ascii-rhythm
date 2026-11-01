class_name HitCircleView
extends HitObjectView
## An osu! standard hit circle with its approach circle. Positions are osu!
## pixels, so the parent playfield scales 512x384 up to the screen. A hit needs
## the right timing and the cursor on the circle.

## Approach circle size at spawn, relative to the hit circle.
const APPROACH_START_SCALE := 4.0

## Hit radius in osu! pixels, from circle size.
var radius: float
## Seconds the circle is on screen before its hit time, from approach rate.
var preempt: float
var combo_color := Color.WHITE

@onready var overlay: Sprite2D = $Overlay
@onready var number: Node2D = $Number
@onready var approach: Sprite2D = $Approach


func setup(p_data: HitObject, p_map: Beatmap) -> void:
	super(p_data, p_map)
	position = p_data.get("position") # HitCircle and HitSlider both have one.
	radius = 54.4 - 4.48 * map.circle_size
	var ar := map.approach_rate
	preempt = 1.2 - 0.75 * (ar - 5.0) / 5.0 if ar >= 5.0 else 1.2 + 0.6 * (5.0 - ar) / 5.0


func _ready() -> void:
	sprite.scale = Vector2.ONE * radius * 2.0 / 256.0
	sprite.self_modulate = combo_color
	approach.self_modulate = combo_color
	overlay.scale = sprite.scale
	number.set_number(data.combo_number, radius * 2.0)


func update_view(t: float) -> void:
	_update_approach(t)
	if is_missed(t):
		_finish(Judgement.MISS)


func press(t: float) -> bool:
	if finished or not contains(cursor()):
		return false
	var judgement := judge(t)
	if judgement == Judgement.NONE:
		return false
	_finish(judgement)
	return true


## True if point, in osu! pixels, is inside the circle.
func contains(point: Vector2) -> bool:
	return point.distance_to(position) <= radius


func _update_approach(t: float) -> void:
	modulate.a = clampf((t - data.time + preempt) / minf(0.4, preempt), 0.0, 1.0)
	var progress := clampf(1.0 - (data.time - t) / preempt, 0.0, 1.0)
	approach.scale = Vector2.ONE * radius * 2.0 / approach.texture.get_width() * lerpf(APPROACH_START_SCALE, 1.0, progress)


func play_exit() -> void:
	approach.hide()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_property(self, "scale", scale * 1.15, 0.18)
	tween.chain().tween_callback(queue_free)
