class_name SpinnerView
extends HitObjectView
## An osu! standard spinner. Spin the cursor around the centre with a hit key
## held. The judgement is how much of the required spinning got done.

## Ring size at the start, in osu! pixels. It shrinks to show the time left.
const RING_SIZE := 360.0

## Net rotation in radians. Signed, so wiggling back and forth cancels out.
var _spun := 0.0
var _last_angle := NAN
## Rotation needed for full credit, in radians.
var _required := 0.0

@onready var arm: Sprite2D = $Arm


func setup(p_data: HitObject, p_map: Beatmap) -> void:
	super(p_data, p_map)
	position = Spinner.CENTER
	var od := map.overall_difficulty
	var spins_per_second := 2.5 + 1.25 * (od - 5.0) / 5.0 if od > 5.0 else 2.5 - (5.0 - od) / 5.0
	_required = (data.end_time - data.time) * spins_per_second * TAU


func _ready() -> void:
	arm.scale = Vector2.ONE * RING_SIZE / arm.texture.get_width()


func update_view(t: float) -> void:
	modulate.a = clampf((t - data.time + 1.2) / 0.4, 0.0, 1.0)
	var remaining := clampf((data.end_time - t) / maxf(data.end_time - data.time, 0.001), 0.0, 1.0)
	sprite.scale = Vector2.ONE * RING_SIZE / sprite.texture.get_width() * maxf(remaining, 0.05)
	if holding and t >= data.time and t <= data.end_time:
		var angle := (cursor() - position).angle()
		if not is_nan(_last_angle):
			_spun += wrapf(angle - _last_angle, -PI, PI)
		_last_angle = angle
	else:
		_last_angle = NAN
	arm.rotation = _spun
	$Progress.value = clampf(absf(_spun) / maxf(_required, 0.001), 0.0, 1.0)
	if t >= data.end_time:
		_finish(_judgement())


## osu!lazer thresholds: all of it Perfect, over 90% Great, over 75% Good.
func _judgement() -> Judgement:
	var progress := absf(_spun) / _required if _required > 0.0 else 1.0
	if progress >= 1.0:
		return Judgement.PERFECT
	if progress > 0.9:
		return Judgement.GREAT
	if progress > 0.75:
		return Judgement.GOOD
	return Judgement.MISS
