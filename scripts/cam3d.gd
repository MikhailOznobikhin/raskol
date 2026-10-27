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
		# 0.012 — даже shake(8) даёт около 0.1 м, а не «землетрясение»
		camera.h_offset = randf_range(-shake_amp, shake_amp) * 0.012
		camera.v_offset = randf_range(-shake_amp, shake_amp) * 0.012
		shake_amp = maxf(0.0, shake_amp - delta * 20.0)
	else:
		camera.h_offset = lerp(camera.h_offset, 0.0, delta * 10.0)
		camera.v_offset = lerp(camera.v_offset, 0.0, delta * 10.0)
	# покачивание добавляем поверх тряски: position камеры принадлежит SpringArm3D
	camera.h_offset += sin(bob_t) * bob_amp * 0.25
	camera.v_offset += sin(bob_t * 2.0) * bob_amp


func shake(amount: float, duration: float) -> void:
	shake_amp = maxf(shake_amp, amount)
	shake_t = maxf(shake_t, duration)
