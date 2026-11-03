extends Control
## Gameplay HUD: score, combo, accuracy, HP, judgement popups and song progress.
## Instanced under Play; it listens to Play's hit object views, so scoring stays out of play.gd.

## Indexed by HitObjectView.Judgement. Neptune hides standard 300s (hit300.png is blank),
## and every judgement's -0 frame is blank, so these use the -1 frame.
const STANDARD_POPUPS: Array[Texture2D] = [
	null,
	null,
	preload("res://assets/skins/neptune/standard/judgements/hit100-1.png"),
	preload("res://assets/skins/neptune/standard/judgements/hit50-1.png"),
	preload("res://assets/skins/neptune/standard/judgements/hit0-1.png"),
]
const MANIA_POPUPS: Array[Texture2D] = [
	null,
	preload("res://assets/skins/neptune/mania/mania-hit300-1@2x.png"),
	preload("res://assets/skins/neptune/mania/mania-hit200-1@2x.png"),
	preload("res://assets/skins/neptune/mania/mania-hit100-1@2x.png"),
	preload("res://assets/skins/neptune/mania/mania-hit0-1@2x.png"),
]
## Neptune skin.ini [Mania] ScorePosition: judgement height on a 480 px tall screen.
const MANIA_POPUP_Y := 220.0 / 480.0

var _score: RunScore
## Hit objects that have given their last judgement; the map is done when all have.
var _finished_objects := 0
var _leaving := false
var _mania_popup: Sprite2D

@onready var _play: Control = get_parent()
@onready var _music: AudioStreamPlayer = _play.get_node("Music")
@onready var _field: Node2D = _play.get_node("Playfield")
@onready var _health: TextureProgressBar = $Health
@onready var _score_text: SkinNumber = $Score
@onready var _accuracy_text: SkinNumber = $Accuracy
@onready var _combo_text: SkinNumber = $Combo
@onready var _progress: ColorRect = $Progress


func _ready() -> void:
	hide()
	_field.child_entered_tree.connect(_on_field_child)
	_music.finished.connect(_leave.bind(false))
	# Play's _ready runs after its children's, so wait for it to load the map.
	_start.call_deferred()


func _start() -> void:
	# Without a playable map, Play shows its own message and Back button.
	if _play.beatmap == null or _music.stream == null or _music.stream.get_length() <= 0.0:
		return
	_score = RunScore.new(_play.beatmap)
	_refresh()
	show()


func _process(delta: float) -> void:
	if _score == null:
		return
	_health.value = lerpf(_health.value, _score.hp, minf(1.0, delta * 8.0))
	if _music.playing:
		_progress.scale.x = clampf(_music.get_playback_position() / _music.stream.get_length(), 0.0, 1.0)


func _on_field_child(node: Node) -> void:
	if node is HitObjectView:
		node.judged.connect(_on_judged.bind(node))


func _on_judged(judgement: HitObjectView.Judgement, view: HitObjectView) -> void:
	# Judgements still count while leaving after the song, so objects it cut off show as misses.
	if _score == null or _score.failed:
		return
	_score.add(judgement)
	_refresh()
	_show_popup(judgement, view)
	if view.finished:
		_finished_objects += 1
	if _score.failed:
		_leave(true)
	elif _finished_objects == _play.beatmap.hit_objects.size():
		_leave(false)


func _refresh() -> void:
	_score_text.set_text("%08d" % _score.score)
	_accuracy_text.set_text("%.2f%%" % (_score.accuracy * 100.0))
	_combo_text.set_text("%dx" % _score.combo)


func _show_popup(judgement: HitObjectView.Judgement, view: HitObjectView) -> void:
	var mania: bool = _play.beatmap.mode == Beatmap.MODE_MANIA
	var texture := (MANIA_POPUPS if mania else STANDARD_POPUPS)[judgement]
	if texture == null:
		return
	var popup := Sprite2D.new()
	popup.texture = texture
	popup.scale = Vector2.ONE * _field.scale.x * (0.5 if mania else 0.8)
	if mania:
		# Mania judgements share one spot, so the newest replaces the last.
		if is_instance_valid(_mania_popup):
			_mania_popup.queue_free()
		_mania_popup = popup
		popup.position = Vector2(size.x / 2.0, size.y * MANIA_POPUP_Y)
	else:
		popup.position = view.global_position
	add_child(popup)
	var tween := popup.create_tween()
	tween.tween_property(popup, "scale", popup.scale * 1.15, 0.08)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.25)
	tween.tween_callback(popup.queue_free)


## Hands the run to the results screen: a quiet fade-out on fail, or a short music
## fade once every object is judged or the song ends.
func _leave(failed: bool) -> void:
	if _leaving:
		return
	_leaving = true
	var duration := 1.5 if failed else 2.0
	var tween := create_tween().set_parallel()
	if failed:
		tween.tween_property(_play, "modulate:a", 0.0, duration)
	tween.tween_property(_music, "volume_db", -40.0, duration)
	tween.chain().tween_callback(_play.run_finished.emit.bind(_score))
