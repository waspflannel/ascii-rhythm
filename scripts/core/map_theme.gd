extends Node
## Themes the screens from a beatmap's background art. The art's dominant colour takes
## over from Neptune's royal blue as the accent: Neptune's blue ramp (Palette.BLUES) moves
## to the accent's hue in every project theme colour and in the dither palette, so panels,
## borders, captions and the dithered art all take on the map's colours. Grey art, or
## none, keeps Neptune's blue.

## Seconds to blend from one map's colours to the next.
const BLEND := 0.35
## Hue buckets the art's pixels fall into; the most colourful bucket wins.
const HUES := 12
## The art is shrunk to this many pixels before sampling.
const SAMPLE := Vector2i(32, 18)
## Art whose winning bucket averages less colour (saturation x value) per sampled pixel
## counts as grey.
const MIN_COLOUR := 0.04
## Accent saturation range, so pale art still tints and loud art stays readable.
const SATURATION := Vector2(0.45, 0.75)
## The dither material main.tscn draws the screen with (one shared resource).
const DITHER := preload("res://shaders/dither_material.tres")
## The shader's palette array length.
const PALETTE_SLOTS := 16

## The art the theme was last taken from; null for none.
var art: Texture2D
## The current accent (Palette.BLUE moved to the map's hue) and its light tint (SKY).
var accent := Palette.BLUE
var light := Palette.SKY
## Moves the dither palette's blues too. main.gd turns it off during play so notes and
## hit objects dither to the skin's own colours.
var theme_dither := true:
	set(value):
		theme_dither = value
		apply_palette()

var _blend: Tween
## Accents by texture instance id, so refocusing a map skips resampling.
var _accents := {}
## Theme colours to retint: [theme or style box, property, original colour].
var _slots: Array = []
@onready var _theme := ThemeDB.get_project_theme()


func _ready() -> void:
	for type in _theme.get_type_list():
		for name in _theme.get_color_list(type):
			_track(_theme, "%s/colors/%s" % [type, name])
		for name in _theme.get_stylebox_list(type):
			var box := _theme.get_stylebox(name, type) as StyleBoxFlat
			if box:
				_track(box, "bg_color")
				_track(box, "border_color")
	Settings.dither_changed.connect(apply_palette)
	apply_palette()


## Blends the theme to texture's colours, or back to Neptune's blue for null or grey art.
func retarget(texture: Texture2D) -> void:
	art = texture
	var target := _accent_of(texture)
	if _blend:
		_blend.kill()
	if target != accent:
		_blend = create_tween()
		_blend.tween_method(_apply, accent, target, BLEND)


func _track(owner: Object, property: String) -> void:
	var color: Color = owner.get(property)
	if Color(color, 1.0) in Palette.BLUES:
		_slots.append([owner, property, color])


func _apply(color: Color) -> void:
	accent = color
	light = _shift(Palette.SKY)
	# One theme change for the whole retint, not one per colour.
	_theme.set_block_signals(true)
	for slot: Array in _slots:
		slot[0].set(slot[1], _shift(slot[2]))
	_theme.set_block_signals(false)
	_theme.emit_changed()
	apply_palette()


## A Neptune blue moved to the accent: its hue offset from BLUE and its brightness are
## kept and its saturation scales with the accent's, so BLUE itself becomes the accent.
func _shift(blue: Color) -> Color:
	var hue := fposmod(blue.h - Palette.BLUE.h + accent.h, 1.0)
	var saturation := clampf(blue.s * accent.s / Palette.BLUE.s, 0.0, 1.0)
	return Color.from_hsv(hue, saturation, blue.v, blue.a)


## Loads Settings dither/palette into the shader, its blues moved to the accent while
## theme_dither is on; an unknown name (such as "rgb") dithers each colour channel instead.
func apply_palette() -> void:
	var colors: Array = Palette.DITHER.get(str(Settings.get_value("dither", "palette")), [])
	var packed := PackedVector3Array()
	for color: Color in colors.slice(0, PALETTE_SLOTS):
		if theme_dither and color in Palette.BLUES:
			color = _shift(color)
		packed.append(Vector3(color.r, color.g, color.b))
	packed.resize(PALETTE_SLOTS)
	DITHER.set_shader_parameter("palette", packed)
	DITHER.set_shader_parameter("palette_size", mini(colors.size(), PALETTE_SLOTS))


func _accent_of(texture: Texture2D) -> Color:
	if texture == null:
		return Palette.BLUE
	var id := texture.get_instance_id()
	if not _accents.has(id):
		_accents[id] = _sample(texture.get_image())
	return _accents[id]


## The image's most colourful hue (pixels weighted by saturation x value, averaged within
## the winning hue bucket) at full brightness, or Neptune's blue for grey images.
static func _sample(image: Image) -> Color:
	if image == null:
		return Palette.BLUE
	if image.is_compressed():
		image.decompress()
	image.resize(SAMPLE.x, SAMPLE.y, Image.INTERPOLATE_BILINEAR)
	var buckets: Array[Color] = []
	buckets.resize(HUES)
	buckets.fill(Color(0, 0, 0, 0))
	for y in SAMPLE.y:
		for x in SAMPLE.x:
			var pixel := image.get_pixel(x, y)
			var weight := pixel.s * pixel.v
			buckets[int(pixel.h * HUES) % HUES] += Color(pixel.r * weight, pixel.g * weight, pixel.b * weight, weight)
	var best := Color(0, 0, 0, 0)
	for bucket in buckets:
		if bucket.a > best.a:
			best = bucket
	if best.a < MIN_COLOUR * SAMPLE.x * SAMPLE.y:
		return Palette.BLUE
	var mean := Color(best.r / best.a, best.g / best.a, best.b / best.a)
	return Color.from_hsv(mean.h, clampf(mean.s, SATURATION.x, SATURATION.y), 1.0)
