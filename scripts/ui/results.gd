extends Control
## End-of-run results: map details, score, hit counts, accuracy, max combo and the
## osu! grade in front of the planet, for a passed or failed run, over the map's dimmed
## background art. The root scene handles screen changes.

signal retry_requested
signal back_requested

const HUD := preload("res://scripts/ui/hud.gd")
## Grade letters by RunScore.grade(). Neptune has no F, so a failed run shows the letter
## as text in the same wide face as Neptune's letters.
const GRADES := {
	"SS": preload(SkinAssets.DIR + "hud/ranking-X@2x.png"),
	"S": preload(SkinAssets.DIR + "hud/ranking-S@2x.png"),
	"A": preload(SkinAssets.DIR + "hud/ranking-A@2x.png"),
	"B": preload(SkinAssets.DIR + "hud/ranking-B@2x.png"),
	"C": preload(SkinAssets.DIR + "hud/ranking-C@2x.png"),
	"D": preload(SkinAssets.DIR + "hud/ranking-D@2x.png"),
}

## Set before adding to the tree.
var score: RunScore

## Hit count rows in HitObjectView.Judgement order, starting at MAX.
@onready var _hit_rows: Array[Node] = [$Panel/Stats/Hits/Max, $Panel/Stats/Hits/Perfect, $Panel/Stats/Hits/Great, $Panel/Stats/Hits/Good, $Panel/Stats/Hits/Meh, $Panel/Stats/Hits/Miss]


func _ready() -> void:
	$Retry.pressed.connect(retry_requested.emit)
	$Back.pressed.connect(back_requested.emit)
	_show_map(score.map)
	$Panel/Stats/Score.set_text("%08d" % score.score)
	$Panel/Stats/Totals/Accuracy/Value.set_text("%.2f%%" % (score.accuracy * 100.0))
	$Panel/Stats/Totals/MaxCombo/Value.set_text("%dx" % score.max_combo)
	_show_hit_counts()
	_show_grade()
	# RETRY is Neptune art with no focus style, so light it up while hovered or focused.
	for changed: Signal in [$Retry.focus_entered, $Retry.focus_exited, $Retry.mouse_entered, $Retry.mouse_exited]:
		changed.connect(_light_retry)
	$Retry.grab_focus()


## The texture cropped to its visible pixels: Neptune's standard judgements sit small in
## the middle of a 256 px square.
static func _trimmed(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = texture.get_image().get_used_rect()
	return cropped


func _light_retry() -> void:
	$Retry.modulate = Palette.SKY if $Retry.has_focus() or $Retry.is_hovered() else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		retry_requested.emit()


func _show_map(map: Beatmap) -> void:
	$Map/Title.text = map.title
	$Map/Artist.text = map.artist
	var mode := "Standard"
	if map is ManiaBeatmap:
		mode = "Mania %dK" % (map as ManiaBeatmap).key_count()
	$Map/Version.text = "[%s]  %s" % [map.version, mode]
	$Art.texture = map.load_background()


## One row per judgement the mode gives: the skin's judgement image where Neptune has one,
## its hit value and the count.
func _show_hit_counts() -> void:
	var mania := score.map.mode == Beatmap.MODE_MANIA
	var icons := HUD.MANIA_POPUPS if mania else HUD.STANDARD_POPUPS
	var values := RunScore.MANIA_VALUES if mania else RunScore.STANDARD_VALUES
	for i in _hit_rows.size():
		var judgement := i + 1
		var row := _hit_rows[i]
		var miss := judgement == HitObjectView.Judgement.MISS
		row.visible = miss or values[judgement] > 0
		row.get_node("Icon").texture = _trimmed(icons[judgement])
		var label := str(values[judgement])
		if miss:
			label = "Miss"
		elif judgement == HitObjectView.Judgement.MAX:
			label = "MAX"
		row.get_node("Name").text = label
		row.get_node("Count").set_text(str(score.counts[judgement]))


func _show_grade() -> void:
	var grade := score.grade()
	if GRADES.has(grade):
		$Grade.texture = GRADES[grade]
	else:
		$GradeText.text = grade
		$GradeText.show()
	$Failed.visible = score.failed
	# osu!'s "perfect" badge: a full combo, nothing missed.
	$Perfect.visible = not score.failed and score.counts[HitObjectView.Judgement.MISS] == 0
