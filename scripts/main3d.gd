extends Node3D
## Точка входа 3D-версии: меню, кинематик, миссия, финал.

var current: Node = null


func _ready() -> void:
	_register_input()
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		_shots_mode()
	elif "--models" in args:
		_models_mode()
	elif "--fit" in args:
		_fit_mode()
	elif "--test3d" in args:
		_test_mode()
	elif "--mission" in args:
		start_mission()
	else:
		show_menu()


func _register_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("dash", [KEY_SPACE])
	_add_action("spike", [KEY_Q])
	_add_action("blood_nova", [KEY_R])
	_add_action("skills", [KEY_K])
	_add_action("absorb", [KEY_E])
	_add_action("interact", [KEY_F])
	_add_action("sneak", [KEY_SHIFT])
	_add_action("crouch", [KEY_CTRL])
	_add_action("distract", [KEY_G])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("confirm", [KEY_SPACE, KEY_ENTER])
	_add_action("fullscreen", [KEY_F11])
	_add_action("choice_1", [KEY_1])
	_add_action("choice_2", [KEY_2])
	_add_action("choice_3", [KEY_3])
	# Экшены Wyvernbox: без них аддон зовёт Input.is_action_pressed на несуществующий
	# экшен и тултип с перетаскиванием падают на каждой кнопке мыши.
	_add_action("inventory_more", [KEY_SHIFT])
	_add_action("inventory_less", [KEY_ALT])
	_add_action("inventory_filter", [KEY_F])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	if not InputMap.has_action("heavy"):
		InputMap.add_action("heavy")
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("heavy", mb2)


func _add_action(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)


func _swap(node: Node) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		# F11 — быстрый тумблер, настройка сохраняется в user://settings.cfg
		Settings.toggle_fullscreen()


func show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_all_loops(0.4)
	var m = load("res://scripts/menu3d.gd").new()
	m.continue_game.connect(func(): start_mission(true))
	m.start_story.connect(show_cinema)
	m.start_mission.connect(func(): start_mission(false))
	m.open_settings.connect(show_settings)
	m.quit_game.connect(func(): get_tree().quit())
	_swap(m)
	Sfx.loop("music_menu", -16.0, 1.2)


## Экран настроек поверх меню (или паузы).
func show_settings() -> void:
	var s: Control = load("res://scripts/settings_screen.gd").new()
	s.closed.connect(s.queue_free)
	add_child(s)


