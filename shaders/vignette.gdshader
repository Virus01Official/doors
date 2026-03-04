shader_type canvas_item;

uniform float vignette_radius : hint_range(0.0, 1.0) = 0.75;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;

uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool active = false;

uniform vec4 vignette_color : source_color = vec4(0.55, 0.0, 0.0, 1.0);

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0));

    // 0 at center, 1 at edges
    float vignette = smoothstep(vignette_radius - vignette_softness, vignette_radius, dist);

    float pulse = 0.0;
    if (active) {
        float t = TIME * pulse_speed;
        pulse = abs(sin(t)) * abs(sin(t * 0.47 + 1.2));
        pulse = pow(pulse, 0.6) * pulse_strength;
    }

    float final_intensity = clamp(vignette_intensity + (active ? pulse : 0.0), 0.0, 1.0);

    // Alpha is 0 at center (fully transparent), dark red at edges
    float alpha = vignette * final_intensity;

    COLOR = vec4(vignette_color.rgb, alpha);
}