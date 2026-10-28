extends Node3D
## Миссия 1 в 3D: подземелье, герой, стража, босс, задачи и диалоги.

const T := 2.0

var dungeon: Dungeon
var hero: Hero3D
var cam: Cam3D
var hud
var boss: Enemy3D
var enemies: Array = []
var busy := false
var ended := false
var objective := ""
var load_on_start := false

var door_open := false
var gate_open := false
var selena_done := false
var boss_dead := false
var fleshes := []
var pickups := []
var collected_notes := 0
var collected_items := 0
var lore := {}
var selena_node: Node3D


func _ready() -> void:
	randomize()
	dungeon = Dungeon.new()
	add_child(dungeon)
	dungeon.build()
	dungeon._torch(Vector3(10.0, 0.0, 60.5))
	dungeon._torch(Vector3(18.5, 0.0, 61.0))

	hero = Hero3D.new()
	hero.position = Vector3(13.0, 0.2, 56.5)
	add_child(hero)
	hero.died.connect(_on_hero_died)

	cam = Cam3D.new()
	cam.target = hero
	cam.yaw = 0.0
	add_child(cam)
	cam.global_position = hero.global_position + Vector3(0, 1.5, 0)

	_build_hud()
	_load_lore()
	_spawn_enemies()
	_spawn_interactables()
	_spawn_lore_pickups()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if load_on_start and SaveSystem.has_save():
		_restore_save()
	else:
		_intro()


func _build_hud() -> void:
	hud = load("res://scripts/hud.gd").new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.layer = 10
	add_child(hud)
	hud.transform = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2.ZERO)
	hud.restart_requested.connect(func():
		GameState.health = GameState.get_max_health()
		get_tree().paused = false
		get_parent().start_mission())
	hud.menu_requested.connect(func():
		get_tree().paused = false
		get_parent().show_menu())


func _spawn_enemies() -> void:
	var spots := [
		{"pos": Vector3(33, 0, 49), "patrol": [Vector3(28, 0, 49), Vector3(58, 0, 49)]},
		{"pos": Vector3(53, 0, 49), "patrol": [Vector3(40, 0, 47), Vector3(60, 0, 51)]},
		{"pos": Vector3(81, 0, 57), "patrol": [Vector3(74, 0, 57), Vector3(105, 0, 57)]},
		{"pos": Vector3(91, 0, 31), "patrol": [Vector3(80, 0, 31), Vector3(108, 0, 31)]},
		{"pos": Vector3(91, 0, 39), "patrol": [Vector3(80, 0, 39), Vector3(108, 0, 39)]},
	]
	for s in spots:
		var e: Enemy3D = Enemy3D.new()
		e.setup("guard")
		e.position = s["pos"]
		e.patrol = s["patrol"]
		e.target = hero
		add_child(e)
		e.died.connect(_on_enemy_died)
		enemies.append(e)

	boss = Enemy3D.new()
	boss.setup("boss")
	boss.position = Vector3(45, 0, 33)
	boss.target = hero
	boss.patrol = [Vector3(40, 0, 33), Vector3(52, 0, 33)]
	add_child(boss)
	boss.died.connect(_on_boss_died)


func _spawn_interactables() -> void:
	_add_flesh(Vector3(16.0, 0.0, 58.0))
	_add_flesh(Vector3(20.0, 0.0, 57.0))

	selena_node = Node3D.new()
	selena_node.position = Vector3(45.0, 0.0, 59.0)
	var sel := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.5
	sel.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.6, 0.75)
	sel.material_override = m
	sel.position = Vector3(0, 0.8, 0)
	selena_node.add_child(sel)
	var hair := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	hair.mesh = sph
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.85, 0.78, 0.55)
	hair.material_override = m2
	hair.position = Vector3(0, 1.55, 0)
	selena_node.add_child(hair)
	add_child(selena_node)


func _add_flesh(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for i in 5:
		var s := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.18 + randf() * 0.12
		s.mesh = sph
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.06, 0.1)
		m.roughness = 0.85
		m.emission_enabled = true
		m.emission = Color(0.45, 0.05, 0.08)
		m.emission_energy_multiplier = 0.35
		s.material_override = m
		s.position = Vector3(randf_range(-0.4, 0.4), 0.12, randf_range(-0.4, 0.4))
		root.add_child(s)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 0.15, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.5, 0)
	root.add_child(glow)
	fleshes.append({"node": root, "used": false, "charges": 3})


