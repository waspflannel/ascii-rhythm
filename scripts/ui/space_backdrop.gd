class_name SpaceBackdrop
extends Control
## The menus' night sky: a black field of stars in three depths that drift slowly and
## shift with the mouse, a few of Neptune's four-point sparkles, and optional ASCII
## box corners framing the screen.

const SPARKLE := preload(SkinAssets.DIR + "hud/star@2x.png")
## Star depths, far to near: drift and parallax scale with depth.
const DEPTHS: Array[float] = [0.25, 0.55, 1.0]
## Pixels per second the nearest layer drifts.
const DRIFT := Vector2(-7.0, 1.5)
## Pixels the nearest layer shifts when the mouse is at a screen edge.
const PARALLAX := 14.0
const FRAME_INSET := 22.0
const FRAME_ARM := 110.0
## The frame's glyph size and how many │ rows each corner drops.
const FRAME_FONT_SIZE := 14
const FRAME_DROP := 3

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


## Box-drawing corners in the monospace font, an ASCII frame around the screen.
func _draw_frame() -> void:
	var font := get_theme_default_font()
	var color := Color(Palette.WHITE, 0.5)
	var dash := font.get_string_size("─", HORIZONTAL_ALIGNMENT_LEFT, -1, FRAME_FONT_SIZE)
	var run := "─".repeat(int(FRAME_ARM / dash.x))
	var ascent := font.get_ascent(FRAME_FONT_SIZE)
	var inner := Rect2(Vector2.ONE * FRAME_INSET, size - Vector2.ONE * FRAME_INSET * 2.0)
	var right := inner.end.x - dash.x * (run.length() + 1)
	var rows := {
		inner.position.y: ["┌" + run, run + "┐"],
		inner.end.y - dash.y: ["└" + run, run + "┘"],
	}
	for y: float in rows:
		draw_string(font, Vector2(inner.position.x, y + ascent), rows[y][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FRAME_FONT_SIZE, color)
		draw_string(font, Vector2(right, y + ascent), rows[y][1], HORIZONTAL_ALIGNMENT_LEFT, -1, FRAME_FONT_SIZE, color)
		var down := 1.0 if y == inner.position.y else -1.0
		for i in range(1, FRAME_DROP + 1):
			for x: float in [inner.position.x, inner.end.x - dash.x]:
				draw_string(font, Vector2(x, y + down * dash.y * i + ascent), "│", HORIZONTAL_ALIGNMENT_LEFT, -1, FRAME_FONT_SIZE, color)
