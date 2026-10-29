extends CharacterBody3D
## Торвин в 3D: риг из примитивов, движение от камеры, бой, рывок.

class_name Hero3D

const SPEED: float = Balance.HERO_SPEED
const RUN: float = Balance.HERO_RUN
const CROUCH: float = Balance.HERO_CROUCH
const ACCEL := Balance.HERO_ACCEL
const DODGE_SPEED: float = Balance.HERO_DODGE_SPEED
const DODGE_TIME: float = Balance.HERO_DODGE_TIME
const LIGHT_DMG: float = Balance.HERO_LIGHT_DMG
const HEAVY_DMG: float = Balance.HERO_HEAVY_DMG
const HEAVY_WINDUP: float = Balance.HERO_HEAVY_WINDUP
const ATTACK_TIME := Balance.HERO_ATTACK_TIME
const HITSTOP_DURATION := 0.055
const HITSTOP_TIME_SCALE := 0.4

static var hitstop_generation := 0
static var hitstop_active := false
static var hitstop_restore_scale := 1.0

var state := "idle"
var state_t := 0.0
var attack_phase := ""
var attack_done := false
var invuln := 0.0
var dead := false
var control_enabled := true
var crouching := false
var distract_cd := 0.0
var spike_cd := 0.0
var nova_cd := 0.0
var dodge_dir := Vector3.ZERO
var turn_rate := 0.0

var rig: Node3D
var hips: Node3D
var chest: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var weapon: Node3D

var phase := 0.0
var combo_step := 0
var attack_queued := false
var step_t := 0.0
var facing_yaw := 0.0
var move_dir := Vector3.ZERO
var mat_cloth: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_leather: StandardMaterial3D
var mat_cloth_dark: StandardMaterial3D
var mat_metal_dark: StandardMaterial3D

var use_model := false
var model_root: Node3D
var weapon_model: Node3D
var anim: AnimationPlayer
var anim_tree: AnimationTree
var anim_has_walk_scale := false
var anim_has_run_scale := false
var anim_has_idle_walk_blend := false
var anim_has_walk_run_blend := false
var anim_has_slash := false
var anim_has_roll := false
var anim_has_hit := false
var anim_has_death := false
var anim_locomotion_blend := 0.0
var anim_run_blend := 0.0
var anim_death_blend := 0.0
var anim_was_dead := false
var active_anim_action := ""
## шаг комбо, для которого Slash уже запущен (-99 — атаки нет)
var slash_step := -99
## узел Slash и длина его клипа: скорость взмаха задаём через custom timeline
var slash_node: AnimationNodeAnimation
var slash_len := 0.72

var last_safe_position: Vector3 = Vector3.ZERO
var _safe_timer := 0.0
var lowest_floor_y := 0.0

signal died
## Шаг коснулся пола: surface — "stone", "water" или "wood" (этап 10).
signal footstep(surface: String)

const STEP_DB := -10.0
const STEP_DB_CROUCH := -17.0
var footsteps: FootstepPlayer


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.5
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.78, 0)
	add_child(col)
	_build_rig()
	_add_readability_light()
	footsteps = FootstepPlayer.new()
	add_child(footsteps)
	footstep.connect(footsteps.on_footstep)


## Поверхность под ногами: её знает подземелье (лужи), вне его — камень.
func surface_under() -> String:
	var d := get_tree().get_first_node_in_group("dungeon")
	if d != null and d.has_method("surface_at"):
		return d.surface_at(global_position)
	return "stone"


## Едва заметная тёплая лампа над-перед гномом: в тёмном коридоре он не
## превращается в чёрный силуэт. Висит на риге (вперёд — -Z), без теней.
func _add_readability_light() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "ReadabilityLight"
	lamp.light_color = Color(1.0, 0.75, 0.5)
	lamp.light_energy = 0.25
	lamp.omni_range = 3.0
	lamp.shadow_enabled = false
	lamp.light_specular = 0.1
	lamp.position = Vector3(0.0, 1.9, -0.6)
	rig.add_child(lamp)


