extends Node2D
## Draw the supplied skin digits, rather than replacing them with a font.

const DIGITS: Array[Texture2D] = [
    preload(SkinAssets.DIR + "standard/hitcircles/default-0@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-1@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-2@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-3@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-4@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-5@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-6@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-7@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-8@2x.png"),
    preload(SkinAssets.DIR + "standard/hitcircles/default-9@2x.png"),
]


func set_number(value: int, diameter: float) -> void:
    var text := str(value)
    var textures: Array[AtlasTexture] = []
    var total := 0.0
    var glyph_height := 1.0
    for character in text:
        var source := DIGITS[character.to_int()]
        var texture := AtlasTexture.new()
        texture.atlas = source
        texture.region = source.get_image().get_used_rect()
        textures.append(texture)
        total += texture.get_width()
        glyph_height = maxf(glyph_height, texture.get_height())
    var digit_scale := diameter * 0.22 / glyph_height
    var gap := 2.0 / digit_scale
    total += gap * (text.length() - 1)
    while get_child_count() < text.length():
        add_child(Sprite2D.new())
    var x := -total * digit_scale / 2.0
    for i in get_child_count():
        var digit := get_child(i) as Sprite2D
        digit.visible = i < text.length()
        if not digit.visible:
            continue
        digit.texture = textures[i]
        digit.scale = Vector2.ONE * digit_scale
        digit.position.x = x + digit.texture.get_width() * digit_scale / 2.0
        x += (digit.texture.get_width() + gap) * digit_scale
