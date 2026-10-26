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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	get_tree().quit()


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
	m._finish()
	await get_tree().create_timer(1.6).timeout
	print("TEST DONE escaped=", GameState.escaped)
	get_tree().quit()