func _mat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	return m


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _box(parent: Node3D, size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi



func _cyl(r: float, h: float, offset: Vector3, mat: Material, parent: Node3D, bottom := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if bottom < 0.0 else bottom
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float, offset: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 6
	mi.mesh = c
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi

func _build_rig() -> void:
	mat_cloth = _mat(Color(0.24, 0.3, 0.46), 0.85)
	mat_cloth_dark = _mat(Color(0.15, 0.19, 0.3), 0.9)
	mat_skin = _mat(Color(0.66, 0.48, 0.36), 0.7)
	mat_metal = _mat(Color(0.55, 0.58, 0.66), 0.35, 0.85)
	mat_metal_dark = _mat(Color(0.3, 0.32, 0.38), 0.5, 0.8)
	mat_hair = _mat(Color(0.45, 0.24, 0.11), 0.9)
	mat_leather = _mat(Color(0.32, 0.23, 0.15), 0.8)

	rig = Node3D.new()
	add_child(rig)

	hips = _joint(rig, Vector3(0, 0.9, 0))
	_box(hips, Vector3(0.46, 0.2, 0.34), Vector3(0, 0, 0), mat_leather)
	_box(hips, Vector3(0.52, 0.1, 0.36), Vector3(0, 0.08, 0), mat_metal_dark)
	_box(hips, Vector3(0.12, 0.09, 0.03), Vector3(0, 0.08, 0.19), mat_metal)

	chest = _joint(hips, Vector3(0, 0.12, 0))
	_box(chest, Vector3(0.56, 0.42, 0.38), Vector3(0, 0.24, 0), mat_cloth)
	_box(chest, Vector3(0.6, 0.3, 0.4), Vector3(0, 0.34, 0.005), mat_cloth)
	# нагрудная пластина и перевязь
	_box(chest, Vector3(0.34, 0.26, 0.03), Vector3(0, 0.28, 0.2), mat_metal_dark)
	_box(chest, Vector3(0.07, 0.46, 0.02), Vector3(0.12, 0.26, 0.21), mat_leather)
	_box(chest, Vector3(0.62, 0.1, 0.42), Vector3(0, 0.47, 0), mat_metal)
	# наплечники
	_sphere(chest, 0.14, Vector3(-0.38, 0.43, 0), mat_metal)
	_sphere(chest, 0.14, Vector3(0.38, 0.43, 0), mat_metal)
	# плащ из сегментов
	var cloak := _box(chest, Vector3(0.5, 0.72, 0.04), Vector3(0, 0.16, -0.235), mat_cloth_dark)
	cloak.rotation_degrees = Vector3(-6, 0, 0)
	_box(chest, Vector3(0.48, 0.18, 0.03), Vector3(0, -0.16, -0.245), mat_cloth_dark)
	_box(chest, Vector3(0.42, 0.16, 0.03), Vector3(0, -0.31, -0.255), mat_cloth_dark)
	# ремень с пряжкой
	_box(hips, Vector3(0.48, 0.06, 0.36), Vector3(0, 0.02, 0), mat_leather)
	_box(hips, Vector3(0.08, 0.08, 0.03), Vector3(0, 0.02, 0.19), mat_metal)

	# голова
	head = _joint(chest, Vector3(0, 0.52, 0))
	_sphere(head, 0.18, Vector3(0, 0.14, 0), mat_skin)
	_box(head, Vector3(0.26, 0.16, 0.26), Vector3(0, 0.02, 0.02), mat_skin)
	# волосы: шапка сзади и по бокам
	var hair := _sphere(head, 0.19, Vector3(0, 0.19, -0.06), mat_hair)
	hair.scale = Vector3(1.0, 0.7, 0.95)
	_box(head, Vector3(0.32, 0.1, 0.26), Vector3(0, 0.27, -0.05), mat_hair)
	# борода-клин
	_cyl(0.15, 0.34, Vector3(0, -0.08, 0.07), mat_hair, head, 0.05)
	_box(head, Vector3(0.3, 0.1, 0.16), Vector3(0, 0.04, 0.13), mat_hair)
	# нос и глаза
	_box(head, Vector3(0.07, 0.08, 0.09), Vector3(0, 0.12, 0.18), mat_skin)
	var eye_mat := _mat(Color(1.0, 0.72, 0.28), 0.3)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.62, 0.2)
	eye_mat.emission_energy_multiplier = 1.6
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(-0.075, 0.16, 0.17), eye_mat)
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(0.075, 0.16, 0.17), eye_mat)

	# руки
	arm_l = _joint(chest, Vector3(-0.34, 0.42, 0))
	_capsule(0.09, 0.36, Vector3(0, -0.18, 0), mat_cloth, arm_l)
	_sphere(arm_l, 0.12, Vector3(0, -0.01, 0), mat_metal)
	forearm_l = _joint(arm_l, Vector3(0, -0.36, 0))
	_capsule(0.075, 0.3, Vector3(0, -0.15, 0), mat_leather, forearm_l)
	_sphere(forearm_l, 0.08, Vector3(0, -0.33, 0), mat_skin)

	arm_r = _joint(chest, Vector3(0.34, 0.42, 0))
	_capsule(0.09, 0.36, Vector3(0, -0.18, 0), mat_cloth, arm_r)
	_sphere(arm_r, 0.12, Vector3(0, -0.01, 0), mat_metal)
	forearm_r = _joint(arm_r, Vector3(0, -0.36, 0))
	_capsule(0.075, 0.3, Vector3(0, -0.15, 0), mat_leather, forearm_r)
	_sphere(forearm_r, 0.08, Vector3(0, -0.33, 0), mat_skin)

	# молот
	weapon = Node3D.new()
	weapon.position = Vector3(0, -0.34, 0)
	forearm_r.add_child(weapon)
	_box(weapon, Vector3(0.055, 0.72, 0.055), Vector3(0, -0.34, 0.12), mat_leather)
	_box(weapon, Vector3(0.2, 0.2, 0.28), Vector3(0, -0.68, 0.24), mat_metal_dark)
	_box(weapon, Vector3(0.22, 0.06, 0.3), Vector3(0, -0.6, 0.24), mat_metal)

	# ноги
	leg_l = _joint(hips, Vector3(-0.14, -0.06, 0))
	_capsule(0.1, 0.42, Vector3(0, -0.21, 0), mat_cloth_dark, leg_l)
	shin_l = _joint(leg_l, Vector3(0, -0.42, 0))
	_capsule(0.09, 0.34, Vector3(0, -0.17, 0), mat_leather, shin_l)
	_box(shin_l, Vector3(0.21, 0.14, 0.34), Vector3(0, -0.36, 0.05), mat_leather)

	leg_r = _joint(hips, Vector3(0.14, -0.06, 0))
	_capsule(0.1, 0.42, Vector3(0, -0.21, 0), mat_cloth_dark, leg_r)
	shin_r = _joint(leg_r, Vector3(0, -0.42, 0))
	_capsule(0.09, 0.34, Vector3(0, -0.17, 0), mat_leather, shin_r)
	_box(shin_r, Vector3(0.21, 0.14, 0.34), Vector3(0, -0.36, 0.05), mat_leather)

	_add_blob_shadow(0.55)
	_attach_model()
	# Лужи-декали проецируются только на слой 1: герой живёт на слое 2,
	# иначе вода красит сапоги и плащ.
	ModelUtil.set_visual_layer(self, ModelUtil.CHARACTER_LAYER)


## Надевает glTF-модель гнома на риг и вешает молот в правую кисть.
## Если модель не загрузилась — остаются примитивы (игра не ломается).
func _attach_model() -> void:
	ModelUtil.hide_meshes(rig)
	var model := ModelUtil.spawn(rig, "res://assets/hero_mixamo.glb", Balance.HERO_MODEL_HEIGHT)
	if model == null:
		ModelUtil.show_meshes(rig)
		return
	use_model = true
	model_root = model
	anim = ModelUtil.find_anim_player(model)
	if anim != null:
		_build_anim_tree()
	_attach_weapon(model)
	# CC0-модели гнома с этим ригом нет, поэтому шляпу лепим поверх Head
	GnomeKit.decorate(model)
	if anim != null and anim_tree == null:
		ModelUtil.play_key(anim, ["Idle"], true)


