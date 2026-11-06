extends RefCounted
## Maps a song for Standard or Mania with Mapperatorinator, a local AI mapper (see third_party/README.md),
## run by tools/mapperatorinator_run.py in its own process so the game keeps going. start
## launches it; the caller polls OS.is_process_running and reads progress() meanwhile.

const DIR := "res://third_party/Mapperatorinator"
const RUNNER := "res://tools/mapperatorinator_run.py"
## The job the runner reads, and the log it writes and progress() tails.
const JOB := "user://mapperatorinator_job.json"
const LOG := "user://mapperatorinator.log"
const GENERATOR := preload("res://scripts/beatmap/beatmap_generator.gd")


## Starts mapping song (a BeatmapGenerator.prepare_set result) with Hydra overrides plus
## config_name ("v32-mini" or "v32"), named version. overrides.gamemode picks the mode
## (Beatmap.MODE_STANDARD or MODE_MANIA). Returns {error, pid, out}: out is the
## .osu it will write, which only exists once the run has succeeded.
static func start(song: Dictionary, version: String, overrides: Dictionary) -> Dictionary:
	var dir := ProjectSettings.globalize_path(DIR)
	var python := dir.path_join(".venv/Scripts/python.exe" if OS.get_name() == "Windows" else ".venv/bin/python")
	var runner := ProjectSettings.globalize_path(RUNNER)
	for need: String in [dir.path_join("inference.py"), python, runner]:
		if not FileAccess.file_exists(need):
			return {error = "Mapperatorinator isn't set up (missing %s). See third_party/README.md." % need}
	if overrides.get("gamemode") not in [Beatmap.MODE_STANDARD, Beatmap.MODE_MANIA]:
		return {error = "Mapperatorinator needs gamemode %d or %d, not %s" % [Beatmap.MODE_STANDARD, Beatmap.MODE_MANIA, overrides.get("gamemode")]}
	var settings := overrides.duplicate()
	var config: String = settings.config_name
	settings.erase("config_name")
	settings.merge({title = song.title, artist = song.artist, version = version}, true)
	var out := ProjectSettings.globalize_path(song.path.path_join(GENERATOR.osu_name(song, version)))
	# A map left from an earlier run would read as this one's success.
	DirAccess.remove_absolute(out)
	var job := {
		mapper_dir = dir,
		config_name = config,
		audio = ProjectSettings.globalize_path(song.path.path_join(song.audio_name)),
		out = out,
		log = ProjectSettings.globalize_path(LOG),
		overrides = settings,
	}
	var file := FileAccess.open(JOB, FileAccess.WRITE)
	if file == null:
		return {error = "Could not write %s (error %d)" % [JOB, FileAccess.get_open_error()]}
	file.store_string(JSON.stringify(job, "\t"))
	file.close()
	# An old log would show the last run's progress until this one starts writing.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	var pid := OS.create_process(python, [runner, ProjectSettings.globalize_path(JOB)])
	if pid == -1:
		return {error = "Could not start %s" % python}
	return {error = "", pid = pid, out = out}


## The run's latest step from its log, with tqdm's percentage when a bar is going, e.g.
## "Generating map  42%"; on failure, its last line is the runner's "ERROR: …".
static func progress() -> String:
	var stage := ""
	var bar := ""
	# tqdm redraws its bar after a \r, so each redraw becomes a line.
	for line in FileAccess.get_file_as_string(LOG).replace("\r", "\n").split("\n", false):
		var percent := line.get_slice("%|", 0).strip_edges()
		if line.contains("%|") and percent.is_valid_int():
			bar = percent + "%"
		elif not line.strip_edges().is_empty():
			stage = line.strip_edges()
			bar = ""
	return (stage + "  " + bar).strip_edges()
