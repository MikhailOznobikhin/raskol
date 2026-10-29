shader_type canvas_item;
// Виньетка и плёночное зерно поверх 3D, под интерфейсом (этап 7).
// Экран читается без мип-цепочки: сэмпл идёт ровно в SCREEN_UV, а мипы
// заставили бы движок каждый кадр строить размытые копии экрана.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_radius : hint_range(0.3, 1.6) = 0.95;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.02;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec2 d = SCREEN_UV - vec2(0.5);
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;     // aspect correction
	float len = length(d) * 1.4;
	float v = 1.0 - smoothstep(vignette_radius - 0.6, vignette_radius, len);
	col *= mix(1.0 - vignette_strength, 1.0, v);
	float g = hash(SCREEN_UV * 1000.0 + fract(TIME) * 100.0) - 0.5;
	col += g * grain_strength;
	COLOR = vec4(col, 1.0);
}