func _attach_weapon(model: Node3D) -> void:
	var att := ModelUtil.bone_attach(model, ["Wrist.R", "mixamorig_RightHand", "RightHand"])
	if att == null:
		return
	var grip := Node3D.new()
	att.add_child(grip)
	# кости glTF приходят с масштабом ~100 (сантиметры): без компенсации
	# молот получается стометровым и накрывает камеру
	var ws: Vector3 = att.global_transform.basis.get_scale()
	if ws.x > 0.0001 and ws.y > 0.0001 and ws.z > 0.0001:
		grip.scale = Vector3(1.0 / ws.x, 1.0 / ws.y, 1.0 / ws.z)
	var tool := ModelUtil.spawn(grip, "res://assets/weapon_hammer.glb", 0.56, 0.0)
	if tool == null:
		return
	# молот висит головой вниз, как на поясе: +Y модели смотрит по кости вниз
	tool.rotation_degrees = Vector3(0, 0, 0)
	tool.position = Vector3.ZERO
	weapon_model = tool


func _add_blob_shadow(radius: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.2, radius * 2.2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0, 0, 0, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0.03, 0)
	add_child(mi)


func is_crouching() -> bool:
	return crouching


## Скорости с учётом ловкости: очки характеристик разгоняют шаг, бег и присед.
func walk_speed() -> float:
	return SPEED * GameState.move_speed_mult()


func run_speed() -> float:
	return RUN * GameState.move_speed_mult()


func crouch_speed() -> float:
	return CROUCH * GameState.move_speed_mult()


## Порог «уже бегу» — середина между шагом и бегом. Без него после вложений
## в ловкость обычный шаг переваливал бы за старые 4,4 м/с и включал бег.
func run_threshold() -> float:
	return (walk_speed() + run_speed()) * 0.5


## Множитель заметности: крадущийся шаг тише и незаметнее, бег — наоборот.
func visibility_mult() -> float:
	if crouching:
		return 0.6
	if Vector2(velocity.x, velocity.z).length() > walk_speed() + 0.3:
		return 1.4
	return 1.0


func noise_radius() -> float:
	if crouching:
		return Balance.NOISE_CROUCH
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > walk_speed() + 0.3:
		return Balance.NOISE_RUN
	if sp > 0.4:
		return Balance.NOISE_WALK
	return 0.0


## Событие шума: стража слышит его в радиусе и идёт проверять точку.
func emit_noise_at(pos: Vector3, radius: float) -> void:
	if radius <= 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != null and is_instance_valid(e) and e.has_method("hear_noise"):
			e.hear_noise(pos, radius)


func emit_noise(radius: float) -> void:
	emit_noise_at(global_position, radius)


func _throw_stone() -> void:
	distract_cd = Balance.DISTRACT_CD
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.05:
		fwd = Vector3(0, 0, 1)
	fwd = fwd.normalized()
	var start: Vector3 = global_position + Vector3(0, 1.2, 0) + fwd * 0.6
	var land: Vector3 = start + fwd * 8.0
	var q := PhysicsRayQueryParameters3D.create(start, land)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		land = hit.get("position", land) - fwd * 0.35
		land.y = 0.1
	var stone := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.09
	sph.height = 0.18
	stone.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.3, 0.28)
	m.roughness = 0.95
	stone.material_override = m
	get_tree().current_scene.add_child(stone)
	stone.global_position = start
	var peak: Vector3 = (start + land) * 0.5 + Vector3(0, 1.6, 0)
	var tw := create_tween()
	tw.tween_property(stone, "global_position", peak, 0.18)
	tw.tween_property(stone, "global_position", land, 0.18)
	tw.tween_callback(func():
		stone.queue_free()
		emit_noise_at(land, Balance.NOISE_THROW)
		Sfx.play_at("sfx_hit", land + Vector3(0, 0.1, 0), -16.0, 1.7))
	Sfx.play_at("sfx_swing", _sfx_pos(), -12.0, 1.5)


## Кровавый шип (Q): тратит магию и бьёт по направлению камеры.
func _cast_spike() -> void:
	if not GameState.spend_magic(Balance.SPIKE_COST):
		Sfx.play("sfx_lowmagic", -14.0)
		return
	spike_cd = Balance.SPIKE_CD
	_set_state("cast")
	Sfx.play_at("sfx_cast", _sfx_pos(), -8.0)
	emit_noise(Balance.NOISE_SPIKE)
	var dir := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		dir = -cam.global_transform.basis.z
	if dir.length() < 0.05:
		dir = -rig.global_transform.basis.z
	dir.y = 0.0
	_launch_spike(dir.normalized())


## Летит по прямой, гаснет о стену или о первого врага.
func _launch_spike(dir: Vector3) -> void:
	var start: Vector3 = global_position + Vector3(0, 1.15, 0) + dir * 0.6
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.14, 0.7)
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.07, 0.1)
	m.emission_enabled = true
	m.emission = Color(0.7, 0.05, 0.08)
	m.emission_energy_multiplier = 2.2
	m.roughness = 0.4
	mi.material_override = m
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.9, 0.15, 0.18)
	glow.light_energy = 0.9
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	mi.add_child(glow)
	get_tree().current_scene.add_child(mi)
	mi.global_position = start
	mi.look_at(start + dir, Vector3.UP)
	var space := get_world_3d().direct_space_state
	var pos := start
	var left: float = Balance.SPIKE_RANGE
	while left > 0.0:
		await get_tree().physics_frame
		if not is_instance_valid(mi):
			return
		if get_tree().paused:
			continue
		var step: float = minf(Balance.SPIKE_SPEED * get_physics_process_delta_time(), left)
		var next := pos + dir * step
		var q := PhysicsRayQueryParameters3D.create(pos, next)
		q.collision_mask = 1 | 4
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var body = hit.get("collider")
			if body != null and body.has_method("take_damage"):
				body.take_damage(Balance.SPIKE_DMG * GameState.spell_damage_mult(), global_position)
				_hitstop()
				_shake(0.9, 0.12, dir)
			_spike_hit_fx(next)
			mi.queue_free()
			return
		pos = next
		mi.global_position = pos
		left -= step
	mi.queue_free()


