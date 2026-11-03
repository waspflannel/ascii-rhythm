class_name RunScore
extends RefCounted
## osu!-like score, combo, accuracy and HP for one run, fed one judgement at a time.

## Hit values indexed by HitObjectView.Judgement: NONE, PERFECT, GREAT, GOOD, MISS.
const STANDARD_VALUES: Array[int] = [0, 300, 100, 50, 0]
const MANIA_VALUES: Array[int] = [0, 300, 200, 100, 0]

var score := 0
var combo := 0
var max_combo := 0
## 0 to 1.
var accuracy := 1.0
## 0 to 1. The run fails when it reaches 0.
var hp := 1.0
var failed := false
## Judgements so far, indexed by HitObjectView.Judgement.
var counts: Array[int] = [0, 0, 0, 0, 0]
## The map this run is scored against.
var map: Beatmap

var _values := STANDARD_VALUES
var _value_sum := 0
var _judged := 0
## Mania only: judgements in a full run (one per note, two per hold), so score tops out at 1,000,000.
var _mania_total := 0
## Standard only: the ScoreV1 difficulty multiplier.
var _difficulty := 0


func _init(p_map: Beatmap) -> void:
	map = p_map
	var objects := map.hit_objects
	if map.mode == Beatmap.MODE_MANIA:
		_values = MANIA_VALUES
		for note: ManiaNote in objects:
			_mania_total += 2 if note.is_hold() else 1
	else:
		var drain_time := maxf(objects.back().time - objects.front().time, 1.0)
		var density := clampf(objects.size() / drain_time * 8.0, 0.0, 16.0)
		_difficulty = roundi((map.hp_drain + map.circle_size + map.overall_difficulty + density) / 38.0 * 5.0)


func add(judgement: HitObjectView.Judgement) -> void:
	if failed or judgement == HitObjectView.Judgement.NONE:
		return
	counts[judgement] += 1
	var value := _values[judgement]
	_value_sum += value
	_judged += 1
	accuracy = _value_sum / (300.0 * _judged)
	if map.mode == Beatmap.MODE_MANIA:
		score = roundi(1000000.0 * _value_sum / (300.0 * maxi(_mania_total, 1)))
	else:
		# ScoreV1: the combo before this hit raises its value.
		score += value + int(value * maxi(combo - 1, 0) * _difficulty / 25.0)
	combo = 0 if judgement == HitObjectView.Judgement.MISS else combo + 1
	max_combo = maxi(max_combo, combo)
	# ponytail: flat per-judgement HP scaled by the map's HP drain, no passive drain;
	# swap in osu!'s per-map HP normalisation if fails feel off.
	var drain := map.hp_drain / 10.0
	match judgement:
		HitObjectView.Judgement.PERFECT:
			hp += 0.025 * (1.5 - drain)
		HitObjectView.Judgement.GREAT:
			hp += 0.01 * (1.5 - drain)
		HitObjectView.Judgement.MISS:
			hp -= 0.04 + 0.16 * drain
	hp = clampf(hp, 0.0, 1.0)
	failed = hp <= 0.0


## osu! letter grade: SS, S, A, B, C or D, and F for a failed run (as osu!lazer does).
func grade() -> String:
	if failed:
		return "F"
	if accuracy >= 1.0:
		return "SS"
	if map.mode == Beatmap.MODE_MANIA:
		# osu!mania grades on accuracy alone.
		if accuracy > 0.95:
			return "S"
		if accuracy > 0.9:
			return "A"
		if accuracy > 0.8:
			return "B"
		if accuracy > 0.7:
			return "C"
		return "D"
	# osu! standard grades on the share of 300s; misses and 50s hold back S, A and B.
	var judged := float(maxi(_judged, 1))
	var greats := counts[HitObjectView.Judgement.PERFECT] / judged
	var mehs := counts[HitObjectView.Judgement.GOOD] / judged
	var no_miss := counts[HitObjectView.Judgement.MISS] == 0
	if greats > 0.9 and mehs < 0.01 and no_miss:
		return "S"
	if greats > 0.9 or (greats > 0.8 and no_miss):
		return "A"
	if greats > 0.8 or (greats > 0.7 and no_miss):
		return "B"
	if greats > 0.6:
		return "C"
	return "D"
