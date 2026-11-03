class_name SkinNumber
extends HBoxContainer
## Draws text with the skin's score font: digits plus , . % and x.

const GLYPHS := {
	"0": preload("res://assets/skins/neptune/hud/score-0@2x.png"),
	"1": preload("res://assets/skins/neptune/hud/score-1@2x.png"),
	"2": preload("res://assets/skins/neptune/hud/score-2@2x.png"),
	"3": preload("res://assets/skins/neptune/hud/score-3@2x.png"),
	"4": preload("res://assets/skins/neptune/hud/score-4@2x.png"),
	"5": preload("res://assets/skins/neptune/hud/score-5@2x.png"),
	"6": preload("res://assets/skins/neptune/hud/score-6@2x.png"),
	"7": preload("res://assets/skins/neptune/hud/score-7@2x.png"),
	"8": preload("res://assets/skins/neptune/hud/score-8@2x.png"),
	"9": preload("res://assets/skins/neptune/hud/score-9@2x.png"),
	",": preload("res://assets/skins/neptune/hud/score-comma@2x.png"),
	".": preload("res://assets/skins/neptune/hud/score-dot@2x.png"),
	"%": preload("res://assets/skins/neptune/hud/score-percent@2x.png"),
	"x": preload("res://assets/skins/neptune/hud/score-x@2x.png"),
}
## Height of a digit in screen pixels.
@export var glyph_height := 40.0
## Glyph overlap in @1x skin pixels (skin.ini ScoreOverlap / ComboOverlap).
@export var overlap := 8.0


func set_text(text: String) -> void:
	# Digits are 92 px tall at @2x, so one @1x pixel is 2 / 92 of a digit.
	var pixel := glyph_height / 92.0
	add_theme_constant_override("separation", -roundi(overlap * 2.0 * pixel))
	while get_child_count() < text.length():
		var glyph := TextureRect.new()
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.size_flags_vertical = Control.SIZE_SHRINK_END
		add_child(glyph)
	for i in get_child_count():
		var glyph := get_child(i) as TextureRect
		glyph.visible = i < text.length()
		if glyph.visible:
			glyph.texture = GLYPHS[text[i]]
			glyph.custom_minimum_size = glyph.texture.get_size() * pixel
