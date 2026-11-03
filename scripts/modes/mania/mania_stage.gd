class_name ManiaStage
extends Node2D
## The mania stage behind the notes: a Neptune key image per column, the judgement
## line, stage edges, a lane light per held key and a hit flash per column. Neptune's
## stage, hint and lighting images are blank, so the edges, lights and flashes are
## plain dark red shapes. The origin is the left end of the judgement line; notes fall
## towards it from HIT_POSITION above.

## Neptune skin.ini [Mania] layout, in pixels on a 480 px tall screen.
const COLUMN_WIDTH := 56.0
const HIT_POSITION := 420.0
const SCREEN_HEIGHT := 480.0
const DARK_RED := Color(0.6, 0.06, 0.08)
const FLASH_HEIGHT := 48.0
const LIGHT_HEIGHT := 160.0
const LIGHT_ALPHA := 0.35
## Pixels a pressed key sinks.
const PRESS_OFFSET := 2.0

var _keys: Array[Sprite2D] = []
var _key_up: Array[Texture2D] = []
var _key_down: Array[Texture2D] = []
var _flashes: Array[ColorRect] = []
var _lights: Array[Sprite2D] = []
var _light_fades: Array[Tween] = []


## Neptune skins outer and inner lanes differently (blue and white in 4K). Counting in
## from both edges, lanes alternate outer, inner, outer, so any key count stays symmetric.
static func is_inner(column: int, keys: int) -> bool:
	return mini(column, keys - 1 - column) % 2 == 1


## Builds the stage for a map with this many keys. Call before adding it to the tree.
func setup(keys: int) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow := GradientTexture2D.new()
	glow.gradient = Gradient.new()
	glow.gradient.set_color(0, Color(DARK_RED, 0.0))
	glow.gradient.set_color(1, DARK_RED)
	glow.fill_to = Vector2(0.0, 1.0)
	glow.width = 1
	_light_fades.resize(keys)
	for column in keys:
		_add_light(column, glow)
		_add_key(column, keys)
		_add_flash(column)
	var width := keys * COLUMN_WIDTH
	_add_line(Vector2.ZERO, Vector2(width, 0.0), Color.WHITE) # skin.ini JudgementLine: 1
	for x in [0.0, width]:
		_add_line(Vector2(x, -HIT_POSITION), Vector2(x, SCREEN_HEIGHT - HIT_POSITION), DARK_RED)


## Swaps column's key image for its pressed or released look and lights its lane.
func set_pressed(column: int, down: bool) -> void:
	var key := _keys[column]
	key.texture = _key_down[column] if down else _key_up[column]
	key.position.y = -HIT_POSITION + (PRESS_OFFSET if down else 0.0)
	key.modulate = Color(1.25, 1.25, 1.25) if down else Color.WHITE
	var light := _lights[column]
	if _light_fades[column]:
		_light_fades[column].kill()
	if down:
		light.modulate.a = LIGHT_ALPHA
	else:
		_light_fades[column] = light.create_tween()
		_light_fades[column].tween_property(light, "modulate:a", 0.0, 0.12)


## Lights column briefly after a hit.
func flash(column: int) -> void:
	var rect := _flashes[column]
	rect.modulate.a = 1.0
	rect.create_tween().tween_property(rect, "modulate:a", 0.0, 0.15)


## Neptune has key-1 to key-4 (plus pressed -p versions) for its four 4K columns: outer
## and inner on the left, then inner and outer on the right. Other key counts reuse them.
func _add_key(column: int, keys: int) -> void:
	var right := column >= ceili(keys / 2.0)
	var inner := is_inner(column, keys)
	var image := (3 if inner else 4) if right else (2 if inner else 1)
	_key_up.append(load("res://assets/skins/neptune/mania/key-%d.png" % image))
	_key_down.append(load("res://assets/skins/neptune/mania/key-%dp.png" % image))
	var key := Sprite2D.new()
	key.texture = _key_up[column]
	key.centered = false
	# Key images span the whole screen height, with the key itself at the judgement line.
	key.scale = Vector2(COLUMN_WIDTH / key.texture.get_width(), SCREEN_HEIGHT / key.texture.get_height())
	key.position = Vector2(column * COLUMN_WIDTH, -HIT_POSITION)
	add_child(key)
	_keys.append(key)


## Drawn under the key, so the glow rises from the top of the receptor.
func _add_light(column: int, glow: GradientTexture2D) -> void:
	var light := Sprite2D.new()
	light.texture = glow
	light.centered = false
	light.scale = Vector2(COLUMN_WIDTH / glow.width, LIGHT_HEIGHT / glow.height)
	light.position = Vector2(column * COLUMN_WIDTH, -LIGHT_HEIGHT)
	light.modulate.a = 0.0
	add_child(light)
	_lights.append(light)


func _add_flash(column: int) -> void:
	var rect := ColorRect.new()
	rect.color = DARK_RED
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(column * COLUMN_WIDTH, -FLASH_HEIGHT)
	rect.size = Vector2(COLUMN_WIDTH, FLASH_HEIGHT)
	add_child(rect)
	_flashes.append(rect)


func _add_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 2.0
	line.default_color = color
	add_child(line)
