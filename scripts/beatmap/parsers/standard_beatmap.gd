class_name StandardBeatmap
extends Beatmap
## An osu! standard map: circles, sliders and spinners.

const TYPE_CIRCLE := 1
const TYPE_SLIDER := 2
const TYPE_SPINNER := 8

## Slider pixels per beat, divided by 100.
var slider_multiplier := 1.4
## Slider ticks per beat.
var slider_tick_rate := 1.0


func _set_field(key: String, value: String) -> void:
	match key:
		"SliderMultiplier": slider_multiplier = value.to_float()
		"SliderTickRate": slider_tick_rate = value.to_float()
		_: super(key, value)


func _parse_hit_object(parts: PackedStringArray) -> HitObject:
	var type := parts[3].to_int()
	var time := parts[2].to_float() / 1000.0
	if type & TYPE_CIRCLE:
		return HitCircle.new(time, Vector2(parts[0].to_float(), parts[1].to_float()))
	# x,y,time,type,hitSound,endTime,hitSample
	if type & TYPE_SPINNER and parts.size() >= 6:
		return Spinner.new(time, parts[5].to_float() / 1000.0)
	# x,y,time,type,hitSound,curveType|curvePoints,slides,length,...
	if type & TYPE_SLIDER and parts.size() >= 8:
		var curve_parts := parts[5].split("|")
		var points := PackedVector2Array([Vector2(parts[0].to_float(), parts[1].to_float())])
		for i in range(1, curve_parts.size()):
			points.append(Vector2(curve_parts[i].get_slice(":", 0).to_float(), curve_parts[i].get_slice(":", 1).to_float()))
		var slides := maxi(1, parts[6].to_int())
		var length := parts[7].to_float()
		var timing := timing_at(time)
		var span_ms := length / (slider_multiplier * 100.0 * timing.slider_velocity) * timing.beat_length
		var slider := HitSlider.new(
			time,
			time + span_ms * slides / 1000.0,
			HitSlider.build_curve(curve_parts[0], points, length),
			slides,
			timing.beat_length / slider_tick_rate / 1000.0)
		# ...,edgeSounds,edgeSets,hitSample: 2|0|8 and normal:addition per edge.
		if parts.size() >= 9:
			for sound in parts[8].split("|"):
				slider.edge_sounds.append(sound.to_int())
		if parts.size() >= 10:
			for sets in parts[9].split("|"):
				slider.edge_sets.append(Vector2i(clampi(sets.get_slice(":", 0).to_int(), 0, 3), clampi(sets.get_slice(":", 1).to_int(), 0, 3)))
		return slider
	return null
