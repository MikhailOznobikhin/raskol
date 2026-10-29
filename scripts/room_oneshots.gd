extends Node3D
class_name RoomOneShots
## Случайные звуки комнаты (этап 10): раз в 8–25 с из случайной точки
## комнаты звучит далёкий гул, звон цепи, писк крысы, осыпь или капель.
## Один и тот же вид звука дважды подряд не повторяется.

const SOUNDS := {
	"rumble": ["res://audio/oneshots/rumble_distant_0.wav", "res://audio/oneshots/rumble_distant_1.wav"],
	"chain": ["res://audio/oneshots/chain_clink_0.wav", "res://audio/oneshots/chain_clink_1.wav"],
	"rat": ["res://audio/oneshots/rat_squeak_0.wav", "res://audio/oneshots/rat_squeak_1.wav"],
	"stone": ["res://audio/oneshots/stone_fall_0.wav", "res://audio/oneshots/stone_fall_1.wav"],
	"drip": ["res://audio/oneshots/drip_distant_0.wav", "res://audio/oneshots/drip_distant_1.wav"],
}

@export var min_interval := 8.0
@export var max_interval := 25.0
## Центры клеток комнаты в мировых координатах; точка звука — случайная
## клетка плюс сдвиг внутри неё.
var cells: Array[Vector3] = []
var cell_size := 2.0
var height_range := Vector2(0.4, 3.5)
var last_kind := ""

static var _streams := {}
var _player: AudioStreamPlayer3D
var _timer: Timer


func _ready() -> void:
	if _streams.is_empty():
		for kind in SOUNDS:
			var list: Array[AudioStream] = []
			for path in SOUNDS[kind]:
				if ResourceLoader.exists(path):
					list.append(load(path))
			if not list.is_empty():
				_streams[kind] = list
	_player = AudioStreamPlayer3D.new()
	_player.bus = "Ambience"
	_player.area_mask = Sfx.AUDIO_ZONE_MASK
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	# Звуки «далёкие», но комната их держит: слышно из любой её точки.
	_player.unit_size = 4.0
	_player.max_distance = 40.0
	add_child(_player)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	# Первый звук — в случайный момент интервала, иначе все комнаты уровня
	# отзовутся в одну и ту же секунду после загрузки.
	_timer.start(randf_range(0.0, max_interval))


func _on_timeout() -> void:
	play_random()
	_timer.start(randf_range(min_interval, max_interval))


## Проигрывает случайный звук и возвращает его вид (для автотеста).
func play_random() -> String:
	if cells.is_empty() or _streams.is_empty():
		return ""
	var kinds: Array = _streams.keys()
	if kinds.size() > 1:
		kinds.erase(last_kind)
	var kind: String = kinds.pick_random()
	last_kind = kind
	var c: Vector3 = cells.pick_random()
	var half := cell_size * 0.45
	_player.global_position = c + Vector3(randf_range(-half, half),
		randf_range(height_range.x, height_range.y), randf_range(-half, half))
	_player.stream = (_streams[kind] as Array).pick_random()
	_player.volume_db = randf_range(-12.0, -6.0)
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()
	return kind
