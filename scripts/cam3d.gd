extends Node3D
## Камера от третьего лица: орбита вокруг героя на двух пружинах.
##
## Дерево узлов (камера НЕ ребёнок героя — mission3d/level2_play создают её
## отдельным узлом и двигают за целью, публичный API сохранён):
##   Cam3D            — «пивот»: yaw/pitch, стоит на высоте плеча героя
##   └─ ShoulderArm   — SpringArm3D, смотрит вправо (+X), 0.35 м, шар r=0.2
##      └─ CameraArm  — SpringArm3D, смотрит назад (+Z пивота), 3.2 м, шар r=0.25
##         └─ Camera3D
##
## Смещение «через плечо» стоит ДО основной пружины и проверяется коллизией:
## смещение, приложенное к камере после пружины, вылезало сквозь стены.
##
## Длина основной пружины не константа: при взгляде вниз/вверх она укорачивается
## по косинусу угла. Так камера не уходит сквозь свод (в коридорах потолок ниже
## 3,2 м, а полной коллизии у свода нет) и одновременно не «отлётывает» в стену.
##
## Возврат после препятствия: внутрь — мгновенно (иначе кадр проходит сквозь
## стену), наружу — плавно (4 м/с), чтобы камера не «выстреливала» из угла.

class_name Cam3D

## Максимальная амплитуда покачивания при 100% настройки. Раньше 0.022 м
## складывались с FOV-киком и тряской в «болтанку» уже на обычном шаге.
const MAX_BOB := 0.004
const BASE_FOV := 70.0
## Длина пружины камеры (максимум, при взгляде «в горизонт»).
const ARM_LENGTH := 3.2
const ARM_RADIUS := 0.25
const ARM_MARGIN := 0.05
## Смещение через плечо и его пружина.
const SHOULDER_OFFSET := 0.35
const SHOULDER_RADIUS := 0.2
## world_static (1) + props_dynamic (8): своды/стены и крупный реквизит.
## NPC (4), игрок (2) и триггеры (16) в маску не входят.
const COLLIDE_MASK := 1 | 8
## Пределы наклона: вниз смотрим сильнее, чем вверх — подземелье низкое.
const PITCH_MIN := deg_to_rad(-65.0)
const PITCH_MAX := deg_to_rad(30.0)
const DEFAULT_PITCH := deg_to_rad(-12.0)
## Высота пивота: 0.85 от роста Торвина (Balance.HERO_MODEL_HEIGHT = 1.42).
const PIVOT_HEIGHT := 1.21
const CROUCH_HEIGHT := 0.95
## Скорости возврата пружины, м/с.
const RETURN_SPEED := 4.0
const SHORTEN_SPEED := 14.0
## Камера вжалась в героя — прячем шляпу, чтобы не закрывала весь кадр.
const NEAR_HIDE := 0.6
const NEAR_SHOW := 0.8
const HERO_ALPHA := 0.6
## Реквизит между камерой и головой героя становится полупрозрачным.
const PROP_ALPHA := 0.7
const FADE_TIME := 0.15
const FADE_RANGE := 14.0
const PROP_MAX_SIZE := 2.5
## «Дыхание» в покое (этап 9): пивот кивает на ±0.3° с частотой 0.25 Гц.
## Выключается вместе с покачиванием (Settings.camera_bob = 0).
const SWAY_PITCH := deg_to_rad(0.3)
const SWAY_HZ := 0.25
## Тряска от удара молотом: травма 0..1 крутит пивот до 0.6° (квадрат
## травмы — слабые удары почти не видны) и гаснет с 1 до 0 за 0.25 с.
const TRAUMA_MAX_ROT := deg_to_rad(0.6)
const TRAUMA_DECAY := 1.0 / 0.25
## Скорость бега по шуму: ~20 рывков в секунду — дрожь, а не качка.
const TRAUMA_NOISE_SPEED := 20.0

const POST_FX_SCENE := "res://scenes/fx/post_fx.tscn"

