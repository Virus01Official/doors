shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 col = vec4(0.0, 0.0, 0.0, strength);
    COLOR = col;
}