func show_cinema() -> void:
	Sfx.stop_all_loops(0.4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c = load("res://scripts/intro_cinema.gd").new()
	c.scale = Vector2(2, 2)
	c.size = Vector2(640, 360)
	c.finished.connect(start_mission)
	_swap(c)


func start_mission(load_save := false) -> void:
	Sfx.stop_all_loops(0.5)
	if not load_save:
		# новая миссия — новая прокачка; «Продолжить» восстанавливает её из сейва
		GameState.reset_progression()
	var script: GDScript = load("res://scripts/mission3d.gd")
	var m: Node = script.new()
	m.load_on_start = load_save
	_swap(m)
	Sfx.loop("amb_prison", -18.0, 1.5)


func mission_finished(escaped: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_all_loops(0.8)
	var e = load("res://scripts/ending_screen.gd").new()
	e.scale = Vector2(2, 2)
	e.size = Vector2(640, 360)
	e.escaped = escaped
	e.back_to_menu.connect(show_menu)
	_swap(e)


func _shots_mode() -> void:
	# для читаемых скриншотов снимаем окно, а не весь монитор
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i.ZERO)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# страховка: если съёмка застрянет на await, окно закроется само —
	# иначе запущенная игра остаётся висеть на ноутбуке до утра
	var wd := get_tree().create_timer(150.0)
	wd.timeout.connect(func():
		print("SHOT watchdog: съёмка не завершилась, выхожу")
		get_tree().quit())
	show_menu()
	await get_tree().create_timer(1.0).timeout
	await _shot("3d_menu")
	# экран настроек — визуальная проверка вёрстки и переключателей
	var s: Control = load("res://scripts/settings_screen.gd").new()
	add_child(s)
	await get_tree().create_timer(0.6).timeout
	await _shot("3d_settings")
	s.queue_free()
	start_mission()
	await get_tree().create_timer(3.2).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("3d_01")
	var m = current
	# ввод больше не имитируем: без этого интро-диалог висел на всех кадрах
	if m and m.hud:
		m.hud.auto = true
	if m and m.hero:
		print("SHOT hero=", m.hero.global_position, " model=", m.hero.use_model,
			" lights=", m.dungeon.lights.size())
		# телепорт в середину коридора: патрули ходят у (33,49) и (53,49),
		# в 10 м от обоих герой никого не заслоняет
		m.hero.global_position = Vector3(43.0, 0.2, 49.0)
		if m.cam:
			m.cam.yaw = PI * 0.5
	await get_tree().create_timer(1.5).timeout
	await _shot("3d_02")
	# геометрия: два кадра, по которым и проверяется «квадратность» уровня —
	# длинный коридор (кладка, арки, мостовая) и зал (ступени свода, столбы).
	# HUD на этих двух кадрах полностью выключен: удерживаемая клавиша «I»
	# иначе открывает инвентарь, а инвентарь ставит дерево на паузу — камера
	# замирает и кадр показывает неизвестно что.
	if m and m.hud:
		m.hud.auto = false
		m.hud.toggle_inventory(false)
		m.hud.set_process(false)
		m.hud.visible = false
	if m and m.hero:
		m.hero.global_position = Vector3(45.0, 0.2, 53.0)
		if m.cam:
			m.cam.yaw = 0.0
			m.cam.pitch = -0.05
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_wall")
		# зал с опорой в кадре: виден курс кладки, капитель и карниз.
		# Камеру ставим так, чтобы рука пружины шла по открытому пространству,
		# иначе она липнет к стене и кадр упирается в затылок героя.
		m.hero.global_position = Vector3(108.0, 0.2, 32.0)
		if m.cam:
			m.cam.yaw = PI * 0.5
			m.cam.pitch = 0.05
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_course")
		m.hero.global_position = Vector3(96.0, 0.2, 32.0)
		if m.cam:
			m.cam.yaw = 0.0
			m.cam.pitch = 0.24
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_vault")
		m.hero.global_position = Vector3(13.0, 0.2, 33.0)
		if m.cam:
			m.cam.yaw = -PI * 0.5
			m.cam.pitch = 0.08
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_mine_loop")
		m.hero.global_position = Vector3(130.0, 0.2, 38.0)
		if m.cam:
			m.cam.yaw = PI * 0.5
			m.cam.pitch = 0.08
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_cistern")
		m.hero.global_position = Vector3(112.0, 0.2, 76.0)
		if m.cam:
			m.cam.yaw = -2.0
			m.cam.pitch = 0.08
		await get_tree().create_timer(1.2).timeout
		await _shot("3d_deep_mine")
	if m and m.hud:
		m.hud.visible = true
		m.hud.set_process(true)
	# бег: проверяем, что модель развёрнута по движению (видим спину, а не лицо)
	Input.action_press("move_up")
	await get_tree().create_timer(1.0).timeout
	await _shot("3d_run")
	Input.action_release("move_up")
	# пауза + настройки: оверлей внутри HUD живёт в 640×360 (масштаб ×0.5)
	if m and m.hud:
		m.hud.toggle_pause(true)
		m.hud._open_settings()
		await get_tree().create_timer(0.6).timeout
		await _shot("3d_pause_settings")
	# инвентарь Wyvernbox: проверяем вёрстку панели, слоты экипировки, сетку сумки
	# и тултип. Предметы кладём в GameState прямо здесь — экран их подхватывает сам.
	if m and m.hud:
		m.hud.toggle_pause(false)
		for id in ["potion_heal", "scroll_fire", "ring_power", "cloak_shadow",
				"boots_wanderer", "amulet_ward"]:
			GameState.add_item(ItemCatalog.source(id))
		m.hud._open_inventory()
		# view пересобирается с задержкой в кадр, а стопки едут в ячейки не сразу
		await get_tree().create_timer(0.8).timeout
		var inv = m.hud.inventory_root
		await _mouse_equip_check(inv)
		# Наводим на последнюю заполненную ячейку: тултип раскрывается вправо
		# и не закрывает собой остальные предметы сумки.
		var shown = inv.bag_view.get_item_view_at_position(4, 0) if inv != null else null
		if is_instance_valid(shown):
			shown.notification(Control.NOTIFICATION_MOUSE_ENTER)
		await get_tree().create_timer(0.4).timeout
		await _shot("3d_inventory")
		if is_instance_valid(shown):
			shown.notification(Control.NOTIFICATION_MOUSE_EXIT)
		m.hud.toggle_inventory(false)
	get_tree().quit()


## Проверка инвентаря НАСТОЯЩИМ курсором — то, чего не может headless-тест:
## там метрики окна недостоверны и клик в пустоту проходит «сам по себе».
## Берём амулет из сумки кликом, ведём мышь в слот амулета, кадрируем предмет
## под курсором и кликаем в слот. Если экран висит на масштабированном слое,
## аддон выбирает ячейку по удвоенным координатам: предмет не берётся, «рука»
## уезжает от курсора, а нажатие в слот надевает не то (или ничего).
func _mouse_equip_check(inv) -> void:
	if inv == null:
		print("SHOT FAIL: экран инвентаря не открылся")
		return
	var src = null
	for st in inv.bag_view.inventory.items:
		if st != null and String(st.item_type.resource_name) == "amulet_ward":
			src = st
			break
	if src == null:
		print("SHOT FAIL: амулет не лёг в сумку экрана")
		return
	var from = inv.bag_view.get_item_view_at_positionv(src.position_in_inventory)
	if not is_instance_valid(from):
		print("SHOT FAIL: ячейка амулета не отрисована")
		return
	await _mouse_click(from.get_global_rect().get_center())
	await get_tree().create_timer(0.35).timeout
	var held = GrabbedItemStackView.get_instance()
	var grabbed: bool = is_instance_valid(held) and held.stack == src
	var amulet_idx: int = GameState.EQUIP_SLOTS.find("amulet")
	var slot: Control = inv.equip_view.get_node("Cells").get_child(amulet_idx)
	var slot_pos: Vector2 = slot.get_global_rect().get_center()
	_mouse_move(slot_pos)
	await get_tree().create_timer(0.35).timeout
	# центр предмета в «руке» должен совпасть с курсором: расхождение и есть
	# тот самый «съезжающий» предмет
	var drift := 1e9
	if is_instance_valid(held) and held.visible:
		drift = (held.global_position + held.size * 0.5 * held.scale).distance_to(slot_pos)
	# ячейка, которую аддон выбрал по настоящей позиции мыши
	var target: Vector2 = inv.equip_view.selected_cell
	await _shot("3d_inventory_drag")
	await _mouse_click(slot_pos)
	await get_tree().create_timer(0.35).timeout
	var worn = GameState.equipped.get("amulet")
	var worn_ok: bool = worn is Dictionary and String(worn.get("id", "")) == "amulet_ward"
	print("SHOT mouse grab=", grabbed, " drift=", snappedf(drift, 0.1),
		" target=", target, " want=", Vector2(amulet_idx, 0), " amulet_worn=", worn_ok)
	if not grabbed or drift > 2.0 or target != Vector2(amulet_idx, 0) or not worn_ok:
		print("SHOT FAIL: инвентарь не слушается реального курсора")



## Витрина оружия в руке: герой с трёх сторон, чтобы подобрать поворот в кисти.
func _fit_mode() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mi.mesh = plane
	add_child(floor_mi)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.current = true
	add_child(cam)

	var hero := Hero3D.new()
	hero.control_enabled = false
	hero.position = Vector3.ZERO
	add_child(hero)
	hero.set_physics_process(false)

	await get_tree().create_timer(0.6).timeout
	var views := [Vector3(1.5, 1.35, 2.1), Vector3(-1.2, 1.35, -2.3), Vector3(3.0, 1.2, 0.2)]
	var i := 0
	for v in views:
		cam.position = Vector3(0, 0.85, 0) + v
		cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)
		await get_tree().create_timer(0.35).timeout
		await _shot("fit_%d" % i)
		i += 1
	# проверка ориентации при движении: поворот рига считается той же формулой,
	# что в hero3d для бега «от камеры» (-Z). Должны видеть спину.
	var dir := Vector3(0, 0, -1)
	hero.rig.rotation.y = atan2(-dir.x, -dir.z)
	cam.position = Vector3(0, 1.0, 3.0)
	cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	await get_tree().create_timer(0.35).timeout
	await _shot("fit_run")
	get_tree().quit()


