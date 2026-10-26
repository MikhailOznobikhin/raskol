extends Node
## Звук: пул проигрывателей, лупы, рандомизация тона.

const DIR := "res://assets/audio/"
const POOL_SIZE := 14

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _loops: Dictionary = {}
var muted := false


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	_cache[name] = s
	return s


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if muted:
		return
	var s := _stream(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_varied(name: String, volume_db := 0.0, spread := 0.08) -> void:
	play(name, volume_db, 1.0 + randf_range(-spread, spread))


## Зацикленный эмбиент/музыка. Возвращает ключ для stop_loop.
func loop(name: String, volume_db := -8.0, fade := 0.6) -> AudioStreamPlayer:
	if _loops.has(name):
		return _loops[name]
	var s := _stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.loop_end <= 0:
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	p.stream = s
	p.volume_db = -60.0
	add_child(p)
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", volume_db, fade)
	_loops[name] = p
	return p


func stop_loop(name: String, fade := 0.7) -> void:
	if not _loops.has(name):
		return
	var p: AudioStreamPlayer = _loops[name]
	_loops.erase(name)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_loops(fade := 0.5) -> void:
	for k in _loops.keys():
		stop_loop(k, fade)
