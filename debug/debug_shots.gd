extends Node
## Autoload "DebugShots". Debug builds only.
## F12 = single screenshot to user://shots/
## F11 = photo tour: visits every Node3D in group "photo_spot" and saves res://_screenshots/<stage>/<name>.png
## Command line: godot --path . -- --photo-tour [--photo-scene=res://path/level.tscn]
##   (stage name comes from env var SHOT_STAGE, default "manual")

const SETTLE_FRAMES := 45  # lets TAA / volumetric fog / SDFGI settle before capture

var _touring := false

func _ready() -> void:
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	if "--photo-tour" in args:
		for a in args:
			if a.begins_with("--photo-scene="):
				get_tree().change_scene_to_file.call_deferred(a.trim_prefix("--photo-scene="))
		await get_tree().create_timer(3.0).timeout
		await _run_tour()
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_save_shot("user://shots", Time.get_datetime_string_from_system().replace(":", "-"))
		elif event.keycode == KEY_F11 and not _touring:
			_run_tour()

func _save_shot(dir_path: String, file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir_path, file_name]
	var err := img.save_png(path)
	print("[DebugShots] saved ", path, " err=", err)

## Средний FPS и худший кадр за 120 кадров на текущей точке.
func _measure_fps(spot_name: String) -> void:
	var frames := 120
	var worst := 0
	var start := Time.get_ticks_usec()
	var prev := start
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - prev)
		prev = now
	var avg_fps := frames * 1000000.0 / float(prev - start)
	print("[DebugShots] fps %s avg=%.1f worst_frame_ms=%.1f" % [spot_name, avg_fps, worst / 1000.0])


## Бисекция FPS: эффекты этапа 7 выключаются по одному прямо в рантайме,
## на той же точке, без перезапуска. Строки «fps off_<эффект>» сравнивать
## с замером точки: прирост FPS — цена эффекта.
func _bisect_fx() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	var env: Environment = null
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		env = (we as WorldEnvironment).environment
	for kind in ["post_fx", "fx_dust", "fx_mist", "volfog", "taa", "msaa", "all"]:
		var restore := _set_fx(kind, false, vp, env)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		await _measure_fps("off_" + kind)
		restore.call()


## Выключает эффект и возвращает функцию, которая вернёт как было.
func _set_fx(kind: String, on: bool, vp: Viewport, env: Environment) -> Callable:
	match kind:
		"volfog":
			if env == null:
				return func(): pass
			var was := env.volumetric_fog_enabled
			env.volumetric_fog_enabled = on and was
			return func(): env.volumetric_fog_enabled = was
		"taa":
			var was := vp.use_taa
			vp.use_taa = on and was
			return func(): vp.use_taa = was
		"msaa":
			var was := vp.msaa_3d
			if not on:
				vp.msaa_3d = Viewport.MSAA_DISABLED
			return func(): vp.msaa_3d = was
		"all":
			var undo: Array[Callable] = []
			for k in ["post_fx", "fx_dust", "fx_mist", "volfog", "taa", "msaa"]:
				undo.append(_set_fx(k, on, vp, env))
			return func():
				for u in undo:
					u.call()
	# группы узлов: виньетка (CanvasLayer), пыль, коробки дымки
	var nodes := get_tree().get_nodes_in_group(kind)
	var shown := {}
	for n in nodes:
		shown[n] = n.get("visible")
		n.set("visible", on and shown[n])
	return func():
		for n in shown:
			if is_instance_valid(n):
				n.set("visible", shown[n])


## Прячет HUD на время съёмки; возвращает скрытые слои.
func _hide_hud() -> Array[CanvasLayer]:
	var hidden_layers: Array[CanvasLayer] = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		# пост-эффект (виньетка/зерно) — часть картинки, а не HUD
		if cl.visible and not cl.is_in_group("post_fx"):
			cl.visible = false
			hidden_layers.append(cl)
	return hidden_layers


func _run_tour() -> void:
	_touring = true
	var stage := OS.get_environment("SHOT_STAGE")
	if stage == "":
		stage = "manual"
	if stage.begins_with("stage9"):
		await _hero_tour(stage)
		_touring = false
		return
	var hidden_layers := _hide_hud()
	var original_cam := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	get_tree().current_scene.add_child(cam)
	if original_cam:
		cam.fov = original_cam.fov
		cam.near = original_cam.near
		cam.far = original_cam.far
	# SHOT_FPS=1 — после каждого кадра замер FPS на этой точке, без vsync
	var measure_fps := OS.get_environment("SHOT_FPS") == "1"
	if measure_fps:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("[DebugShots] viewport=", get_viewport().get_visible_rect().size)
	# SHOT_BISECT=1 — на первой точке ещё и цена каждого эффекта этапа 7
	var bisect := OS.get_environment("SHOT_BISECT") == "1"
	# SHOT_DRESS=only — только кадры этапа 8 (быстрая проверка)
	var spots: Array = [] if OS.get_environment("SHOT_DRESS") == "only" \
		else get_tree().get_nodes_in_group("photo_spot")
	for spot in spots:
		if spot is Node3D:
			cam.global_transform = (spot as Node3D).global_transform
			cam.make_current()
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
			_save_shot("res://_screenshots/" + stage, spot.name)
			if measure_fps:
				await _measure_fps(spot.name)
			if bisect:
				bisect = false
				await _bisect_fx()
	# SHOT_DRESS=1 — ещё кадры этапа 8: по одному на комнату и крупно факел
	if OS.get_environment("SHOT_DRESS") in ["1", "only"]:
		var dungeon := get_tree().get_first_node_in_group("dungeon")
		var dressing = dungeon.get("dressing") if dungeon else null
		if dressing:
			for v in dressing.views:
				cam.global_position = v["from"]
				cam.look_at(v["to"])
				cam.make_current()
				for i in SETTLE_FRAMES:
					await get_tree().process_frame
				_save_shot("res://_screenshots/" + stage, v["name"])
	cam.queue_free()
	if original_cam:
		original_cam.make_current()
	for cl in hidden_layers:
		cl.visible = true
	_touring = false


