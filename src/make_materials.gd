extends SceneTree
## Сборка общих материалов окружения (Этап 4).
##
## Все материалы подземелья — файлы res://materials/*.tres, а не объекты,
## которые генератор создаёт заново на каждом запуске: правка материала
## видна всем поверхностям сразу, а git показывает изменение как обычный
## diff ресурса.
##
## Запуск (пересоздать все .tres после правки параметров):
##   godot --headless --path . --script res://src/make_materials.gd
## Скрипт пишет файлы сам; в игре материалы только загружаются
## (res://materials/, шейдеры — res://shaders/stone_world.gdshader).

const SHADER_UV := "res://shaders/stone_world.gdshader"
const SHADER_TRIPLANAR := "res://assets/shaders/stone_triplanar.gdshader"
const NOISE_PATH := "res://environment/variation_noise.tres"
const DIR_MAT := "res://materials"
const DIR_ENV := "res://environment"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_MAT)
	DirAccess.make_dir_recursive_absolute(DIR_ENV)
	var noise := _variation_noise()
	_save(noise, NOISE_PATH)

	# --- Кирпичная кладка ---------------------------------------------------
	# Обшивка стен и арки набора: UV меша уже метрические, поэтому масштаб —
	# множитель UV, а не мировых метров.
	_save(_stone_uv(
		"brickwalls", Color(0.94, 0.91, 0.87), Vector2(3.66, 3.66), noise,
		0.70, 1.05, 0.55, 0.20, 0.22, 1.1, 0.45, 0.35
	), DIR_MAT + "/wall_brick.tres")

	# Тело стены, ступени и стволы колонн — процедурные коробки без UV:
	# кладка проецируется по миру стоячими курсами.
	var brick_world := _stone_triplanar(
		"brickwalls", Color(0.90, 0.88, 0.85), 0.25, 0.70, 1.05, 0.55, 0.20,
		true, 0.9, 0.45, 0.35)
	_save(brick_world, DIR_MAT + "/brick_blocks.tres")

	# Свод и потолок: та же кладка, но темнее стен на ~20 %, иначе потолок
	# читается самым светлым и самым «плоским» пятном кадра.
	_save(_stone_uv(
		"brickwalls", Color(0.72, 0.70, 0.66), Vector2(0.25, 0.25), noise,
		0.60, 1.0, 0.62, 0.20, 0.18, 0.9, 0.0, 0.0
	), DIR_MAT + "/ceiling_vault.tres")

	# --- Пол ----------------------------------------------------------------
	# Плиты пола набора. Грязи у пола нет (он сам пол): только крупная
	# вариация тона. normal_strength намеренно ниже стен — камера третьего
	# лица смотрит на пол почти по касательной, и сильный рельеф там
	# превращается в «кипящую» кашу.
	_save(_stone_uv(
		"tile_floor", Color(0.86, 0.84, 0.82), Vector2(1.70, 1.70), noise,
		0.55, 1.0, 0.60, 0.18, 0.15, 0.7, 0.0, 0.0
	), DIR_MAT + "/floor_cobble.tres")

	# Аварийный пол, если набор не загрузился: та же коббл-плитка, только по
	# миру и без UV — серый «заглушечный» камень из tex3d в кадр больше не лезет.
	_save(_stone_triplanar(
		"tile_floor", Color(0.86, 0.84, 0.82), 0.25, 0.55, 1.0, 0.60, 0.18,
		true, 0.7, 0.0, 0.0), DIR_MAT + "/floor_stone_plain.tres")

	# --- Тёсаный камень и тримы --------------------------------------------
	# Рёбра, ступени, порталы и настилы. Раньше это брало stone_wall из tex3d —
	# серую блочную заглушку, которая рядом с настоящей кладкой читалась
	# вставленным пластиком. Теперь та же кладка пака, но тёмная и выветренная:
	# своя семья, свой тон, без чужой текстуры.
	_save(_stone_triplanar(
		"brickwalls", Color(0.62, 0.58, 0.55), 0.25, 0.60, 1.10, 0.70, 0.18,
		true, 1.1, 0.55, 0.35), DIR_MAT + "/stone_trim.tres")

	# Тесаная кладка без сильного затемнения: косяки арок, обломки.
	_save(_stone_triplanar(
		"brickwalls", Color(0.78, 0.75, 0.71), 0.25, 0.65, 1.05, 0.62, 0.20,
		true, 1.0, 0.45, 0.30), DIR_MAT + "/wall_stone_blocks.tres")

	# Заплатки земли в залах. Родной песок пака светлый и гладкий и в кадре
	# читался светлым листом над кобблом; сырая земля — тёмная и матовая.
	_save(_stone_triplanar(
		"sand", Color(0.38, 0.33, 0.28), 0.25, 0.45, 1.10, 0.75, 0.12,
		true, 0.7, 0.0, 0.0), DIR_MAT + "/floor_dirt.tres")

	# --- Дерево и железо ----------------------------------------------------
	_save(_pbr("wood", Color(0.82, 0.76, 0.70), 0.78, 0.0, 1.0, 0.80),
		DIR_MAT + "/wood_planks.tres")
	_save(_pbr("wood", Color(0.62, 0.57, 0.52), 0.82, 0.0, 1.0, 0.90),
		DIR_MAT + "/wood_beam.tres")
	# Фонарный столб и скобы: железо, а не чёрная заглушка. metallic 0.7 и
	# roughness 0.62 дают тусклый металл, который держит блик факела.
	_save(_pbr("metal", Color(0.60, 0.62, 0.66), 0.62, 0.70, 1.2, 0.60),
		DIR_MAT + "/iron.tres")

	print("MATERIALS DONE")
	quit()


