extends Node3D
## Полигон уровня 2 «Разлом Собора».
##
## Сцена собрана только из новых файлов и ничего не трогает в миссии 1:
## подключать её к main3d.gd будем после ревью ветки (правило из AGENTS.md).
##
## Запуск:
##   godot --path . res://scenes/level2.tscn -- --l2check   самопроверка
##   godot --path . res://scenes/level2.tscn -- --shots2    кадры для ревью
##   godot --path . res://scenes/level2.tscn               руками

const T := 2.0
## Сколько теней держим на уровне: больше — и свет начинает «исчезать».
const SHADOW_BUDGET := 3

var dungeon: Level2Builder
var hero: Hero3D
var cam: Cam3D
var hud
var enemies: Array = []
var boss: Enemy3D
var exit_node: Node3D
var exit_pos := Vector3.ZERO
var ended := false


func _ready() -> void:
	randomize()
	_register_input()
	var args := OS.get_cmdline_user_args()
	# watchdog ставим до сборки: если _ready упадёт на битой карте, процесс
	# иначе останется висеть в фоне до утра
	if "--l2check" in args or "--shots2" in args:
		var wd := get_tree().create_timer(200.0)
		wd.timeout.connect(func():
			print("LEVEL2 FAIL: режим не завершился за 200 с, выхожу")
			get_tree().quit())

	dungeon = Level2Builder.new()
	add_child(dungeon)
	dungeon.build()

	hero = Hero3D.new()
	hero.position = dungeon.pos_of(dungeon.spawn_cell.x, dungeon.spawn_cell.y) \
		+ Vector3(0.0, 0.2, 0.0)
	add_child(hero)
	hero.died.connect(_on_hero_died)

	cam = Cam3D.new()
	cam.target = hero
	cam.yaw = _face(_view_dir(dungeon.spawn_cell))
	add_child(cam)
	cam.global_position = hero.global_position + Vector3(0, 1.5, 0)

	_build_hud()
	_spawn_exit()
	_spawn_enemies()

	hud.set_objective("Найти брешь в своде и выйти из Собора")
	hud.set_prompt("")

	await get_tree().process_frame
	if "--l2check" in args:
		_check_mode.call_deferred()
	elif "--shots2" in args:
		_shots_mode.call_deferred()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ввод регистрируем сами: main3d.gd в этом полигоне не запускается.
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


func _build_hud() -> void:
	hud = load("res://scripts/hud.gd").new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.layer = 10
	add_child(hud)
	hud.transform = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2.ZERO)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.menu_requested.connect(func(): get_tree().quit())


# ---------------------------------------------------------------------------
# стража, босс, выход
# ---------------------------------------------------------------------------

func _spawn_enemies() -> void:
	for c in dungeon.guard_cells:
		var e: Enemy3D = Enemy3D.new()
		e.setup("guard")
		e.position = dungeon.pos_of(c.x, c.y) + Vector3(0.0, 0.2, 0.0)
		e.patrol = _patrol_of(c)
		e.target = hero
		add_child(e)
		e.died.connect(_on_enemy_died)
		enemies.append(e)
	boss = Enemy3D.new()
	boss.setup("boss")
	boss.position = dungeon.pos_of(dungeon.boss_cell.x, dungeon.boss_cell.y) \
		+ Vector3(0.0, 0.2, 0.0)
	boss.target = hero
	boss.patrol = _patrol_of(dungeon.boss_cell)
	add_child(boss)
	boss.died.connect(_on_boss_died)


## Патруль — самая длинная прямая чистого пола через клетку: стражник ходит
## вдоль коридора, а не упирается в стену и не стоит на месте.
func _patrol_of(c: Vector2i) -> Array:
	var best_n := 0
	var best: Array[Vector2i] = [c, c]
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for ax in axes:
		var lo := c
		while dungeon.is_plain(lo.x - ax.x, lo.y - ax.y):
			lo -= ax
		var hi := c
		while dungeon.is_plain(hi.x + ax.x, hi.y + ax.y):
			hi += ax
		var n: int = absi(hi.x - lo.x) + absi(hi.y - lo.y) + 1
		if n > best_n:
			best_n = n
			best = [lo, hi]
	var out: Array = []
	for k in best:
		out.append(dungeon.pos_of(k.x, k.y) + Vector3(0.0, 0.2, 0.0))
	return out


## Выход — светящийся пролом в конце зала: один источник без тени, чтобы
## не выбивать бюджет теней.
func _spawn_exit() -> void:
	exit_pos = dungeon.pos_of(dungeon.exit_cell.x, dungeon.exit_cell.y)
	exit_node = Node3D.new()
	exit_node.position = exit_pos
	add_child(exit_node)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.7
	tor.outer_radius = 1.0
	tor.rings = 8
	tor.ring_segments = 20
	ring.mesh = tor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.86, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = Vector3(0, 0.12, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	exit_node.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.68, 0.8, 1.0)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = Vector3(0, 1.6, 0)
	exit_node.add_child(light)