var target: Node3D
var yaw := 0.0
var pitch := DEFAULT_PITCH
## Чувствительность мыши (рад на пиксель) и стика (рад в секунду при полном отклонении).
var sensitivity := 0.0028
var gamepad_sensitivity := 2.6
var invert_y := false
## Основная пружина (камера). Имя сохранено: снаружи на неё никто не опирается,
## но диагностика и старые скрипты ищут именно `spring`.
var spring: SpringArm3D
var shoulder: SpringArm3D
var camera: Camera3D
var shake_amp := 0.0
var shake_t := 0.0
var shake_duration := 0.0
var shake_phase := 0.0
var shake_dir := Vector2.RIGHT
var cam_h := PIVOT_HEIGHT
var follow := Vector3.ZERO
var follow_ready := false
var bob_t := 0.0
var bob_amp := 0.0
## Текущая (сглаженная) длина основной пружины, м.
var arm_length := ARM_LENGTH
var trauma := 0.0
## Поворот «жизни» камеры (дыхание + травма) поверх yaw/pitch игрока.
var _life_rot := Vector3.ZERO
var _sway_t := 0.0
var _sway_w := 0.0
var _trauma_t := 0.0
var _trauma_noise := FastNoiseLite.new()

## RID героя, исключённый из обеих пружин (иначе камера липнет к его капсуле).
var _excluded_rid := RID()
## Меши героя: при вжатой пружине гасим их прозрачностью.
var _hero_meshes: Array[GeometryInstance3D] = []
var _hero_faded := false
## Кандидаты на «проявление» между камерой и героем (мелкий реквизит).
var _fade_nodes: Array[MeshInstance3D] = []
var _fade_root: Node = null
## Текущая прозрачность реквизита: instance_id -> alpha.
var _fade_alpha := {}


func _ready() -> void:
	add_to_group("cam")
	_trauma_noise.seed = randi()
	_trauma_noise.frequency = 1.0
	shoulder = SpringArm3D.new()
	shoulder.name = "ShoulderArm"
	# Пружина тянет детей по своему локальному +Z, поэтому поворот на +90°
	# по Y направляет её вправо (+X пивота) — «через плечо».
	shoulder.rotation.y = PI * 0.5
	shoulder.spring_length = SHOULDER_OFFSET
	shoulder.margin = 0.0
	shoulder.collision_mask = 1
	var shoulder_shape := SphereShape3D.new()
	shoulder_shape.radius = SHOULDER_RADIUS
	shoulder.shape = shoulder_shape
	add_child(shoulder)

	spring = SpringArm3D.new()
	spring.name = "CameraArm"
	# Компенсация поворота плеча: своя ось +Z снова смотрит назад по пивоту.
	spring.rotation.y = -PI * 0.5
	spring.spring_length = arm_length
	spring.margin = ARM_MARGIN
	spring.collision_mask = COLLIDE_MASK
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = ARM_RADIUS
	spring.shape = arm_shape
	shoulder.add_child(spring)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = BASE_FOV
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	# DOF дальнего плана: размывается только глубина залов дальше 25 м —
	# граница отодвинута, чтобы блюр не схватывал половину кадра подземелья
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 25.0
	attrs.dof_blur_far_transition = 5.0
	attrs.dof_blur_amount = 0.05
	camera.attributes = attrs
	spring.add_child(camera)

	# «Походный свет» камеры (белый, 1.7, радиус 12 м) снят на этапе 6: он
	# ровно заливал всё, на что смотрит игрок, и гасил пятна света факелов.
	# Силуэт героя держит слабая лампа самого героя (Hero3D._add_readability_light).

	# Виньетка и зерно (этап 7): canvas-слой -1 — поверх 3D, под любым UI.
	if Dungeon.air_fx_on("post"):
		var post := (load(POST_FX_SCENE) as PackedScene).instantiate() as CanvasLayer
		post.visible = Settings.post_fx
		add_child(post)

	_sync_exclusion()
	call_deferred("_collect_fade_candidates")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		var dy: float = event.relative.y * sensitivity
		pitch += dy if invert_y else -dy
		pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		_sync_exclusion()
		_update_pivot(delta)
		_apply_gamepad_look(delta)
	rotation = Vector3(pitch, yaw, 0) + _life_rot
	_update_arm(delta)
	_update_props(delta)
	_update_hero_visibility()


