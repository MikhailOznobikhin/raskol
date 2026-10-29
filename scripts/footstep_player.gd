extends AudioStreamPlayer3D
class_name FootstepPlayer
## Шаги героя (этап 10): на каждую поверхность свой AudioStreamRandomizer —
## тон 0.9–1.1, громкость ±2 дБ, один файл дважды подряд не звучит.
## Слушает сигнал Hero3D.footstep(surface).

const SURFACES := {
	"stone": ["res://audio/footsteps/step_stone_%d.wav", 5],
	"water": ["res://audio/footsteps/step_water_%d.wav", 4],
	"wood": ["res://audio/footsteps/step_wood_%d.wav", 5],
}

var _sets := {}


func _ready() -> void:
	name = "Footsteps"
	bus = "Footsteps"
	area_mask = Sfx.AUDIO_ZONE_MASK
	attenuation_model = ATTENUATION_INVERSE_DISTANCE
	unit_size = 3.0
	max_distance = Sfx.LISTEN_RANGE
	for surface in SURFACES:
		var pattern: String = SURFACES[surface][0]
		var rnd := AudioStreamRandomizer.new()
		rnd.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		# random_pitch — множитель: 1.1 даёт тон от 1/1.1 до 1.1.
		rnd.random_pitch = 1.1
		rnd.random_volume_offset_db = 2.0
		for i in int(SURFACES[surface][1]):
			var path := pattern % i
			if ResourceLoader.exists(path):
				rnd.add_stream(-1, load(path))
		if rnd.streams_count > 0:
			_sets[surface] = rnd


func on_footstep(surface: String) -> void:
	var s: AudioStream = _sets.get(surface, _sets.get("stone"))
	if s == null:
		return
	stream = s
	play()
