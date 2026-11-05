extends Node
## Themes the screens from a beatmap's background art, and loads the dither colour. The
## art's dominant colour takes over from Neptune's royal blue as the accent: Neptune's blue
## ramp (Palette.BLUES) moves to the accent's hue in every project theme colour, so panels,
## borders and captions take on the map's colours. Grey art, or none, keeps Neptune's
## blue. The dither follows the colour picked in Settings unless Follow map is on (see
## apply_palette).

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
## With Follow map on, lets the map's accent drive the dither. main.gd turns it off during
## play so notes and hit objects dither to the skin's own colours.
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
	light = Palette.shift(Palette.SKY, accent)
	# One theme change for the whole retint, not one per colour.
	_theme.set_block_signals(true)
	for slot: Array in _slots:
		slot[0].set(slot[1], Palette.shift(slot[2], accent))
	_theme.set_block_signals(false)
	_theme.emit_changed()
	apply_palette()


## The dither's colour. Settings dither/accent (Neptune's blue if unreadable), or with
## Follow map on the map's accent while theme_dither is on and Neptune's blue in play.
func dither_accent() -> Color:
	if Settings.get_value("dither", "follow_map"):
		return accent if theme_dither else Palette.BLUE
	var hex := str(Settings.get_value("dither", "accent"))
	return Color(Color.html(hex), 1.0) if Color.html_is_valid(hex) else Palette.BLUE


## Loads the dither colour into the shader's tint, and in palette mode its palette
## (Palette.dither_palette); other modes clear the palette. The colour picked in Settings
## drives the dither (palette ramp and tint) on every screen, play included, and overrides
## the map's accent. With Follow map on, the map art's accent drives it outside play and
## Neptune's blue during play. Map art themes the UI chrome either way.
func apply_palette() -> void:
	var color := dither_accent()
	var colors: Array[Color] = []
	if Settings.get_value("dither", "mode") == "palette":
		colors = Palette.dither_palette(color, Settings.get_value("dither", "shades"), Settings.get_value("dither", "skin_colours"))
	var packed := PackedVector3Array()
	for entry in colors:
		packed.append(Vector3(entry.r, entry.g, entry.b))
	packed.resize(PALETTE_SLOTS)
	DITHER.set_shader_parameter("palette", packed)
	DITHER.set_shader_parameter("palette_size", colors.size())
	DITHER.set_shader_parameter("tint_color", color)


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
