class_name BeatmapGenerator
extends RefCounted
## Makes playable .osu maps from a song, offline: decodes the audio, finds onsets where its
## energy jumps, estimates the tempo, then puts Mania 4K notes or Standard circles on the
## strongest onsets for the chosen star rating. Writes them with a copy of the song into a
## set folder under beatmaps/, where song select finds them.

## The folder song select scans.
const LIBRARY := "res://beatmaps"
## mix_audio rate scale: the song is read at a quarter of the mix rate, plenty for energy.
const DECIMATE := 4.0
## Seconds per energy frame.
const HOP := 0.01
## Fewer onsets than this and the song is too quiet or too short to map.
const MIN_ONSETS := 10
## The 512x384 Standard playfield minus a circle radius margin.
const FIELD := Rect2(40, 40, 432, 304)
const KEYS := 4
## One row per star band, from its lowest star: the fraction of onsets kept (strongest
## first), the shortest gap between notes (beat / gap), Mania chord chances (2 and 3
## notes), hold chance and whether a column may repeat, the Standard jump in osu! pixels,
## and the map's difficulty settings. The star itself is only a label in the version.
const BANDS: Array[Dictionary] = [
	{from = 0.0, keep = 0.35, gap = 1, chord2 = 0.0, chord3 = 0.0, hold = 0.10, jacks = false, jump = 80.0, cs = 3.5, ar = 5.0, od = 4.0, hp = 3.0},
	{from = 3.0, keep = 0.55, gap = 2, chord2 = 0.10, chord3 = 0.0, hold = 0.15, jacks = false, jump = 120.0, cs = 4.0, ar = 7.0, od = 6.0, hp = 4.0},
	{from = 5.0, keep = 0.75, gap = 4, chord2 = 0.25, chord3 = 0.0, hold = 0.15, jacks = false, jump = 160.0, cs = 4.0, ar = 8.5, od = 7.5, hp = 5.0},
	{from = 7.0, keep = 0.90, gap = 8, chord2 = 0.35, chord3 = 0.10, hold = 0.20, jacks = false, jump = 200.0, cs = 4.2, ar = 9.3, od = 8.5, hp = 6.0},
	{from = 8.5, keep = 1.00, gap = 8, chord2 = 0.45, chord3 = 0.20, hold = 0.20, jacks = true, jump = 240.0, cs = 4.5, ar = 9.8, od = 9.0, hp = 7.0},
]


## Writes a map of source for each chosen mode. Returns {error, folder, paths}: error is
## empty on success, folder is the set folder's name and paths the written .osu files.
static func generate(source: String, mania: bool, standard: bool, stars: float) -> Dictionary:
	var result := {error = "", folder = "", paths = [] as Array[String]}
	var stream := Beatmap.load_audio_file(source)
	if stream == null or stream.get_length() <= 0.0:
		result.error = "Could not decode %s" % source.get_file()
		return result
	var analysis := _analyse(stream)
	if analysis.onsets.size() < MIN_ONSETS:
		result.error = "Too few beats found in %s" % source.get_file()
		return result
	var song := prepare_set(source)
	result.folder = song.folder
	if not song.error.is_empty():
		result.error = song.error
		return result
	var knobs := _knobs(stars)
	var times := _pick(analysis, knobs)
	var rng := RandomNumberGenerator.new()
	for mode: int in ([Beatmap.MODE_MANIA] if mania else []) + ([Beatmap.MODE_STANDARD] if standard else []):
		var mode_name := "Mania" if mode == Beatmap.MODE_MANIA else "Standard"
		# Seeded from the title, so the same song and stars give the same map.
		rng.seed = hash(song.title)
		var text := _header(song.title, song.artist, song.audio_name, mode, "AI %.1f★ %s" % [stars, mode_name], analysis, knobs)
		if mode == Beatmap.MODE_MANIA:
			text += _mania_objects(times, analysis.bpm, knobs, rng)
		else:
			text += _standard_objects(times, analysis.bpm, knobs, rng)
		var path: String = song.path.path_join(osu_name(song, "AI %.1f %s" % [stars, mode_name]))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			result.error = "Could not write %s (error %d)" % [path.get_file(), FileAccess.get_open_error()]
			return result
		file.store_string(text)
		result.paths.append(path)
	return result