func _process(delta: float) -> void:
	var speed := 0.0
	if target and is_instance_valid(target):
		# на беге камера чуть расширяет угол — добавляет ощущение скорости
		if target is CharacterBody3D:
			var v: Vector3 = (target as CharacterBody3D).velocity
			speed = Vector2(v.x, v.z).length()
		var want_fov: float = BASE_FOV + clampf(speed - 4.4, 0.0, 2.5) * 0.4
		camera.fov = lerp(camera.fov, want_fov, 4.0 * delta)
		# Покачивание: настройка из Settings, по умолчанию 20%. Даже на 100%
		# амплитуда меньше прежней; горизонталь почти не уводит кадр.
		var bob_setting: float = Settings.camera_bob
		var want_bob: float = clampf((speed - 1.2) / 5.0, 0.0, 1.0) * MAX_BOB * bob_setting
		bob_amp = lerp(bob_amp, want_bob, 3.0 * delta)
		bob_t += delta * (5.5 + speed * 0.5)
	if shake_t > 0.0:
		shake_t -= delta
		shake_phase += delta * TAU * 24.0
		var fade: float = clampf(shake_t / maxf(shake_duration, 0.001), 0.0, 1.0)
		var impulse: float = sin(shake_phase) * fade * shake_amp * 0.012
		camera.h_offset = shake_dir.x * impulse
		camera.v_offset = shake_dir.y * impulse
	else:
		shake_amp = 0.0
		shake_duration = 0.0
		camera.h_offset = lerp(camera.h_offset, 0.0, delta * 10.0)
		camera.v_offset = lerp(camera.v_offset, 0.0, delta * 10.0)
	# покачивание добавляем поверх тряски: position камеры принадлежит SpringArm3D
	camera.h_offset += sin(bob_t) * bob_amp * 0.25
	camera.v_offset += sin(bob_t * 2.0) * bob_amp
	_update_life(delta, speed)
	# и в кадре отрисовки: физический такт (60 Гц) реже кадра, без этого
	# дыхание и травма шли бы ступеньками
	rotation = Vector3(pitch, yaw, 0) + _life_rot


## Дыхание стоящего героя и поворотная тряска от удара (этап 9).
## Оба слагаемых — поворот пивота, а не смещение камеры: смещение вбок у
## стены просовывало кадр в кладку, поворот пружина отрабатывает сама.
func _update_life(delta: float, speed: float) -> void:
	var breathe: bool = speed < 0.3 and Settings.camera_bob > 0.001
	# вес дыхания набирается за ~1.5 с: шаг→стоп не дёргает кадр
	_sway_w = move_toward(_sway_w, 1.0 if breathe else 0.0, delta / 1.5)
	_sway_t = fmod(_sway_t + delta, 1.0 / SWAY_HZ)
	var sway: float = sin(_sway_t * TAU * SWAY_HZ) * SWAY_PITCH * _sway_w
	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	var k: float = trauma * trauma * TRAUMA_MAX_ROT
	var shake_rot := Vector3.ZERO
	if k > 0.0:
		_trauma_t += delta * TRAUMA_NOISE_SPEED
		# симплекс-шум редко выходит за ±0.5: ×2 и обрезка — пик действительно 0.6°
		shake_rot = (Vector3(
			_trauma_noise.get_noise_2d(_trauma_t, 0.0),
			_trauma_noise.get_noise_2d(_trauma_t, 50.0),
			_trauma_noise.get_noise_2d(_trauma_t, 100.0)) * 2.0).clamp(-Vector3.ONE, Vector3.ONE) * k
	_life_rot = Vector3(sway, 0.0, 0.0) + shake_rot


## Удар молотом: травма копится и гаснет сама (TRAUMA_DECAY).
## Настройка «ТРЯСКА КАМЕРЫ: ВЫКЛ» отключает её вместе с shake().
func add_trauma(amount: float) -> void:
	if not Settings.camera_shake:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Пивот идёт за героем в физическом такте — в том же, где двигается
## CharacterBody3D, иначе на лестницах камера дёргается.
func _update_pivot(delta: float) -> void:
	# присед опускает камеру — игрок физически «становится ниже» в укрытии
	var want := PIVOT_HEIGHT
	if target.has_method("is_crouching") and target.is_crouching():
		want = CROUCH_HEIGHT
	cam_h = lerp(cam_h, want, delta * 7.0)
	var desired := target.global_position + Vector3(0, cam_h, 0)
	if not follow_ready or follow.distance_to(desired) > 3.0:
		# телепорт (респавн, загрузка, переход): догоняем сразу, без «полёта»
		follow = desired
		follow_ready = true
	else:
		# лёгкое отставание: камера перестаёт быть приклеенной к герою
		follow = follow.lerp(desired, 1.0 - exp(-12.0 * delta))
	global_position = follow


