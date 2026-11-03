extends RefCounted
## Optional simulation driver, selected in Settings.


static func drive(view: HitObjectView, t: float) -> void:
    var object := view.data
    view.holding = t >= object.time
    if object is HitSlider:
        view.simulated_cursor = object.position_at(t)
    elif object is HitCircle:
        view.simulated_cursor = object.position
    elif object is Spinner:
        view.simulated_cursor = Spinner.CENTER + Vector2.from_angle((t - object.time) * TAU * 5.0) * 100.0
    if t >= object.time:
        # Use the exact scheduled timestamp even when it falls between rendered frames.
        view.press(object.time)
    if object is ManiaNote and object.is_hold() and t >= object.end_time:
        view.release(object.end_time)
