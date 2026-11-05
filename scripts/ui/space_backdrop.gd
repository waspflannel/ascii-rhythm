class_name SpaceBackdrop
extends Control
## The menus' night sky: a black field of stars in three depths that drift slowly and
## shift with the mouse, a few of Neptune's four-point sparkles, and optional corner
## brackets framing the screen like Neptune's menu art.

const SPARKLE := preload(SkinAssets.DIR + "hud/star@2x.png")
## Star depths, far to near: drift and parallax scale with depth.
const DEPTHS: Array[float] = [0.25, 0.55, 1.0]
## Pixels per second the nearest layer drifts.
const DRIFT := Vector2(-7.0, 1.5)
## Pixels the nearest layer shifts when the mouse is at a screen edge.
const PARALLAX := 14.0
const FRAME_INSET := 22.0
const FRAME_ARM := 110.0

@export var star_count := 170
@export var sparkle_count := 7
@export var show_frame := true

## One entry per star: [position 0..1, depth index, size, twinkle phase].
var _stars: Array = []
var _sparkles: Array = []
var _time := 0.0
var _parallax := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in star_count:
		var depth := rng.randi_range(0, DEPTHS.size() - 1)
		_stars.append([Vector2(rng.randf(), rng.randf()), depth, 1.0 + depth * 0.6 + rng.randf() * 0.6, rng.randf() * TAU])
	for i in sparkle_count:
		_sparkles.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(10.0, 26.0), rng.randf() * TAU])


func _process(delta: float) -> void:
	_time += delta
	var half := size / 2.0
	var mouse := ((get_local_mouse_position() - half) / half).clampf(-1.0, 1.0)
	_parallax = _parallax.lerp(-mouse * PARALLAX, minf(1.0, delta * 3.0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for star: Array in _stars:
		var depth: float = DEPTHS[star[1]]
		var at := _wrap((star[0] as Vector2) * size + (DRIFT * _time + _parallax) * depth)
		var twinkle := 0.55 + 0.45 * sin(_time * (0.8 + depth) + star[3])
		var color := Color(Palette.WHITE, (0.25 + 0.75 * depth) * twinkle)
		draw_rect(Rect2(at, Vector2.ONE * star[2]), color)
	for sparkle: Array in _sparkles:
		var at := _wrap((sparkle[0] as Vector2) * size + (DRIFT * _time * 0.4 + _parallax * 0.7))
		var length: float = sparkle[1] * (0.85 + 0.15 * sin(_time * 0.7 + sparkle[2]))
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * length / 2.0, Vector2.ONE * length), false, Color(1, 1, 1, 0.55))
	if show_frame:
		_draw_frame()


## Keeps a drifting point on screen by wrapping it around the edges.
func _wrap(point: Vector2) -> Vector2:
	return Vector2(fposmod(point.x, size.x), fposmod(point.y, size.y))


func _draw_frame() -> void:
	var color := Color(Palette.WHITE, 0.5)
	var inner := Rect2(Vector2.ONE * FRAME_INSET, size - Vector2.ONE * FRAME_INSET * 2.0)
	for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var toward: Vector2 = (inner.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(toward.x * FRAME_ARM, 0.0), color, 1.0)
		draw_line(corner, corner + Vector2(0.0, toward.y * FRAME_ARM * 0.6), color, 1.0)
