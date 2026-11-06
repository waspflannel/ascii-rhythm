class_name CursorView
extends Sprite2D
## The standard-mode cursor: Neptune's ring, sized, coloured and outlined from Settings
## [cursor]. Play moves it; the Settings screen shows one as a live preview.

const RING := preload("res://assets/skins/neptune/standard/hitcircles/cursor@2x.png")
const SHADER := preload("res://shaders/cursor.gdshader")
## The ring's scale at size 100%.
const BASE_SCALE := 0.075
## The ring grows this much while a hit key or button is held (with Expand on).
const HELD_SCALE := 1.2
## Outline thickness in layout pixels, and its cap in texels so a tiny cursor keeps it
## attached to the ring.
const OUTLINE := 1.0
const MAX_OUTLINE_TEXELS := 8.0

var _rest := Vector2.ONE * BASE_SCALE
var _expand := true
var _tween: Tween


func _init() -> void:
	texture = RING
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER


func _ready() -> void:
	refresh()
	# The Accent colour follows the dither colour.
	Settings.cursor_changed.connect(refresh)
	Settings.dither_changed.connect(refresh)


## Loads the [cursor] settings, clamped so a hand-edited file can't break them.
func refresh() -> void:
	var percent := clampi(Settings.get_value("cursor", "size"), 25, 300)
	_rest = Vector2.ONE * BASE_SCALE * percent / 100.0
	_expand = Settings.get_value("cursor", "expand")
	if _tween:
		_tween.kill()
	scale = _rest
	var shader := material as ShaderMaterial
	var colour := _colour()
	shader.set_shader_parameter("use_tint", colour.a > 0.0)
	shader.set_shader_parameter("tint", colour)
	shader.set_shader_parameter("outline_width", minf(OUTLINE / _rest.x, MAX_OUTLINE_TEXELS) if Settings.get_value("cursor", "outline") else 0.0)
	shader.set_shader_parameter("opacity", clampi(Settings.get_value("cursor", "opacity"), 30, 100) / 100.0)


## Grows the ring quickly while a hit key or button is down, easing back on release.
func set_held(held: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _rest * (HELD_SCALE if held and _expand else 1.0), 0.05 if held else 0.15)


## The colour mode's tint, or a transparent colour for Skin (the ring's own blue).
func _colour() -> Color:
	match Settings.get_value("cursor", "colour"):
		"white":
			return Color.WHITE
		"accent":
			return MapTheme.dither_accent()
		"custom":
			return custom_colour()
	return Color(0.0, 0.0, 0.0, 0.0)


## The custom colour setting, or white if it is unreadable.
static func custom_colour() -> Color:
	var hex := str(Settings.get_value("cursor", "custom_colour"))
	return Color(Color.html(hex), 1.0) if Color.html_is_valid(hex) else Color.WHITE
