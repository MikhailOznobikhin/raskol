shader_type spatial;

// Камень в мировых координатах со « стоячими» курсами.
//
// Встроенный трипланар StandardMaterial3D для граней, обращённых вдоль X,
// берёт строку текстуры по мировой высоте, а столбец — по Z, и наоборот для
// граней вдоль Z. На практике это значит, что на половине стен подземелья
// ряды кладки бегут вертикально вверх. Здесь V жёстко привязан к мировой
// высоте, поэтому курс всегда горизонтален, а швы не зависят от сетки
// двухметровых блоков.

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float uv_scale = 0.4;
uniform float normal_scale = 1.0;
uniform float roughness_mult = 0.85;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.4;
// Крупная вариация тона по миру: рвёт «обои» из повторяющейся кладки.
uniform float macro_strength = 0.22;


void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// вес плоскости: на ребре блока переход мягкий, на самой грани — одна
	// плоскость даёт почти весь вклад
	vec3 aw = pow(abs(wn), vec3(6.0));
	aw /= max(aw.x + aw.y + aw.z, 1e-4);

	vec2 uvx = vec2(wp.z, -wp.y) * uv_scale;
	vec2 uvy = vec2(wp.x, wp.z) * uv_scale;
	vec2 uvz = vec2(wp.x, -wp.y) * uv_scale;

	vec3 alb = texture(albedo_tex, uvx).rgb * aw.x
		+ texture(albedo_tex, uvy).rgb * aw.y
		+ texture(albedo_tex, uvz).rgb * aw.z;
	float rgh = texture(rough_tex, uvx).r * aw.x
		+ texture(rough_tex, uvy).r * aw.y
		+ texture(rough_tex, uvz).r * aw.z;

	vec3 nx = texture(normal_tex, uvx).xyz * 2.0 - 1.0;
	vec3 ny = texture(normal_tex, uvy).xyz * 2.0 - 1.0;
	vec3 nz = texture(normal_tex, uvz).xyz * 2.0 - 1.0;
	nx.xy *= normal_scale;
	ny.xy *= normal_scale;
	nz.xy *= normal_scale;
	float sx = wn.x >= 0.0 ? 1.0 : -1.0;
	float sy = wn.y >= 0.0 ? 1.0 : -1.0;
	float sz = wn.z >= 0.0 ? 1.0 : -1.0;
	// касательные плоскостей: U -> мировая ось текстуры, V -> вверх по стене
	vec3 cx = vec3(nx.z * sx, -nx.y, nx.x);
	vec3 cy = vec3(ny.x, ny.z * sy, ny.y);
	vec3 cz = vec3(nz.x, -nz.y, nz.z * sz);
	vec3 nw = normalize(cx * aw.x + cy * aw.y + cz * aw.z);

	// Медленная волна по миру в двух масштабах: пятна сырости и выцветания,
	// которые не совпадают с сеткой блоков и не дают кладке тайлиться.
	float macro = 0.5 + 0.5 * sin(wp.x * 0.55 + sin(wp.y * 0.8) * 1.7 + wp.z * 0.63);
	// Вторая октава 1.5–3 м: первая волна слишком плавная и читается как
	// градиент освещения, а не как неровность камня.
	macro = macro * 0.68 + 0.32 * (0.5 + 0.5 * sin(wp.x * 1.35 - wp.z * 1.15
		+ sin(wp.y * 2.1) * 2.2));
	float macro_k = mix(1.0 - macro_strength, 1.0 + macro_strength * 0.5, macro);

	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = alb * tint.rgb * COLOR.rgb * macro_k;
	ROUGHNESS = clamp(rgh * roughness_mult * mix(0.92, 1.06, macro), 0.05, 1.0);
	METALLIC = metallic_value;
	SPECULAR = specular_value;
}
