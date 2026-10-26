shader_type canvas_item;
// Плёночный грейд: тёплый сдвиг, лёгкая хроматика, виньетка и живое зерно.
// Накладывается поверх всего кадра, чтобы пиксель-арт и видео жили в одной плёнке.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float grain_amount = 0.026;
uniform float vignette_strength = 0.28;
uniform float aberration = 0.5;
uniform float warmth = 0.045;
uniform float contrast = 1.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float off = aberration * 0.0012 * (0.4 + length(d) * 2.2);

	vec3 col;
	col.r = texture(screen_texture, uv + d * off).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - d * off).b;

	// тёплый грейд и контраст
	col *= vec3(1.0 + warmth, 1.0 + warmth * 0.25, 1.0 - warmth);
	col = clamp((col - 0.5) * contrast + 0.5, 0.0, 1.0);

	// виньетка
	float v = smoothstep(0.95, 0.28, length(d) * 1.28);
	col *= mix(1.0 - vignette_strength, 1.0, v);

	// зерно, дышащее во времени
	float n = hash(uv * vec2(1376.0, 768.0) + fract(TIME) * 137.0) - 0.5;
	col += n * grain_amount;

	COLOR = vec4(col, 1.0);
}
