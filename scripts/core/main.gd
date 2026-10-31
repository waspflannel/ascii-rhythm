extends Control
## Root scene. Renders the game into a low-res SubViewport and shows it
## upscaled through the dither shader.

@onready var _screen: SubViewportContainer = $Screen


func _ready() -> void:
	var pixel_scale: int = Settings.get_value("dither", "pixel_scale")
	_screen.stretch_shrink = pixel_scale
	var dither := _screen.material as ShaderMaterial
	dither.set_shader_parameter("pixel_scale", float(pixel_scale))
	dither.set_shader_parameter("matrix_size", Settings.get_value("dither", "matrix_size"))
