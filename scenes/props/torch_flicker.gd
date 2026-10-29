extends OmniLight3D
## Мерцание факела: энергия ±flicker_amount по 1D-шуму и дрожание лампы на
## полтора сантиметра — тени «живут», но без стробоскопа.

@export var base_energy := 2.5
@export var flicker_amount := 0.18      # ±18 %
@export var flicker_speed := 9.0
@export var jitter_cm := 1.5
var _noise := FastNoiseLite.new()
var _t := 0.0
var _base_pos: Vector3


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_t = randf() * 100.0
	_base_pos = position


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	var n := _noise.get_noise_1d(_t)                   # -1..1
	light_energy = base_energy * (1.0 + n * flicker_amount)
	position = _base_pos + Vector3(_noise.get_noise_1d(_t + 37.0), _noise.get_noise_1d(_t + 71.0), 0.0) * jitter_cm * 0.01
