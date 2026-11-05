class_name Palette
extends RefCounted
## The game's colours: the Neptune skin's black, royal blue and white, plus the dither
## palettes the screen can be reduced to (Settings dither/palette) and the screen filters
## that reduce it (Settings dither/filter).

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
## Neptune's blue ramp. MapTheme moves these to a map's hue, in the UI theme and the
## dither palette alike.
const BLUES: Array[Color] = [DEEP, NAVY, INDIGO, BLUE, SKY]
## Neptune skin.ini Combo1 to Combo3, so standard hit objects keep their colours.
const CYAN := Color(0.18, 0.99, 0.99)
const MAGENTA := Color(0.99, 0.39, 0.99)
const YELLOW := Color(1.0, 0.86, 0.07)
## Darker steps of the yellow and magenta, so shaded combo circles keep their hue
## instead of dithering towards CRIMSON.
const GOLD := Color(0.55, 0.45, 0.04)
const PLUM := Color(0.5, 0.18, 0.52)

## Dither palettes by Settings name. "rgb" (or any unknown name) is not listed: it
## dithers each colour channel instead, the original look.
const DITHER := {
	"neptune": [BLACK, DEEP, NAVY, INDIGO, BLUE, SKY, WHITE, GREY, CRIMSON, CYAN, MAGENTA, YELLOW, GOLD, PLUM],
	"crimson": [BLACK, Color(0.22, 0.02, 0.04), Color(0.6, 0.06, 0.08), Color(0.92, 0.22, 0.22), Color(0.86, 0.83, 0.8)],
}

## dither.gdshader parameters every screen filter starts from: the original full Bayer
## dither. pixel_scale is the cell size at 1280x720; main.gd grows it with the window.
const FILTER_BASE := {
	"quantize": true, "pattern": 0, "matrix_size": 4, "pixel_scale": 3,
	"strength": 1.0, "scanlines": 0.0, "grain": 0.0,
}
## Screen filters by Settings name, strongest first, as the settings carousel steps
## through them. Each overrides FILTER_BASE; an unknown name gets FILTER_BASE as is.
const FILTERS := {
	"bayer": {},
	"soft bayer": {"matrix_size": 8, "pixel_scale": 2, "strength": 0.6},
	"scanlines": {"pixel_scale": 2, "strength": 0.4, "scanlines": 0.2},
	"noise": {"pattern": 1, "pixel_scale": 2, "strength": 0.5},
	## Palette colours only, in flat bands.
	"flat": {"strength": 0.0},
	## The screen's own colours under a light film grain.
	"grain": {"quantize": false, "grain": 0.06},
	"off": {"quantize": false},
}