## Makes source's set folder under beatmaps/ and copies the song into it. Returns {error,
## folder (its name), path (res://), audio_name, title, artist}; "Artist - Title" file
## names give both, others are all title.
static func prepare_set(source: String) -> Dictionary:
	var stem := source.get_file().get_basename()
	var parts := stem.split(" - ", true, 1)
	var song := {
		error = "",
		folder = ("%s (Rhythm AI)" % stem).validate_filename(),
		audio_name = "audio." + source.get_extension().to_lower(),
		artist = parts[0].strip_edges() if parts.size() == 2 else "Unknown",
		title = parts[-1].strip_edges(),
	}
	song.path = LIBRARY.path_join(song.folder)
	var audio := ProjectSettings.globalize_path(song.path.path_join(song.audio_name))
	var error := DirAccess.make_dir_recursive_absolute(song.path)
	# Regenerating from the set's own copy must not copy the file onto itself.
	if error == OK and audio.replace("\\", "/").nocasecmp_to(source.replace("\\", "/")) != 0:
		error = DirAccess.copy_absolute(source, audio)
	if error != OK:
		song.error = "Could not write to beatmaps/%s (error %d)" % [song.folder, error]
	return song


## A map's .osu file name in song's set, for its difficulty name.
static func osu_name(song: Dictionary, version: String) -> String:
	return ("%s - %s (Rhythm AI) [%s].osu" % [song.artist, song.title, version]).validate_filename()


## Decodes the song and returns {onsets (s), strength, bpm, offset (s), length (s)}.
# ponytail: energy-flux onsets + autocorrelation BPM; swap in spectral flux / beat tracking if maps feel off-beat.
static func _analyse(stream: AudioStream) -> Dictionary:
	var length := stream.get_length()
	var rate := AudioServer.get_mix_rate() / DECIMATE
	var hop := int(rate * HOP)
	# The real hop length, as HOP rounds to whole frames.
	var seconds := hop / rate
	var limit := int(length * rate) + 8192
	# Energy of each HOP of the song, decoded straight from a playback, no player needed.
	var energy := PackedFloat32Array()
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var sum := 0.0
	var count := 0
	var read := 0
	while read < limit:
		var chunk := playback.mix_audio(DECIMATE, 8192)
		if chunk.is_empty():
			break
		read += chunk.size()
		for frame: Vector2 in chunk:
			var mono := frame.x + frame.y
			sum += mono * mono
			count += 1
			if count == hop:
				energy.append(sum)
				sum = 0.0
				count = 0
		if not playback.is_playing():
			break
	playback.stop()
	# Flux: how much the energy rose since the last hop.
	var n := energy.size()
	var flux := PackedFloat32Array()
	flux.resize(n)
	var peak := 0.0
	for k in range(1, n):
		flux[k] = maxf(0.0, energy[k] - energy[k - 1])
		peak = maxf(peak, flux[k])
	var running := PackedFloat64Array([0.0])
	for value in flux:
		running.append(running[-1] + value)
	# Onsets: local flux peaks well above the flux around them.
	var onsets := PackedFloat32Array()
	var strength := PackedFloat32Array()
	for k in n:
		if flux[k] <= 0.0 or flux[k] < 0.05 * peak:
			continue
		var is_peak := true
		for j in range(maxi(0, k - 3), mini(n, k + 4)):
			if flux[j] > flux[k] or (j < k and flux[j] == flux[k]):
				is_peak = false
				break
		var low := maxi(0, k - 50)
		var high := mini(n, k + 51)
		if is_peak and flux[k] >= 2.0 * (running[high] - running[low]) / (high - low):
			onsets.append(k * seconds)
			strength.append(flux[k])
	# Tempo: the flux autocorrelation peak between 300 and 1000 ms (200 to 60 BPM).
	var best := 0
	var scores := {}
	for candidate in range(roundi(0.3 / seconds), mini(roundi(1.0 / seconds) + 1, n)):
		var score := 0.0
		for k in n - candidate:
			score += flux[k] * flux[k + candidate]
		scores[candidate] = score
		if best == 0 or score > scores[best]:
			best = candidate
	var lag := 0.5 / seconds
	if best > 0:
		lag = best
		if scores.has(best - 1) and scores.has(best + 1):
			var a: float = scores[best - 1]
			var b: float = scores[best]
			var c: float = scores[best + 1]
			if a - 2.0 * b + c != 0.0:
				lag += 0.5 * (a - c) / (a - 2.0 * b + c)
	var bpm := 60.0 / (lag * seconds)
	while bpm < 85.0:
		bpm *= 2.0
	while bpm > 175.0:
		bpm /= 2.0
	# Offset: the beat phase whose hops carry the most flux.
	lag = 60.0 / bpm / seconds
	var phase := 0
	var phase_score := -1.0
	for p in int(lag):
		var score := 0.0
		var at := float(p)
		while at < n:
			score += flux[int(at)]
			at += lag
		if score > phase_score:
			phase = p
			phase_score = score
	return {onsets = onsets, strength = strength, bpm = bpm, offset = phase * seconds, length = length}


## The BANDS row for stars.
static func _knobs(stars: float) -> Dictionary:
	for i in range(BANDS.size() - 1, -1, -1):
		if stars >= BANDS[i].from:
			return BANDS[i]
	return BANDS[0]


