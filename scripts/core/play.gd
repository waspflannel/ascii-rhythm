extends Control
## Shared beatmap simulation: parse, play audio, spawn views, and route player input.

signal back_requested

const CIRCLE := preload("res://scenes/hit_objects/hit_circle_view.tscn")
const SLIDER := preload("res://scenes/hit_objects/slider_view.tscn")
const SPINNER := preload("res://scenes/hit_objects/spinner_view.tscn")
const NOTE := preload("res://scenes/hit_objects/mania_note_view.tscn")

@export var mode_name := "Play"
## Leave empty to pick a local matching map (Normal is preferred for the demo).
@export_file("*.osu") var beatmap_path := ""

var _skin := RhythmSkin.from_file("res://assets/skins/neptune/skin.ini")
var beatmap: Beatmap
var _live: Array[HitObjectView] = []
var _next_object := 0
var _preempt := 1.2
var _lead_in := 2.0
var _running := false
var _judgements := [0, 0, 0, 0, 0]
var _completed := 0
var _pressed: Dictionary = {}
var _lane_keys: Array = []
var _hit_sound: AudioStreamPlayer

@onready var _field: Node2D = $Playfield
@onready var _music: AudioStreamPlayer = $Music
@onready var _map_value: Label = $UI/Details/MapValue
@onready var _time_value: Label = $UI/Details/TimeValue
@onready var _objects_value: Label = $UI/Stats/ObjectsValue
@onready var _judgement_values: Array[Label] = [$UI/Stats/PerfectValue, $UI/Stats/GreatValue, $UI/Stats/GoodValue, $UI/Stats/MissValue]
@onready var _cursor: Sprite2D = $Playfield/Cursor


func _ready() -> void:
    $UI/BackButton.pressed.connect(back_requested.emit)
    $UI/BackButton.focus_mode = Control.FOCUS_NONE
    $UI/ModeLabel.text = mode_name
    resized.connect(_layout_playfield)
    _music.finished.connect(_on_music_finished)
    var mode := Beatmap.MODE_MANIA if mode_name == "Mania" else Beatmap.MODE_STANDARD
    if not beatmap_path.is_empty():
        beatmap = Beatmap.from_file(beatmap_path)
        if beatmap != null and beatmap.mode != mode:
            beatmap = null
    else:
        var paths := _map_paths("res://beatmaps")
        paths.sort()
        for path in paths:
            var candidate := Beatmap.from_file(path)
            if candidate == null or candidate.mode != mode or candidate.hit_objects.is_empty():
                continue
            if beatmap == null or candidate.version.to_lower() == "normal":
                beatmap = candidate
            if candidate.version.to_lower() == "normal":
                break
    if beatmap == null or beatmap.hit_objects.is_empty():
        $UI/MissingMapLabel.show()
        return
    _music.stream = _load_audio(beatmap.path.get_base_dir().path_join(beatmap.audio_filename))
    if _music.stream == null or _music.stream.get_length() <= 0.0:
        $UI/AudioErrorLabel.show()
        return
    _map_value.text = "%s [%s]" % [beatmap.title, beatmap.version]
    _music.volume_linear = clampf(float(Settings.get_value("audio", "volume")), 0.0, 1.0)
    _hit_sound = AudioStreamPlayer.new()
    _hit_sound.stream = _skin.hit_sound(beatmap.sample_set)
    _hit_sound.volume_linear = _music.volume_linear * 0.5
    # Built-in voice pool: rapid hits overlap instead of cutting each other off.
    _hit_sound.max_polyphony = 8
    add_child(_hit_sound)
    if beatmap.mode == Beatmap.MODE_STANDARD:
        var ar := beatmap.approach_rate
        _preempt = 1.2 - 0.75 * (ar - 5.0) / 5.0 if ar >= 5.0 else 1.2 + 0.6 * (5.0 - ar) / 5.0
    else:
        _preempt = 600.0 / 800.0
        _lane_keys = _keys_for_lanes(int(beatmap.circle_size))
        _add_lanes()
    _lead_in = maxf(2.0, beatmap.audio_lead_in)
    _layout_playfield()
    _running = true
    _advance(-_lead_in)


func _process(delta: float) -> void:
    if not _running:
        return
    if _lead_in > 0.0:
        _lead_in = maxf(0.0, _lead_in - delta)
        if _lead_in == 0.0:
            SongClock.start(_music)
        else:
            _advance(-_lead_in)
            return
    _advance(SongClock.get_time())


func _advance(t: float) -> void:
    while _next_object < beatmap.hit_objects.size() and beatmap.hit_objects[_next_object].time - _preempt <= t:
        _spawn(beatmap.hit_objects[_next_object])
        _next_object += 1
    _cursor.visible = beatmap.mode == Beatmap.MODE_STANDARD
    _cursor.position = _field.get_local_mouse_position()
    for view in _live.duplicate():
        view.holding = _is_holding(view)
        if not view.finished:
            view.update_view(t)
        if view.finished:
            _completed += 1
            _live.erase(view)
            view.play_exit()
    _time_value.text = "%.1f" % t
    _objects_value.text = "%d/%d" % [_completed, beatmap.hit_objects.size()]
    for i in _judgement_values.size():
        _judgement_values[i].text = str(_judgements[i + 1])