func _spike_hit_fx(pos: Vector3) -> void:
	Sfx.play_at("sfx_hit", pos, -8.0, 1.3)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.14
	sph.height = 0.28
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.05, 0.08, 0.85)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.03, 0.05)
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(2.2, 2.2, 2.2), 0.18)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(func(): mi.queue_free())


## Кровавая нова (R): кольцо урона вокруг героя. Открывается навыком на 4 уровне.
func _cast_nova() -> void:
	if GameState.skill_rank("blood_nova") <= 0:
		return
	if not GameState.spend_magic(Balance.NOVA_COST):
		Sfx.play("sfx_lowmagic", -14.0)
		return
	nova_cd = Balance.NOVA_CD
	_set_state("cast")
	Sfx.play_at("sfx_cast", _sfx_pos(), -6.0, 0.8)
	emit_noise(Balance.NOISE_SPIKE)
	var center := global_position
	var dmg: float = Balance.NOVA_DMG * GameState.spell_damage_mult()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - center
		to.y = 0.0
		if to.length() > Balance.NOVA_RADIUS:
			continue
		e.take_damage(dmg, center)
		if e.has_method("knockback") and to.length() > 0.05:
			e.knockback(to.normalized(), 6.0)
	_nova_fx(center)
	_shake(2.6, 0.18)
	_hitstop()


## Расходящееся кольцо крови: читается и в темноте, и на свету.
func _nova_fx(center: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.1
	ring.rings = 20
	ring.ring_segments = 12
	mi.mesh = ring
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.06, 0.1, 0.85)
	m.emission_enabled = true
	m.emission = Color(0.8, 0.06, 0.1)
	m.emission_energy_multiplier = 2.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = center + Vector3(0, 0.18, 0)
	var k: float = Balance.NOVA_RADIUS / 1.1
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(k, 1.0, k), 0.32)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.32)
	tw.tween_callback(mi.queue_free)


func _physics_process(delta: float) -> void:
	state_t += delta
	invuln = max(0.0, invuln - delta)
	distract_cd = max(0.0, distract_cd - delta)
	spike_cd = max(0.0, spike_cd - delta)
	nova_cd = max(0.0, nova_cd - delta)
	_update_safe_position(delta)
	if dead:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		velocity.y -= 18.0 * delta
		move_and_slide()
		return

	var input := Vector2.ZERO
	if control_enabled and not get_tree().paused:
		input = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		crouching = Input.is_action_pressed("crouch") and state not in ["attack", "heavy", "dodge", "hurt", "cast"]
	else:
		crouching = false
	var cam := get_viewport().get_camera_3d()
	var yaw := 0.0
	if cam:
		yaw = cam.global_rotation.y
	var dir := Vector3(input.x, 0, input.y)
	dir = dir.rotated(Vector3.UP, yaw)
	if dir.length() > 1.0:
		dir = dir.normalized()
	move_dir = dir

	var target_speed := 0.0
	match state:
		"dodge":
			# направление фиксируется в момент рывка, иначе рывок «загзает» за курсором
			velocity = dodge_dir * DODGE_SPEED * (1.0 - 0.3 * clampf(state_t / DODGE_TIME, 0.0, 1.0))
			if state_t > DODGE_TIME:
				_set_state("idle")
		"attack":
			target_speed = walk_speed() * 0.25
			if attack_phase == "active":
				target_speed = 0.0
			elif attack_phase == "recovery":
				target_speed = walk_speed() * 0.3
			if state_t >= 0.25 and not attack_done:
				attack_done = true
				_hit(false)
			_update_attack_phase(0.25, ATTACK_TIME)
			if state_t > ATTACK_TIME:
				if attack_queued and combo_step < 2:
					attack_queued = false
					combo_step += 1
					_start_attack()
				else:
					attack_queued = false
					combo_step = 0
					_set_state("idle")
		"heavy":
			target_speed = walk_speed() * 0.1
			if attack_phase == "active":
				target_speed = 0.0
			elif attack_phase == "recovery":
				target_speed = walk_speed() * 0.2
			if state_t >= HEAVY_WINDUP and not attack_done:
				attack_done = true
				_hit(true)
			_update_attack_phase(HEAVY_WINDUP, HEAVY_WINDUP + 0.3)
			if state_t > HEAVY_WINDUP + 0.3:
				_set_state("idle")
		"hurt":
			target_speed = 0.0
			if state_t > 0.35:
				_set_state("idle")
		"cast":
			# короткая пауза выброса руки — движение почти стоит
			target_speed = walk_speed() * 0.15
			if state_t > 0.35:
				_set_state("idle")
		_:
			var run := Input.is_action_pressed("sneak") and not crouching
			target_speed = crouch_speed() if crouching else (run_speed() if run else walk_speed())
			if input.length() < 0.1:
				target_speed = 0.0
	_handle_input()

	var desired := dir * target_speed
	if state != "dodge":
		# разгон резче торможения: остановка с ходу не должна быть «выключателем»
		var cur_speed := Vector2(velocity.x, velocity.z).length()
		var rate: float = ACCEL if desired.length() >= cur_speed else ACCEL * 0.75
		velocity.x = move_toward(velocity.x, desired.x, rate * delta)
		velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y -= 18.0 * delta
	if is_on_floor():
		velocity.y = 0.0
	move_and_slide()

	# поворот рига по движению; в начале удара/каста герой ещё доворачивается
	var can_turn: bool = dir.length() > 0.1 and (
		state in ["idle", "run"] or (state in ["attack", "heavy", "cast"] and state_t < 0.1))
	if can_turn:
		var want := atan2(-dir.x, -dir.z)
		var prev_yaw := rig.rotation.y
		rig.rotation.y = lerp_angle(rig.rotation.y, want, 12.0 * delta)
		var dy := wrapf(rig.rotation.y - prev_yaw, -PI, PI)
		turn_rate = lerp(turn_rate, dy / maxf(delta, 0.001), 8.0 * delta)
	else:
		turn_rate = lerp(turn_rate, 0.0, 8.0 * delta)
	_animate(delta)


