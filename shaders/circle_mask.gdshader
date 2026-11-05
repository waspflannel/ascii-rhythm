shader_type canvas_item;

// Cuts a texture down to the disc inscribed in it, with a soft edge.
uniform float radius : hint_range(0.0, 0.5) = 0.49;
uniform float softness : hint_range(0.0, 0.1) = 0.01;

void fragment() {
    COLOR.a *= 1.0 - smoothstep(radius - softness, radius, distance(UV, vec2(0.5)));
}
