extends Control
## Gameplay HUD: score, combo, accuracy, HP, judgement popups, song progress and the
## dither's beat pulse. Instanced under Play; it listens to Play's hit object views, so
## scoring stays out of play.gd.

## Indexed by HitObjectView.Judgement. Neptune hides standard 300s (hit300.png is blank),
## and every judgement's -0 frame is blank, so these use the -1 frame.
const STANDARD_POPUPS: Array[Texture2D] = [
	null,
	null,
	null,
	preload(SkinAssets.DIR + "standard/judgements/hit100-1.png"),
	preload(SkinAssets.DIR + "standard/judgements/hit50-1.png"),
	null,
	preload(SkinAssets.DIR + "standard/judgements/hit0-1.png"),
]
const MANIA_POPUPS: Array[Texture2D] = [
	null,
	preload(SkinAssets.DIR + "mania/mania-hit300g-1@2x.png"),
	preload(SkinAssets.DIR + "mania/mania-hit300-1@2x.png"),
	preload(SkinAssets.DIR + "mania/mania-hit200-1@2x.png"),
	preload(SkinAssets.DIR + "mania/mania-hit100-1@2x.png"),
	preload(SkinAssets.DIR + "mania/mania-hit50-1@2x.png"),
	preload(SkinAssets.DIR + "mania/mania-hit0-1@2x.png"),
]
## Neptune skin.ini [Mania] ScorePosition: judgement height on a 480 px tall screen.
const MANIA_POPUP_Y := 220.0 / 480.0
## Extra screen brightness on a beat, eased out over the beat.
const PULSE := 0.07
## The dither material main.tscn draws the screen with (one shared resource).
const DITHER := preload("res://shaders/dither_material.tres")
## Combo and score kick on a hit: scale, seconds. Combo milestones snap bigger and longer.
const PUNCH := 1.2
const PUNCH_TIME := 0.1
const PUNCH_50 := 1.3
const PUNCH_100 := 1.4
const PUNCH_MILESTONE_TIME := 0.18
## A broken combo dims to this alpha, then eases back.
const COMBO_BREAK_ALPHA := 0.3

var _score: RunScore
## Hit objects that have given their last judgement; the map is done when all have.
var _finished_objects := 0
var _leaving := false
var _mania_popup: Sprite2D
var _beat_pulse := bool(Settings.get_value("dither", "beat_pulse"))
var _combo_tween: Tween
var _score_tween: Tween

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
	# Without a playable map, Play shows its own message; Esc leaves.
	if _play.beatmap == null or _music.stream == null or _music.stream.get_length() <= 0.0:
		return
	_score = RunScore.new(_play.beatmap)
	$MapTitle.text = "%s [%s]" % [_play.beatmap.title, _play.beatmap.version]
	_progress.color = MapTheme.accent
	_refresh()
	show()


func _process(delta: float) -> void:
	if _score == null:
		return
	_health.value = lerpf(_health.value, _score.hp, minf(1.0, delta * 8.0))
	if _music.playing:
		var length := _music.stream.get_length()
		var at := _music.get_playback_position()
		_progress.scale.x = clampf(at / length, 0.0, 1.0)
		$Time.text = "%s / %s" % [_clock(at), _clock(length)]
	_pulse()


func _exit_tree() -> void:
	DITHER.set_shader_parameter("pulse", 0.0)


## Brightens the dither a little on each beat of the song, fading out before the next.
func _pulse() -> void:
	var amount := 0.0
	if _beat_pulse and _music.playing:
		var t := SongClock.get_time()
		var beat: Beatmap.TimingPoint = _play.beatmap.beat_at(t)
		if beat.beat_length > 0.0:
			var phase := fposmod((t - beat.time) * 1000.0 / beat.beat_length, 1.0)
			amount = PULSE * pow(1.0 - phase, 3.0)
	DITHER.set_shader_parameter("pulse", amount)


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _on_field_child(node: Node) -> void:
	if node is HitObjectView:
		node.judged.connect(_on_judged.bind(node))


func _on_judged(judgement: HitObjectView.Judgement, view: HitObjectView) -> void:
	# Judgements still count while leaving after the song, so objects it cut off show as misses.
	if _score == null or _score.failed:
		return
	var broken := judgement == HitObjectView.Judgement.MISS and _score.combo > 0
	_score.add(judgement)
	_refresh()
	_kick(judgement, broken)
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


## Punches the combo (and score) on a hit, harder on every 50th and 100th combo; a broken
## combo dims and eases back instead. Misses never punch.
func _kick(judgement: HitObjectView.Judgement, broken: bool) -> void:
	if judgement == HitObjectView.Judgement.MISS:
		if broken:
			if _combo_tween:
				_combo_tween.kill()
			_combo_text.scale = Vector2.ONE
			_combo_text.modulate.a = COMBO_BREAK_ALPHA
			_combo_tween = _combo_text.create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			_combo_tween.tween_property(_combo_text, "modulate:a", 1.0, 0.4)
		return
	var combo := _score.combo
	var amount := PUNCH_100 if combo % 100 == 0 else PUNCH_50 if combo % 50 == 0 else PUNCH
	var time := PUNCH_TIME if amount == PUNCH else PUNCH_MILESTONE_TIME
	# Combo grows from its bottom-left corner, score from its top-right, like their anchors.
	_combo_tween = _punch(_combo_text, _combo_tween, Vector2(0.0, 1.0), amount, time)
	_score_tween = _punch(_score_text, _score_tween, Vector2(1.0, 0.0), PUNCH, PUNCH_TIME)


## Snaps node to amount times its size around pivot (a fraction of its size), easing back.
func _punch(node: Control, running: Tween, pivot: Vector2, amount: float, time: float) -> Tween:
	if running:
		running.kill()
	node.modulate.a = 1.0
	node.pivot_offset = node.size * pivot
	node.scale = Vector2.ONE * amount
	var tween := node.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, time)
	return tween


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
	if judgement == HitObjectView.Judgement.MISS:
		# Misses drop quietly instead of punching in.
		tween.set_parallel()
		tween.tween_property(popup, "position:y", popup.position.y + 24.0 * _field.scale.x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.25)
		tween.chain().tween_callback(popup.queue_free)
		return
	# Hits punch in from 1.5x, then fade.
	var base := popup.scale
	popup.scale = base * 1.5
	tween.tween_property(popup, "scale", base, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.25)
	tween.tween_callback(popup.queue_free)


## Hands the run to the results screen: on fail, a red cut on the playfield then a quiet
## fade-out; on a pass (every object judged or the song ended), a short music fade that
## ends in a quick white-out into the results.
func _leave(failed: bool) -> void:
	if _leaving:
		return
	_leaving = true
	var duration := 1.5 if failed else 2.0
	var tween := create_tween().set_parallel()
	if failed:
		_field.modulate = Color(2.0, 0.35, 0.35)
		tween.tween_property(_field, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(_play, "modulate:a", 0.0, duration)
	tween.tween_property(_music, "volume_db", -40.0, duration)
	if not failed:
		var white := ColorRect.new()
		white.color = Color(1.0, 1.0, 1.0, 0.0)
		white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		white.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(white)
		tween.tween_property(white, "color:a", 0.9, 0.15).set_delay(duration - 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_play.run_finished.emit.bind(_score))