func _on_enemy_died(_e) -> void:
	pass


func _on_boss_died(_e) -> void:
	hud.set_objective("Надзиратель Собора пал — искать выход")


func _on_hero_died() -> void:
	print("LEVEL2 FAIL: герой погиб — полигон перезапускается")
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if ended or hero == null or exit_node == null:
		return
	if event.is_action_pressed("interact") and _near_exit():
		_finish()


func _near_exit() -> bool:
	return hero.global_position.distance_to(exit_pos) < 3.0


func _finish() -> void:
	ended = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_prompt("")
	hud.set_objective("Собор остался позади")
	hud.hide_boss()
	print("LEVEL2 ESCAPED pos=", hero.global_position)


func _process(delta: float) -> void:
	# герой/интерфейс могут не построиться (битая карта) — в этом случае
	# ошибка в каждом кадре забивает лог и маскирует настоящую причину
	if ended or hero == null or hud == null or exit_node == null:
		return
	if _near_exit():
		hud.set_prompt("[F] Выйти из Собора")
	else:
		hud.set_prompt("")
	if boss and is_instance_valid(boss) and not boss.dead:
		if hero.global_position.distance_to(boss.global_position) < 14.0:
			hud.show_boss("НАДЗИРАТЕЛЬ СОБОРА", boss.hp / boss.max_hp)
		else:
			hud.hide_boss()
	else:
		hud.hide_boss()
	# кольцо выхода медленно дышит — иначе оно читается как пятно на полу
	exit_node.rotation.y += delta * 0.5


# ---------------------------------------------------------------------------
# самопроверка: проходимость, пандусы, свет, спавн
# ---------------------------------------------------------------------------

## Обход в ширину по «не стена» — вода считается проходимой: под ней пол.
func _reachable(from: Vector2i) -> Dictionary:
	var seen := {}
	if from.x < 0 or not dungeon.is_floor(from.x, from.y):
		return seen
	var q: Array[Vector2i] = [from]
	seen[from] = true
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in Dungeon.DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or not dungeon.is_floor(n.x, n.y):
				continue
			seen[n] = true
			q.append(n)
	return seen


func _check_mode() -> void:
	var fails: Array[String] = []
	var open_cells := 0
	for y in dungeon.map_h:
		for x in dungeon.map_w:
			if dungeon.is_floor(x, y):
				open_cells += 1
	var reach := _reachable(dungeon.spawn_cell)
	if reach.is_empty():
		fails.append("спавн стоит в стене")
	if not reach.has(dungeon.exit_cell):
		fails.append("exit %s недостижим из спавна" % str(dungeon.exit_cell))
	if not reach.has(dungeon.boss_cell):
		fails.append("босс %s недостижим" % str(dungeon.boss_cell))
	for c in dungeon.guard_cells:
		if not reach.has(c):
			fails.append("стражник %s в тупике без прохода" % str(c))
	for c in dungeon.niche_cells:
		if not reach.has(c):
			fails.append("ниша %s отрезана" % str(c))
	for c in dungeon.dais_cells:
		if not reach.has(c):
			fails.append("подиум %s отрезан" % str(c))
			break

	var sd: int = int(dungeon.dist[dungeon.spawn_cell.y][dungeon.spawn_cell.x])
	if sd * T < 5.0:
		fails.append("спавн в %.1f м от стены — камере плохо" % (sd * T))
	if dungeon.cell_ceil(dungeon.spawn_cell.x, dungeon.spawn_cell.y) < 2.2:
		fails.append("над спавном потолок ниже 2,2 м")

	if dungeon.dais_count == 0:
		fails.append("нет ни одного подиума — вертикали не видно")
	if dungeon.ramp_count < dungeon.dais_count:
		fails.append("пандусов %d меньше, чем подиумов %d" \
			% [dungeon.ramp_count, dungeon.dais_count])
	if dungeon.arch_count < 4:
		fails.append("арок всего %d — порталы не поставлены" % dungeon.arch_count)
	if dungeon.niche_count < dungeon.niche_cells.size():
		fails.append("ниш построено %d из %d" % [dungeon.niche_count, dungeon.niche_cells.size()])
	if dungeon.breach_cell.x < 0:
		fails.append("нет пробитого свода — уровень без «нефакельного» света")

	var idle_guards := 0
	for e in enemies:
		if (e as Enemy3D).patrol.size() < 2:
			idle_guards += 1
	if idle_guards > 0:
		fails.append("%d стражников без маршрута" % idle_guards)
	if enemies.size() < 4:
		fails.append("стражи мало: %d" % enemies.size())

	await get_tree().create_timer(1.0).timeout
	var dy: float = hero.global_position.y \
		- dungeon.pos_of(dungeon.spawn_cell.x, dungeon.spawn_cell.y).y
	if absf(dy) > 0.6 or hero.global_position.distance_to(
			dungeon.pos_of(dungeon.spawn_cell.x, dungeon.spawn_cell.y)) > 2.0:
		fails.append("герой провалился или уехал: сдвиг %.2f м" % dy)

	# тени считаем после тика: базовый лимитер включает их только трём
	# ближайшим к герою источникам, сразу после сборки их видно больше
	await get_tree().create_timer(0.5).timeout
	var shadows := 0
	for l in dungeon.lights:
		var ol: OmniLight3D = l["light"]
		if ol.shadow_enabled:
			shadows += 1
	if shadows > SHADOW_BUDGET:
		fails.append("теневых источников %d (максимум %d)" % [shadows, SHADOW_BUDGET])

	print("LEVEL2 cells=", open_cells, " reachable=", reach.size(),
		" guards=", enemies.size(), " arches=", dungeon.arch_count,
		" niches=", dungeon.niche_count, " daises=", dungeon.dais_count,
		" ramps=", dungeon.ramp_count, " sconces=", dungeon.sconce_count,
		" lights=", dungeon.lights.size(), " shadows=", shadows,
		" breach=", dungeon.breach_cell)
	for f in fails:
		print("LEVEL2 FAIL: ", f)
	if fails.is_empty():
		print("[OK] LEVEL2")
	get_tree().quit()