# ---------------------------------------------------------------------------
# этап 9: герой в мире

const TORCH_SCRIPT := "res://scenes/props/torch_flicker.gd"

var _step_log: Array[StringName] = []
var _last_step_ms := 0


## Тур этапа 9 снимает не фото-точки, а игровую камеру за героем: он идёт
## через лужу у факела и вдоль стены с факелом (шаги по скрипту, без ввода).
## Кадр снимается после шага нужной поверхности — в нём брызги или пыль.
## В лог: рост героя (отчёт о масштабе), поверхность каждого шага,
## амплитуда «дыхания» и пик/затухание тряски от удара.
func _hero_tour(stage: String) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Hero3D
	var cam := get_tree().get_first_node_in_group("cam") as Cam3D
	if hero == null or cam == null:
		push_warning("[DebugShots] stage9: нет героя или камеры")
		return
	var hidden_layers := _hide_hud()
	var dir_path := "res://_screenshots/" + stage
	hero.control_enabled = false
	hero.invuln = 9999.0
	hero.footstep.connect(_on_hero_step)
	_print_hero_scale(hero)

	var zone := _pick_puddle(hero)
	if zone != null:
		var at := zone.global_position
		var dir := _clear_dir(hero, at, 2.6)
		await _walk(hero, cam, at - dir * 2.2, dir, deg_to_rad(55.0))
		# в пятно ~1.5 м попадает обычно один шаг из трёх
		await _shoot_on_step(hero, dir_path, "puddle", FootstepFx.SURFACE_WATER, 1, 2.4)
	var torch := _pick_torch(hero)
	if not torch.is_empty():
		var along: Vector3 = torch["along"]
		# камера из зала спереди-сбоку: лицо героя смотрит в свет факела
		await _walk(hero, cam, torch["start"], along, deg_to_rad(40.0))
		await _shoot_on_step(hero, dir_path, "torch_walk", FootstepFx.SURFACE_STONE, 1, 1.6)
		await _wait(1.5)
		_save_shot(dir_path, "torch_idle")
		await _measure_sway(cam)
	await _measure_trauma(cam)
	print("[DebugShots] steps ", _step_log)
	hero.scripted_move = Vector3.ZERO
	hero.control_enabled = true
	for cl in hidden_layers:
		cl.visible = true


func _on_hero_step(surface: StringName) -> void:
	_step_log.append(surface)
	_last_step_ms = Time.get_ticks_msec()
	print("[DebugShots] footstep ", surface)


## Ставит героя, разворачивает камеру на него спереди-сбоку (cam_turn —
## угол от «прямо в лицо»), ждёт, пока кадр успокоится, и запускает шаг.
func _walk(hero: Hero3D, cam: Cam3D, start: Vector3, dir: Vector3, cam_turn: float) -> void:
	hero.scripted_move = Vector3.ZERO
	hero.velocity = Vector3.ZERO
	hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	hero.rig.rotation.y = atan2(-dir.x, -dir.z)
	var look := (-dir).rotated(Vector3.UP, cam_turn)
	cam.yaw = atan2(-look.x, -look.z)
	cam.pitch = deg_to_rad(-10.0)
	await _wait(1.0)
	hero.scripted_move = dir