func _handle_input() -> void:
	if not control_enabled:
		return
	if state in ["attack", "heavy"]:
		if state == "attack" and Input.is_action_just_pressed("attack") \
				and state_t >= ATTACK_TIME - 0.16:
			attack_queued = true
		if attack_phase == "recovery" and Input.is_action_just_pressed("dash"):
			if _start_dodge():
				attack_queued = false
				combo_step = 0
		return
	if state in ["dodge", "hurt", "cast"]:
		return
	if Input.is_action_just_pressed("distract") and distract_cd <= 0.0:
		_throw_stone()
		return
	if Input.is_action_just_pressed("spike") and spike_cd <= 0.0:
		_cast_spike()
		return
	if GameState.skill_rank("blood_nova") > 0 and InputMap.has_action("blood_nova") \
			and Input.is_action_just_pressed("blood_nova") and nova_cd <= 0.0:
		_cast_nova()
		return
	if Input.is_action_just_pressed("dash") and _start_dodge():
		return
	if Input.is_action_just_pressed("attack"):
		combo_step = 0
		_start_attack()
		return
	if Input.is_action_just_pressed("heavy"):
		_set_state("heavy")
		attack_done = false
		var fwd := -rig.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.05:
			velocity = fwd.normalized() * 4.0
		Sfx.play_at("sfx_swing", _sfx_pos(), -8.0, 0.8)


func _start_dodge() -> bool:
	if not GameState.spend_magic(GameState.dodge_cost()):
		return false
	if state in ["attack", "heavy"] and anim_tree != null and anim_has_slash:
		anim_tree.set("parameters/SlashShot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	dodge_dir = move_dir
	dodge_dir.y = 0.0
	if dodge_dir.length() < 0.1:
		dodge_dir = -rig.global_transform.basis.z
		dodge_dir.y = 0.0
	dodge_dir = dodge_dir.normalized()
	_set_state("dodge")
	invuln = Balance.HERO_INVULN_DODGE
	Sfx.play_at("sfx_swing", _sfx_pos(), -10.0, 1.4)
	return true


func _update_attack_phase(windup_end: float, attack_end: float) -> void:
	if state_t < windup_end:
		attack_phase = "windup"
	elif state_t < minf(windup_end + 0.10, attack_end):
		attack_phase = "active"
	else:
		attack_phase = "recovery"


func _start_attack() -> void:
	_set_state("attack")
	attack_done = false
	# раньше шаг комбо уходил в spread, и взмах играл со случайным тоном ±50%
	Sfx.play_at("sfx_swing", _sfx_pos(), -9.0, 0.92 + 0.06 * combo_step)


func _hit(heavy: bool) -> void:
	var step_mult := 1.0
	if not heavy:
		step_mult = [1.0, 14.0 / 12.0, 20.0 / 12.0][combo_step]
	var dmg := (HEAVY_DMG if heavy else LIGHT_DMG) * step_mult * GameState.craving_damage_mult()
	dmg *= GameState.melee_damage_mult()
	var reach := 2.6 if heavy else 2.2
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach * 0.62
	params.shape = sphere
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0) + fwd * reach * 0.55)
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := space.intersect_shape(params, 8)

	var hit_any := false
	var hit_pos := Vector3.ZERO
	var seen: Array = []
	for h in hits:
		var area = h.get("collider")
		if area == null:
			continue
		var enemy = area.get_meta("owner_enemy", null)
		if enemy == null or not is_instance_valid(enemy) or enemy.dead or seen.has(enemy):
			continue
		seen.append(enemy)
		enemy.take_damage(dmg, global_position)
		# разлёт: финальный удар комбо и тяжёлый (ПКМ) — тяжёлый отбрасывает сильнее
		if enemy.has_method("knockback") and (heavy or combo_step == 2):
			enemy.knockback(fwd, 8.5 if heavy else 5.0)
		hit_pos = enemy.global_position + Vector3(0, 1.1, 0)
		hit_any = true

	# страховка: если Area3D-хитбокс не сработал (например, враг без хуртбокса),
	# добираем попадания по группе врагов в пределах дуги
	if not hit_any:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var center: Vector3 = e.global_position + Vector3(0, 1.0, 0)
			var to: Vector3 = center - (global_position + Vector3(0, 1.0, 0))
			if to.length() > reach + 0.7:
				continue
			var flat := Vector3(to.x, 0, to.z)
			if flat.length() > 0.05 and fwd.dot(flat.normalized()) < 0.2:
				continue
			e.take_damage(dmg, global_position)
			if e.has_method("knockback") and (heavy or combo_step == 2):
				e.knockback(fwd, 8.5 if heavy else 5.0)
			hit_pos = center
			hit_any = true

	if hit_any:
		Sfx.play_at("sfx_hit_heavy" if heavy else "sfx_hit", hit_pos, -6.0)
		_impact(hit_pos, heavy)
		_hitstop()
		emit_noise(Balance.NOISE_HIT)
		# первые два удара комбо только помечают ритм, третий и тяжёлый бьют по камере
		_shake(2.6 if heavy else 0.45 + 0.9 * combo_step, 0.15,
			hit_pos - global_position)
	else:
		Sfx.play_at("sfx_swing", _sfx_pos(), -14.0, 1.2)


## Толкает камеру — главный способ «почувствовать» удар под ногами.
func _shake(amount: float, duration: float, impact_direction: Vector3 = Vector3.ZERO) -> void:
	var cam_node := get_tree().get_first_node_in_group("cam")
	if cam_node != null and cam_node.has_method("shake"):
		cam_node.shake(amount, duration, impact_direction)


## Точка у груди героя — откуда звучат его взмахи и шаги.
func _sfx_pos() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if invuln > 0.0 or dead:
		return
	invuln = 0.6
	GameState.damage(GameState.mitigate_damage(amount))
	_bark_damage()
	Sfx.play_at("sfx_hit", _sfx_pos(), -5.0)
	_set_state("hurt")
	_hitstop()
	var recoil := Vector3.ZERO
	if from != Vector3.ZERO:
		recoil = global_position - from
		recoil.y = 0.0
		if recoil.length_squared() > 0.0001:
			velocity = recoil.normalized() * 6.0
	_shake(2.2, 0.18, recoil)
	emit_noise(Balance.NOISE_HIT)
	if GameState.health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	Sfx.play("sfx_death", -4.0)
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -1.35, 0.6)
	tw.parallel().tween_property(rig, "position:y", 0.15, 0.6)
	died.emit()


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	attack_phase = "windup" if s in ["attack", "heavy"] else ""


