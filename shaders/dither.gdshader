shader_type canvas_item;

// Ordered Bayer dithering to a three-colour palette. Applied to the
// SubViewportContainer showing the low-res render, so one dither cell
// is one low-res pixel.

uniform vec4 color_dark : source_color = vec4(0.0, 0.0, 0.0, 1.0); // #000000
uniform vec4 color_mid : source_color = vec4(0.353, 0.039, 0.059, 1.0); // #5a0a0f
uniform vec4 color_light : source_color = vec4(0.722, 0.698, 0.659, 1.0); // dim off-white
// Bayer matrix side length; use a power of two (2, 4 or 8).
uniform int matrix_size : hint_range(2, 8) = 4;
// Screen pixels per low-res pixel; main.gd keeps it equal to stretch_shrink.
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 3.0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Bayer threshold in (0, 1), built one bit pair at a time.
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
	float lum = luma(texture(TEXTURE, UV).rgb);
	float l_dark = luma(color_dark.rgb);
	float l_mid = luma(color_mid.rgb);
	float l_light = luma(color_light.rgb);

	vec3 lo = color_mid.rgb;
	vec3 hi = color_light.rgb;
	float t = (lum - l_mid) / max(l_light - l_mid, 1e-4);
	if (lum < l_mid) {
		lo = color_dark.rgb;
		hi = color_mid.rgb;
		t = (lum - l_dark) / max(l_mid - l_dark, 1e-4);
	}

	float threshold = bayer(ivec2(floor(FRAGCOORD.xy / pixel_scale)), matrix_size);
	COLOR = vec4(clamp(t, 0.0, 1.0) > threshold ? hi : lo, 1.0);
}
