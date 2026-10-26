extends Node3D
## Точка входа 3D-версии: меню, кинематик, миссия, финал.

var current: Node = null


func _ready() -> void:
	_register_input()
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		_shots_mode()
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
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_all_loops(0.4)
	var m = load("res://scripts/menu3d.gd").new()
	m.continue_game.connect(func(): start_mission(true))
	m.start_story.connect(show_cinema)
	m.start_mission.connect(func(): start_mission(false))
	m.quit_game.connect(func(): get_tree().quit())
	_swap(m)
	Sfx.loop("music_menu", -16.0, 1.2)


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_menu()
	await get_tree().create_timer(1.0).timeout
	await _shot("3d_menu")
	start_mission()
	await get_tree().create_timer(3.2).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("3d_01")
	var m = current
	if m and m.hero:
		print("DBG hero=", m.hero.global_position, " cam=", m.cam.camera.global_position,
			" hit=", m.cam.spring.get_hit_length(), " lights=", m.dungeon.lights.size())
		m.hero.global_position = Vector3(34.0, 0.2, 49.0)
		if m.cam:
			m.cam.yaw = PI * 0.5
	await get_tree().create_timer(1.5).timeout
	await _shot("3d_02")
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
	m._absorb(m.fleshes[0])
	await get_tree().create_timer(0.3).timeout
	print("TEST absorb magic=", GameState.magic, " craving=", GameState.craving)
	m._break_door()
	await get_tree().create_timer(0.8).timeout
	print("TEST door=", m.door_open, " magic=", GameState.magic, " objective=", m.objective)
	var g = m.enemies[0]
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
	m.boss.take_damage(999.0, Vector3.ZERO)
	await get_tree().create_timer(1.6).timeout
	print("TEST boss dead=", m.boss_dead, " objective=", m.objective)
	m._finish()
	await get_tree().create_timer(1.6).timeout
	print("TEST DONE escaped=", GameState.escaped)
	get_tree().quit()
