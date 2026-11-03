class_name ManiaBeatmap
extends Beatmap
## A mania map. CircleSize is the key count and x picks the column.

const TYPE_HOLD := 128


## osu!mania supports 1 to 18 keys.
func key_count() -> int:
	return clampi(int(circle_size), 1, 18)


func _parse_hit_object(parts: PackedStringArray) -> HitObject:
	var keys := key_count()
	var column := clampi(floori(parts[0].to_float() * keys / 512.0), 0, keys - 1)
	var time := parts[2].to_float() / 1000.0
	var end_time := time
	# Holds put endTime first in the last field: endTime:hitSample
	if parts[3].to_int() & TYPE_HOLD:
		end_time = parts[5].get_slice(":", 0).to_float() / 1000.0
	return ManiaNote.new(time, column, end_time)
