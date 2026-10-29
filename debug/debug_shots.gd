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


func _run_tour() -> void:
	_touring = true
	var stage := OS.get_environment("SHOT_STAGE")
	if stage == "":
		stage = "manual"
	# hide HUD while capturing
	var hidden_layers: Array[CanvasLayer] = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		# пост-эффект (виньетка/зерно) — часть картинки, а не HUD
		if cl.visible and not cl.is_in_group("post_fx"):
			cl.visible = false
			hidden_layers.append(cl)
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
