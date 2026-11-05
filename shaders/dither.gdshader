shader_type canvas_item;

// Dithering of the whole screen, either to a palette or per colour channel. The knobs come
// from Settings [dither]: main.gd sets the pattern, strength, cell size, tint and extras,
// and MapTheme the palette and tint colour.
// Levels per channel when no palette is set.
uniform int color_levels : hint_range(2, 16) = 4;
// Values are rounded to a supported Bayer matrix size: 2, 4, 8 or 16.
uniform int matrix_size : hint_range(2, 16) = 8;
// Dither cell size in window pixels.
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;
// How many entries of palette are used; 0 dithers each channel to color_levels instead.
uniform int palette_size : hint_range(0, 16) = 0;
uniform vec3 palette[16];
// Off shows the screen's own colours, with no palette or levels.
uniform bool quantize = true;
// 0 is an ordered Bayer pattern. 1 is a static noise pattern (interleaved gradient noise).
// 2 is grain: the same noise re-seeded 24 times a second, so the dots move. 3 is flat: a
// fixed 0.5 threshold, so each pixel takes its nearest colour with no dots.
uniform int pattern : hint_range(0, 3) = 0;
// How far the pattern spreads around the nearest colour: 1 is a full dither, 0 snaps each
// pixel to its nearest colour (flat bands). In between, only colours far from both
// neighbours get dots, so the dither thins out.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// How much every other cell row darkens.
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;
// Film grain over the final colour, redrawn 24 times a second.
uniform float grain : hint_range(0.0, 0.2) = 0.0;
// The accent colour the tint ramp passes through (MapTheme's dither accent).
uniform vec3 tint_color : source_color = vec3(0.278, 0.463, 1.0);
// How far each colour moves to its place on the tint ramp: 0 is untouched, 1 is a
// duotone of black, tint_color and white.
uniform float tint : hint_range(0.0, 1.0) = 0.0;
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

// Jimenez's interleaved gradient noise: an even, fine-grained threshold in 0 to 1.
float noise(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// The noise offset for grain this frame: 24 a second, wrapped every 256 frames so the
// offset stays small enough for noise() to keep its float precision.
vec2 frame_offset() {
    return mod(floor(TIME * 24.0), 256.0) * vec2(37.0, 17.0);
}

// Maps c's luminance (Rec.601) onto black, then tint_color at its own luminance, then white.
// The pivot is clamped so a black or white accent does not divide by zero.
vec3 tint_ramp(vec3 c) {
    vec3 weights = vec3(0.299, 0.587, 0.114);
    float luma = dot(c, weights);
    float pivot = clamp(dot(tint_color, weights), 0.001, 0.999);
    if (luma < pivot) {
        return tint_color * (luma / pivot);
    }
    return mix(tint_color, vec3(1.0), (luma - pivot) / (1.0 - pivot));
}

// Mixes the two palette colours nearest to c in the dither pattern. A colour that is in
// the palette comes out solid, so black stays clean black.
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
    vec2 cell = floor(FRAGCOORD.xy / max(pixel_scale, 1.0));
    // COLOR already includes the texture and CanvasItem modulation.
    vec3 c = mix(COLOR.rgb, tint_ramp(COLOR.rgb), tint);
    c = clamp(c * brightness * (1.0 + pulse), vec3(0.0), vec3(1.0));
    if (quantize) {
        int size = matrix_size <= 2 ? 2 : (matrix_size <= 4 ? 4 : (matrix_size <= 8 ? 8 : 16));
        float threshold = 0.5;
        if (pattern == 0) {
            threshold = bayer(ivec2(cell), size);
        } else if (pattern == 1) {
            threshold = noise(cell);
        } else if (pattern == 2) {
            threshold = noise(cell + frame_offset());
        }
        threshold = 0.5 + (threshold - 0.5) * strength;
        if (palette_size > 0) {
            c = dither_palette(c, threshold);
        } else {
            float steps = float(max(color_levels - 1, 1));
            c = clamp(floor(c * steps + threshold) / steps, vec3(0.0), vec3(1.0));
        }
    }
    c *= 1.0 - scanlines * mod(cell.y, 2.0);
    if (grain > 0.0) {
        c += (noise(FRAGCOORD.xy + frame_offset()) - 0.5) * grain * brightness;
    }
    COLOR.rgb = clamp(c, vec3(0.0), vec3(1.0));
}
