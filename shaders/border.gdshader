shader_type canvas_item;
render_mode blend_mix;

uniform float border_size : hint_range(1.0, 96.0) = 14.0;
uniform float glow_size : hint_range(1.0, 192.0) = 54.0;
uniform float speed : hint_range(0.0, 4.0) = 0.42;
uniform float saturation : hint_range(0.0, 1.0) = 0.82;
uniform float brightness : hint_range(0.0, 3.0) = 1.55;
uniform float alpha : hint_range(0.0, 1.0) = 0.95;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.42;

vec3 hsv2rgb(vec3 c)
{
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment()
{
	vec4 canvas_color = COLOR;
	vec2 rect_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel = UV * rect_size;
	vec2 edge_distance = min(pixel, rect_size - pixel);
	float distance_to_edge = min(edge_distance.x, edge_distance.y);

	float border = 1.0 - smoothstep(border_size * 0.35, border_size, distance_to_edge);
	float glow = 1.0 - smoothstep(border_size, border_size + glow_size, distance_to_edge);
	float mask = max(border, glow * 0.55);

	vec2 centered = (UV - vec2(0.5)) * vec2(rect_size.x / rect_size.y, 1.0);
	float edge_phase = fract((atan(centered.y, centered.x) / TAU) + 0.5);
	float wave = sin((edge_phase * TAU * 2.0) + TIME * 2.4);
	float hue = edge_phase + TIME * speed + wave * wave_strength * 0.04;

	vec3 rainbow = hsv2rgb(vec3(fract(hue), saturation, brightness));
	vec3 aura = hsv2rgb(vec3(fract(hue + 0.08), saturation * 0.7, brightness * 0.85));
	vec3 color = mix(aura, rainbow, border);

	COLOR = vec4(color * canvas_color.rgb, mask * alpha * canvas_color.a);
}
