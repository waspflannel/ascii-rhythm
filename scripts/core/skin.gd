class_name RhythmSkin
extends RefCounted
## Read osu! skin colors separately from grayscale texture masks.

var combo_colors: Array[Color] = []
var slider_border := Color.WHITE
var slider_track := Color.BLACK
var tint_slider_ball := true
## Folder holding skin.ini.
var folder := ""


static func from_file(path: String) -> RhythmSkin:
    var skin := RhythmSkin.new()
    skin.folder = path.get_base_dir()
    var section := ""
    for raw in FileAccess.get_file_as_string(path).split("\n"):
        var line := raw.strip_edges()
        if line.begins_with("["):
            section = line
        var colon := line.find(":")
        if colon < 0:
            continue
        var key := line.left(colon).strip_edges()
        var value := line.substr(colon + 1).strip_edges()
        if section == "[Colours]":
            var parts := value.split(",")
            if parts.size() < 3:
                continue
            var color := Color.from_rgba8(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
            if key.begins_with("Combo"):
                skin.combo_colors.append(color)
            elif key == "SliderBorder":
                skin.slider_border = color
            elif key == "SliderTrackOverride":
                skin.slider_track = color
        elif section == "[General]" and key == "AllowSliderBallTint":
            skin.tint_slider_ball = value.to_int() != 0
    if skin.combo_colors.is_empty():
        skin.combo_colors.append(Color.WHITE)
    return skin


## The hitnormal sample for a beatmap SampleSet; falls back to soft if the skin lacks it.
func hit_sound(sample_set: String) -> AudioStream:
    var path := folder.path_join("sounds/%s-hitnormal.ogg" % sample_set.to_lower())
    if not ResourceLoader.exists(path):
        path = folder.path_join("sounds/soft-hitnormal.ogg")
    return load(path)
