extends Node
## Загрузчик графики: собирает SpriteFrames из манифеста и кэширует текстуры.

const MANIFEST_PATH := "res://assets/sprites/manifest.json"

var manifest: Dictionary = {}
var char_cache: Dictionary = {}
var tex_cache: Dictionary = {}


func _ready() -> void:
	_load_manifest()


func _load_manifest() -> void:
	var txt := FileAccess.get_file_as_string(MANIFEST_PATH)
	if txt.is_empty():
		push_error("Не найден манифест спрайтов: " + MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		manifest = parsed
	else:
		push_error("Манифест спрайтов повреждён")


func tex(path: String) -> Texture2D:
	if tex_cache.has(path):
		return tex_cache[path]
	var t: Texture2D = load(path)
	tex_cache[path] = t
	return t


## SpriteFrames для персонажа: Art.frames("hero", "down", "walk")
func frames(char_name: String, dir: String, anim: String) -> SpriteFrames:
	var key := "%s|%s|%s" % [char_name, dir, anim]
	if char_cache.has(key):
		return char_cache[key]
	var sf := SpriteFrames.new()
	var data: Dictionary = manifest.get("characters", {}).get(char_name, {}) \
		.get("dirs", {}).get(dir, {}).get(anim, {})
	if data.is_empty():
		push_warning("Нет анимации %s / %s / %s" % [char_name, dir, anim])
		sf.add_animation("default")
		return sf
	var fw: int = manifest.get("frame", [48, 64])[0]
	var fh: int = manifest.get("frame", [48, 64])[1]
	var sheet: Texture2D = tex(data["sheet"])
	var count: int = int(data.get("frames", 1))
	var fps: float = float(data.get("fps", 8.0))
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, not (anim in ["attack", "heavy", "cast", "dash", "hurt", "dead"]))
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, at)
	char_cache[key] = sf
	return sf


## Удобный конструктор анимированного спрайта.
func make_sprite(char_name: String, dir := "down", anim := "idle") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(char_name, dir, anim)
	s.animation = anim
	s.play(anim)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
