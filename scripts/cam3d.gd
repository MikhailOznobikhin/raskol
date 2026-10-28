extends Node3D
## Камера от третьего лица: орбита вокруг героя, пружина с коллизией.

class_name Cam3D

## Максимальная амплитуда покачивания при 100% настройки. Раньше 0.022 м
## складывались с FOV-киком и тряской в «болтанку» уже на обычном шаге.
const MAX_BOB := 0.004
const BASE_FOV := 70.0

var target: Node3D
var yaw := 0.0
var pitch := -0.10
var sensitivity := 0.0028
var spring: SpringArm3D
var camera: Camera3D
var shake_amp := 0.0
var shake_t := 0.0
var shake_duration := 0.0
var shake_phase := 0.0
var shake_dir := Vector2.RIGHT
var cam_h := 1.55
var follow := Vector3.ZERO
var follow_ready := false
var bob_t := 0.0
var bob_amp := 0.0


func _ready() -> void:
	add_to_group("cam")
	spring = SpringArm3D.new()
	spring.spring_length = 4.0
	spring.margin = 0.25
	spring.collision_mask = 1
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.position = Vector3(0.45, 0.10, 0.0)
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

	# «походный свет» у камеры: подсвечивает то, на что смотрит игрок,
	# и вытаскивает силуэт героя из темноты
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.9)
	lamp.light_energy = 1.7
	lamp.omni_range = 12.0
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = false
	camera.add_child(lamp)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -0.95, 0.55)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		# присед опускает камеру — игрок физически «становится ниже» в укрытии
		var want := 1.55
		if target.has_method("is_crouching") and target.is_crouching():
			want = 1.15
		cam_h = lerp(cam_h, want, delta * 7.0)
		var desired := target.global_position + Vector3(0, cam_h, 0)
		if not follow_ready or follow.distance_to(desired) > 3.0:
			follow = desired
			follow_ready = true
		else:
			# лёгкое отставание: камера перестаёт быть приклеенной к герою
			follow = follow.lerp(desired, 1.0 - exp(-12.0 * delta))
		global_position = follow
		# на беге камера чуть расширяет угол — добавляет ощущение скорости
		var speed := 0.0
		if target is CharacterBody3D:
			var v: Vector3 = (target as CharacterBody3D).velocity
			speed = Vector2(v.x, v.z).length()
		var want_fov: float = BASE_FOV + clampf(speed - 4.4, 0.0, 2.5) * 0.4
		camera.fov = lerp(camera.fov, want_fov, 4.0 * delta)
		# Покачивание: настройка из Settings, по умолчанию 35%. Даже на 100%
		# амплитуда меньше прежней; горизонталь почти не уводит кадр.
		var bob_setting: float = Settings.camera_bob
		var want_bob: float = clampf((speed - 1.2) / 5.0, 0.0, 1.0) * MAX_BOB * bob_setting
		bob_amp = lerp(bob_amp, want_bob, 3.0 * delta)
		bob_t += delta * (5.5 + speed * 0.5)
	rotation = Vector3(pitch, yaw, 0)
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


func shake(amount: float, duration: float, impact_direction: Vector3 = Vector3.ZERO) -> void:
	if amount <= 0.0 or duration <= 0.0:
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
