extends Node
## Настройки: разрешение окна, полноэкранный режим, громкость, графика.
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
## Сила покачивания камеры: 0 — выключено, 1 — максимум. По умолчанию
## оставляем лёгкое (35%), потому что полный bob укачивает в узких коридорах.
var camera_bob := 0.20
const BOB_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
## Тряска камеры от ударов, урона и обвалов (Cam3D.shake/add_trauma).
## Выключение не трогает покачивание и дыхание — у них своя строка.
var camera_shake := true

## Общая громкость 0..1. По умолчанию 0 — игра стартует без звука.
## В debug-сборке глушим принудительно на каждом запуске (см. _ready).
var volume := 0.0
const VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

## Графика. Пресет задаёт дорогие эффекты разом; правка отдельной строки
## переводит его в «СВОЁ». Цена эффектов замерена на этапе 7 (visual_log):
## MSAA −9 FPS (в меню не выносится, выключен), TAA −5..7, объёмный туман
## −4..5, дымка с пылью −5, SSR/SSIL — по замерам этапов 5–6.
## Масштаб 3D и виньетка — вкус и железо игрока, пресет их не трогает.
const QUALITY_LABELS: Array[String] = ["НИЗКОЕ", "СРЕДНЕЕ", "ВЫСОКОЕ", "СВОЁ"]
const QUALITY_CUSTOM := 3
const PRESETS: Array[Dictionary] = [
	{"aa": 1, "shadows": 0, "volfog": false, "air": false, "ssr": false, "ssil": false},
	{"aa": 2, "shadows": 1, "volfog": true, "air": false, "ssr": false, "ssil": true},
	{"aa": 2, "shadows": 2, "volfog": true, "air": true, "ssr": true, "ssil": true},
]
const AA_LABELS: Array[String] = ["ВЫКЛ", "FXAA", "TAA"]
const SCALE_STEPS: Array[float] = [1.0, 0.85, 0.7]
const SHADOW_LABELS: Array[String] = ["НИЗКИЕ", "СРЕДНИЕ", "ВЫСОКИЕ"]
## Сколько ближайших огней отбрасывают тени (у уровня ещё свой лимит,
## Dungeon.shadow_budget) и мягкость теней.
const SHADOW_LIMITS: Array[int] = [2, 4, 99]
const SHADOW_FILTERS: Array[int] = [
	RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
]
## По умолчанию — «ВЫСОКОЕ»: так настроены этапы 5–7.
var quality := 2
var gfx: Dictionary = PRESETS[2].duplicate()
var render_scale := 0
var post_fx := true


func _ready() -> void:
	load_settings()
	# в debug-сборке (редактор, --test3d, --shots) звук всегда выключен на старте,
	# иначе запуск из редактора бьёт по ушам. Поднять громкость можно в настройках,
	# но следующий запуск снова тихий.
	if OS.is_debug_build():
		volume = 0.0
	apply_audio()
	# SHOT_QUALITY=0|1|2 — съёмка и замер FPS на нужном пресете
	var shot_q := OS.get_environment("SHOT_QUALITY")
	if _reference_run() and shot_q.is_valid_int():
		quality = clampi(int(shot_q), 0, PRESETS.size() - 1)
		gfx = PRESETS[quality].duplicate()
	apply_graphics()
	# режим скриншотов (--shots) снимает окно в разрешении из --resolution,
	# иначе сохранённый user://settings.cfg ломает воспроизводимость кадров
	if OS.get_cmdline_user_args().has("--shots"):
		return
	apply()


## Съёмка кадров (--shots, фототур) идёт на графике по умолчанию, а не на
## той, что игрок выставил у себя: иначе кадры этапов несравнимы.
func _reference_run() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--shots") or args.has("--photo-tour")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution_index = clampi(int(cfg.get_value("video", "resolution", 0)), 0, RESOLUTIONS.size() - 1)
	fullscreen = bool(cfg.get_value("video", "fullscreen", true))
	camera_bob = clampf(float(cfg.get_value("camera", "bob", 0.35)), 0.0, 1.0)
	camera_shake = bool(cfg.get_value("camera", "shake", true))
	volume = clampf(float(cfg.get_value("audio", "volume", 0.0)), 0.0, 1.0)
	if _reference_run():
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", 2)), 0, QUALITY_CUSTOM)
	for key in gfx:
		var v = cfg.get_value("graphics", key, gfx[key])
		gfx[key] = bool(v) if gfx[key] is bool else clampi(int(v), 0, 2)
	render_scale = clampi(int(cfg.get_value("graphics", "render_scale", 0)), 0, SCALE_STEPS.size() - 1)
	post_fx = bool(cfg.get_value("graphics", "post_fx", true))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution", resolution_index)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("camera", "bob", camera_bob)
	cfg.set_value("camera", "shake", camera_shake)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("graphics", "quality", quality)
	for key in gfx:
		cfg.set_value("graphics", key, gfx[key])
	cfg.set_value("graphics", "render_scale", render_scale)
	cfg.set_value("graphics", "post_fx", post_fx)
	cfg.save(CONFIG_PATH)


## Громкость через шину Master: Sfx, Voice и лупы идут в неё,
## поэтому одного места хватает на музыку, шаги и озвучку.
func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(volume, 0.001, 1.0)))


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


