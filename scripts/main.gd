extends Node2D
## Точка входа: регистрирует управление и переключает экраны.

var current: Node = null


func _ready() -> void:
	_register_input()
	_add_postfx()
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		_shots_mode(args)
	elif "--mission" in args:
		start_mission()
	elif "--prologue" in args:
		start_prologue()
	elif "--cinema" in args:
		show_cinema()
	else:
		show_menu()


## Плёночный слой без чтения экранного буфера: запечённая виньетка и тёплый
## мультиплай-фильтр. Шейдер с SCREEN_TEXTURE в Compatibility-рендерере давал
## чёрный мир под HUD, поэтому от него отказались (файл оставлен в assets/shaders
## как референс для Forward+).
func _add_postfx() -> void:
	if "--nofx" in OS.get_cmdline_user_args():
		return
	var layer := CanvasLayer.new()
	layer.layer = 5

	# ВАЖНО: никаких blend_mode=MUL и чтения SCREEN_TEXTURE в Compatibility —
	# такие слои гасят весь мир под HUD. Только обычная альфа-виньетка.
	var vig := TextureRect.new()
	vig.texture = Art.tex("res://assets/fx/vignette.png")
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vig)

	add_child(layer)


func _register_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("dash", [KEY_SPACE])
	_add_action("boss_dash", [KEY_SPACE])
	_add_action("spike", [KEY_Q])
	_add_action("absorb", [KEY_E])
	_add_action("interact", [KEY_F])
	_add_action("sneak", [KEY_SHIFT, KEY_CTRL])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("confirm", [KEY_SPACE, KEY_ENTER])
	_add_action("choice_1", [KEY_1])
	_add_action("choice_2", [KEY_2])
	_add_action("choice_3", [KEY_3])
	_add_action("attack", [])
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("heavy", MOUSE_BUTTON_RIGHT)


func _add_action(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)


func _add_mouse(name: String, button: MouseButton) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(name, ev)


func _swap(node: Node) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(node)


func show_menu() -> void:
	Sfx.stop_all_loops(0.4)
	var m := preload("res://scripts/menu_screen.gd").new()
	m.start_prologue.connect(show_cinema)
	m.start_mission.connect(start_mission)
	m.quit_game.connect(func(): get_tree().quit())
	_swap(m)
	Sfx.loop("music_menu", -14.0, 1.2)


func show_cinema() -> void:
	Sfx.stop_all_loops(0.5)
	var c := preload("res://scripts/intro_cinema.gd").new()
	c.finished.connect(start_prologue)
	_swap(c)


func start_prologue() -> void:
	var p := preload("res://scripts/prologue_screen.gd").new()
	p.finished.connect(start_mission)
	_swap(p)
	Sfx.loop("music_menu", -16.0, 1.0)


func start_mission() -> void:
	Sfx.stop_all_loops(0.6)
	var m := preload("res://scripts/mission.gd").new()
	m.mission_finished.connect(_on_mission_finished)
	_swap(m)


func _on_mission_finished(escaped: bool) -> void:
	Sfx.stop_all_loops(1.0)
	var e := preload("res://scripts/ending_screen.gd").new()
	e.escaped = escaped
	e.back_to_menu.connect(show_menu)
	_swap(e)
	if escaped:
		Sfx.play("sfx_win", -6.0)
		Sfx.loop("music_menu", -16.0, 1.5)


func _shots_mode(args: PackedStringArray) -> void:
	if "--prologue" in args:
		start_prologue()
		await get_tree().create_timer(3.5).timeout
		await _shot("01_prologue")
		get_tree().quit()
		return
	if "--cinema" in args:
		show_cinema()
		await get_tree().create_timer(2.4).timeout
		await _shot("cinema_poster")
		await get_tree().create_timer(4.6).timeout
		await _shot("cinema_video")
		get_tree().quit()
		return
	if "--mission" in args:
		start_mission()
		await get_tree().create_timer(4.2).timeout
		await _shot("02_mission")
		get_tree().quit()
		return
	show_menu()
	await get_tree().create_timer(1.6).timeout
	await _shot("01_menu")
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shot_%s.png" % shot_name)
	print("SHOT ", shot_name, " ", img.get_width(), "x", img.get_height())
