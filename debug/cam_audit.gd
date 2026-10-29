extends SceneTree
## Аудит камеры Stage 2: гоняет героя по клеткам уровня, крутит yaw на 360°
## и проверяет, что камера не оказывается внутри стены, вне уровня и не
## упирается в стену вплотную. Запуск:
##   godot --headless --path . --script res://debug/cam_audit.gd
## Печатает строки AUDIT и итог AUDIT RESULT=..., код выхода не используем
## (headless-скрипт всегда завершается через quit()).

const YAW_STEPS := 8
const PITCHES: Array[float] = [deg_to_rad(-65.0), deg_to_rad(-12.0), deg_to_rad(25.0)]
const SETTLE_FRAMES := 3


class Runner extends Node:
	var mission: Node
	var dungeon: Node
	var hero: CharacterBody3D
	var cam: Node
	var spots: Array[Vector3] = []
	var spot_i := 0
	var yaw_i := 0
	var pitch_i := 0
	var wait := 0
	var total := 0
	var ticks := 0
	var bad_inside := 0
	var bad_outside := 0
	var bad_close := 0
	var prop_faded := 0
	var arm_min := 99.0
	var arm_squeezed := 0
	var worst_inside: Array[String] = []
	var worst_outside: Array[String] = []
	var worst_close: Array[String] = []

	func _ready() -> void:
		var m: Node = load("res://scripts/mission3d.gd").new()
		mission = m
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		dungeon = m.get("dungeon")
		hero = m.get("hero")
		cam = m.get("cam")
		if dungeon == null or hero == null or cam == null:
			print("AUDIT RESULT=FAIL (mission did not build)")
			get_tree().quit()
			return
		# Стража только мешает замеру (двигается, бьёт, шумит).
		for e in m.get("enemies"):
			if is_instance_valid(e):
				e.queue_free()
		hero.set_physics_process(false)
		_fill_spots()
		print("AUDIT spots=", spots.size(), " yaw_steps=", YAW_STEPS, " pitches=", PITCHES.size())

	func _fill_spots() -> void:
		var map_w: int = dungeon.get("map_w")
		var map_h: int = dungeon.get("map_h")
		var grid: Array = dungeon.get("grid")
		var t: float = 2.0
		var edge: Array[Vector3] = []
		var center: Array[Vector3] = []
		for y in map_h:
			for x in map_w:
				if grid[y][x]:
					continue
				var wall_near := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= map_w or ny >= map_h or grid[ny][nx]:
						wall_near = true
				var p := Vector3((x + 0.5) * t, 0.05, (y + 0.5) * t)
				if wall_near:
					edge.append(p)
				elif (x + y) % 5 == 0:
					center.append(p)
		# Каждая 9-я клетка у стены (углы, двери, тупики) + редкие центры залов.
		var i := 0
		while i < edge.size() and spots.size() < 34:
			spots.append(edge[i])
			i += 19
		i = 0
		while i < center.size() and spots.size() < 44:
			spots.append(center[i])
			i += 3

	func _physics_process(_delta: float) -> void:
		ticks += 1
		if ticks > 30000:
			print("AUDIT RESULT=FAIL (watchdog: samples=", total, ")")
			get_tree().quit()
			return
		if spots.is_empty():
			print("AUDIT RESULT=FAIL (no walkable spots)")
			get_tree().quit()
			return
		if wait > 0:
			wait -= 1
			if wait == 0:
				_measure()
			return
		if spot_i >= spots.size():
			_report()
			return
		_place()
		wait = SETTLE_FRAMES

	func _place() -> void:
		var p := spots[spot_i]
		hero.global_position = p
		hero.velocity = Vector3.ZERO
		cam.set("pitch", PITCHES[pitch_i])
		cam.set("yaw", TAU * float(yaw_i) / float(YAW_STEPS))
		# Сбрасываем пружину в полную длину: проверяем худший случай, а не
		# «камера уже была поджата с прошлой точки».
		if cam.get("arm_length") != null:
			cam.set("arm_length", 3.2)
		var spring: SpringArm3D = cam.get("spring")
		if spring != null:
			spring.spring_length = 4.0 if cam.get("arm_length") == null else 3.2

	func _cam_arm() -> float:
		var a: Variant = cam.get("arm_length")
		if a != null:
			return float(a)
		var spring: SpringArm3D = cam.get("spring")
		return spring.spring_length if spring != null else 0.0

	func _measure() -> void:
		var camera: Camera3D = cam.get("camera")
		var pos := camera.global_position
		var tag := "spot=%s yaw=%.0f pitch=%.0f" % [
			str(spots[spot_i]), rad_to_deg(TAU * float(yaw_i) / float(YAW_STEPS)),
			rad_to_deg(PITCHES[pitch_i])]
		total += 1
		var arm := _cam_arm()
		arm_min = minf(arm_min, arm)
		if arm < 0.62:
			arm_squeezed += 1
		var space := get_viewport().world_3d.direct_space_state
		var pq := PhysicsPointQueryParameters3D.new()
		pq.position = pos
		pq.collision_mask = 1
		pq.collide_with_bodies = true
		pq.collide_with_areas = false
		if not space.intersect_point(pq, 4).is_empty():
			bad_inside += 1
			if worst_inside.size() < 6:
				worst_inside.append(tag + " cam=" + str(pos))
		var map_w: int = dungeon.get("map_w")
		var map_h: int = dungeon.get("map_h")
		var cx := int(floor(pos.x / 2.0))
		var cz := int(floor(pos.z / 2.0))
		var out := pos.y > 4.9 or pos.y < -0.4
		out = out or cx < 0 or cz < 0 or cx >= map_w or cz >= map_h
		if not out and pos.y > float(dungeon.call("cell_ceil", cx, cz)) + 0.15:
			# Над локальным сводом — то есть вне помещения, в пустоте.
			out = true
		# Клетка m1.txt «камень» — это НЕ сплошной блок: модуль кладки стоит
		# лицевой поверхностью на FACE_Z (1.88 м) в глубь клетки, а полоса перед
		# ним — проходимая ниша (коллизия кладки тоже на FACE_Z). Поэтому вместо
		# проверки по сетке проверяем функционально: между камерой и плечом героя
		# не должно быть кладки. Если камера за стеной — луч упрётся в неё.
		if not out:
			var shoulder: Vector3 = cam.global_position
			var lq := PhysicsRayQueryParameters3D.create(pos, shoulder, 1)
			var los := space.intersect_ray(lq)
			if not los.is_empty() and pos.distance_to(los["position"]) > 0.05:
				out = true
		if out:
			bad_outside += 1
			if worst_outside.size() < 6:
				worst_outside.append(tag + " cam=" + str(pos) + " cell=" + str(cx) + "," + str(cz))
		# Вплотную к стене в направлении взгляда: стена занимает почти весь кадр.
		var fwd := -camera.global_transform.basis.z
		var rq := PhysicsRayQueryParameters3D.create(pos, pos + fwd * 1.2, 1 | 8)
		var hit := space.intersect_ray(rq)
		if not hit.is_empty() and pos.distance_to(hit["position"]) < 0.45:
			bad_close += 1
			if worst_close.size() < 6:
				worst_close.append(tag + " d=%.2f" % pos.distance_to(hit["position"]))
		# Реквизит в кадре: сколько раз сработало гашение.
		var fade_nodes: Variant = cam.get("_fade_nodes")
		if fade_nodes != null:
			for mi in fade_nodes:
				if not is_instance_valid(mi):
					continue
				if mi.transparency > 0.05 and mi.global_position.distance_to(pos) < 3.0:
					prop_faded += 1
					break
		# следующий кадр
		pitch_i += 1
		if pitch_i >= PITCHES.size():
			pitch_i = 0
			yaw_i += 1
			if yaw_i >= YAW_STEPS:
				yaw_i = 0
				spot_i += 1

	func _report() -> void:
		print("AUDIT samples=", total, " inside_wall=", bad_inside,
			" outside_level=", bad_outside, " wall_in_face=", bad_close,
			" arm_min=%.2f" % arm_min, " arm_lt_0.62=", arm_squeezed,
			" prop_fades=", prop_faded)
		for s in worst_inside:
			print("AUDIT INSIDE ", s)
		for s in worst_outside:
			print("AUDIT OUTSIDE ", s)
		for s in worst_close:
			print("AUDIT CLOSE ", s)
		var ok := bad_inside == 0 and bad_outside == 0 and bad_close == 0
		print("AUDIT RESULT=", "PASS" if ok else "FAIL")
		get_tree().quit()


func _initialize() -> void:
	var runner := Runner.new()
	runner.name = "CamAudit"
	get_root().add_child.call_deferred(runner)
