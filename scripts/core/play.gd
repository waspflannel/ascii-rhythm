extends Control
## Shared beatmap simulation: parse, play audio, spawn views, and route player input.

## Quit in the pause menu, or Esc without a playable map.
signal back_requested
signal retry_requested
## The HUD emits this once the run is over: failed, or every object judged / the song ended.
signal run_finished(score: RunScore)

const CIRCLE := preload("res://scenes/hit_objects/hit_circle_view.tscn")
const SLIDER := preload("res://scenes/hit_objects/slider_view.tscn")
const SPINNER := preload("res://scenes/hit_objects/spinner_view.tscn")
const NOTE := preload("res://scenes/hit_objects/mania_note_view.tscn")
## Default mania keys per key count, symmetric around the space bar.
const MANIA_KEYS := {
    1: [KEY_SPACE],
    2: [KEY_F, KEY_J],
    3: [KEY_F, KEY_SPACE, KEY_J],
    4: [KEY_D, KEY_F, KEY_J, KEY_K],
    5: [KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K],
    6: [KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L],
    7: [KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K, KEY_L],
    8: [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON],
    9: [KEY_A, KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON],
    10: [KEY_A, KEY_S, KEY_D, KEY_F, KEY_V, KEY_N, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON],
}
## Larger key counts take the first keys from this list.
const MANIA_EXTRA_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_U, KEY_I, KEY_O, KEY_P]
## osu!lazer scroll speed: notes take this many seconds / speed to fall to the judgement line.
const MANIA_SCROLL_TIME := 11.485

@export var mode_name := "Play"
## Leave empty to pick a local matching map (Normal is preferred for the demo).
@export_file("*.osu") var beatmap_path := ""

var _skin := RhythmSkin.from_file(SkinAssets.INI)
var beatmap: Beatmap
var _live: Array[HitObjectView] = []
var _next_object := 0
var _preempt := 1.2
var _lead_in := 2.0
var _running := false
## A map and its audio loaded, so Esc pauses instead of leaving.
var _playable := false
var _judgements: Array[int] = []
var _completed := 0
var _pressed: Dictionary = {}
var _lane_keys: Array = []
## Mania only: the keys, judgement line and lane flashes.
var _stage: ManiaStage
## Mania only: how fast notes fall, in stage pixels per second.
var _note_speed := 0.0
var _hit_sound: AudioStreamPlayer

@onready var _field: Node2D = $Playfield
@onready var _music: AudioStreamPlayer = $Music
@onready var _map_value: Label = $UI/Details/MapValue
@onready var _time_value: Label = $UI/Details/TimeValue
@onready var _objects_value: Label = $UI/Stats/ObjectsValue
@onready var _judgement_values: Array[Label] = [$UI/Stats/PerfectValue, $UI/Stats/GreatValue, $UI/Stats/GoodValue, $UI/Stats/MissValue]
@onready var _cursor: CursorView = $Playfield/Cursor
## Standard only: the layer above the dither filter that holds the cursor unless Settings
## draws it dithered; null when the cursor stays in the playfield.
var _overlay: CanvasLayer


func _ready() -> void:
    # Every mouse motion event reaches _input, so the cursor and hit tests use the latest
    # position instead of one merged per frame. Restored on exit for the menus.
    Input.use_accumulated_input = false
    _hide_os_cursor()
    if not Settings.get_value("cursor", "dithered"):
        # The dither filter covers the whole SubViewport, so a crisp cursor lives in the
        # root window's canvas instead, above it. Deferred: the root is not ours to edit
        # mid-ready.
        _overlay = CanvasLayer.new()
        _overlay.layer = 100
        get_tree().root.add_child.call_deferred(_overlay)
        _cursor.reparent.call_deferred(_overlay, false)
    $Pause.resumed.connect(_release_keys.bind(false))
    $Pause.resumed.connect(_hide_os_cursor)
    $Pause.retry_requested.connect(retry_requested.emit)
    $Pause.quit_requested.connect(back_requested.emit)
    $UI/ModeLabel.text = mode_name
    _judgements.resize(HitObjectView.Judgement.size())
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
    _music.stream = beatmap.load_audio()
    if _music.stream == null or _music.stream.get_length() <= 0.0:
        $UI/AudioErrorLabel.show()
        return
    _map_value.text = "%s [%s]" % [beatmap.title, beatmap.version]
    _hit_sound = AudioStreamPlayer.new()
    _hit_sound.stream = _skin.hit_sound(beatmap.sample_set)
    _hit_sound.bus = &"SFX"
    _hit_sound.volume_linear = 0.5
    # Built-in voice pool: rapid hits overlap instead of cutting each other off.
    _hit_sound.max_polyphony = 8
    add_child(_hit_sound)
    if beatmap.mode == Beatmap.MODE_STANDARD:
        var ar := beatmap.approach_rate
        _preempt = 1.2 - 0.75 * (ar - 5.0) / 5.0 if ar >= 5.0 else 1.2 + 0.6 * (5.0 - ar) / 5.0
    else:
        var keys := (beatmap as ManiaBeatmap).key_count()
        _lane_keys = MANIA_KEYS.get(keys, MANIA_EXTRA_KEYS.slice(0, keys))
        _stage = ManiaStage.new()
        _stage.setup(keys, _skin.mania_lights)
        _field.add_child(_stage)
        _set_scroll_speed(int(Settings.get_value("mania", "scroll_speed")))
    _lead_in = maxf(2.0, beatmap.audio_lead_in)
    _layout_playfield()
    _playable = true
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
    # The overlay is in window coordinates; the SubViewport fills the window from its corner.
    _cursor.position = get_viewport().get_mouse_position() if _overlay else _field.get_local_mouse_position()
    for view in _live.duplicate():
        view.holding = _is_holding(view)
        if not view.finished:
            view.update_view(t)
        if view.finished:
            _completed += 1
            _live.erase(view)
            view.play_exit()
    _time_value.text = "%.1f" % t
    _show_stats()


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
    if view is ManiaNoteView:
        view.scroll_speed = _note_speed
    view.judged.connect(_on_judged.bind(view))
    _field.add_child(view)
    _live.append(view)
    if object is HitCircle or object is HitSlider or object is Spinner:
        # Earlier objects render above later ones, including each complete slider track.
        _field.move_child(view, 0)
    if object is ManiaNote:
        view.position.x = (object.column + 0.5) * ManiaStage.COLUMN_WIDTH


