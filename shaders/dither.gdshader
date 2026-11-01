shader_type canvas_item;

// Ordered dithering of each color channel; texture colors and alpha are retained.
uniform int color_levels : hint_range(2, 16) = 4;
// Values are rounded to a supported Bayer matrix size: 2, 4, or 8.
uniform int matrix_size : hint_range(2, 8) = 4;
// Dither cell size in render-target pixels.
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;

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

void fragment() {
    int size = matrix_size <= 2 ? 2 : (matrix_size <= 4 ? 4 : 8);
    float threshold = bayer(ivec2(floor(FRAGCOORD.xy / max(pixel_scale, 1.0))), size);
    float steps = float(max(color_levels - 1, 1));
    // COLOR already includes the texture and CanvasItem modulation.
    COLOR.rgb = clamp(floor(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)) * steps + threshold) / steps, vec3(0.0), vec3(1.0));
}
