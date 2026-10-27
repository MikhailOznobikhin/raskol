extends Node
## Настройки видео: разрешение окна и полноэкранный режим.
## Хранятся в user://settings.cfg, применяются при старте и сразу при изменении.

signal changed

const CONFIG_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const RES_LABELS: Array[String] = ["1280×720", "1600×900", "1920×1080", "2560×1440"]

var resolution_index := 0
var fullscreen := true


func _ready() -> void:
	load_settings()
	# режим скриншотов (--shots) снимает окно в разрешении из --resolution,
	# иначе сохранённый user://settings.cfg ломает воспроизводимость кадров
	if OS.get_cmdline_user_args().has("--shots"):
		return
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution_index = clampi(int(cfg.get_value("video", "resolution", 0)), 0, RESOLUTIONS.size() - 1)
	fullscreen = bool(cfg.get_value("video", "fullscreen", true))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution", resolution_index)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(CONFIG_PATH)


## Применяет настройки к окну. 3D рендерится в размер окна,
## 2D-UI растягивается из 1280×720 (canvas_items), поэтому HUD не ломается.
func apply() -> void:
	# в headless (build.ps1 -Test) окна нет — настройки видео пропускаем
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var want := RESOLUTIONS[resolution_index]
		var screen := DisplayServer.screen_get_size()
		want.x = mini(want.x, screen.x)
		want.y = mini(want.y, screen.y)
		DisplayServer.window_set_size(want)
		var real := DisplayServer.window_get_size()
		DisplayServer.window_set_position(Vector2i(
			maxi(0, (screen.x - real.x) / 2),
			maxi(0, (screen.y - real.y) / 2)))
	changed.emit()


func resolution_label() -> String:
	return RES_LABELS[resolution_index]


func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	save_settings()
	apply()


func cycle_resolution(step: int) -> void:
	var n := RESOLUTIONS.size()
	set_resolution((resolution_index + step + n) % n)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	save_settings()
	apply()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)
