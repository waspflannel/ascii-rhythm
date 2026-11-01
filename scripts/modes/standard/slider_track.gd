extends Node2D
## Stroke the entire outside before the inside so tight bends have no cracks.

var points := PackedVector2Array()
var radius := 32.0
var border_color := Color.WHITE
var track_color := Color.BLACK


func _draw() -> void:
    if points.is_empty():
        return
    _stroke(radius, border_color)
    # Nested complete strokes shade by distance from the path, including joins.
    for layer in 12:
        var amount := float(layer) / 11.0
        var width := lerpf(radius - 3.0, 1.0, amount)
        _stroke(maxf(1.0, width), track_color.lerp(Color.WHITE, 0.02 + 0.12 * amount))


func _stroke(width: float, color: Color) -> void:
    # Independent segments avoid polyline miter spikes at near-180-degree turns.
    for i in range(1, points.size()):
        draw_line(points[i - 1], points[i], color, width * 2.0, true)
    # Discs fill round joins and caps even at reversals and self intersections.
    for point in points:
        draw_circle(point, width, color, true, -1.0, true)
