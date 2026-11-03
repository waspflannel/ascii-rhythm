extends Control
## End-of-run results: map details, score, hit counts, accuracy, max combo and the
## osu! grade, for a passed or failed run. The root scene handles screen changes.

signal retry_requested
signal back_requested

const HUD := preload("res://scripts/ui/hud.gd")
## Grade letters by RunScore.grade(). Neptune has no F, so a failed run shows the letter as text.
const GRADES := {
	"SS": preload("res://assets/skins/neptune/hud/ranking-X@2x.png"),
	"S": preload("res://assets/skins/neptune/hud/ranking-S@2x.png"),
	"A": preload("res://assets/skins/neptune/hud/ranking-A@2x.png"),
	"B": preload("res://assets/skins/neptune/hud/ranking-B@2x.png"),
	"C": preload("res://assets/skins/neptune/hud/ranking-C@2x.png"),
	"D": preload("res://assets/skins/neptune/hud/ranking-D@2x.png"),
}

## Set before adding to the tree.
var score: RunScore

## Hit count rows in HitObjectView.Judgement order, starting at MAX.
@onready var _hit_rows: Array[Node] = [$Stats/Max, $Stats/Perfect, $Stats/Great, $Stats/Good, $Stats/Meh, $Stats/Miss]


func _ready() -> void:
	$Retry.pressed.connect(retry_requested.emit)
	$Back.pressed.connect(back_requested.emit)
	_show_map(score.map)
	$Stats/Score.set_text("%08d" % score.score)
	$Stats/Accuracy/Value.set_text("%.2f%%" % (score.accuracy * 100.0))
	$Stats/MaxCombo/Value.set_text("%dx" % score.max_combo)
	_show_hit_counts()
	_show_grade()
	$Retry.grab_focus()


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
		row.get_node("Icon").texture = icons[judgement]
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
