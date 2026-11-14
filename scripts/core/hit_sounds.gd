class_name HitSounds
extends AudioStreamPlayer
## Plays osu! hitsounds through one polyphonic voice pool on the SFX bus. Samples are
## decoded once in setup: the map folder's own (normal|soft|drum-hit(normal|whistle|
## finish|clap)[index].wav/ogg/mp3), else the bundled default set. Each
## hit plays the normal sound plus its whistle, finish and clap additions, at the sample
## volume times Settings audio/hitsound_volume.

## Timing point sample set numbers to file name prefixes; 0 means inherit.
const SETS := ["", "normal", "soft", "drum"]
## hitSound flags to their addition sample.
const ADDITIONS := {2: "whistle", 4: "finish", 8: "clap"}
const KINDS := ["normal", "whistle", "finish", "clap"]
const BUNDLED := "res://assets/sounds/hitsounds/"
## Voices that can overlap: fast streams with additions stack several per hit.
const VOICES := 32

var _map: Beatmap
## Map folder samples by name without extension (soft-hitclap2); null for an empty file,
## which osu! maps use to mute a sound.
var _custom := {}
## Bundled sample by name (soft-hitclap).
var _defaults := {}
var _playback: AudioStreamPlaybackPolyphonic


## Loads every sample for map; call before adding to the tree.
func setup(map: Beatmap) -> void:
	_map = map
	bus = &"SFX"
	var pool := AudioStreamPolyphonic.new()
	pool.polyphony = VOICES
	stream = pool
	var folder := map.path.get_base_dir()
	var dir := DirAccess.open(folder)
	if dir:
		var pattern := RegEx.create_from_string("^(normal|soft|drum)-hit(normal|whistle|finish|clap)\\d*$")
		for file in dir.get_files():
			var sample := file.get_basename().to_lower()
			if file.get_extension().to_lower() in ["wav", "ogg", "mp3"] and pattern.search(sample):
				_custom[sample] = Beatmap.load_audio_file(folder.path_join(file))
	for set_name: String in SETS.slice(1):
		for kind: String in KINDS:
			var sample := "%s-hit%s" % [set_name, kind]
			_defaults[sample] = load(BUNDLED + sample + ".wav")


func _ready() -> void:
	play()
	_playback = get_stream_playback()


## Plays object's sounds: a circle, mania note or spinner as it is hit or cleared.
func play_hit(object: HitObject) -> void:
	var at := object.end_time if object is Spinner else object.time
	_play(object, at, object.hit_sound, Vector2i(object.normal_set, object.addition_set))


## Plays a slider edge's sounds: 0 the head, then each repeat, slides the tail.
func play_edge(slider: HitSlider, edge: int) -> void:
	var sound := slider.edge_sounds[edge] if edge < slider.edge_sounds.size() else slider.hit_sound
	var sets := slider.edge_sets[edge] if edge < slider.edge_sets.size() else Vector2i(slider.normal_set, slider.addition_set)
	_play(slider, slider.edge_time(edge), sound, sets)


## osu!'s rules: unset sets, index and volume come from the timing point at song time at
## (its set, unset, from [General] SampleSet), and the addition set follows the normal one.
func _play(object: HitObject, at: float, sound: int, sets: Vector2i) -> void:
	if _playback == null:
		return
	var point := _map.timing_at(at)
	var normal := sets.x if sets.x else point.sample_set if point.sample_set else _map.sample_set_id()
	var addition := sets.y if sets.y else normal
	var index := object.sample_index if object.sample_index else point.sample_index
	var volume := (object.volume if object.volume else point.volume) / 100.0
	volume *= clampf(float(Settings.get_value("audio", "hitsound_volume")), 0.0, 1.0)
	if volume <= 0.0:
		return
	_voice(SETS[normal], "normal", index, volume)
	for flag: int in ADDITIONS:
		if sound & flag:
			_voice(SETS[addition], ADDITIONS[flag], index, volume)


## Index 0 is the default sound, 1 the map's unnumbered file and 2 up the numbered one;
## a map sample that is missing falls back to the default.
func _voice(set_name: String, kind: String, index: int, volume: float) -> void:
	var base := "%s-hit%s" % [set_name, kind]
	var custom := base + (str(index) if index > 1 else "")
	var sample: AudioStream = _defaults.get(base)
	if index > 0 and _custom.has(custom):
		sample = _custom[custom]
	if sample:
		_playback.play_stream(sample, 0.0, linear_to_db(volume))