func _spawn(object: HitObject) -> void:
    var scene: PackedScene = CIRCLE
    if object is HitSlider:
        scene = SLIDER
    elif object is Spinner:
        scene = SPINNER
    elif object is ManiaNote:
        scene = NOTE
    var view := scene.instantiate() as HitObjectView
    view.setup(object, beatmap)
    if view is HitCircleView:
        view.combo_color = _skin.combo_colors[object.combo_index % _skin.combo_colors.size()]
    if view is SliderView:
        view.track_color = _skin.slider_track
        view.border_color = _skin.slider_border
        view.tint_ball = _skin.tint_slider_ball
    view.judged.connect(_on_judged)
    _field.add_child(view)
    _live.append(view)
    if object is HitCircle or object is HitSlider or object is Spinner:
        # Earlier objects render above later ones, including each complete slider track.
        _field.move_child(view, 0)
    if object is ManiaNote:
        view.position.x = (object.column + 0.5) * 64.0


func _on_judged(judgement: HitObjectView.Judgement) -> void:
    _judgements[judgement] += 1
    if judgement != HitObjectView.Judgement.MISS:
        _hit_sound.play()


func _layout_playfield() -> void:
    if beatmap == null:
        return
    var available := Vector2(maxf(size.x - 32.0, 1.0), maxf(size.y - 136.0, 1.0))
    var world := Vector2(512, 384) if beatmap.mode == Beatmap.MODE_STANDARD else Vector2(beatmap.circle_size * 64.0, 600)
    var fit := minf(available.x / world.x, available.y / world.y)
    _field.scale = Vector2.ONE * fit
    _field.position = Vector2((size.x - world.x * fit) / 2.0, 88.0)
    if beatmap.mode == Beatmap.MODE_MANIA:
        _field.position.y += 560.0 * fit


func _add_lanes() -> void:
    var width := beatmap.circle_size * 64.0
    for i in int(beatmap.circle_size) + 1:
        var line := Line2D.new()
        line.points = PackedVector2Array([Vector2(i * 64, -560), Vector2(i * 64, 24)])
        line.width = 2.0
        line.default_color = Color(0.25, 0.25, 0.3)
        _field.add_child(line)
    var hit_line := Line2D.new()
    hit_line.points = PackedVector2Array([Vector2.ZERO, Vector2(width, 0)])
    hit_line.width = 3.0
    _field.add_child(hit_line)


func _on_music_finished() -> void:
    _advance(SongClock.get_time())
    # Audio has ended: objects beyond it cannot receive player input.
    while _next_object < beatmap.hit_objects.size():
        _spawn(beatmap.hit_objects[_next_object])
        _next_object += 1
    for view in _live:
        view.miss()
        _completed += 1
        view.play_exit()
    _live.clear()
    _objects_value.text = "%d/%d" % [_completed, beatmap.hit_objects.size()]
    for i in _judgement_values.size():
        _judgement_values[i].text = str(_judgements[i + 1])
    _running = false
    $UI/CompleteLabel.show()


func _exit_tree() -> void:
    SongClock.stop()


func _map_paths(folder: String) -> Array[String]:
    var result: Array[String] = []
    var dir := DirAccess.open(folder)
    if dir == null:
        return result
    for file in dir.get_files():
        if file.get_extension().to_lower() == "osu":
            result.append(folder.path_join(file))
    for child in dir.get_directories():
        result.append_array(_map_paths(folder.path_join(child)))
    return result


func _load_audio(path: String) -> AudioStream:
    if not FileAccess.file_exists(path):
        return null
    match path.get_extension().to_lower():
        "mp3":
            var stream := AudioStreamMP3.new()
            stream.data = FileAccess.get_file_as_bytes(path)
            return stream
        "ogg":
            return AudioStreamOggVorbis.load_from_file(path)
        "wav":
            return AudioStreamWAV.load_from_file(path)
    return null


func _keys_for_lanes(count: int) -> Array:
    match count:
        4: return [KEY_D, KEY_F, KEY_J, KEY_K]
        7: return [KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K, KEY_L]
    # Other osu!mania key counts get one distinct physical key per lane.
    return [KEY_A, KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_U, KEY_I, KEY_O, KEY_P].slice(0, count)


func _is_holding(view: HitObjectView) -> bool:
    if view.data is ManiaNote:
        return _pressed.has(_lane_keys[view.data.column])
    return not _pressed.is_empty()


func _input(event: InputEvent) -> void:
    if not _running:
        return
    var code := 0
    var down := false
    if event is InputEventKey:
        if event.echo:
            return
        code = event.physical_keycode
        down = event.pressed
        var keys: Array = _lane_keys if beatmap.mode == Beatmap.MODE_MANIA else [KEY_Z, KEY_X]
        if not keys.has(code):
            return
    elif event is InputEventMouseButton and beatmap.mode == Beatmap.MODE_STANDARD:
        if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            return
        if event.pressed and $UI/BackButton.get_global_rect().has_point(event.position):
            return
        code = -event.button_index
        down = event.pressed
    elif event is InputEventMouseMotion:
        if _lead_in == 0.0:
            _advance(SongClock.get_time())
        return
    else:
        return
    get_viewport().set_input_as_handled()
    if down == _pressed.has(code):
        return
    var t := -_lead_in if _lead_in > 0.0 else SongClock.get_time()
    # Advance with the old held state before applying this event's transition.
    _advance(t)
    if down:
        _pressed[code] = true
    else:
        _pressed.erase(code)
    for view in _live:
        view.holding = _is_holding(view)
        if view.finished:
            continue
        if view.data is ManiaNote and _lane_keys[view.data.column] != code:
            continue
        if down:
            if view.press(t):
                # A slider head hit gives no judgement until the slider ends, so sound it here.
                if view is SliderView and not view.finished:
                    _hit_sound.play()
                break
        elif not view.holding:
            view.release(t)
    _advance(t)


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _running:
        _pressed.clear()
        var t := -_lead_in if _lead_in > 0.0 else SongClock.get_time()
        for view in _live:
            view.holding = false
            view.release(t)