func _animate(dt: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.4
	phase += dt * (6.0 if speed < run_threshold() else 8.5) * (1.0 if moving else 0.0)
	var swing := sin(phase)
	var amp: float = clampf(speed / run_speed(), 0.0, 1.0)

	var l_target := 0.0
	var r_target := 0.0
	var al := 0.0
	var ar := 0.0
	var elbow_l := 0.0
	var elbow_r := 0.0



	if state == "attack" or state == "heavy":
		var t: float = clampf(state_t / (ATTACK_TIME if state == "attack" else HEAVY_WINDUP + 0.3), 0.0, 1.0)
		var wind := 0.0
		var strike := 0.0
		if t < 0.4:
			wind = t / 0.4
			strike = 0.0
		else:
			wind = 1.0 - (t - 0.4) / 0.6
			strike = (t - 0.4) / 0.6
		ar = lerp(0.4, -2.2 - 0.5 * combo_step, wind) + strike * (3.0 + 0.6 * combo_step)
		al = -0.3 - strike * 0.4
		chest.rotation.y = lerp(0.0, 0.5, wind) - strike * 0.9
		chest.rotation.x = -0.15 + strike * 0.5
		head.rotation.x = 0.1
	elif state == "cast":
		# выброс правой руки вперёд — шип уходит по направлению камеры
		var ct: float = clampf(state_t / 0.35, 0.0, 1.0)
		ar = lerp(-0.5, -1.55, ct)
		elbow_r = -0.15
		al = -0.25
		chest.rotation.y = lerp(chest.rotation.y, 0.3, dt * 14.0)
		chest.rotation.x = lerp(chest.rotation.x, -0.1, dt * 12.0)
	else:
		chest.rotation.y = lerp(chest.rotation.y, 0.0, dt * 10.0)
		chest.rotation.x = lerp(chest.rotation.x, 0.0, dt * 10.0)
		head.rotation.x = lerp(head.rotation.x, 0.0, dt * 8.0)
		if moving:
			l_target = swing * 0.6 * amp
			r_target = -swing * 0.6 * amp
			al = -swing * 0.5 * amp
			ar = swing * 0.5 * amp
			elbow_l = max(0.0, -swing) * 0.7
			elbow_r = max(0.0, swing) * 0.7
			hips.position.y = 0.86 + abs(sin(phase * 2.0)) * 0.025 * amp
		else:
			l_target = sin(Time.get_ticks_msec() / 900.0) * 0.03
			r_target = -l_target
			al = sin(Time.get_ticks_msec() / 1100.0) * 0.05
			ar = -al
			hips.position.y = lerp(hips.position.y, 0.86, dt * 6.0)

	if state == "dodge":
		rig.rotation.x = lerp(rig.rotation.x, -0.35, dt * 14.0)
	else:
		rig.rotation.x = lerp(rig.rotation.x, 0.0, dt * 10.0)

	leg_l.rotation.x = lerp(leg_l.rotation.x, l_target, dt * 14.0)
	leg_r.rotation.x = lerp(leg_r.rotation.x, r_target, dt * 14.0)
	shin_l.rotation.x = lerp(shin_l.rotation.x, max(0.0, -swing) * 0.9 * amp, dt * 14.0)
	shin_r.rotation.x = lerp(shin_r.rotation.x, max(0.0, swing) * 0.9 * amp, dt * 14.0)
	arm_l.rotation.x = lerp(arm_l.rotation.x, al, dt * 14.0)
	forearm_l.rotation.x = lerp(forearm_l.rotation.x, elbow_l, dt * 14.0)
	if state != "attack" and state != "heavy":
		arm_r.rotation.x = lerp(arm_r.rotation.x, ar, dt * 14.0)
		forearm_r.rotation.x = lerp(forearm_r.rotation.x, elbow_r, dt * 14.0)
	else:
		arm_r.rotation.x = lerp(arm_r.rotation.x, ar, dt * 22.0)
		forearm_r.rotation.x = lerp(forearm_r.rotation.x, -0.3, dt * 18.0)

	# присед: ниже корпус, ближе к земле — меньше заметность и тише шаг
	if crouching and state not in ["attack", "heavy", "dodge", "hurt", "cast"]:
		hips.position.y = lerp(hips.position.y, 0.56, dt * 9.0)
		chest.rotation.x = lerp(chest.rotation.x, 0.3, dt * 8.0)
		head.rotation.x = lerp(head.rotation.x, -0.2, dt * 8.0)

	# шаги: каждый шаг — событие шума для стражи
	if moving and is_on_floor():
		step_t += dt
		if step_t > (0.55 if crouching else (0.42 if speed < run_threshold() else 0.3)):
			step_t = 0.0
			footsteps.volume_db = STEP_DB_CROUCH if crouching else STEP_DB
			footstep.emit(surface_under())
			emit_noise(noise_radius())

	if use_model:
		_animate_model(dt)
		return


## Анимации glTF-модели героя (Idle/Walk/Run/Sword_Slash/Roll/Death...).
func _build_anim_tree() -> void:
	if anim == null or anim_tree != null:
		return
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimTree"
	anim_tree.anim_player = NodePath("../" + anim.name)
	var p := anim.get_parent()
	if p:
		p.add_child(anim_tree)
	else:
		add_child(anim_tree)
	var blend_tree := AnimationNodeBlendTree.new()
	anim_tree.tree_root = blend_tree
	var idle := ModelUtil.pick_anim(anim, ["Idle"])
	var walk := ModelUtil.pick_anim(anim, ["Walk"])
	var run := ModelUtil.pick_anim(anim, ["Run"])
	var slash := ModelUtil.pick_anim(anim, ["Sword_Slash", "Slash", "Attack"])
	var roll := ModelUtil.pick_anim(anim, ["Roll"])
	var hit := ModelUtil.pick_anim(anim, ["HitRecieve", "HitReact"])
	var death := ModelUtil.pick_anim(anim, ["Death"])
	var base := ""
	if idle != "":
		var idle_node := AnimationNodeAnimation.new()
		idle_node.animation = idle
		var idle_clip: Animation = anim.get_animation(idle)
		if idle_clip != null:
			idle_clip.loop_mode = Animation.LOOP_LINEAR
		blend_tree.add_node("Idle", idle_node)
		base = "Idle"
	if walk != "":
		var walk_node := AnimationNodeAnimation.new()
		walk_node.animation = walk
		var walk_clip: Animation = anim.get_animation(walk)
		if walk_clip != null:
			walk_clip.loop_mode = Animation.LOOP_LINEAR
		blend_tree.add_node("Walk", walk_node)
		var walk_scale := AnimationNodeTimeScale.new()
		blend_tree.add_node("WalkScale", walk_scale)
		blend_tree.connect_node("WalkScale", 0, "Walk")
		anim_has_walk_scale = true
		if base == "":
			base = "WalkScale"
		else:
			blend_tree.add_node("IdleWalk", AnimationNodeBlend2.new())
			blend_tree.connect_node("IdleWalk", 0, base)
			blend_tree.connect_node("IdleWalk", 1, "WalkScale")
			base = "IdleWalk"
			anim_has_idle_walk_blend = true
	if run != "":
		var run_node := AnimationNodeAnimation.new()
		run_node.animation = run
		var run_clip: Animation = anim.get_animation(run)
		if run_clip != null:
			run_clip.loop_mode = Animation.LOOP_LINEAR
		blend_tree.add_node("Run", run_node)
		var run_scale := AnimationNodeTimeScale.new()
		blend_tree.add_node("RunScale", run_scale)
		blend_tree.connect_node("RunScale", 0, "Run")
		anim_has_run_scale = true
		if base == "":
			base = "RunScale"
		else:
			blend_tree.add_node("WalkRun", AnimationNodeBlend2.new())
			blend_tree.connect_node("WalkRun", 0, base)
			blend_tree.connect_node("WalkRun", 1, "RunScale")
			base = "WalkRun"
			anim_has_walk_run_blend = true
	if base == "":
		anim_tree.queue_free()
		anim_tree = null
		return
	if slash != "":
		slash_node = AnimationNodeAnimation.new()
		slash_node.animation = slash
		slash_node.use_custom_timeline = true
		slash_node.stretch_time_scale = true
		var slash_anim: Animation = anim.get_animation(slash)
		if slash_anim != null:
			slash_len = slash_anim.length
			slash_anim.loop_mode = Animation.LOOP_NONE
		slash_node.timeline_length = slash_len
		blend_tree.add_node("SlashClip", slash_node)
		var slash_shot := AnimationNodeOneShot.new()
		slash_shot.fadein_time = 0.12
		slash_shot.fadeout_time = 0.18
		blend_tree.add_node("SlashShot", slash_shot)
		blend_tree.connect_node("SlashShot", 0, base)
		blend_tree.connect_node("SlashShot", 1, "SlashClip")
		base = "SlashShot"
		anim_has_slash = true
	if roll != "":
		var roll_node := AnimationNodeAnimation.new()
		roll_node.animation = roll
		roll_node.use_custom_timeline = true
		roll_node.stretch_time_scale = true
		var roll_anim: Animation = anim.get_animation(roll)
		if roll_anim != null:
			# рывок длится DODGE_TIME (0.22 с): растянутый на 1.2 с Roll
			# держал бы цикл шага на паузе и герой «ехал» в позе кувырка
			roll_node.timeline_length = minf(roll_anim.length, 0.5)
			roll_anim.loop_mode = Animation.LOOP_NONE
		blend_tree.add_node("RollClip", roll_node)
		var roll_shot := AnimationNodeOneShot.new()
		roll_shot.fadein_time = 0.10
		roll_shot.fadeout_time = 0.22
		blend_tree.add_node("RollShot", roll_shot)
		blend_tree.connect_node("RollShot", 0, base)
		blend_tree.connect_node("RollShot", 1, "RollClip")
		base = "RollShot"
		anim_has_roll = true
	if hit != "":
		var hit_node := AnimationNodeAnimation.new()
		hit_node.animation = hit
		hit_node.use_custom_timeline = true
		hit_node.stretch_time_scale = true
		var hit_anim: Animation = anim.get_animation(hit)
		if hit_anim != null:
			hit_node.timeline_length = hit_anim.length / 1.1
			hit_anim.loop_mode = Animation.LOOP_NONE
		blend_tree.add_node("HitClip", hit_node)
		var hit_shot := AnimationNodeOneShot.new()
		# мягкий вход/выход: удар не «щёлкает» поверх шага
		hit_shot.fadein_time = 0.10
		hit_shot.fadeout_time = 0.18
		blend_tree.add_node("HitShot", hit_shot)
		blend_tree.connect_node("HitShot", 0, base)
		blend_tree.connect_node("HitShot", 1, "HitClip")
		base = "HitShot"
		anim_has_hit = true
	if death != "":
		var death_node := AnimationNodeAnimation.new()
		death_node.animation = death
		var death_anim: Animation = anim.get_animation(death)
		if death_anim != null:
			death_anim.loop_mode = Animation.LOOP_NONE
		blend_tree.add_node("Death", death_node)
		blend_tree.add_node("DeathSeek", AnimationNodeTimeSeek.new())
		blend_tree.connect_node("DeathSeek", 0, "Death")
		blend_tree.add_node("DeathBlend", AnimationNodeBlend2.new())
		blend_tree.connect_node("DeathBlend", 0, base)
		blend_tree.connect_node("DeathBlend", 1, "DeathSeek")
		base = "DeathBlend"
		anim_has_death = true
	blend_tree.connect_node("output", 0, base)
	anim_tree.active = true
	anim_tree.anim_player = anim.get_path()


func _animate_model(dt: float) -> void:
	if anim == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var walk_base: float = maxf(walk_speed(), 0.01)
	var run_base: float = maxf(run_speed(), walk_base)
	if anim_tree != null:
		anim_locomotion_blend = move_toward(anim_locomotion_blend,
			clampf(speed / walk_base, 0.0, 1.0), dt / 0.18)
		anim_run_blend = move_toward(anim_run_blend,
			clampf((speed / run_base - walk_base / run_base)
				/ maxf(1.0 - walk_base / run_base, 0.01), 0.0, 1.0), dt / 0.18)
		if anim_has_idle_walk_blend:
			anim_tree.set("parameters/IdleWalk/blend_amount",
				anim_locomotion_blend)
		if anim_has_walk_scale:
			anim_tree.set("parameters/WalkScale/scale",
				clampf(speed / walk_base, 0.7, 1.6))
		if anim_has_walk_run_blend:
			anim_tree.set("parameters/WalkRun/blend_amount",
				anim_run_blend)
		if anim_has_run_scale:
			anim_tree.set("parameters/RunScale/scale",
				clampf(speed / run_base, 0.7, 1.6))
		if anim_has_death:
			anim_death_blend = move_toward(anim_death_blend, 1.0 if dead else 0.0,
				dt / 0.15)
			anim_tree.set("parameters/DeathBlend/blend_amount", anim_death_blend)
	if dead:
		if anim_has_death and not anim_was_dead:
			anim_tree.set("parameters/DeathSeek/seek_request", 0.0)
		anim_was_dead = true
		if anim_tree == null:
			ModelUtil.play_key(anim, ["Death"], false)
		return
	anim_was_dead = false
	var prev_action := active_anim_action
	if state == "attack" or state == "heavy":
		if prev_action != "attack":
			_stop_action_shot(prev_action)
		var step := combo_step if state == "attack" else -1
		var sc := (2.0 + 0.08 * combo_step) if state == "attack" else 1.2
		if slash_node != null:
			slash_node.timeline_length = maxf(0.1, slash_len / sc)
		if anim_tree != null and anim_has_slash:
			if slash_step != step:
				anim_tree.set("parameters/SlashShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
				slash_step = step
		elif anim_tree == null:
			ModelUtil.play_key(anim, ["Sword_Slash", "Slash", "Attack"], false, sc,
				0.07 if state == "attack" else 0.10)
		active_anim_action = "attack"
		return
	slash_step = -99
	if state == "dodge":
		if prev_action != "dodge":
			_stop_action_shot(prev_action)
		if anim_tree != null and anim_has_roll:
			if active_anim_action != "dodge":
				anim_tree.set("parameters/RollShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		elif anim_tree == null:
			ModelUtil.play_key(anim, ["Roll"], false, 1.2, 0.06)
		active_anim_action = "dodge"
		return
	if state == "hurt":
		if prev_action != "hurt":
			_stop_action_shot(prev_action)
		if anim_tree != null and anim_has_hit:
			if active_anim_action != "hurt":
				anim_tree.set("parameters/HitShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		elif anim_tree == null:
			ModelUtil.play_key(anim, ["HitRecieve", "HitReact"], false, 1.1, 0.05)
		active_anim_action = "hurt"
		return
	# OneShot глушит базовый цикл шага, пока играет целиком, а клип удара
	# (1.6 с) заметно длиннее стана: по выходу из действия гасим его сами,
	# иначе герой скользит в позе урона и «шаги пропадают»
	_stop_action_shot(prev_action)
	active_anim_action = ""
	if anim_tree == null:
		if speed > 0.45:
			var running := speed > run_threshold()
			var base := run_speed() if running else walk_speed()
			ModelUtil.play_key(anim, ["Run"] if running else ["Walk"], true,
				clampf(speed / base, 0.7, 1.6), 0.2)
		else:
			ModelUtil.play_key(anim, ["Idle"], true, 1.0, 0.25)
	if model_root != null:
		var lean := -0.12 if state == "dodge" else 0.0
		if crouching and state not in ["attack", "heavy", "dodge"]:
			lean = 0.16
		model_root.rotation.x = lerp(model_root.rotation.x, lean, dt * 10.0)
		# крен в поворот: тело заваливается в сторону, а не «щёлкает» на 180°
		var roll: float = clampf(-turn_rate * 0.03, -0.22, 0.22)
		model_root.rotation.z = lerp(model_root.rotation.z, roll, dt * 9.0)


## Гасит OneShot завершённого действия: его базовый вход — весь цикл шага,
## и пока клип играет, он стоит на паузе.
func _stop_action_shot(action: String) -> void:
	if anim_tree == null:
		return
	match action:
		"attack":
			if anim_has_slash:
				anim_tree.set("parameters/SlashShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		"dodge":
			if anim_has_roll:
				anim_tree.set("parameters/RollShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		"hurt":
			if anim_has_hit:
				anim_tree.set("parameters/HitShot/request",
					AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


func _impact(pos: Vector3, heavy: bool) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16 if not heavy else 0.24
	sph.height = sph.radius * 2.0
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.25, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.15)
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(3.0, 3.0, 3.0), 0.16)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(mi.queue_free)


func _hitstop() -> void:
	if not hitstop_active:
		hitstop_restore_scale = Engine.time_scale
		hitstop_active = true
	hitstop_generation += 1
	var request_id: int = hitstop_generation
	Engine.time_scale = minf(Engine.time_scale, HITSTOP_TIME_SCALE)
	await get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout
	if request_id != hitstop_generation:
		return
	Engine.time_scale = hitstop_restore_scale
	hitstop_active = false


func _bark_damage() -> void:
	var mission := get_tree().current_scene
	if mission != null and mission.get("hud") != null:
		mission.hud.flash_damage()


func respawn_to_safe() -> void:
	if last_safe_position == Vector3.ZERO:
		return
	global_position = last_safe_position + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	if has_method("reset_physics_interpolation"):
		call("reset_physics_interpolation")


## Запоминает последнюю позицию, где герой стоял на полу, и возвращает его туда,
## если он провалился ниже уровня пола (страховка от дыр в геометрии).
func _update_safe_position(delta: float) -> void:
	_safe_timer += delta
	if _safe_timer >= 0.5:
		_safe_timer = 0.0
		if is_on_floor():
			last_safe_position = global_position
	if global_position.y < (lowest_floor_y - 15.0) and last_safe_position != Vector3.ZERO:
		respawn_to_safe()
