shader_type canvas_item;

// Ordered (Bayer) dithering of the whole screen, either to a palette or per colour channel.
// Levels per channel when no palette is set.
uniform int color_levels : hint_range(2, 16) = 4;
// Values are rounded to a supported Bayer matrix size: 2, 4, or 8.
uniform int matrix_size : hint_range(2, 8) = 4;
// Dither cell size in window pixels.
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;
// How many entries of palette are used; 0 dithers each channel to color_levels instead.
uniform int palette_size : hint_range(0, 16) = 0;
uniform vec3 palette[16];
// Screen fade: 0 is black, 1 is full brightness.
uniform float brightness = 1.0;
// Beat pulse: extra brightness, eased out after each beat by the HUD.
uniform float pulse = 0.0;

float bayer(ivec2 p, int size) {
    int value = 0;
    int n = 1;
    for (int bit = 1; bit < size; bit *= 2) {
        int x = (p.x & bit) != 0 ? 1 : 0;
        int y = (p.y & bit) != 0 ? 1 : 0;
        value = value * 4 + 2 * (x ^ y) + y;
        n *= 2;
    }
    return (float(value) + 0.5) / float(n * n);
}

// Mixes the two palette colours nearest to c in a Bayer pattern. A colour that is in the
// palette comes out solid, so black stays clean black.
vec3 dither_palette(vec3 c, float threshold) {
    int nearest = 0;
    int second = 0;
    float nearest_dist = 1e9;
    float second_dist = 1e9;
    for (int i = 0; i < 16; i++) {
        if (i >= palette_size) {
            break;
        }
        vec3 d = c - palette[i];
        float dist = dot(d, d);
        if (dist < nearest_dist) {
            second_dist = nearest_dist;
            second = nearest;
            nearest_dist = dist;
            nearest = i;
        } else if (dist < second_dist) {
            second_dist = dist;
            second = i;
        }
    }
    vec3 a = palette[nearest];
    vec3 ab = palette[second] - a;
    float len = dot(ab, ab);
    float mix_amount = len > 0.0 ? clamp(dot(c - a, ab) / len, 0.0, 1.0) : 0.0;
    return threshold < mix_amount ? palette[second] : a;
}

void fragment() {
    int size = matrix_size <= 2 ? 2 : (matrix_size <= 4 ? 4 : 8);
    float threshold = bayer(ivec2(floor(FRAGCOORD.xy / max(pixel_scale, 1.0))), size);
    // COLOR already includes the texture and CanvasItem modulation.
    vec3 c = clamp(COLOR.rgb * brightness * (1.0 + pulse), vec3(0.0), vec3(1.0));
    if (palette_size > 0) {
        COLOR.rgb = dither_palette(c, threshold);
    } else {
        float steps = float(max(color_levels - 1, 1));
        COLOR.rgb = clamp(floor(c * steps + threshold) / steps, vec3(0.0), vec3(1.0));
    }
}
