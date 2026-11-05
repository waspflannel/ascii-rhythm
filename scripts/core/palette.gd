class_name Palette
extends RefCounted
## The game's colours: the Neptune skin's black, royal blue and white, plus the palette
## the screen dithers to in palette mode (Settings dither/mode), built around the accent.

const BLACK := Color(0.0, 0.0, 0.0)
const DEEP := Color(0.02, 0.03, 0.1)
const NAVY := Color(0.06, 0.1, 0.29)
const INDIGO := Color(0.14, 0.22, 0.6)
## Neptune skin.ini MenuGlow and SongSelectInactiveText.
const BLUE := Color(0.278, 0.463, 1.0)
const SKY := Color(0.62, 0.71, 1.0)
const WHITE := Color(0.95, 0.96, 1.0)
## Cool grey for hairlines and dim text; a warm grey dithers olive against the blues.
const GREY := Color(0.36, 0.41, 0.6)
const CRIMSON := Color(0.86, 0.16, 0.27)
## Neptune's blue ramp. MapTheme moves these to a map's hue in the UI theme, and
## dither_palette to the dither accent's.
const BLUES: Array[Color] = [DEEP, NAVY, INDIGO, BLUE, SKY]
## Neptune skin.ini Combo1 to Combo3, so standard hit objects keep their colours.
const CYAN := Color(0.18, 0.99, 0.99)
const MAGENTA := Color(0.99, 0.39, 0.99)
const YELLOW := Color(1.0, 0.86, 0.07)
## Darker steps of the yellow and magenta, so shaded combo circles keep their hue
## instead of dithering towards CRIMSON.
const GOLD := Color(0.55, 0.45, 0.04)
const PLUM := Color(0.5, 0.18, 0.52)

## The skin colours the dither palette can keep (Settings dither/skin_colours).
const SKIN: Array[Color] = [CRIMSON, CYAN, MAGENTA, YELLOW, GOLD, PLUM]


## A Neptune blue moved to accent: its hue offset from BLUE and its brightness are kept and
## its saturation scales with the accent's, so BLUE itself becomes the accent.
static func shift(color: Color, accent: Color) -> Color:
	var hue := fposmod(color.h - BLUE.h + accent.h, 1.0)
	var saturation := clampf(color.s * accent.s / BLUE.s, 0.0, 1.0)
	return Color.from_hsv(hue, saturation, color.v, color.a)


## The palette-mode dither palette: black, shades colours (2 to 7) sampled evenly along
## BLUES moved to accent and darkened with it, the accent's grey, white and, with skin,
## the SKIN colours. At most 16 colours, the shader's slots. With BLUE, 5 shades and skin,
## it is Neptune's palette.
static func dither_palette(accent: Color, shades: int, skin: bool) -> Array[Color]:
	var colors: Array[Color] = [BLACK]
	var count := clampi(shades, 2, 7)
	var last := BLUES.size() - 1
	for i in count:
		var at := float(i * last) / (count - 1)
		var low := floori(at)
		var high := mini(low + 1, last)
		var color := shift(BLUES[low], accent).lerp(shift(BLUES[high], accent), at - low)
		color.v *= accent.v
		colors.append(color)
	colors.append(shift(GREY, accent))
	colors.append(WHITE)
	if skin:
		colors.append_array(SKIN)
	return colors
