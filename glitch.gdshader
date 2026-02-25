shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;

void fragment(){
	vec2 uv = SCREEN_UV;

	float shift = sin(uv.y * 90.0 + TIME * 40.0) * 0.01 * strength;

	vec2 r_uv = uv + vec2(shift, 0.0);
	vec2 g_uv = uv;
	vec2 b_uv = uv - vec2(shift, 0.0);

	float noise = fract(sin(dot(uv * TIME, vec2(12.9898,78.233))) * 43758.5453) * 0.01 * strength;

	r_uv.y += noise;
	g_uv.y -= noise;
	b_uv.y += noise * 0.5;

	float r = texture(SCREEN_TEXTURE, r_uv).r;
	float g = texture(SCREEN_TEXTURE, g_uv).g;
	float b = texture(SCREEN_TEXTURE, b_uv).b;

	COLOR = vec4(r, g, b, 1.0);
}