func bob_label() -> String:
	if camera_bob <= 0.001:
		return "ВЫКЛ"
	return "%d%%" % int(round(camera_bob * 100.0))


func set_camera_bob(value: float) -> void:
	camera_bob = clampf(value, 0.0, 1.0)
	save_settings()
	changed.emit()


func toggle_camera_shake() -> void:
	camera_shake = not camera_shake
	save_settings()
	changed.emit()


func cycle_camera_bob(step: int) -> void:
	if step > 0:
		for v in BOB_STEPS:
			if v > camera_bob + 0.001:
				set_camera_bob(v)
				return
		set_camera_bob(1.0)
	else:
		for i in range(BOB_STEPS.size() - 1, -1, -1):
			if BOB_STEPS[i] < camera_bob - 0.001:
				set_camera_bob(BOB_STEPS[i])
				return
		set_camera_bob(0.0)


func volume_label() -> String:
	if volume <= 0.001:
		return "ВЫКЛ"
	return "%d%%" % int(round(volume * 100.0))


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	save_settings()
	apply_audio()
	changed.emit()


func cycle_volume(step: int) -> void:
	if step > 0:
		for v in VOLUME_STEPS:
			if v > volume + 0.001:
				set_volume(v)
				return
		set_volume(1.0)
	else:
		for i in range(VOLUME_STEPS.size() - 1, -1, -1):
			if VOLUME_STEPS[i] < volume - 0.001:
				set_volume(VOLUME_STEPS[i])
				return
		set_volume(0.0)


# ---------------------------------------------------------------------------
# графика

## Применяет графику к корневому вьюпорту, общему окружению и узлам
## эффектов уже построенного уровня. Новый уровень берёт значения сам:
## Dungeon.make_world_environment() зовёт apply_environment(), а дымка,
## пыль и виньетка при создании смотрят в gfx / post_fx.
func apply_graphics() -> void:
	var vp := get_tree().root
	vp.use_taa = gfx["aa"] == 2
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if gfx["aa"] == 1 \
		else Viewport.SCREEN_SPACE_AA_DISABLED
	var s := SCALE_STEPS[render_scale]
	# FSR 1.0 почти бесплатен и резче билинейного апскейла
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.999 \
		else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = s
	RenderingServer.positional_soft_shadow_filter_set_quality(
		SHADOW_FILTERS[gfx["shadows"]] as RenderingServer.ShadowQuality)
	apply_environment(load(Dungeon.ENV_PATH))
	for group in ["fx_mist", "fx_dust"]:
		for n in get_tree().get_nodes_in_group(group):
			n.set("visible", gfx["air"])
	for n in get_tree().get_nodes_in_group("post_fx"):
		n.set("visible", post_fx)
	changed.emit()


## Дорогие эффекты общего окружения. Ресурс один на все уровни, поэтому
## правка видна сразу и в текущем уровне, и в следующем (пока он в кэше).
func apply_environment(env: Environment) -> void:
	if env == null:
		return
	env.volumetric_fog_enabled = gfx["volfog"]
	env.ssr_enabled = gfx["ssr"]
	env.ssil_enabled = gfx["ssil"]


## Сколько ближайших огней могут отбрасывать тени (Dungeon берёт минимум
## со своим лимитом уровня).
func shadow_limit() -> int:
	return SHADOW_LIMITS[gfx["shadows"]]


func quality_label() -> String:
	return QUALITY_LABELS[quality]


func cycle_quality(step: int) -> void:
	# «СВОЁ» выбирается не стрелками, а правкой отдельной строки
	var n := PRESETS.size()
	var from := quality if quality < n else 2
	quality = (from + step + n) % n
	gfx = PRESETS[quality].duplicate()
	_graphics_changed()


func gfx_label(key: String) -> String:
	match key:
		"aa":
			return AA_LABELS[gfx["aa"]]
		"shadows":
			return SHADOW_LABELS[gfx["shadows"]]
		"render_scale":
			return "%d%%" % int(round(SCALE_STEPS[render_scale] * 100.0))
		"post_fx":
			return "ВКЛ" if post_fx else "ВЫКЛ"
	return "ВКЛ" if gfx[key] else "ВЫКЛ"


## Включена ли строка (для приглушения в меню).
func gfx_on(key: String) -> bool:
	match key:
		"render_scale":
			return render_scale == 0
		"post_fx":
			return post_fx
		"aa":
			return gfx["aa"] != 0
		"shadows":
			return true
	return gfx[key]


func cycle_gfx(key: String, step: int) -> void:
	match key:
		"render_scale":
			# стрелка вправо — чётче, то есть к 100 %
			render_scale = clampi(render_scale - step, 0, SCALE_STEPS.size() - 1)
		"post_fx":
			post_fx = not post_fx
		"aa", "shadows":
			gfx[key] = (gfx[key] + step + 3) % 3
		_:
			gfx[key] = not gfx[key]
	if key in PRESETS[0]:
		quality = PRESETS.find(gfx) if PRESETS.has(gfx) else QUALITY_CUSTOM
	_graphics_changed()


func _graphics_changed() -> void:
	save_settings()
	apply_graphics()