## Ждёт шага по нужной поверхности и снимает кадр через 0.12 с — брызги
## или пыль ещё в воздухе. Не дождался за timeout — снимает как есть.
## В конце герой останавливается.
func _shoot_on_step(hero: Hero3D, dir_path: String, prefix: String, surface: StringName, shots: int, timeout: float) -> void:
	var taken := 0
	var start := Time.get_ticks_msec()
	var seen := _step_log.size()
	while taken < shots and Time.get_ticks_msec() - start < int(timeout * 1000.0):
		await get_tree().process_frame
		if _step_log.size() > seen and _step_log[-1] == surface \
				and Time.get_ticks_msec() - _last_step_ms >= 120:
			seen = _step_log.size()
			taken += 1
			_save_shot(dir_path, "%s_%d" % [prefix, taken])
	if taken == 0:
		print("[DebugShots] stage9: шаг ", surface, " не пойман, кадр без него")
		_save_shot(dir_path, prefix + "_0")
	hero.scripted_move = Vector3.ZERO


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Рост героя для отчёта о масштабе: кость головы и макушка шляпы.
## AABB скин-меша не годится — он в позе покоя (T-поза).
func _print_hero_scale(hero: Hero3D) -> void:
	var base := hero.global_position.y
	var head_y := -1.0
	var sk := ModelUtil.find_skeleton(hero)
	if sk != null:
		for bone in ["Head", "mixamorig_Head", "head"]:
			var i := sk.find_bone(bone)
			if i >= 0:
				head_y = (sk.global_transform * sk.get_bone_global_pose(i)).origin.y - base
				break
	var hat_y := -1.0
	for hat in hero.find_children("GnomeHat", "", true, false):
		for mi in ModelUtil.meshes(hat):
			var m: MeshInstance3D = mi
			hat_y = maxf(hat_y, (m.global_transform * m.get_aabb()).end.y - base)
	print("[DebugShots] SCALE model_height=%.2f head_bone=%.2f hat_top=%.2f" % [
		Balance.HERO_MODEL_HEIGHT, head_y, hat_y])


## Лужа ближе всех к факелу: шаг через неё виден и в свете, и в отражении.
func _pick_puddle(hero: Hero3D) -> Node3D:
	var torches := _torch_lights()
	var best: Node3D = null
	var best_d := INF
	for z in get_tree().get_nodes_in_group("water_zone"):
		var zone := z as Node3D
		if _clear_dir(hero, zone.global_position, 2.6) == Vector3.ZERO:
			continue
		var d := INF
		for l in torches:
			d = minf(d, zone.global_position.distance_to(l.global_position))
		if d < best_d:
			best_d = d
			best = zone
	return best


## Направление, свободное на `need` метров в обе стороны от точки.
func _clear_dir(hero: Hero3D, at: Vector3, need: float) -> Vector3:
	for i in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, i * PI / 4.0)
		if _clear_line(hero, at, d, need):
			return d
	return Vector3.ZERO


## Луч на высоте груди в обе стороны по `d` не встречает стен.
func _clear_line(hero: Hero3D, at: Vector3, d: Vector3, need: float) -> bool:
	var space := hero.get_world_3d().direct_space_state
	for s in [1.0, -1.0]:
		var from := Vector3(at.x, 0.8, at.z)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * s * need, 1)
		q.exclude = [hero.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	return true


func _torch_lights() -> Array[Node3D]:
	var res: Array[Node3D] = []
	for n in get_tree().current_scene.find_children("*", "OmniLight3D", true, false):
		var s: Script = n.get_script()
		if s != null and s.resource_path == TORCH_SCRIPT:
			res.append(n)
	return res


## Настенный факел, вдоль стены которого есть 4.8 м свободного пола:
## герой идёт в 1.3 м от кладки, камера смотрит на стену из зала.
func _pick_torch(hero: Hero3D) -> Dictionary:
	var space := hero.get_world_3d().direct_space_state
	var lights := _torch_lights()
	lights.sort_custom(func(a, b):
		return a.global_position.distance_to(hero.global_position) \
			< b.global_position.distance_to(hero.global_position))
	for l in lights:
		var p: Vector3 = l.global_position
		for i in 4:
			var d := Vector3.FORWARD.rotated(Vector3.UP, i * PI / 2.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + d * 1.0, 1))
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"]
			n.y = 0.0
			n = n.normalized()
			var along := n.cross(Vector3.UP).normalized()
			var mid := Vector3(p.x, 0.0, p.z) + n * 1.3
			if _clear_line(hero, mid, along, 2.4):
				return {"start": mid - along * 2.0, "along": along}
	return {}


## Дыхание стоящего героя: размах наклона пивота за 4.5 с (ожидание ±0.3°).
func _measure_sway(cam: Cam3D) -> void:
	var lo := INF
	var hi := -INF
	var t := 0.0
	while t < 4.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		lo = minf(lo, cam._life_rot.x)
		hi = maxf(hi, cam._life_rot.x)
	print("[DebugShots] sway pitch_deg min=%.3f max=%.3f" % [rad_to_deg(lo), rad_to_deg(hi)])


## Тряска от тяжёлого удара (травма 1.0): пик поворота по рысканью/крену,
## время до нуля и то, что выключенная настройка травму не принимает.
func _measure_trauma(cam: Cam3D) -> void:
	var was := Settings.camera_shake
	Settings.camera_shake = true
	cam.add_trauma(1.0)
	var peak := 0.0
	var t := 0.0
	var zero_at := -1.0
	while t < 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		peak = maxf(peak, maxf(absf(cam._life_rot.y), absf(cam._life_rot.z)))
		if zero_at < 0.0 and cam.trauma <= 0.0:
			zero_at = t
	Settings.camera_shake = false
	cam.add_trauma(1.0)
	var blocked := cam.trauma
	Settings.camera_shake = was
	print("[DebugShots] trauma peak_deg=%.3f zero_after_s=%.3f trauma_when_disabled=%.2f" % [
		rad_to_deg(peak), zero_at, blocked])
