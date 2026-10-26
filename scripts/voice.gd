extends Node
## Автолоад Voice: озвучка реплик диалогов (Фаза 5.5 ROADMAP).
##
## Текст реплики ищется в assets/text/voice_manifest.json → id →
## assets/audio/voice/<id>.ogg. Файла нет (CI/до генерации) — просто
## субтитры, ничего не ломается. Отключение: флаг `--novoice`.
## Правки диалогов не требуются: hud.say сам зовёт play_for().

var enabled := true

var _index: Dictionary = {}           # текст реплики -> id из манифеста
var _player: AudioStreamPlayer = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -4.0
	add_child(_player)
	for a in OS.get_cmdline_user_args():
		if a == "--novoice":
			enabled = false
	_load_index()


func _load_index() -> void:
	var f := FileAccess.open("res://assets/text/voice_manifest.json",
			FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Voice: voice_manifest.json не распарсился")
		return
	var lines = parsed.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		return
	for line in lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var text := String(line.get("text", "")).strip_edges()
		var id := String(line.get("id", ""))
		if text != "" and id != "":
			_index[text] = id


## Играть озвучку для данного текста реплики (если она озвучена).
func play_for(text: String) -> void:
	_player.stop()                       # перебить предыдущую реплику
	if not enabled:
		return
	var id: String = _index.get(text.strip_edges(), "")
	if id == "":
		return
	var path := "res://assets/audio/voice/%s.ogg" % id
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


func stop() -> void:
	_player.stop()
