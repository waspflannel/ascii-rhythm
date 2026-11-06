shader_type canvas_item;

// The standard-mode cursor: the skin's ring, optionally recoloured and given a thin black
// outline. CursorView sets the uniforms from Settings [cursor]. Opacity is a uniform, not
// the node's modulate, because assigning COLOR here would drop the modulate anyway.
// Colour that replaces the ring's own when use_tint is on.
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_tint = true;
// Outline thickness in texels of the ring texture; 0 draws none.
uniform float outline_width = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

const int TAPS = 16;

void fragment() {
	vec4 ring = texture(TEXTURE, UV);
	vec3 rgb = use_tint ? tint.rgb : ring.rgb;
	float alpha = ring.a;
	if (outline_width > 0.0) {
		// The outline is wherever the ring is within outline_width texels.
		float halo = 0.0;
		for (int i = 0; i < TAPS; i++) {
			float angle = float(i) * TAU / float(TAPS);
			halo = max(halo, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * outline_width * TEXTURE_PIXEL_SIZE).a);
		}
		// Black behind the ring, so its soft edge blends into the outline.
		rgb = mix(vec3(0.0), rgb, ring.a);
		alpha = max(ring.a, halo);
	}
	COLOR = vec4(rgb, alpha * opacity);
}