func _save(res: Resource, path: String) -> void:
	res.resource_path = path
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("не сохранился %s: %d" % [path, err])
	else:
		print("MAT  ", path)


## Бесшовный шум 512×512, частота ~0.02: пятна в 1–3 м, которые не совпадают
## с сеткой плит и модулей.
func _variation_noise() -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.seed = 20261029
	fn.frequency = 0.02
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.seamless_blend_skirt = 0.15
	tex.generate_mipmaps = true
	tex.noise = fn
	return tex


## Каменная поверхность по UV меша (res://shaders/stone_world.gdshader).
func _stone_uv(tex_set: String, tint: Color, uv: Vector2, noise: Texture2D,
		normal: float, rough_mult: float, rough_floor: float, spec: float,
		var_strength: float, grime_h: float, grime_s: float,
		damp: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_UV)
	m.set_shader_parameter("albedo_tex", _kit(tex_set + "_basecolor.jpg"))
	m.set_shader_parameter("normal_tex", _kit(tex_set + "_normal.jpg"))
	m.set_shader_parameter("mr_tex", _kit(tex_set + "_mr.png"))
	m.set_shader_parameter("albedo_tint", tint)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("normal_strength", normal)
	m.set_shader_parameter("roughness_mult", rough_mult)
	m.set_shader_parameter("roughness_floor", rough_floor)
	m.set_shader_parameter("specular_value", spec)
	m.set_shader_parameter("metallic_mult", 0.0)
	m.set_shader_parameter("variation_noise", noise)
	m.set_shader_parameter("variation_scale", 0.055)
	m.set_shader_parameter("variation_strength", var_strength)
	m.set_shader_parameter("grime_color", Color(0.12, 0.10, 0.08))
	m.set_shader_parameter("floor_y", 0.0)
	m.set_shader_parameter("grime_height", grime_h)
	m.set_shader_parameter("grime_strength", grime_s)
	m.set_shader_parameter("damp_strength", damp)
	return m


## Каменная поверхность в мировых координатах (assets/shaders/stone_triplanar).
## pack_textures: true — атласы набора (brickwalls, tile_floor, sand),
## false — grayscale-набор res://assets/tex3d/ (stone_wall, stone_floor).
func _stone_triplanar(tex_set: String, tint: Color, uv: float, normal: float,
		rough_mult: float, rough_floor: float, spec: float, pack_textures: bool,
		grime_h: float, grime_s: float, damp: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_TRIPLANAR)
	var albedo: Texture2D = null
	var normal_tex: Texture2D = null
	var rough: Texture2D = null
	if pack_textures:
		albedo = _kit(tex_set + "_basecolor.jpg")
		normal_tex = _kit(tex_set + "_normal.jpg")
		rough = _kit(tex_set + "_mr.png")
	else:
		albedo = _tex3d(tex_set + "_albedo")
		normal_tex = _tex3d(tex_set + "_normal")
		rough = _tex3d(tex_set + "_rough")
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("normal_tex", normal_tex)
	m.set_shader_parameter("rough_tex", rough)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("normal_scale", normal)
	m.set_shader_parameter("roughness_mult", rough_mult)
	m.set_shader_parameter("roughness_floor", rough_floor)
	m.set_shader_parameter("metallic_value", 0.0)
	m.set_shader_parameter("specular_value", spec)
	m.set_shader_parameter("macro_strength", 0.22)
	m.set_shader_parameter("rough_from_green", pack_textures)
	m.set_shader_parameter("floor_y", 0.0)
	m.set_shader_parameter("grime_height", grime_h)
	m.set_shader_parameter("grime_strength", grime_s)
	m.set_shader_parameter("damp_strength", damp)
	return m


## Дерево/железо: обычный StandardMaterial3D, трипланар по миру.
func _pbr(tex_set: String, tint: Color, rough: float, metal: float, uv: float,
		normal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex3d(tex_set + "_albedo")
	m.albedo_color = tint
	var n := _tex3d(tex_set + "_normal")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = normal
	var r := _tex3d(tex_set + "_rough")
	if r != null:
		m.roughness_texture = r
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.35
	m.uv1_scale = Vector3(uv, uv, uv)
	m.uv1_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _kit(name: String) -> Texture2D:
	var path := "res://assets/models/dungeon_kit/textures/" + name
	return load(path) if ResourceLoader.exists(path) else null


func _tex3d(name: String) -> Texture2D:
	var path := "res://assets/tex3d/" + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null