## Витрина моделей: проверка масштаба и ориентации перед встройкой в игру.
func _models_mode() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 2.0
	light.shadow_enabled = true
	add_child(light)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	add_child(floor_mi)

	# полу нужна коллизия, иначе герой и враги просто проваливаются вниз
	var floor_body := StaticBody3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 0.4, 30)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -0.2, 0)
	floor_body.add_child(floor_col)
	add_child(floor_body)

	var cam := Camera3D.new()
	cam.position = Vector3(0.1, 1.15, 3.5)
	cam.rotation_degrees = Vector3(-3, 0, 0)
	cam.fov = 50.0
	cam.current = true
	add_child(cam)

	var holder := Node3D.new()
	add_child(holder)

	# рост-эталон 1.7 м рядом с героем
	var ref := MeshInstance3D.new()
	var ref_box := BoxMesh.new()
	ref_box.size = Vector3(0.2, 1.7, 0.2)
	ref.mesh = ref_box
	ref.position = Vector3(-2.2, 0.85, 0)
	add_child(ref)

	var hero := Hero3D.new()
	hero.control_enabled = false
	hero.position = Vector3(-1.0, 0.05, 0)
	holder.add_child(hero)

	var guard := Enemy3D.new()
	guard.setup("guard")
	guard.position = Vector3(1.1, 0.05, 0)
	holder.add_child(guard)

	var boss := Enemy3D.new()
	boss.setup("boss")
	boss.position = Vector3(2.9, 0.05, -3.2)
	holder.add_child(boss)

	await get_tree().physics_frame
	await get_tree().physics_frame
	# в витрине никто не должен ходить и падать — только стоять и дышать
	hero.set_physics_process(false)
	guard.set_physics_process(false)
	boss.set_physics_process(false)

	await get_tree().create_timer(1.0).timeout
	var names := ["hero", "guard", "boss"]
	var chars := [hero, guard, boss]
	for i in names.size():
		var e: Node3D = chars[i]
		var ok := e.model_root != null
		print("SHOWCASE ", names[i], " модель=", ok, " pos=", e.global_position,
			" scale=", e.model_root.scale if ok else Vector3.ZERO)
	await _shot("models")
	# вторая витрина: крупный план героя (проверка оружия в руке)
	cam.position = Vector3(-1.55, 1.1, 1.75)
	cam.rotation_degrees = Vector3(-8, -14, 0)
	await get_tree().create_timer(0.4).timeout
	await _shot("models_close")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shot_%s.png" % name)
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())


## Наведение настоящего курсора: warp_mouse двигает системную мышь — из этого
## получается и настоящее событие движения (по нему аддон выбирает ячейку), и
## позиция предмета в «руке». parse_input_event дублирует то же движение, чтобы
## кадр не зависел от того, успела ли ОС доставить свой WM_MOUSEMOVE.
func _mouse_move(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	Input.parse_input_event(_mouse_motion(pos))


func _mouse_motion(pos: Vector2) -> InputEventMouseMotion:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	return mv


## Полный клик ЛКМ в точке pos: наведение, нажатие, отпускание. Именно так
## выглядит перетаскивание в инвентаре для игрока.
func _mouse_click(pos: Vector2) -> void:
	_mouse_move(pos)
	await get_tree().create_timer(0.12).timeout
	var b := InputEventMouseButton.new()
	b.position = pos
	b.global_position = pos
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	Input.parse_input_event(b)
	await get_tree().create_timer(0.12).timeout
	b.pressed = false
	Input.parse_input_event(b)


func _map_region_connected(dungeon: Dungeon, start: Vector2i, goal: Vector2i,
		bounds: Rect2i) -> bool:
	if not bounds.has_point(start) or not bounds.has_point(goal) \
			or dungeon.is_wall(start.x, start.y) or dungeon.is_wall(goal.x, goal.y):
		return false
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
	]
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		if cell == goal:
			return true
		for direction in directions:
			var next := cell + direction
			if not bounds.has_point(next) or visited.has(next) \
					or dungeon.is_wall(next.x, next.y):
				continue
			visited[next] = true
			frontier.append(next)
	return false


func _count_lights(node: Node) -> int:
	var count := 1 if node is Light3D else 0
	for child in node.get_children():
		count += _count_lights(child)
	return count


