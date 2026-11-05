class_name Planet
extends Control
## Neptune from the skin's pause art, cut out as a disc, bobbing slowly inside two tilted
## hairline orbits with a small moon. The orbits' far halves draw behind the planet and
## their near halves in front.

## The planet in hud/pause-overlay@2x.png (it is centred at 1366, 768, radius about 294).
const SOURCE := SkinAssets.DIR + "hud/pause-overlay@2x.png"
const SOURCE_DISC := Rect2i(1060, 462, 612, 612)
## Orbits as [x radius, y radius, tilt in radians], in units of the planet's radius.
const ORBITS := [[1.55, 0.36, -0.28], [1.95, 0.5, -0.22]]
const ORBIT_POINTS := 96
## Seconds per moon orbit.
const MOON_PERIOD := 24.0

var _time := 0.0

@onready var _disc: TextureRect = $Disc
@onready var _front: Control = $Front


func _ready() -> void:
	var image := (load(SOURCE) as Texture2D).get_image()
	_disc.texture = ImageTexture.create_from_image(image.get_region(SOURCE_DISC))
	_front.draw.connect(_draw_orbits.bind(_front, true))


func _process(delta: float) -> void:
	_time += delta
	_disc.position.y = sin(_time * 0.45) * 5.0
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	_draw_orbits(self, false)


## Draws the near (lower) or far (upper) half of each orbit, and the moon when it is on that half.
func _draw_orbits(canvas: CanvasItem, near: bool) -> void:
	var radius := size.x / 2.0
	var center := size / 2.0
	for i in ORBITS.size():
		var orbit: Array = ORBITS[i]
		var points := PackedVector2Array()
		for step in ORBIT_POINTS / 2 + 1:
			var angle := PI * step / (ORBIT_POINTS / 2) + (0.0 if near else PI)
			points.append(_orbit_point(orbit, angle, center, radius))
		canvas.draw_polyline(points, Color(Palette.WHITE, 0.35 if near else 0.18), 1.0, true)
	var moon_angle := fposmod(TAU * _time / MOON_PERIOD, TAU)
	if (moon_angle < PI) == near:
		var moon := _orbit_point(ORBITS[1], moon_angle, center, radius)
		canvas.draw_circle(moon, 4.0, Palette.WHITE)


## Angles 0 to PI run along the near half.
func _orbit_point(orbit: Array, angle: float, center: Vector2, radius: float) -> Vector2:
	var flat := Vector2(cos(angle) * orbit[0], sin(angle) * orbit[1]) * radius
	return center + flat.rotated(orbit[2])