## Правый стик геймпада, если он подключён. Действия InputMap не нужны:
## стик читается напрямую, клавиатурные действия не затрагиваются.
func _apply_gamepad_look(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var gx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var gy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(gx) < 0.15:
		gx = 0.0
	if absf(gy) < 0.15:
		gy = 0.0
	if gx == 0.0 and gy == 0.0:
		return
	yaw -= gx * gamepad_sensitivity * delta
	var dy: float = gy * gamepad_sensitivity * delta
	pitch += dy if invert_y else -dy
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


## Длина пружины: цель зависит от наклона (см. шапку файла). Внутрь —
## мгновенно, наружу — плавно.
func _update_arm(delta: float) -> void:
	spring.spring_length = arm_length
	var want: float = ARM_LENGTH * clampf(cos(pitch), 0.3, 1.0)
	var hit: float = spring.get_hit_length()
	if hit < arm_length - 0.001:
		# препятствие: вжимаемся сразу, иначе кадр проходит сквозь стену
		arm_length = hit
	else:
		var speed := RETURN_SPEED if want > arm_length else SHORTEN_SPEED
		arm_length = move_toward(arm_length, want, speed * delta)
	spring.spring_length = arm_length


## Реквизит на линии «камера — голова героя» гасится до 30% непрозрачности.
## Стены не трогаем: их отрабатывает пружина. Кандидаты — меши без коллизии
## (у бочек/ящиков/столов её нет вовсе), поэтому проверка геометрическая:
## отрезок против локального AABB меша.
func _update_props(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var scene := get_tree().current_scene
	if scene != _fade_root:
		_collect_fade_candidates()
	var from := camera.global_position
	var to := target.global_position + Vector3(0, 1.35, 0)
	var step := delta / FADE_TIME
	for mi in _fade_nodes:
		if mi == null or not is_instance_valid(mi) or not mi.is_visible_in_tree():
			continue
		var id := mi.get_instance_id()
		var target_alpha := 0.0
		var center := mi.global_transform * mi.get_aabb().get_center()
		if center.distance_to(from) < FADE_RANGE:
			var inv := mi.global_transform.affine_inverse()
			if mi.get_aabb().intersects_segment(inv * from, inv * to) != null:
				target_alpha = PROP_ALPHA
		var cur: float = _fade_alpha.get(id, 0.0)
		if is_equal_approx(cur, target_alpha):
			continue
		cur = move_toward(cur, target_alpha, step)
		_fade_alpha[id] = cur
		mi.transparency = cur


## Список мешей-реквизита: только дети текущей сцены, только мелкие
## (стены/пол/свод отсекаются по размеру), без мешей героя.
func _collect_fade_candidates() -> void:
	_fade_nodes.clear()
	_fade_alpha.clear()
	_fade_root = get_tree().current_scene
	if _fade_root == null:
		return
	for n in _fade_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if target != null and is_instance_valid(target) \
				and (mi == target or target.is_ancestor_of(mi) or mi.is_ancestor_of(target)):
			continue
		var size := mi.get_aabb().size
		if maxf(size.x, maxf(size.y, size.z)) > PROP_MAX_SIZE:
			continue
		_fade_nodes.append(mi)


## Если пружина вжата в героя — гасим его меши, чтобы шляпа не занимала кадр.
func _update_hero_visibility() -> void:
	if target == null or not is_instance_valid(target):
		return
	if _hero_meshes.is_empty():
		for n in target.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if gi != null:
				_hero_meshes.append(gi)
		if _hero_meshes.is_empty():
			return
	if not _hero_faded and arm_length < NEAR_HIDE:
		_hero_faded = true
	elif _hero_faded and arm_length > NEAR_SHOW:
		_hero_faded = false
	var alpha: float = HERO_ALPHA if _hero_faded else 0.0
	for gi in _hero_meshes:
		if is_instance_valid(gi) and not is_equal_approx(gi.transparency, alpha):
			gi.transparency = alpha


## Обе пружины не должны цеплять капсулу героя.
func _sync_exclusion() -> void:
	if target == null or not is_instance_valid(target) or not target is CollisionObject3D:
		return
	var rid: RID = (target as CollisionObject3D).get_rid()
	if rid == _excluded_rid:
		return
	_excluded_rid = rid
	shoulder.add_excluded_object(rid)
	spring.add_excluded_object(rid)


func shake(amount: float, duration: float, impact_direction: Vector3 = Vector3.ZERO) -> void:
	if amount <= 0.0 or duration <= 0.0 or not Settings.camera_shake:
		return
	if impact_direction.length_squared() > 0.0001:
		var right: Vector3 = camera.global_transform.basis.x
		var up: Vector3 = camera.global_transform.basis.y
		var screen_dir := Vector2(
			-impact_direction.dot(right),
			impact_direction.dot(up)
		)
		if screen_dir.length_squared() > 0.0001:
			shake_dir = screen_dir.normalized()
	else:
		shake_dir = Vector2.RIGHT
	shake_amp = maxf(shake_amp, amount)
	shake_t = maxf(shake_t, duration)
	shake_duration = maxf(shake_duration, duration)
