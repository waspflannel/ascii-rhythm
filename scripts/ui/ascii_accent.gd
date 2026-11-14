class_name AsciiAccent
extends Label
## A screen's Japanese accent line framed as an ASCII header: a box corner before the
## text and a rule after it, out to rule_length pixels, ending in a small diamond.
## ┌─ 設定 ／ SETTINGS ──────────────── ◇

const LEAD := "┌─  "
const RULE := "─"
const TIP := " ◇"
## Opacity of the box characters against the text.
const RULE_ALPHA := 0.45

@export var rule_length := 560.0


func _ready() -> void:
	text = LEAD + text


func _draw() -> void:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var color := get_theme_color("font_color")
	color.a *= RULE_ALPHA
	var start := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.6
	var dash := font.get_string_size(RULE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if dash <= 0.0 or start >= rule_length:
		return
	var rule := RULE.repeat(int((rule_length - start) / dash)) + TIP
	var baseline := (size.y - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
	draw_string(font, Vector2(start, baseline), rule, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
