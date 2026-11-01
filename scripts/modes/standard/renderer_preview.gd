extends Control
## Fixed, silent rendering examples; run scenes/renderer_preview.tscn with F6.


func _enter_tree() -> void:
    var map := StandardBeatmap.new()
    map.circle_size = 4.0
    map.approach_rate = 5.0
    var skin := RhythmSkin.from_file("res://assets/skins/neptune/skin.ini")
    $Field/Circle.setup(HitCircle.new(2.0, Vector2(100, 100)), map)
    $Field/Circle.combo_color = skin.combo_colors[0]
    var curve := HitSlider.build_curve("B", PackedVector2Array([Vector2(280,100),Vector2(340,40),Vector2(410,150),Vector2(490,100)]),230.0)
    $Field/Slider.setup(HitSlider.new(2.0,6.0,curve,1,0.5), map)
    var repeat_curve := HitSlider.build_curve("B", PackedVector2Array([Vector2(100,320),Vector2(230,250),Vector2(350,390),Vector2(480,320)]),400.0)
    $Field/RepeatSlider.setup(HitSlider.new(2.0,6.0,repeat_curve,2,0.5), map)
    for view in [$Field/Slider,$Field/RepeatSlider]:
        view.combo_color = skin.combo_colors[1]
        view.track_color = skin.slider_track
        view.border_color = skin.slider_border
        view.tint_ball = skin.tint_slider_ball


func _ready() -> void:
    $Field/Circle.update_view(1.8)
    $Field/Slider.update_view(1.8)
    var repeat_view := $Field/RepeatSlider
    repeat_view.simulated_cursor = repeat_view.data.position
    repeat_view.press(2.0)
    for part in [repeat_view.sprite, repeat_view.overlay, repeat_view.number]:
        part.hide()
    repeat_view.holding = true
    repeat_view.simulated_cursor = repeat_view.data.position_at(3.1)
    repeat_view.update_view(3.1)