func _ray_hits_dungeon_boundary(space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(query)
	var collider: Variant = hit.get("collider")
	return collider is StaticBody3D and collider.is_in_group("dungeon_boundary")


func _test_dungeon_boundary(dungeon: Dungeon) -> bool:
	var space := dungeon.get_world_3d().direct_space_state
	var width := float(dungeon.map_w) * Dungeon.T
	var depth := float(dungeon.map_h) * Dungeon.T
	var x_mid := width * 0.5
	var z_mid := depth * 0.5
	var probes: Array[Vector3] = [
		Vector3(-1.0, 1.0, z_mid), Vector3(1.0, 1.0, z_mid),
		Vector3(width + 1.0, 1.0, z_mid), Vector3(width - 1.0, 1.0, z_mid),
		Vector3(x_mid, 1.0, -1.0), Vector3(x_mid, 1.0, 1.0),
		Vector3(x_mid, 1.0, depth + 1.0), Vector3(x_mid, 1.0, depth - 1.0),
		Vector3(-1.0, 1.0, -1.0), Vector3(1.0, 1.0, 1.0),
		Vector3(width + 1.0, 1.0, -1.0), Vector3(width - 1.0, 1.0, 1.0),
		Vector3(-1.0, 1.0, depth + 1.0), Vector3(1.0, 1.0, depth - 1.0),
		Vector3(width + 1.0, 1.0, depth + 1.0),
		Vector3(width - 1.0, 1.0, depth - 1.0),
	]
	for i in range(0, probes.size(), 2):
		if not _ray_hits_dungeon_boundary(space, probes[i], probes[i + 1]):
			return false
	return true


func _test_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_mission()
	await get_tree().create_timer(1.2).timeout
	var m = current
	if m == null or m.hero == null:
		print("TEST FAIL: нет миссии")
		get_tree().quit()
		return
	m.hud.auto = true
	m.busy = false
	m.hero.control_enabled = false
	print("TEST start magic=", GameState.magic, " hp=", GameState.health,
		" enemies=", m.enemies.size(), " fleshes=", m.fleshes.size())
	await get_tree().physics_frame
	var boundary_collision := _test_dungeon_boundary(m.dungeon)
	print("TEST dungeon boundary collisions=", boundary_collision)
	if not boundary_collision:
		print("TEST FAIL: внешний контур подземелья не закрыт коллизиями")
		get_tree().quit()
		return

	var branch_path: Array[Vector2i] = []
	for x in range(3, 13):
		branch_path.append(Vector2i(x, 13))
	for y in range(14, 20):
		branch_path.append(Vector2i(3, y))
	for x in range(4, 13):
		branch_path.append(Vector2i(x, 19))
	for y in range(14, 19):
		for x in range(3, 9):
			branch_path.append(Vector2i(x, y))
	var branch_open := true
	for cell in branch_path:
		if m.dungeon.is_wall(cell.x, cell.y):
			branch_open = false
			break
	var branch_sealed := true
	for y in range(14, 19):
		for x in range(9, 12):
			if not m.dungeon.is_wall(x, y):
				branch_sealed = false
				break
	var branch_note := false
	var branch_item := false
	for pickup in m.pickups:
		var pickup_node: Node3D = pickup["node"]
		var in_branch: bool = pickup_node.position.x >= 6.0 \
			and pickup_node.position.x <= 18.0 \
			and pickup_node.position.z >= 28.0 and pickup_node.position.z <= 38.0
		if pickup["kind"] == "note" and pickup["index"] == 4 and in_branch:
			branch_note = true
		elif pickup["kind"] == "item" and pickup["index"] == 6 and in_branch:
			branch_item = true
	if not branch_open or not branch_sealed or not branch_note or not branch_item:
		print("TEST FAIL: боковая выработка path=", branch_open,
			" sealed=", branch_sealed,
			" note=", branch_note, " item=", branch_item)
		get_tree().quit()
		return
	print("TEST side loop connected=true sealed=true note=true item=true")
	var expanded_map: bool = m.dungeon.map_w == 78 and m.dungeon.map_h == 46
	var cistern_connected := _map_region_connected(m.dungeon,
		Vector2i(57, 16), Vector2i(57, 19), Rect2i(57, 14, 18, 8))
	var cistern_to_route := _map_region_connected(m.dungeon,
		Vector2i(57, 16), Vector2i(50, 16), Rect2i(0, 0,
			m.dungeon.map_w, m.dungeon.map_h))
	var cistern_second_to_route := _map_region_connected(m.dungeon,
		Vector2i(57, 19), Vector2i(50, 19), Rect2i(0, 0,
			m.dungeon.map_w, m.dungeon.map_h))
	var lower_mine_connected := _map_region_connected(m.dungeon,
		Vector2i(46, 32), Vector2i(54, 32), Rect2i(46, 32, 10, 10))
	var lower_mine_to_route := _map_region_connected(m.dungeon,
		Vector2i(46, 32), Vector2i(40, 30), Rect2i(0, 0,
			m.dungeon.map_w, m.dungeon.map_h))
	var lower_mine_second_to_route := _map_region_connected(m.dungeon,
		Vector2i(54, 32), Vector2i(54, 30), Rect2i(0, 0,
			m.dungeon.map_w, m.dungeon.map_h))
	var cistern_note := false
	var cistern_item := false
	var lower_mine_note := false
	var lower_mine_item := false
	var dungeon_light_count := _count_lights(m.dungeon)
	for pickup in m.pickups:
		var pickup_node: Node3D = pickup["node"]
		var px: float = pickup_node.position.x
		var pz: float = pickup_node.position.z
		if pickup["kind"] == "note" and pickup["index"] == 5 \
				and px >= 122.0 and px <= 148.0 and pz >= 28.0 and pz <= 42.0:
			cistern_note = true
		elif pickup["kind"] == "item" and pickup["index"] == 7 \
				and px >= 122.0 and px <= 148.0 and pz >= 28.0 and pz <= 42.0:
			cistern_item = true
		elif pickup["kind"] == "note" and pickup["index"] == 6 \
				and px >= 74.0 and px <= 132.0 and pz >= 68.0 and pz <= 86.0:
			lower_mine_note = true
		elif pickup["kind"] == "item" and pickup["index"] == 8 \
				and px >= 74.0 and px <= 132.0 and pz >= 68.0 and pz <= 86.0:
			lower_mine_item = true
	if not expanded_map or not cistern_connected or not cistern_to_route \
			or not cistern_second_to_route or not lower_mine_connected \
			or not lower_mine_to_route or not lower_mine_second_to_route \
			or not cistern_note or not cistern_item \
			or not lower_mine_note or not lower_mine_item \
			or dungeon_light_count > 30:
		print("TEST FAIL: expansion size=", m.dungeon.map_w, "x", m.dungeon.map_h,
			" cistern=", cistern_connected, "/", cistern_to_route,
			"/", cistern_second_to_route,
			" lower_mine=", lower_mine_connected, "/", lower_mine_to_route,
			"/", lower_mine_second_to_route,
			" cistern_rewards=", cistern_note, "/", cistern_item,
			" lower_rewards=", lower_mine_note, "/", lower_mine_item,
			" lights=", dungeon_light_count)
		get_tree().quit()
		return
	print("TEST expanded map=78x46 cistern=true lower_mine=true rewards=true lights=",
		dungeon_light_count)

	# Герой обязан надеть glTF-модель: иначе он молча остаётся примитивами,
	# и заметить это можно только глазами в кадре.
	var no_clips := ""
	for group in [["Idle"], ["Walk"], ["Run"], ["Roll"],
			["Sword_Slash", "Slash", "Attack"], ["HitRecieve", "HitReact"], ["Death"]]:
		if ModelUtil.pick_anim(m.hero.anim, group) == "":
			no_clips += String(group[0]) + " "
	var hat: Node = m.hero.model_root.find_child("GnomeHat", true, false) \
		if m.hero.model_root else null
	if not m.hero.use_model or m.hero.weapon_model == null or hat == null or no_clips != "":
		print("TEST FAIL: герой model=", m.hero.use_model,
			" weapon=", m.hero.weapon_model != null,
			" hat=", hat != null, " нет клипов: ", no_clips)
		get_tree().quit()
		return
	print("TEST hero model=ok weapon=ok hat=ok clips=ok")
	# позиционный пул создаётся в _ready autoload: опечатка в имени свойства
	# роняет его молча, и звук пропадает только на слух
	if Sfx._pool3d.size() != Sfx.POOL_3D_SIZE:
		print("TEST FAIL: пул AudioStreamPlayer3D = ", Sfx._pool3d.size(),
			", ожидалось ", Sfx.POOL_3D_SIZE)
		get_tree().quit()
		return
	print("TEST sfx3d pool=", Sfx._pool3d.size())
	# звук в debug-сборке глушится в Settings._ready, иначе прогон теста и
	# запуск из редактора бьют по ушам; проверяем, что шина действительно тихая
	var master := AudioServer.get_bus_index("Master")
	if not AudioServer.is_bus_mute(master) or Settings.volume > 0.001:
		print("TEST FAIL: звук не выключен на старте (volume=", Settings.volume_label(),
			", mute=", AudioServer.is_bus_mute(master), ")")
		get_tree().quit()
		return
	print("TEST audio muted=true volume=", Settings.volume_label())
	m._absorb(m.fleshes[0])
	await get_tree().create_timer(0.3).timeout
	print("TEST absorb magic=", GameState.magic, " craving=", GameState.craving)
	m._break_door()
	await get_tree().create_timer(0.8).timeout
	print("TEST door=", m.door_open, " magic=", GameState.magic, " objective=", m.objective)
	# «решётку сломал» без снятия коллизии — невидимая стена вместо прохода
	if m.barriers_near(Vector3(13.0, 0.0, 54.0), 1.8).size() > 0:
		print("TEST FAIL: решётка камеры открыта, но коллизия на месте")
		get_tree().quit()
		return

	# пауза (Esc): меню видно, дерево стоит; снятие паузы возвращает игру
	m.hud.toggle_pause(true)
	await get_tree().process_frame
	print("TEST pause visible=", m.hud.pause_root.visible, " paused=", get_tree().paused,
		" buttons=", m.hud.pause_root.get_child_count())
	m.hud.toggle_pause(false)
	await get_tree().process_frame
	print("TEST resume paused=", get_tree().paused)

	# --- скрытность: шум, конус зрения, свет ---
	print("TEST stealth noise crouch=", Balance.NOISE_CROUCH, " walk=", Balance.NOISE_WALK,
		" run=", Balance.NOISE_RUN, " throw=", Balance.NOISE_THROW)
	print("TEST light cell=", snappedf(m.dungeon.light_at(Vector3(13, 0, 56.5)), 0.1),
		" torch=", snappedf(m.dungeon.light_at(Vector3(10, 0, 60.5)), 0.1))

	var g = m.enemies[0]
	var front: Vector3 = g.global_position + g._gaze_dir() * 5.0
	var back: Vector3 = g.global_position - g._gaze_dir() * 5.0
	print("TEST cone front=", g._in_cone(front), " back=", g._in_cone(back))
	# край конуса: GUARD_FOV=60° — это ±30° от оси взгляда
	var gaze: Vector3 = g._gaze_dir().normalized()
	var edge_in: Vector3 = g.global_position + gaze.rotated(Vector3.UP, deg_to_rad(25.0)) * 5.0
	var edge_out: Vector3 = g.global_position + gaze.rotated(Vector3.UP, deg_to_rad(38.0)) * 5.0
	if not g._in_cone(edge_in) or g._in_cone(edge_out) or not g._in_cone(front) or g._in_cone(back):
		print("TEST FAIL: конус зрения не 60° — in=", g._in_cone(edge_in),
			" out=", g._in_cone(edge_out))
		get_tree().quit()
		return
	var noise_at: Vector3 = g.global_position + Vector3(3, 0, 0)
	g.hear_noise(noise_at, Balance.NOISE_THROW)
	await get_tree().create_timer(0.2).timeout
	print("TEST heard state=", g.state, " alert=", snappedf(g.alertness, 1.0),
		" goal=", g.last_seen)
	# именно так работает бросок камня (G): шум в точке падения уводит стражу
	if g.state != "search" or g.last_seen.distance_to(noise_at) > 0.01:
		print("TEST FAIL: страж не пошёл к точке шума — камень не отвлекает")
		get_tree().quit()
		return

	# полная цепочка зрения: тёмный коридор, страж смотрит на героя → погоня
	g.global_position = Vector3(33, 0, 49)
	g.velocity = Vector3.ZERO
	g.rig.rotation.y = 0.0
	g.state = "patrol"
	g.patrol = []
	g.alertness = 0.0
	g.hero_light = 0.0
	g.light_t = 10.0
	g.has_last = false
	g.last_seen = Vector3.ZERO
	g.lose_t = 0.0
	var front_spot: Vector3 = g.global_position + g._gaze_dir() * 2.0
	front_spot.y = 0.0
	m.hero.global_position = front_spot
	await get_tree().physics_frame
	print("TEST detect setup cone=", g._in_cone(m.hero.global_position),
		" los=", g._has_los(m.hero), " range=", snappedf(g._vision_range(), 0.1),
		" dist=", snappedf(g.global_position.distance_to(m.hero.global_position), 0.1),
		" gpos=", g.global_position)
	await get_tree().create_timer(2.2).timeout
	print("TEST seen state=", g.state, " alert=", snappedf(g.alertness, 1.0),
		" light=", snappedf(g.hero_light, 1.0))
	g._attack()
	g._update_attack_telegraph()
	var attack_tell_visible: bool = g.attack_tell.visible
	g.attack_phase = "active"
	g._update_attack_telegraph()
	var attack_tell_hidden: bool = not g.attack_tell.visible
	g._start_chase()
	var boss_tell := Enemy3D.new()
	boss_tell.setup("boss")
	var boss_windup: float = boss_tell._attack_windup_duration()
	boss_tell.free()
	if not attack_tell_visible or not attack_tell_hidden \
			or boss_windup <= g._attack_windup_duration():
		print("TEST FAIL: телеграф атаки не совпадает с фазами или таймингами")
	else:
		print("TEST attack telegraph visible=", attack_tell_visible,
			" hidden_on_strike=", attack_tell_hidden,
			" guard_windup=", g._attack_windup_duration(),
			" boss_windup=", boss_windup)

	# кровавый шип (Q): цена магии, откат и урон снарядом
	GameState.add_magic(30.0)
	var magic0: float = GameState.magic
	m.hero._cast_spike()
	await get_tree().create_timer(0.4).timeout
	print("TEST spike magic=", snappedf(magic0 - GameState.magic, 0.1),
		" cd=", snappedf(m.hero.spike_cd, 0.01))
	m.hero.global_position = g.global_position + Vector3(0, 0, 2.5)
	m.hero.rig.rotation.y = 0.0
	await get_tree().physics_frame
	var hp0: float = g.hp
	m.hero._launch_spike(Vector3(0, 0, -1))
	await get_tree().create_timer(0.4).timeout
	print("TEST spike hit=", g.hp < hp0, " dmg=", snappedf(hp0 - g.hp, 0.1))

	# проверка хитбокса: ставим героя вплотную лицом к врагу и бьём
	m.hero.global_position = g.global_position + Vector3(0, 0, 2.0)
	m.hero.rig.rotation.y = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.hero._hit(false)
	await get_tree().create_timer(0.2).timeout
	print("TEST hitbox hit=", g.hp < g.max_hp, " hp=", g.hp)
	g.take_damage(999.0, Vector3.ZERO)
	await get_tree().create_timer(0.4).timeout
	print("TEST guard dead=", g.dead, " killed=", GameState.guards_killed)

	# --- прокачка: опыт за убийство, уровень, очки ---
	print("TEST xp level=", GameState.level, " xp=", GameState.xp, " need=", GameState.xp_need(),
		" stat_points=", GameState.stat_points, " skill_points=", GameState.skill_points)
	# за уровень — независимые пулы: 3 очка характеристик и 1 очко навыков
	if GameState.level < 2 \
			or GameState.stat_points != Balance.STAT_POINTS_PER_LEVEL \
			or GameState.skill_points != Balance.SKILL_POINTS_PER_LEVEL:
		print("TEST FAIL: за стража не дали опыт/уровень/очки")
		get_tree().quit()
		return
	var speed0: float = GameState.move_speed_mult()
	GameState.add_stat("agility")
	print("TEST stat agility speed=", snappedf(GameState.move_speed_mult(), 0.01), " было=", speed0)
	if GameState.move_speed_mult() <= speed0:
		print("TEST FAIL: ловкость не подняла скорость героя")
		get_tree().quit()
		return
	var hp_max0: float = GameState.get_max_health()
	GameState.add_stat("vitality")
	print("TEST stat vitality hp_max=", GameState.get_max_health(), " было=", hp_max0)
	if GameState.get_max_health() <= hp_max0:
		print("TEST FAIL: живучесть не подняла максимум здоровья")
		get_tree().quit()
		return
	var melee0: float = GameState.melee_damage_mult()
	GameState.add_stat("strength")
	print("TEST stat strength melee=", snappedf(GameState.melee_damage_mult(), 0.01), " было=", melee0)
	if GameState.melee_damage_mult() <= melee0:
		print("TEST FAIL: сила не подняла урон в ближнем бою")
		get_tree().quit()
		return
	if not GameState.unlock_skill("iron_arm"):
		print("TEST FAIL: навык iron_arm не изучен")
		get_tree().quit()
		return
	print("TEST skill iron_arm rank=", GameState.skill_rank("iron_arm"),
		" melee_mult=", snappedf(GameState.melee_damage_mult(), 0.01))
	m.cam.shake(3.0, 0.2)
	m._open_gate()
	await get_tree().create_timer(0.3).timeout
	print("TEST gate=", m.gate_open)
	if m.barriers_near(Vector3(101.0, 0.0, 46.0), 1.8).size() > 0:
		print("TEST FAIL: ворота казармы открыты, но коллизия на месте")
		get_tree().quit()
		return
	m.boss.take_damage(999.0, Vector3.ZERO)
	await get_tree().create_timer(1.6).timeout
	print("TEST boss dead=", m.boss_dead, " objective=", m.objective)
	# --- «Кровавая нова»: открывается на 4 уровне, тратит магию и уходит в откат ---
	print("TEST level after boss=", GameState.level, " skill_points=", GameState.skill_points)
	if not GameState.unlock_skill("blood_nova"):
		print("TEST FAIL: blood_nova не открылась на уровне ", GameState.level)
		get_tree().quit()
		return
	GameState.add_magic(60.0)
	var magic_before: float = GameState.magic
	m.hero._cast_nova()
	await get_tree().create_timer(0.2).timeout
	print("TEST nova cost=", snappedf(magic_before - GameState.magic, 0.1),
		" cd=", snappedf(m.hero.nova_cd, 0.01))
	if m.hero.nova_cd <= 0.0:
		print("TEST FAIL: нова не ушла в откат")
		get_tree().quit()
		return
	# --- экран развития: сборка UI не должна падать, Esc возвращает игру ---
	m.hud._open_development()
	await get_tree().process_frame
	var dev: Control = m.hud.development_root
	print("TEST dev screen open=", dev != null, " paused=", get_tree().paused)
	if dev == null:
		print("TEST FAIL: экран развития не открылся")
		get_tree().quit()
		return
	dev._close()
	await get_tree().process_frame
	print("TEST dev screen closed=", m.hud.development_root == null, " paused=", get_tree().paused)
	if m.hud.development_root != null or get_tree().paused:
		print("TEST FAIL: экран развития не закрылся")
		get_tree().quit()
		return
	# --- инвентарь: подбор обязан доезжать до GameState, а экран — собираться
	# и закрываться без висящей паузы (молча пустой инвентарь жил в игре полгода)
	var pk := {}
	for p in m.pickups:
		if p["kind"] == "item" and not p["used"]:
			pk = p
			break
	if pk.is_empty():
		print("TEST FAIL: в миссии не осталось неподобранных предметов")
		get_tree().quit()
		return
	var inv0: int = GameState.inventory.size()
	m._read_pickup(pk, m._lore_entry("item", int(pk["index"])))
	await get_tree().create_timer(0.6).timeout
	print("TEST pickup inv=", GameState.inventory.size(), " added=",
		GameState.inventory.size() - inv0)
	if GameState.inventory.size() != inv0 + 1:
		print("TEST FAIL: подобранный предмет не лёг в инвентарь")
		get_tree().quit()
		return
	var new_id := String(GameState.inventory[GameState.inventory.size() - 1].get("id"))
	if not GameState.equip_item(new_id):
		print("TEST FAIL: предмет из инвентаря не надевается: ", new_id)
		get_tree().quit()
		return
	m.hud._open_inventory()
	await get_tree().process_frame
	var inv = m.hud.inventory_root
	print("TEST inventory open=", inv != null, " paused=", get_tree().paused)
	if inv == null:
		print("TEST FAIL: экран инвентаря не открылся")
		get_tree().quit()
		return
	# --- пространство координат: аддон переводит экранную позицию мыши в ячейку
	# через get_global_transform(), который не видит трансформ CanvasLayer.
	# На растянутом ×2 слое HUD клик попадал в удвоенную позицию, а предмет в
	# «руке» уезжал от курсора — инвентарём было нельзя пользоваться.
	# Поэтому экран обязан висеть на собственном слое без масштаба. В headless
	# метрики окна недостоверны, так что здесь только структурная проверка,
	# а настоящий курсор смотрим в кадре -Shots.
	var host: CanvasLayer = inv.get_parent() as CanvasLayer
	var identity: bool = host != null and host.transform == Transform2D()
	print("TEST layer identity=", identity, " hud_scaled=",
		m.hud.transform.get_scale() != Vector2.ONE)
	if not identity:
		print("TEST FAIL: экран инвентаря висит на трансформированном слое")
		get_tree().quit()
		return
	var amulet = ItemCatalog.stack("amulet_ward", 1)
	if amulet == null or inv.bag_view.inventory.try_add_item(amulet) != 1:
		print("TEST FAIL: амулет не лёг в сумку экрана")
		get_tree().quit()
		return
	await get_tree().create_timer(0.3).timeout
	var bag_cell0 = inv.bag_view.get_item_view_at_position(0, 0)
	var amulet_idx: int = GameState.EQUIP_SLOTS.find("amulet")
	var eq_rect: Rect2 = inv.equip_view.get_node("Cells").get_child(amulet_idx).get_global_rect()
	var got_bag = inv.bag_view.global_position_to_cell(bag_cell0.get_global_rect().get_center())
	var got_eq = inv.equip_view.global_position_to_cell(eq_rect.get_center())
	var snap_off: float = inv.equip_view.cell_position_to_global(
		Vector2(amulet_idx, 0)).distance_to(eq_rect.end)
	print("TEST cells bag=", got_bag, " equip=", got_eq, " snap_off=", snappedf(snap_off, 0.1))
	if got_bag != Vector2.ZERO or got_eq != Vector2(amulet_idx, 0) or snap_off > 2.0:
		print("TEST FAIL: экранная позиция мыши не совпадает с ячейками")
		get_tree().quit()
		return
	# реальный путь перетаскивания: движение мыши над слотом задаёт цель,
	# отпускание кнопки кладёт стопку именно туда
	var held = GrabbedItemStackView.get_instance()
	held.grab(inv.bag_view.inventory.get_item_at_position(0, 0))
	var motion := InputEventMouseMotion.new()
	motion.global_position = eq_rect.get_center()
	inv.equip_view._on_cell_gui_input(motion, amulet_idx)
	held.drop()
	await get_tree().process_frame
	var worn_amulet = GameState.equipped.get("amulet")
	var clicked_on := worn_amulet is Dictionary and String(worn_amulet.get("id", "")) == "amulet_ward"
	print("TEST click-equip amulet=", clicked_on)
	if not clicked_on:
		print("TEST FAIL: предмет не надевается перетаскиванием")
		get_tree().quit()
		return
	# --- перетаскивание: тот же путь, что и отпускание мыши в UI, —
	# try_place_stackv вью. Стопка обязана уйти из сумки, встать в слот и
	# переехать в GameState. Берём ring2: в ring мог сесть подобранный выше предмет.
	var ring = ItemCatalog.stack("ring_power", 1)
	var src = null
	if ring != null and inv.bag_view.inventory.try_add_item(ring) == 1:
		for st in inv.bag_view.inventory.items:
			if st != null and String(st.item_type.resource_name) == "ring_power":
				src = st
				break
	if src == null:
		print("TEST FAIL: кольцо не легло в сумку экрана")
		get_tree().quit()
		return
	inv.bag_view.inventory.remove_item(src)
	var left_handed = inv.equip_view.try_place_stackv(
		src, Vector2(GameState.EQUIP_SLOTS.find("ring2"), 0))
	await get_tree().process_frame
	var worn = GameState.equipped.get("ring2")
	var worn_ok := worn is Dictionary and String(worn.get("id", "")) == "ring_power"
	var left_in_bag := false
	for e in GameState.inventory:
		if String(e.get("id")) == "ring_power":
			left_in_bag = true
	print("TEST drag placed=", left_handed == null, " worn=", worn_ok,
		" left_in_bag=", left_in_bag)
	if left_handed != null or not worn_ok or left_in_bag:
		print("TEST FAIL: перетаскивание не доехало до GameState")
		get_tree().quit()
		return
	# мост обязан вернуть ровно то же, что принял: пересборка сумки молча
	# чистит GameState, если хоть один предмет не распарсился в ItemType
	var inv_before := GameState.inventory.size()
	var worn_before := 0
	for s in GameState.EQUIP_SLOTS:
		if GameState.equipped.get(s) is Dictionary:
			worn_before += 1
	inv.request_close()
	await get_tree().process_frame
	print("TEST inventory closed=", not m.hud.is_inventory_open(), " paused=", get_tree().paused)
	if m.hud.is_inventory_open() or get_tree().paused:
		print("TEST FAIL: экран инвентаря не закрылся")
		get_tree().quit()
		return
	var worn_after := 0
	for s in GameState.EQUIP_SLOTS:
		if GameState.equipped.get(s) is Dictionary:
			worn_after += 1
	print("TEST bridge inv=", inv_before, "->", GameState.inventory.size(),
		" worn=", worn_before, "->", worn_after)
	if GameState.inventory.size() != inv_before or worn_after != worn_before:
		print("TEST FAIL: экран инвентаря потерял предметы")
		get_tree().quit()
		return
	# --- выбор в диалоге: курсор обязан быть видимым, а цифры 1–3 работать.
	# Раньше мышь оставалась захваченной, и диалог с выбором нельзя было закрыть.
	m.hud.auto = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mode_before: int = Input.mouse_mode
	m.hud.ask("TEST choice", ["A", "B", "C"])
	await get_tree().process_frame
	var choice_open: bool = m.hud.choices_open
	var choice_mouse: bool = Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var choice_buttons: int = m.hud.choice_root.get_child_count()
	print("TEST choice open=", choice_open, " mouse_visible=", choice_mouse,
		" buttons=", choice_buttons)
	if not choice_open or not choice_mouse or choice_buttons != 3:
		print("TEST FAIL: выбор не открылся или курсор остался захваченным")
		get_tree().quit()
		return
	var choice_ev := InputEventAction.new()
	choice_ev.action = "choice_2"
	choice_ev.pressed = true
	m.hud._unhandled_input(choice_ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var choice_closed: bool = not m.hud.choices_open
	var mouse_restored: bool = Input.mouse_mode == mode_before
	print("TEST choice closed=", choice_closed, " mouse_restored=", mouse_restored,
		" mode=", Input.mouse_mode, " before=", mode_before)
	if not choice_closed or not mouse_restored:
		print("TEST FAIL: выбор не закрылся или курсор не вернулся в игру")
		get_tree().quit()
		return
	m.hud.auto = true
	m._finish()
	await get_tree().create_timer(1.6).timeout
	print("TEST DONE escaped=", GameState.escaped)
	get_tree().quit()