# ---------------------------------------------------------------------------
# кадры для ревью
# ---------------------------------------------------------------------------

## Направление взгляда из клетки — в центр карты: в кадр тогда попадает зал,
## а не ближайшая голубая стена.
func _view_dir(from: Vector2i) -> Vector3:
	var mid := dungeon.pos_of(int(dungeon.map_w / 2), int(dungeon.map_h / 2))
	var d := mid - dungeon.pos_of(from.x, from.y)
	d.y = 0.0
	return d.normalized() if d.length() > 0.4 else Vector3(0.0, 0.0, -1.0)


## Поворот камеры: пружина смотрит вдоль -Z, поэтому направление взгляда d
## достигается yaw = atan2(-d.x, -d.z).
func _face(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _look(cell: Vector2i, at: Vector2i) -> void:
	hero.global_position = dungeon.pos_of(cell.x, cell.y) + Vector3(0.0, 0.2, 0.0)
	hero.velocity = Vector3.ZERO
	var d := dungeon.pos_of(at.x, at.y) - dungeon.pos_of(cell.x, cell.y)
	d.y = 0.0
	cam.yaw = _face(d.normalized())
	cam.pitch = -0.06
	cam.cam_h = 1.55
	cam.follow = hero.global_position + Vector3(0, 1.55, 0)


func _shots_mode() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# страховка: зависшую съёмку закрываем сами, иначе окно останется висеть
	var wd := get_tree().create_timer(150.0)
	wd.timeout.connect(func():
		print("SHOT2 watchdog: съёмка не завершилась, выхожу")
		get_tree().quit())
	hud.auto = true
	var views := [
		{"n": "l2_01_spawn", "at": dungeon.spawn_cell, "to": _rotunda_cell()},
		{"n": "l2_02_rotunda", "at": _rotunda_cell(), "to": dungeon.exit_cell},
		# с угла нефа: с диагонали видно и колоннаду, и алтарь на подиуме
		{"n": "l2_03_nave", "at": Vector2i(25, 8), "to": Vector2i(32, 3)},
		# с дамбу по центру затопленного зала: вода тогда по обе стороны кадра
		{"n": "l2_04_crypt", "at": _causeway_cell(), "to": dungeon.boss_cell},
		{"n": "l2_05_barracks", "at": dungeon.guard_cells[0], "to": _rotunda_cell()},
		{"n": "l2_06_breach", "at": dungeon.breach_cell, "to": _rotunda_cell()},
		# к выходу подходим из зала: со стороны стены пружина камеры уходит в кладку
		{"n": "l2_07_exit", "at": Vector2i(53, 34), "to": dungeon.exit_cell},
	]
	for v in views:
		_look(v["at"], v["to"])
		await get_tree().create_timer(0.9).timeout
		await _shot(v["n"])
	get_tree().quit()


func _rotunda_cell() -> Vector2i:
	# центр ротонды — самая «далёкая от стен» клетка вокруг середины карты
	var best := Vector2i(32, 21)
	var far := 0
	for y in range(14, 30):
		for x in range(24, 42):
			if not dungeon.is_plain(x, y):
				continue
			var d: int = int(dungeon.dist[y][x])
			if d > far:
				far = d
				best = Vector2i(x, y)
	return best


## Клетка дамбы: сухой пол, с севера и с юга — вода. С неё затопленный зал
## читается как зал, а не как чёрный провал.
func _causeway_cell() -> Vector2i:
	for c in dungeon.water_cells:
		var d: Vector2i = c + Vector2i(0, -1)
		if dungeon.is_plain(d.x, d.y) and dungeon.cell_char(d.x, d.y - 1) == "w":
			return d
	return dungeon.boss_cell


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shot_%s.png" % name)
	print("SHOT ", name, " ", img.get_width(), "x", img.get_height())
