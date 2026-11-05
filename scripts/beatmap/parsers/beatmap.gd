class_name Beatmap
extends RefCounted
## A parsed .osu file. This class reads the sections every mode shares;
## ManiaBeatmap and StandardBeatmap turn [HitObjects] lines into HitObjects.

const MODE_STANDARD := 0
const MODE_MANIA := 3


class TimingPoint:
	## Seconds.
	var time := 0.0
	## Milliseconds per beat, carried over from the last uninherited point.
	var beat_length := 500.0
	## Scroll / slider speed multiplier from inherited points.
	var slider_velocity := 1.0
	## False for inherited (green line) points, which only change slider velocity.
	var uninherited := true


## Path of the .osu file. Audio and background paths are relative to its folder.
var path := ""
var audio_filename := ""
## Silence before the song starts, in seconds.
var audio_lead_in := 0.0
var mode := MODE_STANDARD
var title := ""
var artist := ""
var creator := ""
## Difficulty name.
var version := ""
var background := ""
var hp_drain := 5.0
var circle_size := 5.0
var overall_difficulty := 5.0
var approach_rate := -1.0
## [General] SampleSet: Normal, Soft or Drum. Picks the skin hit sound.
var sample_set := "Soft"
var timing_points: Array[TimingPoint] = []
## Sorted by time, ready for the gameplay scene.
var hit_objects: Array[HitObject] = []


## Parses the .osu file at file_path. Returns null if it can't be read or
## isn't a mania or standard map.
static func from_file(file_path: String) -> Beatmap:
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		push_error("Could not read beatmap %s (error %d)." % [file_path, FileAccess.get_open_error()])
		return null
	var lines := text.split("\n")
	var map: Beatmap
	match _read_mode(lines):
		MODE_STANDARD:
			map = StandardBeatmap.new()
		MODE_MANIA:
			map = ManiaBeatmap.new()
		_:
			return null
	map.path = file_path
	map._parse(lines)
	return map


## The mode decides which subclass parses the file, so find it first.
static func _read_mode(lines: PackedStringArray) -> int:
	for line in lines:
		if line.begins_with("Mode:"):
			return line.get_slice(":", 1).to_int()
	return MODE_STANDARD


func _parse(lines: PackedStringArray) -> void:
	var section := ""
	var combo_index := 0
	var combo_number := 0
	for raw: String in lines:
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		if line.begins_with("["):
			section = line
			continue
		match section:
			"[General]", "[Metadata]", "[Difficulty]":
				var colon := line.find(":")
				if colon != -1:
					_set_field(line.left(colon).strip_edges(), line.substr(colon + 1).strip_edges())
			"[Events]":
				# Background line: 0,0,"bg.jpg",xOffset,yOffset
				var parts := line.split(",")
				if parts[0] == "0" and parts.size() >= 3:
					background = parts[2].trim_prefix("\"").trim_suffix("\"")
			"[TimingPoints]":
				_parse_timing_point(line.split(","))
			"[HitObjects]":
				# x,y,time,type,hitSound,objectParams...,hitSample
				var parts := line.split(",")
				if parts.size() < 5:
					continue
				var obj := _parse_hit_object(parts)
				if obj:
					var flags := parts[3].to_int()
					if not hit_objects.is_empty() and flags & 4:
						combo_index += 1 + ((flags >> 4) & 7)
						combo_number = 0
					combo_number += 1
					obj.combo_index = combo_index
					obj.combo_number = combo_number
					hit_objects.append(obj)
	if approach_rate < 0.0:
		approach_rate = overall_difficulty # Old maps have no ApproachRate.
	hit_objects.sort_custom(func(a: HitObject, b: HitObject) -> bool: return a.time < b.time)


## time,beatLength,meter,sampleSet,sampleIndex,volume,uninherited,effects
func _parse_timing_point(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		return
	var point := TimingPoint.new()
	point.time = parts[0].to_float() / 1000.0
	var beat_length := parts[1].to_float()
	if parts.size() < 7 or parts[6] == "1":
		point.beat_length = beat_length
	else:
		# Inherited points store -100 / velocity in the beat length field.
		point.uninherited = false
		if not timing_points.is_empty():
			point.beat_length = timing_points.back().beat_length
		point.slider_velocity = clampf(-100.0 / beat_length, 0.1, 10.0)
	timing_points.append(point)


## The timing point in effect at song time t.
func timing_at(t: float) -> TimingPoint:
	# ponytail: linear scan per lookup, binary search if long maps load slowly.
	for i in range(timing_points.size() - 1, -1, -1):
		if timing_points[i].time <= t:
			return timing_points[i]
	return timing_points[0] if not timing_points.is_empty() else TimingPoint.new()


## Decodes the [Events] background image, or returns null if the map has none.
func load_background() -> Texture2D:
	var file := path.get_base_dir().path_join(background)
	if background.is_empty() or not FileAccess.file_exists(file):
		return null
	# beatmaps/ is not imported, so decode the file directly. Maps often name PNGs .jpg,
	# so trust the PNG signature over the extension.
	var bytes := FileAccess.get_file_as_bytes(file)
	var image := Image.new()
	var png := bytes.slice(0, 4) == PackedByteArray([0x89, 0x50, 0x4E, 0x47])
	var err := image.load_png_from_buffer(bytes) if png else image.load_jpg_from_buffer(bytes)
	return ImageTexture.create_from_image(image) if err == OK else null


## The uninherited timing point in effect at song time t: its time is where beats start.
func beat_at(t: float) -> TimingPoint:
	var beat: TimingPoint = null
	for point in timing_points:
		if point.time > t and beat != null:
			break
		if point.uninherited:
			beat = point
	return beat if beat != null else TimingPoint.new()


func _set_field(key: String, value: String) -> void:
	match key:
		"AudioFilename": audio_filename = value
		"AudioLeadIn": audio_lead_in = value.to_float() / 1000.0
		"Mode": mode = value.to_int()
		"Title": title = value
		"Artist": artist = value
		"Creator": creator = value
		"Version": version = value
		"HPDrainRate": hp_drain = value.to_float()
		"CircleSize": circle_size = value.to_float()
		"OverallDifficulty": overall_difficulty = value.to_float()
		"ApproachRate": approach_rate = value.to_float()
		"SampleSet": sample_set = value


## Turns one [HitObjects] line, already split on commas, into a HitObject.
## Return null to skip the line.
func _parse_hit_object(_parts: PackedStringArray) -> HitObject:
	return null