func _on_judged(judgement: HitObjectView.Judgement, view: HitObjectView) -> void:
    _judgements[judgement] += 1
    if judgement != HitObjectView.Judgement.MISS:
        _hit_sound.play()
        if view.data is ManiaNote:
            _stage.flash(view.data.column)
    if view.data is ManiaNote:
        # A hit hold note head leaves the view unfinished until its tail is judged.
        _stage.set_holding(view.data.column, judgement != HitObjectView.Judgement.MISS and not view.finished)


func _layout_playfield() -> void:
    if beatmap == null:
        return
    if beatmap.mode == Beatmap.MODE_MANIA:
        # The stage fills the screen height, as osu!mania's 480 px tall layout does.
        var width := (beatmap as ManiaBeatmap).key_count() * ManiaStage.COLUMN_WIDTH
        var stage_scale := minf(size.y / ManiaStage.SCREEN_HEIGHT, size.x / width)
        _field.scale = Vector2.ONE * stage_scale
        _field.position = Vector2((size.x - width * stage_scale) / 2.0, ManiaStage.HIT_POSITION * stage_scale)
        return
    var available := Vector2(maxf(size.x - 32.0, 1.0), maxf(size.y - 136.0, 1.0))
    var world := Vector2(512, 384)
    var fit := minf(available.x / world.x, available.y / world.y)
    _field.scale = Vector2.ONE * fit
    _field.position = Vector2((size.x - world.x * fit) / 2.0, 88.0)


## Sets the mania scroll speed (1 to 40) for new and falling notes.
func _set_scroll_speed(speed: int) -> void:
    speed = clampi(speed, 1, 40)
    _preempt = MANIA_SCROLL_TIME / speed
    _note_speed = ManiaStage.HIT_POSITION / _preempt
    for view in _live:
        if view is ManiaNoteView:
            view.scroll_speed = _note_speed
    $UI/ModeLabel.text = "%s %dK  speed %d (F3/F4)" % [mode_name, _lane_keys.size(), speed]


## F3 slows the notes down and F4 speeds them up; the setting is saved straight away.
func _change_scroll_speed(step: int) -> void:
    var speed := clampi(int(Settings.get_value("mania", "scroll_speed")) + step, 1, 40)
    Settings.set_value("mania", "scroll_speed", speed)
    Settings.save_settings()
    _set_scroll_speed(speed)


## The hidden debug stats under UI.
func _show_stats() -> void:
    _objects_value.text = "%d/%d" % [_completed, beatmap.hit_objects.size()]
    var shown := [HitObjectView.Judgement.PERFECT, HitObjectView.Judgement.GREAT, HitObjectView.Judgement.GOOD, HitObjectView.Judgement.MISS]
    for i in _judgement_values.size():
        _judgement_values[i].text = str(_judgements[shown[i]])


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
    _show_stats()
    _running = false
    $UI/CompleteLabel.show()


## Only the in-game skin cursor shows during play; the pause menu brings the OS cursor back.
func _hide_os_cursor() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
    if _overlay:
        _overlay.queue_free()
    SongClock.stop()
    Input.use_accumulated_input = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


func _is_holding(view: HitObjectView) -> bool:
    if view.data is ManiaNote:
        return _pressed.has(_lane_keys[view.data.column])
    return not _pressed.is_empty()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        if _playable:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            # The OS cursor takes over while paused; resuming shows this one again.
            _cursor.hide()
            $Pause.open()
        else:
            back_requested.emit()
        return
    if not _running:
        return
    var code := 0
    var down := false
    if event is InputEventKey:
        if beatmap.mode == Beatmap.MODE_MANIA and event.pressed and event.physical_keycode in [KEY_F3, KEY_F4]:
            get_viewport().set_input_as_handled()
            _change_scroll_speed(-1 if event.physical_keycode == KEY_F3 else 1)
            return
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
    if _stage:
        _stage.set_pressed(_lane_keys.find(code), down)
    else:
        _update_cursor_hold()
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
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_keys(true)


## Lets go of held keys and buttons whose release never reached _input: every one on
## focus loss, or those let go while paused.
func _release_keys(all: bool) -> void:
    if not _running:
        return
    for code: int in _pressed.keys():
        var held := Input.is_mouse_button_pressed(-code) if code < 0 else Input.is_physical_key_pressed(code)
        if all or not held:
            _pressed.erase(code)
            if _stage:
                _stage.set_pressed(_lane_keys.find(code), false)
    if not _stage:
        _update_cursor_hold()
    var t := -_lead_in if _lead_in > 0.0 else SongClock.get_time()
    for view in _live:
        view.holding = _is_holding(view)
        if not view.holding:
            view.release(t)


## Grows the standard cursor while any hit key or button is down, easing back on release.
func _update_cursor_hold() -> void:
    _cursor.set_held(not _pressed.is_empty())
