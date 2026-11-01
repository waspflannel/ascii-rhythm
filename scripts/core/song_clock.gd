extends Node
## Audio-derived song time, compensated for mixing and output latency.

var _player: AudioStreamPlayer
var _last_time := 0.0


func start(player: AudioStreamPlayer) -> void:
    _player = player
    _last_time = 0.0
    player.play()


func stop() -> void:
    if is_instance_valid(_player):
        _player.stop()
    _player = null


func get_time() -> float:
    if is_instance_valid(_player) and _player.playing:
        var time := _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
        time += float(Settings.get_value("audio", "offset_ms")) / 1000.0
        _last_time = maxf(_last_time, time)
    return _last_time
