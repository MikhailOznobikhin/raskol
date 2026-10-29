extends SceneTree
## Сборка общего окружения и сцены факела (Этап 6, свет).
##
## Как и make_materials.gd: ресурсы — файлы, а не объекты кода. Одно
## окружение на все уровни (res://environment/dungeon_env.tres) и одна сцена
## факела (res://scenes/props/torch.tscn), которую генераторы уровней
## инстанцируют вместо россыпи примитивов.
##
## Запуск (пересоздать файлы после правки параметров):
##   godot --headless --path . --script res://src/make_lighting.gd

const ENV_PATH := "res://environment/dungeon_env.tres"
const TORCH_PATH := "res://scenes/props/torch.tscn"
const FLICKER := "res://scenes/props/torch_flicker.gd"
const MAT_IRON := "res://materials/iron.tres"
const MAT_WOOD := "res://materials/wood_planks.tres"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://environment")
	DirAccess.make_dir_recursive_absolute("res://scenes/props")
	_save(_environment(), ENV_PATH)
	_save_scene(_torch(), TORCH_PATH)
	quit()


func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.018, 0.016)
	# Холодный слабый ambient: тёмные залы тёмные, но силуэт героя читается.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.25)
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# AgX мягче ACES сжимает яркие пятна у факелов.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.1
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	# Отражения в лужах (этап 5): без SSR глянец декали читается одной белой
	# точкой блика. 64 шага — компромисс: на 48 видны разрывы, на 96 дорого
	# для 1080p на GTX 1660.
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	# Уровни генерируются в рантайме -> из GI подходит только SDFGI (LightmapGI
	# нечего запекать). A/B этапа 6: вклад SDFGI почти не виден, а стоит 10-20 %
	# FPS, поэтому по умолчанию он выключен; параметры оставлены для меню качества.
	# Стены набора толще 0.3 м, клетка 0.15 м — без протечек.
	env.sdfgi_enabled = false
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_energy = 1.0
	env.sdfgi_bounce_feedback = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [2, 3, 4] else 0.0)
	# Дальний туман (этап 7): почти чёрный, прячет повтор кладки и концы
	# коридоров. Светлее — картинка становится молочной.
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.035)
	env.fog_density = 0.01
	env.fog_sky_affect = 0.0
	# Объёмный туман (этап 7): светлое альбедо — воздух подсвечивают только
	# факелы (у них light_volumetric_fog_energy), сам по себе он едва
	# светится холодной эмиссией. Анизотропия вперёд — ореол у огня.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.85, 0.82, 0.78)
	env.volumetric_fog_emission = Color(0.01, 0.012, 0.018)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_ambient_inject = 0.1
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	return env


## Факел на стене. Локальные оси: стена в плоскости z=0, +Z — в зал.
func _torch() -> Node3D:
	var root := Node3D.new()
	root.name = "Torch"
	var iron: Material = load(MAT_IRON)
	var wood: Material = load(MAT_WOOD)

	var mesh := Node3D.new()
	mesh.name = "Mesh"
	_add(root, mesh)
	_part(mesh, "Plate", _box_mesh(Vector3(0.28, 0.46, 0.08)), Vector3(0, 0.22, 0.04), iron)
	_part(mesh, "Arm", _box_mesh(Vector3(0.08, 0.08, 0.28)), Vector3(0, 0.38, 0.18), iron)
	_part(mesh, "Stick", _cyl_mesh(0.045, 0.055, 0.54), Vector3(0, 0.72, 0.3), wood)
	_part(mesh, "Cup", _cyl_mesh(0.17, 0.11, 0.12), Vector3(0, 1.04, 0.3), iron)

	var flame := GPUParticles3D.new()
	flame.name = "Flame"
	flame.position = Vector3(0, 1.1, 0.3)
	flame.amount = 24
	flame.lifetime = 0.6
	flame.local_coords = true
	flame.visibility_aabb = AABB(Vector3(-0.4, -0.2, -0.4), Vector3(0.8, 1.0, 0.8))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fp := ParticleProcessMaterial.new()
	fp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fp.emission_sphere_radius = 0.04
	fp.direction = Vector3(0, 1, 0)
	fp.spread = 10.0
	fp.initial_velocity_min = 0.3
	fp.initial_velocity_max = 0.6
	fp.gravity = Vector3(0, 0.5, 0)
	fp.scale_curve = _curve_tex([Vector2(0, 1), Vector2(1, 0)])
	fp.color_ramp = _ramp([
		[0.0, Color(1.0, 0.85, 0.5, 1.0)],
		[0.45, Color(1.0, 0.45, 0.1, 0.85)],
		[1.0, Color(0.35, 0.04, 0.0, 0.0)],
	])
	flame.process_material = fp
	flame.draw_pass_1 = _particle_quad(0.15)
	_add(root, flame)

	var core := MeshInstance3D.new()
	core.name = "FlameCore"
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.12
	sm.radial_segments = 8
	sm.rings = 4
	core.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0, 0, 0)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.6, 0.25)
	cm.emission_energy_multiplier = 4.0
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = Vector3(0, 1.15, 0.3)
	_add(root, core)

	var embers := GPUParticles3D.new()
	embers.name = "Embers"
	embers.position = Vector3(0, 1.18, 0.3)
	embers.amount = 6
	embers.lifetime = 1.5
	embers.local_coords = false
	embers.visibility_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 2.0, 1.6))
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ep := ParticleProcessMaterial.new()
	ep.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ep.emission_sphere_radius = 0.05
	ep.direction = Vector3(0, 1, 0)
	ep.spread = 30.0
	ep.initial_velocity_min = 0.25
	ep.initial_velocity_max = 0.55
	ep.gravity = Vector3(0, 0.15, 0)
	ep.turbulence_enabled = true
	ep.turbulence_noise_strength = 0.4
	ep.turbulence_noise_scale = 1.5
	ep.color_ramp = _ramp([
		[0.0, Color(1.0, 0.75, 0.35, 1.0)],
		[0.7, Color(1.0, 0.4, 0.08, 0.8)],
		[1.0, Color(0.6, 0.1, 0.0, 0.0)],
	])
	embers.process_material = ep
	embers.draw_pass_1 = _particle_quad(0.025)
	_add(root, embers)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.set_script(load(FLICKER))
	# 0.3 м от стены: стена прямо за факелом не выжигается.
	light.position = Vector3(0, 1.38, 0.3)
	light.light_color = Color(1.0, 0.6, 0.32)
	light.light_energy = 2.5
	light.omni_range = 7.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = true
	light.light_size = 0.08
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.0
	light.light_volumetric_fog_energy = 2.0
	light.light_specular = 0.6
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_shadow = 15.0
	light.distance_fade_length = 8.0
	_add(root, light)
	light.set("base_energy", 2.5)
	return root


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var owner_node := parent
	while owner_node.get_parent() != null:
		owner_node = owner_node.get_parent()
	child.owner = owner_node


func _part(parent: Node3D, part_name: String, m: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	_add(parent, mi)


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


## Плоская частица-billboard: мягкое пятно, аддитивно, цвет из вершин (ramp).
func _particle_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	q.material = m
	return q


func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("не сохранить %s: %d" % [path, err])
	else:
		print("saved ", path)


func _save_scene(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack %s: %d" % [path, err])
		return
	_save(ps, path)
	root.free()
