class_name HitSlider
extends HitObject
## An osu! standard slider: a head circle, a path the ball follows, and
## optional repeats that bounce back and forth along the path.

## Head position in osu! pixels.
var position: Vector2
## The path, already trimmed to the map's pixel length. Draw it with
## curve.get_baked_points().
var curve: Curve2D
## How many times the ball crosses the path. 1 means no repeats.
var slides: int
## Seconds between slider ticks.
var tick_interval: float
## Per edge (head, each repeat, tail): hitSound flags and Vector2i(normal set, addition
## set). Empty, or shorter than slides + 1, falls back to the object's own.
var edge_sounds := PackedInt32Array()
var edge_sets: Array[Vector2i] = []


func _init(p_time: float, p_end_time: float, p_curve: Curve2D, p_slides: int, p_tick_interval: float) -> void:
	super(p_time, p_end_time)
	curve = p_curve
	position = p_curve.get_point_position(0)
	slides = p_slides
	tick_interval = p_tick_interval


## Song time the ball reaches edge (0 the head, slides the tail).
func edge_time(edge: int) -> float:
	return time + (end_time - time) * edge / slides


## Where the slider ball is at song time t.
func position_at(t: float) -> Vector2:
	if end_time <= time:
		return position
	var progress := clampf((t - time) / (end_time - time), 0.0, 1.0) * slides
	var span := mini(floori(progress), slides - 1)
	var along := progress - span
	if span % 2 == 1:
		along = 1.0 - along # Odd spans run backwards.
	return curve.sample_baked(along * curve.get_baked_length())


## Builds the path from the .osu curve letter (B, C, L or P) and its control
## points, head first, trimmed or extended to length pixels.
static func build_curve(type: String, points: PackedVector2Array, length: float) -> Curve2D:
	var flat := PackedVector2Array()
	match type:
		"L":
			flat = points
		"C":
			flat = _catmull(points)
		"P":
			if points.size() == 3:
				flat = _arc(points)
	if flat.size() < 2:
		flat = _bezier(points) # Bezier is also osu!'s fallback for broken P curves.
	var curve := Curve2D.new()
	curve.bake_interval = 1.0
	for point in _fit_length(flat, length):
		curve.add_point(point)
	return curve


## Bezier with red anchors: a repeated point ends one segment and starts the next.
static func _bezier(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var segment := PackedVector2Array()
	for i in points.size():
		segment.append(points[i])
		if i == points.size() - 1 or points[i] == points[i + 1]:
			out.append_array(_bezier_segment(segment))
			segment = PackedVector2Array()
	return out


static func _bezier_segment(controls: PackedVector2Array) -> PackedVector2Array:
	var polygon_length := 0.0
	for i in range(1, controls.size()):
		polygon_length += controls[i - 1].distance_to(controls[i])
	var steps := maxi(1, ceili(polygon_length / 4.0))
	var out := PackedVector2Array()
	for s in steps + 1:
		# de Casteljau: lerp neighbours until one point is left.
		var p := controls.duplicate()
		for k in range(p.size() - 1, 0, -1):
			for j in k:
				p[j] = p[j].lerp(p[j + 1], float(s) / steps)
		out.append(p[0])
	return out


static func _catmull(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var v1: Vector2 = points[i - 1] if i > 0 else points[i]
		var v2 := points[i]
		var v3 := points[i + 1]
		var v4: Vector2 = points[i + 2] if i + 2 < points.size() else v3 + (v3 - v2)
		var steps := maxi(1, ceili(v2.distance_to(v3) / 4.0))
		for s in steps:
			out.append(v2.cubic_interpolate(v3, v1, v4, float(s) / steps))
	out.append(points[points.size() - 1])
	return out


## Circular arc through three points. Empty if they are in a straight line.
static func _arc(points: PackedVector2Array) -> PackedVector2Array:
	var a := points[0]
	var b := points[1]
	var c := points[2]
	var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(d) < 0.001:
		return PackedVector2Array()
	var center := Vector2(
		(a.length_squared() * (b.y - c.y) + b.length_squared() * (c.y - a.y) + c.length_squared() * (a.y - b.y)) / d,
		(a.length_squared() * (c.x - b.x) + b.length_squared() * (a.x - c.x) + c.length_squared() * (b.x - a.x)) / d)
	var radius := a.distance_to(center)
	var start := (a - center).angle()
	var sweep := wrapf((c - center).angle() - start, 0.0, TAU)
	if (b - a).cross(c - a) < 0.0:
		sweep -= TAU # Go the other way round so the arc passes through b.
	var steps := maxi(2, ceili(absf(sweep) * radius / 4.0))
	var out := PackedVector2Array()
	for s in steps + 1:
		out.append(center + Vector2.from_angle(start + sweep * s / steps) * radius)
	return out


## Cuts the path at length pixels, or stretches its last segment to reach it.
static func _fit_length(points: PackedVector2Array, length: float) -> PackedVector2Array:
	if length <= 0.0 or points.size() < 2:
		return points
	var out := PackedVector2Array([points[0]])
	var travelled := 0.0
	for i in range(1, points.size()):
		var segment := points[i - 1].distance_to(points[i])
		if segment <= 0.0001:
			continue
		if travelled + segment >= length:
			out.append(points[i - 1].move_toward(points[i], length - travelled))
			return out
		travelled += segment
		out.append(points[i])
	if out.size() < 2:
		return out
	var last := out[out.size() - 1]
	var direction := out[out.size() - 2].direction_to(last)
	out[out.size() - 1] = last + direction * (length - travelled)
	return out
