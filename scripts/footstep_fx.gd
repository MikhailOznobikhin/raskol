extends Node
## Следы шагов героя (этап 9): поверхность под ногой и мелкий эффект на ней.
##
## Поверхность: вода — точка шага внутри Area3D лужи (группа "water_zone",
## её ставит scenes/props/puddle.gd); дерево — под ногой коллайдер с
## meta "surface" = &"wood" или в группе "wood_surface"; иначе камень.
## В Миссии 1 пол один (камень), деревянных настилов нет — ветка дерева
## ждёт уровней с мостками, на ней только сигнал, без частиц.
##
## Эмиттеры живут в пуле и переиспользуются (restart), чтобы шаг не
## создавал узлы. Родитель — простой Node, поэтому координаты частиц
## мировые и не крутятся вместе с героем.

class_name FootstepFx

const SURFACE_STONE := &"stone"
const SURFACE_WATER := &"water"
const SURFACE_WOOD := &"wood"

## Слой триггеров (5) — на нём Area3D луж.
const WATER_MASK := 16
const POOL := 3
const RIPPLE_TIME := 0.6

var _dust: Array[GPUParticles3D] = []
var _splash: Array[GPUParticles3D] = []
var _ripples: Array[Decal] = []
var _next := 0


func _ready() -> void:
	var dust_draw := _billboard(0.16, 1.0, 0.0)
	var dust_proc := _dust_process()
	var splash_draw := _billboard(0.07, 0.15, 0.8)
	var splash_proc := _splash_process()
	for i in POOL:
		_dust.append(_emitter("Dust", 6, 0.7, dust_proc, dust_draw))
		_splash.append(_emitter("Splash", 10, 0.45, splash_proc, splash_draw))
		_ripples.append(_ripple_decal())


## Определяет поверхность под точкой шага, играет эффект и возвращает её имя.
func step(foot: Vector3, world: World3D) -> StringName:
	var surface := surface_at(foot, world)
	_next = (_next + 1) % POOL
	match surface:
		SURFACE_WATER:
			_play(_splash[_next], foot + Vector3(0, 0.03, 0))
			_play_ripple(_ripples[_next], foot)
		SURFACE_STONE:
			_play(_dust[_next], foot + Vector3(0, 0.04, 0))
	return surface


func surface_at(foot: Vector3, world: World3D) -> StringName:
	var space := world.direct_space_state
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = foot + Vector3(0, 0.05, 0)
	pq.collide_with_areas = true
	pq.collide_with_bodies = false
	pq.collision_mask = WATER_MASK
	for hit in space.intersect_point(pq, 4):
		var area: Node = hit.get("collider")
		if area != null and area.is_in_group("water_zone"):
			return SURFACE_WATER
	var rq := PhysicsRayQueryParameters3D.create(foot + Vector3(0, 0.4, 0), foot - Vector3(0, 0.6, 0), 1)
	var ray := space.intersect_ray(rq)
	var body: Object = ray.get("collider")
	if body is Node:
		if body.has_meta("surface"):
			return StringName(body.get_meta("surface"))
		if (body as Node).is_in_group("wood_surface"):
			return SURFACE_WOOD
	return SURFACE_STONE


func _play(p: GPUParticles3D, at: Vector3) -> void:
	p.global_position = at
	p.restart()


## Круг на воде: декаль-кольцо расходится и гаснет за RIPPLE_TIME.
func _play_ripple(d: Decal, at: Vector3) -> void:
	var tw: Tween = d.get_meta("tween", null)
	if tw != null and tw.is_valid():
		tw.kill()
	d.global_position = at + Vector3(0, 0.1, 0)
	d.scale = Vector3(0.35, 1.0, 0.35)
	d.modulate.a = 0.55
	d.visible = true
	tw = create_tween().set_parallel()
	tw.tween_property(d, "scale", Vector3(1.0, 1.0, 1.0), RIPPLE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "modulate:a", 0.0, RIPPLE_TIME)
	tw.chain().tween_callback(func(): d.visible = false)
	d.set_meta("tween", tw)


func _emitter(prefix: String, amount: int, life: float, proc: ParticleProcessMaterial, draw: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "%s%d" % [prefix, get_child_count()]
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false
	p.process_material = proc
	p.draw_pass_1 = draw
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1, -0.3, -1), Vector3(2, 1.5, 2))
	# слой героя: декали луж (cull_mask 1) не красят частицы
	p.layers = 1 << (ModelUtil.CHARACTER_LAYER - 1)
	add_child(p)
	return p


## Освещаемый мягкий билборд: пыль и брызги должны темнеть вдали от факелов.
func _billboard(size: float, rough: float, specular: float) -> QuadMesh:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = specular
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	return q


func _fade_ramp(alpha: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, alpha))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Пыль: шесть серо-бурых клубков, разлетаются низко и медленно, висят в воздухе.
func _dust_process() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color = Color(0.46, 0.42, 0.37)
	pm.color_ramp = _fade_ramp(0.45)
	return pm


## Брызги: десяток капель вверх и в стороны, падают по гравитации.
func _splash_process() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.78, 0.82, 0.86)
	pm.color_ramp = _fade_ramp(0.9)
	return pm


func _ripple_decal() -> Decal:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var d := Decal.new()
	d.name = "Ripple%d" % get_child_count()
	d.size = Vector3(0.7, 0.3, 0.7)
	d.texture_albedo = tex
	d.modulate = Color(0.78, 0.82, 0.86, 0.0)
	d.albedo_mix = 1.0
	# поверх пятна лужи и только на полу (герой на слое 2)
	d.sorting_offset = 1.0
	d.cull_mask = 1
	d.visible = false
	add_child(d)
	return d
