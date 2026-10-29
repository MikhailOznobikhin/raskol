extends AudioStreamPlayer3D
## Треск факела (этап 10): луп стартует со случайного места, иначе все
## факелы уровня трещат в унисон и слух сразу ловит повтор.


func _ready() -> void:
	area_mask = Sfx.AUDIO_ZONE_MASK
	if stream != null:
		play(randf() * stream.get_length())