## Note times in whole ms: the strongest onsets the band keeps, in time order, without any
## closer than its shortest gap to the note before.
static func _pick(analysis: Dictionary, knobs: Dictionary) -> PackedInt32Array:
	var onsets: PackedFloat32Array = analysis.onsets
	var strength: PackedFloat32Array = analysis.strength
	var order := range(onsets.size())
	order.sort_custom(func(a: int, b: int) -> bool: return strength[a] > strength[b])
	order = order.slice(0, ceili(order.size() * knobs.keep))
	order.sort()
	var min_gap: float = 60000.0 / analysis.bpm / knobs.gap
	var times := PackedInt32Array()
	for i: int in order:
		var t := roundi(onsets[i] * 1000.0)
		if times.is_empty() or t - times[-1] >= min_gap:
			times.append(t)
	return times


## The .osu sections before [HitObjects]' lines. Mode: starts its line, as
## Beatmap._read_mode needs.
static func _header(title: String, artist: String, audio_name: String, mode: int, version: String, analysis: Dictionary, knobs: Dictionary) -> String:
	var lines := PackedStringArray([
		"osu file format v14",
		"",
		"[General]",
		"AudioFilename: %s" % audio_name,
		"AudioLeadIn: 0",
		"PreviewTime: %d" % int(analysis.length * 0.4 * 1000.0),
		"Mode: %d" % mode,
		"SampleSet: Soft",
		"",
		"[Metadata]",
		"Title:%s" % title,
		"Artist:%s" % artist,
		"Creator:Rhythm AI",
		"Version:%s" % version,
		"",
		"[Difficulty]",
		"HPDrainRate:%s" % knobs.hp,
		"CircleSize:%s" % (KEYS if mode == Beatmap.MODE_MANIA else knobs.cs),
		"OverallDifficulty:%s" % knobs.od,
		"ApproachRate:%s" % knobs.ar,
		"SliderMultiplier:1.4",
		"SliderTickRate:1",
		"",
		"[Events]",
		"",
		"[TimingPoints]",
		"%d,%s,4,2,0,60,1,0" % [roundi(analysis.offset * 1000.0), 60000.0 / analysis.bpm],
		"",
		"[HitObjects]",
		"",
	])
	return "\n".join(lines)


## Mania 4K lines: each note moves off the last note's column (unless the band allows
## jacks), may grow into a chord, and may hold until a quarter beat before the next note,
## so no column ever has two notes at once.
static func _mania_objects(times: PackedInt32Array, bpm: float, knobs: Dictionary, rng: RandomNumberGenerator) -> String:
	var beat := 60000.0 / bpm
	var lines := PackedStringArray()
	var last := -1
	for i in times.size():
		var column := rng.randi_range(0, KEYS - 1)
		while column == last and not knobs.jacks:
			column = rng.randi_range(0, KEYS - 1)
		last = column
		var columns := [column]
		var roll := rng.randf()
		var extra := 2 if roll < knobs.chord3 else 1 if roll < knobs.chord3 + knobs.chord2 else 0
		while columns.size() < 1 + extra:
			var more := rng.randi_range(0, KEYS - 1)
			if more not in columns:
				columns.append(more)
		var next := times[i + 1] if i + 1 < times.size() else -1
		var hold: bool = next >= 0 and next - times[i] >= beat and rng.randf() < knobs.hold
		for c: int in columns:
			var x := int((c + 0.5) * 512 / KEYS)
			if hold and c == column:
				lines.append("%d,192,%d,128,0,%d:0:0:0:0:" % [x, times[i], roundi(next - beat / 4.0)])
			else:
				lines.append("%d,192,%d,1,0,0:0:0:0:" % [x, times[i]])
	return "\n".join(lines) + "\n"


## Standard circle lines: each a jump from the last (shorter for close notes) at a random
## angle, kept in FIELD, with a new combo every 8 circles or after a long gap.
static func _standard_objects(times: PackedInt32Array, bpm: float, knobs: Dictionary, rng: RandomNumberGenerator) -> String:
	var beat := 60000.0 / bpm
	var lines := PackedStringArray()
	var at := FIELD.get_center()
	var combo := 0
	for i in times.size():
		var gap := times[i] - times[i - 1] if i > 0 else 0
		if i > 0:
			var step: Vector2 = Vector2.from_angle(rng.randf() * TAU) * knobs.jump * clampf(gap / beat, 0.5, 1.0)
			# Bounce off the edge rather than pile up on it.
			var next := at + step if FIELD.has_point(at + step) else at - step
			at = next.clamp(FIELD.position, FIELD.end)
		var new_combo := combo == 8 or gap > 2.0 * beat or i == 0
		if new_combo:
			combo = 0
		combo += 1
		lines.append("%d,%d,%d,%d,0,0:0:0:0:" % [roundi(at.x), roundi(at.y), times[i], 5 if new_combo else 1])
	return "\n".join(lines) + "\n"
