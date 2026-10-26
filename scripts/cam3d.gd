extends Node3D
## Камера от третьего лица: орбита вокруг героя, пружина с коллизией.

class_name Cam3D

var target: Node3D
var yaw := 0.0
var pitch := -0.12
var sensitivity := 0.0028
var spring: SpringArm3D
var camera: Camera3D
var shake_amp := 0.0
var shake_t := 0.0


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = 4.4
	spring.margin = 0.25
	spring.collision_mask = 1
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0.65, 0.1, 0.0)
	camera.current = true
	spring.add_child(camera)

	# «походный свет» у камеры: подсвечивает то, на что смотрит игрок,
	# и вытаскивает силуэт героя из темноты
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.9, 0.78)
	lamp.light_energy = 2.2
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
		global_position = target.global_position + Vector3(0, 1.65, 0)
	rotation = Vector3(pitch, yaw, 0)
	if shake_t > 0.0:
		shake_t -= delta
		camera.h_offset = randf_range(-shake_amp, shake_amp) * 0.06
		camera.v_offset = randf_range(-shake_amp, shake_amp) * 0.06
		shake_amp = maxf(0.0, shake_amp - delta * 20.0)
	else:
		camera.h_offset = lerp(camera.h_offset, 0.0, delta * 10.0)
		camera.v_offset = lerp(camera.v_offset, 0.0, delta * 10.0)


func shake(amount: float, duration: float) -> void:
	shake_amp = maxf(shake_amp, amount)
	shake_t = maxf(shake_t, duration)
