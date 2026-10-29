shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Камень по UV меша. Используется там, где у геометрии осмысленные UV
// (обшивка стен и арки набора, плиты пола, потолок, гусёк), поэтому кладка
// идёт по развёртке и не зависит от мировых осей.
//
// Отличие от StandardMaterial3D — три вещи, которых у него нет сразу:
// 1) крупная вариация тона по миру (шум + медленная волна) рвёт видимое
//    тайление длинной стены;
// 2) грязь/сырость у пола: стена темнеет и слегка «мокнет» внизу, поэтому
//    кладка стоит в мире, а не висит над полом;
// 3) жёсткий пол шероховатости и приглушённый specular: сухой камень не
//    может блестеть как лакированное дерево.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Пак кладёт шероховатость и металл в один атлас: G — roughness, B — metallic.
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.7;
uniform float roughness_mult : hint_range(0.0, 2.0) = 1.0;
// Ниже этого значения шероховатость не опускается: без него камень ловит
// острые блики и читается пластиком.
uniform float roughness_floor : hint_range(0.0, 1.0) = 0.45;
uniform float specular_value : hint_range(0.0, 1.0) = 0.25;
uniform float metallic_mult : hint_range(0.0, 1.0) = 0.0;

// Крупная вариация тона: бесшовный NoiseTexture2D 512x512 (frequency ~0.02).
uniform sampler2D variation_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float variation_scale = 0.055;
uniform float variation_strength : hint_range(0.0, 0.5) = 0.18;

// Грязь/сырость у пола.
uniform vec4 grime_color : source_color = vec4(0.12, 0.10, 0.08, 1.0);
uniform float floor_y = 0.0;
uniform float grime_height = 0.85;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.45;
uniform float damp_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 alb = texture(albedo_tex, uv).rgb * albedo_tint.rgb * COLOR.rgb;

	// Шум даёт пятна 1–3 м, медленная волна — общий градиент по залу.
	// Обе составляющие берутся в мировых координатах, поэтому не совпадают
	// с сеткой плит и модулей.
	vec2 vp = vec2(world_pos.x + world_pos.z * 0.7, world_pos.y + world_pos.z * 0.3) * variation_scale;
	float n = texture(variation_noise, vp).r;
	float wave = 0.5 + 0.5 * sin(world_pos.x * 0.41 + sin(world_pos.y * 0.7) * 1.7 + world_pos.z * 0.47);
	float macro = mix(wave, n, 0.65);
	alb *= 1.0 + (macro - 0.5) * 2.0 * variation_strength;

	float h = clamp((world_pos.y - floor_y) / max(grime_height, 0.001), 0.0, 1.0);
	float grime = (1.0 - smoothstep(0.0, 1.0, h)) * grime_strength;
	alb = mix(alb, grime_color.rgb, grime);
	// Сырость: грязная полоса отражает чуть сильнее сухого камня.
	alb *= 1.0 - grime * damp_strength * 0.25;

	vec2 mr = texture(mr_tex, uv).gb;
	float rough = mr.x * roughness_mult;
	rough = mix(rough, 0.22, grime * damp_strength);
	rough = max(rough, roughness_floor);

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = mr.y * metallic_mult;
	SPECULAR = specular_value;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