## Лёгкое покачивание и вращение: предметы читаются как «подбираемые».
func _animate_pickups(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for pk in pickups:
		if pk["used"]:
			continue
		var node: Node3D = pk["node"]
		if not is_instance_valid(node):
			continue
		node.position.y = float(pk["base_y"]) + sin(t * 1.6 + float(pk["phase"])) * 0.05
		node.rotation.y += deg_to_rad(float(pk["spin"])) * dt


func _process(_delta: float) -> void:
	if ended or hero == null:
		return
	_animate_pickups(_delta)
	_update_prompt()
	_check_objectives()
	if boss and is_instance_valid(boss) and not boss.dead:
		if hero.global_position.distance_to(boss.global_position) < 13.0:
			hud.show_boss("НАДЗИРАТЕЛЬ ГХАРН", boss.hp / boss.max_hp)
		else:
			hud.hide_boss()
	else:
		hud.hide_boss()


func _update_prompt() -> void:
	if busy:
		hud.set_prompt("")
		return
	var p := hero.global_position
	for pk in pickups:
		if pk["used"]:
			continue
		if p.distance_to(pk["node"].global_position) < 2.4:
			var entry := _lore_entry(pk["kind"], pk["index"])
			if entry.is_empty():
				continue
			if pk["kind"] == "note":
				hud.set_prompt("F  —  прочитать записку")
				if Input.is_action_just_pressed("interact"):
					_read_pickup(pk, entry)
			else:
				hud.set_prompt("F  —  подобрать: %s" % entry.get("name", "предмет"))
				if Input.is_action_just_pressed("interact"):
					_read_pickup(pk, entry)
			return
	for f in fleshes:
		if f["used"]:
			continue
		if p.distance_to(f["node"].global_position) < 2.6:
			hud.set_prompt("E  —  поглотить гнилую плоть (%d)" % f["charges"])
			hud.set_hint("Магия +25 · Жажда +3")
			if Input.is_action_just_pressed("absorb"):
				_absorb(f)
			return
	if not door_open and p.distance_to(Vector3(13, 0, 53)) < 3.0:
		hud.set_prompt("F  —  сломать оковы (20 магии)")
		hud.set_hint("Нужно 20 магии" if GameState.magic < 20.0 else "Оковы поддадутся")
		if Input.is_action_just_pressed("interact"):
			_break_door()
		return
	if not selena_done and p.distance_to(Vector3(45, 0, 53)) < 3.4:
		hud.set_prompt("F  —  поговорить с пленницей")
		hud.set_hint("")
		if Input.is_action_just_pressed("interact"):
			_selena_talk()
		return
	if not gate_open and p.distance_to(Vector3(95, 0, 47)) < 3.0:
		hud.set_prompt("F  —  дёрнуть рычаг ворот")
		hud.set_hint("")
		if Input.is_action_just_pressed("interact"):
			_open_gate()
		return
	if boss_dead and p.distance_to(Vector3(59, 0, 5)) < 4.0:
		hud.set_prompt("F  —  подняться к шахте")
		hud.set_hint("")
		if Input.is_action_just_pressed("interact"):
			_finish()
		return
	hud.set_prompt("")
	hud.set_hint("")


func _absorb(f: Dictionary) -> void:
	f["charges"] = int(f["charges"]) - 1
	GameState.add_magic(25.0)
	GameState.add_craving(3.0)
	GameState.flesh_eaten += 1
	var root: Node3D = f["node"]
	Sfx.play_at("sfx_absorb", root.global_position + Vector3(0, 0.2, 0), -6.0)
	hero.emit_noise(Balance.NOISE_ABSORB)
	if int(f["charges"]) <= 0:
		f["used"] = true
		var tw := create_tween()
		tw.tween_property(root, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	if GameState.flesh_eaten == 1:
		_set_objective("Сломать оковы у решётки (F)")
		busy = true
		hero.control_enabled = false
		await hud.say([
			{"name": "Торвин", "text": "Тёплое. Солёное. Оно шевелится во мне — и магия снова течёт."},
			{"name": "Торвин", "text": "Двадцать единиц — и оковы поддадутся."},
		])
		busy = false
		hero.control_enabled = true


func _break_door() -> void:
	if GameState.magic < 20.0:
		Sfx.play("sfx_lowmagic", -8.0)
		return
	GameState.spend_magic(20.0)
	door_open = true
	Sfx.play("sfx_chain", -5.0)
	hero.emit_noise(Balance.NOISE_CHAIN)
	cam.shake(5.0, 0.3)
	_remove_barrier_near(Vector3(13.0, 0.0, 54.0), 1.8)
	_checkpoint()
	_set_objective("Выйти в коридор")
	busy = true
	hero.control_enabled = false
	await hud.say([
		{"name": "Торвин", "text": "Свобода. Пахнет сыростью и железом."},
		{"name": "Торвин", "text": "В коридоре темно. Пригнусь — Ctrl. Тихо — Shift не жму. Камень (G) отвлечёт стражу."},
	])
	busy = false
	hero.control_enabled = true


func _open_gate() -> void:
	gate_open = true
	Sfx.play("sfx_gate_open", -6.0)
	cam.shake(4.0, 0.4)
	_remove_barrier_near(Vector3(101.0, 0.0, 46.0), 1.8)
	_set_objective("Пройти через казарму в кузню")


func _selena_talk() -> void:
	busy = true
	hero.control_enabled = false
	await hud.say([
		{"name": "Селена Вейн", "text": "Гном. Живой. Значит, это правда — вы едите нас и получаете силу."},
		{"name": "Торвин", "text": "Я не ел... Я выживал. Это разные вещи. Иногда."},
		{"name": "Селена Вейн", "text": "Мой брат Орлан погиб в горах семь лет назад. Скажи, что ты не..."},
		{"name": "Торвин", "text": "Я знал его."},
	])
	var choice: int = await hud.ask("Что делать с пленницей?",
		["Открыть камеру и освободить", "Забрать её магию", "Уйти и не оглядываться"])
	selena_done = true
	if choice == 0:
		GameState.selena = "freed"
		GameState.add_trust(25)
		Sfx.play("sfx_trust", -5.0)
		await hud.say([{"name": "Селена Вейн", "text": "Тогда слушай: есть ритуал, который выжигает магию из крови. Любую."}])
		if selena_node:
			selena_node.visible = false
	elif choice == 1:
		GameState.selena = "devoured"
		GameState.add_trust(-30)
		GameState.add_magic(40.0)
		GameState.add_craving(25.0)
		Sfx.play("sfx_absorb", -4.0)
		cam.shake(6.0, 0.5)
		if selena_node:
			selena_node.visible = false
		await hud.say([{"name": "Торвин", "text": "Прости. Во мне слишком много голода."}])
	else:
		GameState.add_trust(-5)
		await hud.say([{"name": "Торвин", "text": "Есть выборы, которых я не могу себе позволить."}])
	busy = false
	hero.control_enabled = true
	_set_objective("Найти рычаг ворот у казармы")
	_checkpoint()


func _check_objectives() -> void:
	var p := hero.global_position
	if door_open and p.distance_to(Vector3(33, 0, 49)) < 9.0 and objective.find("Выйти") >= 0:
		_set_objective("Пробраться мимо стражи (Ctrl — красться, G — камень)")
	if not selena_done and p.distance_to(Vector3(45, 0, 55)) < 6.0 and objective.find("камера") < 0:
		_set_objective("Камера 13: поговорить с пленницей (F)")
	if not gate_open and p.distance_to(Vector3(81, 0, 57)) < 9.0 and objective.find("рычаг") < 0:
		_set_objective("Найти рычаг ворот в казарму")


func _on_enemy_died(e) -> void:
	enemies.erase(e)


func _on_boss_died(_b) -> void:
	boss_dead = true
	GameState.boss_dead = true
	hud.hide_boss()
	Sfx.play("sfx_boss_roar", -6.0)
	cam.shake(8.0, 0.7)
	_set_objective("Подняться к шахте (вверх)")
	busy = true
	hero.control_enabled = false
	await get_tree().create_timer(0.8).timeout
	await hud.say([
		{"name": "Торвин", "text": "Всё. Хватит. Я больше не буду тем, кем меня сделали."},
		{"name": "Торвин", "text": "Шахта. Воздух. Снег. Свобода пахнет холодом."},
	])
	busy = false
	hero.control_enabled = true
	_checkpoint()


func _finish() -> void:
	if ended:
		return
	ended = true
	hero.control_enabled = false
	GameState.escaped = true
	await hud.say([
		{"name": "Торвин", "text": "Я вышел из земли. Над горами — кровавая луна, и снег в её свете кажется пеплом."},
		{"name": "Торвин", "text": "Первый шаг сделан. Теперь — война."},
	])
	get_parent().mission_finished(true)


func _intro() -> void:
	busy = true
	hero.control_enabled = false
	await get_tree().create_timer(0.5).timeout
	await hud.say([
		{"name": "Торвин", "text": "Просыпайся, гном. Шахта «Кровавый Клык», год седьмой после Раскола."},
		{"name": "Торвин", "text": "Кандалы, пустая камера и запах гнилой плоти. Значит, я ещё жив."},
	])
	busy = false
	hero.control_enabled = true
	_set_objective("Поглотить гнилую плоть (E)")


func _set_objective(text: String) -> void:
	objective = text
	if hud:
		hud.set_objective(text)


func _unhandled_input(event: InputEvent) -> void:
	# паузу и курсор ведёт HUD (одно место на весь проект);
	# здесь только возвращаем захват мыши кликом по миру после паузы.
	# Во время выбора курсор обязан оставаться видимым, иначе кнопки недоступны.
	if hud != null and hud.choices_open:
		return
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_hero_died() -> void:
	if ended:
		return
	ended = true
	if hud:
		hud.show_death()


func _load_lore() -> void:
	var txt := FileAccess.get_file_as_string("res://assets/text/lore.json")
	if txt.is_empty():
		return
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		return
	lore = data
	if data.has("barks"):
		Enemy3D.barks = data["barks"]


func _spawn_lore_pickups() -> void:
	var notes: Array = lore.get("notes", [])
	var items: Array = lore.get("items", [])
	var note_pos := [Vector3(14, 0, 58), Vector3(31, 0, 49), Vector3(45, 0, 58),
		Vector3(80, 0, 57), Vector3(11, 0, 31), Vector3(126, 0, 30),
		Vector3(100, 0, 76)]
	var item_pos := [Vector3(17, 0, 57), Vector3(28, 0, 47), Vector3(46, 0, 60),
		Vector3(78, 0, 59), Vector3(88, 0, 31), Vector3(48, 0, 31),
		Vector3(15, 0, 33), Vector3(140, 0, 38), Vector3(108, 0, 80)]
	for i in mini(notes.size(), note_pos.size()):
		_make_pickup("note", i, note_pos[i], Color(0.9, 0.8, 0.55))
	for i in mini(items.size(), item_pos.size()):
		_make_pickup("item", i, item_pos[i], Color(0.85, 0.3, 0.3))


func _make_pickup(kind: String, index: int, pos: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = pos + Vector3(0, 0.55, 0)
	add_child(root)
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	if kind == "note":
		# записка — свиток: лежит на боку, без «светящегося куба»
		var roll := CylinderMesh.new()
		roll.top_radius = 0.055
		roll.bottom_radius = 0.055
		roll.height = 0.26
		roll.radial_segments = 12
		mi.mesh = roll
		mi.rotation_degrees = Vector3(0, 0, 90)
		m.albedo_color = Color(0.86, 0.79, 0.6)
		m.roughness = 0.9
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.18
		var seal := MeshInstance3D.new()
		var seal_mesh := SphereMesh.new()
		seal_mesh.radius = 0.045
		seal_mesh.height = 0.05
		seal_mesh.radial_segments = 8
		seal_mesh.rings = 3
		seal.mesh = seal_mesh
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.45, 0.1, 0.12)
		sm.roughness = 0.7
		seal.material_override = sm
		seal.position = Vector3(0, 0.06, 0)
		root.add_child(seal)
	else:
		# предмет — гранёный осколок с подсветкой по рёбрам
		var gem := SphereMesh.new()
		gem.radius = 0.16
		gem.height = 0.38
		gem.radial_segments = 6
		gem.rings = 3
		mi.mesh = gem
		mi.rotation_degrees = Vector3(8, 35.0 * index, 0)
		m.albedo_color = Color(0.55, 0.12, 0.14)
		m.roughness = 0.25
		m.metallic = 0.15
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.4
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
	mi.material_override = m
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 0.7 if kind == "note" else 1.0
	l.omni_range = 2.2
	root.add_child(l)
	pickups.append({"node": root, "kind": kind, "index": index, "used": false,
		"spin": 9.0 if kind == "note" else 26.0,
		"base_y": root.position.y, "phase": float(index) * 0.8})


func _lore_entry(kind: String, index: int) -> Dictionary:
	var arr: Array = lore.get("notes" if kind == "note" else "items", [])
	if index >= arr.size():
		return {}
	return arr[index]


func _read_pickup(pk: Dictionary, entry: Dictionary) -> void:
	pk["used"] = true
	var root: Node3D = pk["node"]
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(root.queue_free)
	if pk["kind"] == "note":
		collected_notes += 1
		busy = true
		hero.control_enabled = false
		await hud.say([{"name": entry.get("title", "Записка"), "text": entry.get("text", "")}])
		busy = false
		hero.control_enabled = true
		hud.set_counters(collected_notes, collected_items)
	else:
		collected_items += 1
		# предмет без записи в GameState оставался только строчкой в диалоге:
		# счётчик рос, а в инвентаре было пусто
		GameState.add_item(entry)
		Sfx.play("sfx_absorb", -12.0)
		busy = true
		hero.control_enabled = false
		var text := String(entry.get("desc", ""))
		var bonuses := GameState.item_bonuses_text(entry)
		if bonuses != "":
			text += "\n" + bonuses
		await hud.say([{"name": entry.get("name", "Предмет"), "text": text}])
		busy = false
		hero.control_enabled = true
		hud.set_counters(collected_notes, collected_items)
		# про клавишу игроку никто не говорил: сумка казалась пустой, хотя
		# предметы в ней лежали
		hud.set_hint("Предмет в сумке · открыть инвентарь: I")


func _checkpoint() -> void:
	var data := {
		"x": hero.global_position.x,
		"z": hero.global_position.z,
		"hp": GameState.health,
		"magic": GameState.magic,
		"craving": GameState.craving,
		"trust": GameState.trust,
		"door_open": door_open,
		"gate_open": gate_open,
		"selena_done": selena_done,
		"boss_dead": boss_dead,
		"notes": collected_notes,
		"items": collected_items,
		"inventory": GameState.inventory,
		"equipped": GameState.equipped,
		"objective": objective,
		"progression": GameState.progression_data(),
	}
	SaveSystem.write(data)


func _restore_save() -> void:
	var d := SaveSystem.read()
	if d.is_empty():
		_intro()
		return
	var prog = d.get("progression", {})
	if prog is Dictionary:
		GameState.apply_progression(prog)
	hero.global_position = Vector3(float(d.get("x", 13.0)), 0.2, float(d.get("z", 56.5)))
	GameState.health = minf(float(d.get("hp", GameState.get_max_health())), GameState.get_max_health())
	GameState.magic = minf(float(d.get("magic", 0.0)), GameState.get_max_magic())
	GameState.craving = float(d.get("craving", 0.0))
	GameState.trust = int(d.get("trust", -40))
	door_open = bool(d.get("door_open", false))
	gate_open = bool(d.get("gate_open", false))
	selena_done = bool(d.get("selena_done", false))
	boss_dead = bool(d.get("boss_dead", false))
	collected_notes = int(d.get("notes", 0))
	collected_items = int(d.get("items", 0))
	# сумка без этого возвращалась пустой: счётчик «предметы 3/6» переживал
	# загрузку, а сами предметы — нет
	var inv = d.get("inventory", [])
	if inv is Array:
		GameState.inventory = inv
	var eq = d.get("equipped", {})
	if eq is Dictionary and not eq.is_empty():
		GameState.equipped = eq
	GameState.inventory_changed.emit()
	hud.set_counters(collected_notes, collected_items)
	GameState.boss_dead = boss_dead
	GameState.stats_changed.emit()
	if door_open:
		_remove_barrier_near(Vector3(13.0, 0.0, 54.0), 1.8)
	if gate_open:
		_remove_barrier_near(Vector3(101.0, 0.0, 46.0), 1.8)
	if boss_dead and boss != null and is_instance_valid(boss):
		boss.queue_free()
		boss = null
	_set_objective(String(d.get("objective", "Найти выход из подземелья")))
	busy = false
	hero.control_enabled = true
	await hud.say([{"name": "Торвин", "text": "Снова этот камень. Снова этот воздух. Идём дальше."}])


func _remove_barrier_near(center: Vector3, radius: float) -> void:
	for c in barriers_near(center, radius):
		c.queue_free()


## Стойки-барьеры с коллизией в радиусе: нужно и разлому, и автотесту,
## который проверяет, что «открытая» дверь перестала быть невидимой стеной.
func barriers_near(center: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in dungeon.get_children():
		if not (c is Node3D):
			continue
		var has_body := false
		for ch in (c as Node).get_children():
			if ch is StaticBody3D:
				has_body = true
				break
		if not has_body:
			continue
		var gp := (c as Node3D).global_position
		if Vector2(gp.x - center.x, gp.z - center.z).length() < radius:
			out.append(c)
	return out
