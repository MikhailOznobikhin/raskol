extends Node2D
## Миссия 1 «Побег»: уровень, свет, стража, босс, задачи, диалоги.

signal mission_finished(escaped: bool)

const TILE := 32
const MAP_PATH := "res://assets/level/m1.txt"
const PROPS_PATH := "res://assets/level/m1_props.json"

var lines: Array = []
var map_w := 0
var map_h := 0
var wall_grid: Array = []
var world: Node2D
var player: Player
var hud
var cam: Camera2D
var props: Array = []
var guards: Array = []
var boss = null
var lights: Array = []
var fog: Array = []
var flags := {}
var busy := false
var ended := false
var channel_prop: Dictionary = {}
var channel_t := 0.0
var shake_t := 0.0
var shake_amp := 0.0
var selena_node: Node2D = null
var objective_text := ""


func _ready() -> void:
	if not GameState.saw_prologue:
		GameState.reset_run()
	randomize()
	_load_map()
	_build_world()
	_build_props()
	_spawn_player()
	_spawn_guards()
	_spawn_selena()
	_build_fog()
	_build_hud()
	_build_camera()
	_register_triggers()
	if "--test" in OS.get_cmdline_user_args():
		_run_test()
		return
	if "--tour" in OS.get_cmdline_user_args():
		_run_tour()
		return
	Sfx.loop("amb_prison", -16.0, 1.5)
	_intro()


# ---------------------------------------------------------------------------
# уровень
# ---------------------------------------------------------------------------

func _load_map() -> void:
	var f := FileAccess.open(MAP_PATH, FileAccess.READ)
	if f == null:
		push_error("Нет карты уровня")
		return
	var raw: String = f.get_as_text()
	var split: PackedStringArray = raw.split("\n")
	for l in split:
		if l.strip_edges().length() > 0:
			lines.append(l)
	map_h = lines.size()
	map_w = lines[0].length()
	for y in map_h:
		var row: Array = []
		var line: String = lines[y]
		for x in map_w:
			row.append(line.substr(x, 1) == "#")
		wall_grid.append(row)


func is_wall(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
		return true
	return wall_grid[ty][tx]


func is_wall_at(pos: Vector2) -> bool:
	return is_wall(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))


func is_wall_between(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 10.0) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / float(steps))
		if is_wall_at(p):
			return true
	return false


func _build_world() -> void:
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	var bg := Sprite2D.new()
	bg.texture = Art.tex("res://assets/level/m1_bg.png")
	bg.centered = false
	bg.z_index = -100
	world.add_child(bg)

	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	for y in map_h:
		var x := 0
		while x < map_w:
			if wall_grid[y][x]:
				var start := x
				while x < map_w and wall_grid[y][x]:
					x += 1
				var w := (x - start) * TILE
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(w, TILE)
				shape.shape = rect
				shape.position = Vector2(start * TILE + w * 0.5, y * TILE + TILE * 0.5)
				body.add_child(shape)
			else:
				x += 1

	var modulate := CanvasModulate.new()
	modulate.color = Color(0.56, 0.61, 0.80)
	add_child(modulate)


func _prop_texture(type: String, tex_name: String) -> Texture2D:
	return Art.tex("res://assets/props/%s.png" % tex_name)


func _build_props() -> void:
	var txt := FileAccess.get_file_as_string(PROPS_PATH)
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		push_error("Пропсы не загрузились")
		return
	for p in data.get("props", []):
		_spawn_prop(p)


func _spawn_prop(p: Dictionary) -> void:
	var type: String = p.get("type", "")
	var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	var node := Node2D.new()
	node.position = pos
	world.add_child(node)

	var sprite: Node2D
	var tex_name := type
	if type in ["torch", "brazier", "forge_fire"]:
		var anim := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		frames.add_animation("burn")
		frames.set_animation_speed("burn", 9.0)
		frames.set_animation_loop("burn", true)
		var i := 0
		while true:
			var path := "res://assets/props/%s_%d.png" % [type, i]
			if not ResourceLoader.exists(path):
				break
			frames.add_frame("burn", Art.tex(path))
			i += 1
		anim.sprite_frames = frames
		anim.play("burn")
		anim.centered = true
		var h := 32.0 if type == "torch" else 32.0
		anim.offset = Vector2(0, -h * 0.5)
		sprite = anim
		# свет
		var light := PointLight2D.new()
		light.texture = Art.tex("res://assets/fx/light_warm.png")
		light.color = Color(1.0, 0.72, 0.42)
		light.energy = 1.7 if type == "torch" else 1.9
		light.texture_scale = 0.9 if type == "torch" else 1.2
		light.position = Vector2(0, -26)
		node.add_child(light)
		lights.append({"light": light, "base": light.energy, "t": randf() * 10.0})
	elif type == "forge_fire":
		pass
	else:
		var spr := Sprite2D.new()
		var path2 := "res://assets/props/%s.png" % tex_name
		if ResourceLoader.exists(path2):
			spr.texture = Art.tex(path2)
		else:
			spr.texture = Art.tex("res://assets/props/crate.png")
		spr.centered = true
		var hh: float = float(spr.texture.get_height()) if spr.texture != null else 20.0
		spr.offset = Vector2(0, -hh * 0.5)
		sprite = spr
	node.add_child(sprite)

	var entry := {
		"node": node,
		"sprite": sprite,
		"type": type,
		"id": p.get("id", ""),
		"pos": pos,
		"used": false,
		"charges": 3 if type == "refuse" else 0,
	}
	props.append(entry)

	if type == "gate":
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(56, 20)
		shape.shape = rect
		shape.position = Vector2(0, -22)
		body.add_child(shape)
		node.add_child(body)
		entry["body"] = body
	if type == "cell_door":
		var dbody := StaticBody2D.new()
		dbody.collision_layer = 2
		dbody.collision_mask = 0
		var dshape := CollisionShape2D.new()
		var drect := RectangleShape2D.new()
		drect.size = Vector2(30, 14)
		dshape.shape = drect
		dshape.position = Vector2(0, -18)
		dbody.add_child(dshape)
		node.add_child(dbody)
		entry["body"] = dbody
	if type == "stairs":
		entry["exit"] = true


func _spawn_player() -> void:
	player = Player.new()
	player.position = Vector2(6 * TILE + 16, 30 * TILE + 8)
	world.add_child(player)
	player.died.connect(_on_player_died)
	var pl := PointLight2D.new()
	pl.texture = Art.tex("res://assets/fx/light_warm.png")
	pl.color = Color(0.9, 0.78, 0.62)
	pl.energy = 0.45
	pl.texture_scale = 1.4
	pl.position = Vector2(0, -18)
	player.add_child(pl)


func _spawn_guards() -> void:
	var spots := [
		{"pos": Vector2(16, 24), "path": [Vector2(12, 24), Vector2(26, 24)]},
		{"pos": Vector2(28, 24), "path": [Vector2(26, 24), Vector2(31, 24)]},
		{"pos": Vector2(44, 12), "path": [Vector2(39, 12), Vector2(55, 12)]},
		{"pos": Vector2(47, 19), "path": [Vector2(39, 19), Vector2(55, 19)]},
		{"pos": Vector2(52, 13), "path": [Vector2(49, 13), Vector2(55, 13)]},
		{"pos": Vector2(40, 28), "path": [Vector2(37, 28), Vector2(55, 28)]},
		{"pos": Vector2(20, 14), "path": [Vector2(14, 14), Vector2(30, 14)]},
		{"pos": Vector2(26, 18), "path": [Vector2(16, 18), Vector2(31, 18)]},
	]
	for s in spots:
		var g := Guard.new()
		var pp: Vector2 = s["pos"]
		g.position = Vector2(pp.x * TILE + 16, pp.y * TILE + 16)
		var patrol: Array = []
		for wp in s["path"]:
			patrol.append(Vector2(wp.x * TILE + 16, wp.y * TILE + 16))
		g.patrol = patrol
		g.patrol_i = 0
		world.add_child(g)
		g.died.connect(_on_guard_died)
		guards.append(g)


func _spawn_selena() -> void:
	selena_node = Node2D.new()
	selena_node.position = Vector2(22 * TILE + 16, 29 * TILE + 16)
	var spr := Art.make_sprite("selena", "down", "idle")
	spr.offset = Vector2(0, -32)
	selena_node.add_child(spr)
	world.add_child(selena_node)


func _build_fog() -> void:
	for i in 3:
		var f := Sprite2D.new()
		f.texture = Art.tex("res://assets/fx/fog.png")
		f.modulate = Color(0.7, 0.75, 0.9, 0.07)
		f.scale = Vector2(3.2, 2.2)
		f.position = Vector2(randf_range(200, 1600), randf_range(200, 900))
		f.z_index = 40
		add_child(f)
		fog.append({"node": f, "speed": randf_range(3.0, 8.0), "t": randf() * 6.0})


func _build_hud() -> void:
	hud = load("res://scripts/hud.gd").new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.restart_requested.connect(func():
		get_tree().paused = false
		get_parent().start_mission())
	hud.menu_requested.connect(func():
		get_tree().paused = false
		get_parent().show_menu())
	_set_objective("Очнуться и осмотреться")


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map_w * TILE
	cam.limit_bottom = map_h * TILE
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.zoom = Vector2(1.0, 1.0)
	cam.add_to_group("camera")
	add_child(cam)
	cam.global_position = player.global_position
	cam.make_current()


func _process(delta: float) -> void:
	if hud == null:
		return
	if player:
		cam.global_position = player.global_position + Vector2(0, -18)
	_update_lights(delta)
	_update_fog(delta)
	_update_shake(delta)
	if not busy and not ended and not get_tree().paused:
		_update_prompt()
		_update_channel(delta)
		_check_triggers()


func _update_lights(delta: float) -> void:
	for l in lights:
		l["t"] += delta
		var t: float = l["t"]
		var flick := 0.9 + sin(t * 7.3) * 0.05 + sin(t * 13.7) * 0.03 + randf() * 0.03
		var light: PointLight2D = l["light"]
		light.energy = l["base"] * flick


func _update_fog(delta: float) -> void:
	for f in fog:
		f["t"] += delta
		var n: Sprite2D = f["node"]
		n.position.x += f["speed"] * delta
		if n.position.x > map_w * TILE + 200:
			n.position.x = -200
		n.modulate.a = 0.05 + sin(f["t"] * 0.5) * 0.025


func shake(amount: float, duration: float) -> void:
	shake_amp = max(shake_amp, amount)
	shake_t = max(shake_t, duration)


func _update_shake(delta: float) -> void:
	if shake_t > 0.0:
		shake_t -= delta
		cam.offset = Vector2(randf_range(-shake_amp, shake_amp), randf_range(-shake_amp, shake_amp))
		shake_amp = max(0.0, shake_amp - delta * 22.0)
	else:
		cam.offset = cam.offset.lerp(Vector2.ZERO, delta * 12.0)


# ---------------------------------------------------------------------------
# взаимодействие
# ---------------------------------------------------------------------------

func _nearest_prop(max_dist := 54.0) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for p in props:
		if p.get("type", "") in ["torch", "brazier", "stairs"]:
			if not (p.get("type", "") == "stairs"):
				continue
		if p.get("used", false) and p.get("type", "") != "stairs":
			continue
		var d: float = player.global_position.distance_to(p["pos"] + Vector2(0, -16))
		if d < best_d:
			best_d = d
			best = p
	return best


func _nearest_takedown() -> Guard:
	var best: Guard = null
	var best_d := 46.0
	for g in guards:
		if not is_instance_valid(g) or g.is_dead or g.knocked_out:
			continue
		if g.state == "alert" or g.state == "attack":
			continue
		var d: float = player.global_position.distance_to(g.global_position)
		if d > best_d:
			continue
		var to: Vector2 = player.global_position - g.global_position
		if to.length() < 1.0:
			continue
		if g.facing.normalized().dot(to.normalized()) > 0.1:
			continue
		best = g
		best_d = d
	return best


func _update_prompt() -> void:
	var guard := _nearest_takedown()
	if guard:
		hud.set_prompt("E  —  оглушить со спины")
		hud.set_hint("")
		if Input.is_action_just_pressed("absorb"):
			guard.knockout()
			_dialogue_once("takedown", [
				{"name": "Торвин", "portrait": "hero",
				 "text": "Спи, стражник. Мне не нужна твоя кровь."}
			])
			hud.set_prompt("")
		return

	var p := _nearest_prop()
	if p.is_empty():
		hud.set_prompt("")
		if not channel_prop.is_empty():
			channel_prop = {}
			hud.show_channel(0.0)
		return
	match p["type"]:
		"refuse":
			hud.set_prompt("E  —  поглотить гнилую плоть  (%d)" % p.get("charges", 0))
			hud.set_hint("Магия +25  ·  Жажда +3")
			if Input.is_action_just_pressed("absorb") and not player.busy:
				channel_prop = p
				channel_t = 0.0
		"cell_door":
			if p["id"] == "door_start":
				hud.set_prompt("F  —  сломать оковы (20 магии)")
				if Input.is_action_just_pressed("interact"):
					_break_chains(p)
			elif p["id"] == "door_b":
				hud.set_prompt("F  —  поговорить с пленницей")
				if Input.is_action_just_pressed("interact"):
					_selena_choice()
			else:
				hud.set_prompt("Заперто. Ключ у надзирателя.")
		"lever":
			hud.set_prompt("F  —  дёрнуть рычаг")
			if Input.is_action_just_pressed("interact"):
				_pull_lever(p)
		"stairs":
			hud.set_prompt("F  —  подняться к шахте")
			if Input.is_action_just_pressed("interact"):
				_try_escape()
		_:
			hud.set_prompt("")


func _update_channel(delta: float) -> void:
	if channel_prop.is_empty():
		return
	if not Input.is_action_pressed("absorb"):
		channel_prop = {}
		channel_t = 0.0
		hud.show_channel(0.0)
		player.busy = false
		return
	if player.global_position.distance_to(channel_prop["pos"] + Vector2(0, -16)) > 64.0:
		channel_prop = {}
		channel_t = 0.0
		hud.show_channel(0.0)
		player.busy = false
		return
	player.busy = true
	channel_t += delta
	hud.show_channel(channel_t / 1.2)
	if channel_t >= 1.2:
		var p: Dictionary = channel_prop
		channel_prop = {}
		channel_t = 0.0
		player.busy = false
		hud.show_channel(0.0)
		_absorb(p)


func _absorb(p: Dictionary) -> void:
	GameState.add_magic(25.0)
	GameState.add_craving(3.0)
	GameState.flesh_eaten += 1
	p["charges"] = int(p.get("charges", 1)) - 1
	Sfx.play("sfx_absorb", -6.0)
	var sprite: Node2D = p["sprite"]
	sprite.modulate = Color(1.4, 0.7, 0.75)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	_spawn_blood_burst(p["pos"] + Vector2(0, -10))
	if int(p["charges"]) <= 0:
		p["used"] = true
		sprite.modulate = Color(0.45, 0.42, 0.42, 0.7)
	if GameState.craving >= 30.0 and not flags.get("craving_hint", false):
		flags["craving_hint"] = true
		_dialogue_once("craving", [
			{"name": "Торвин", "portrait": "hero",
			 "text": "Тёплое. Солёное. Оно шевелится во мне... Сердце стучит громче, чем цепи."}
		])
	if GameState.magic >= 20.0 and not flags.get("enough_magic", false) and _objective_id() < 3:
		flags["enough_magic"] = true
		_set_objective("Сломать оковы у решётки (F)")
		hud.set_hint("Оковы поддадутся, если потратить 20 магии")


func _spawn_blood_burst(pos: Vector2) -> void:
	var burst := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_speed("burst", 14.0)
	frames.set_animation_loop("burst", false)
	for i in 4:
		var path := "res://assets/fx/impact_%d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame("burst", Art.tex(path))
	burst.sprite_frames = frames
	burst.global_position = pos
	burst.z_index = 30
	add_child(burst)
	burst.play("burst")
	burst.animation_finished.connect(burst.queue_free)
	burst.modulate = Color(1.2, 0.5, 0.6)


func _break_chains(p: Dictionary) -> void:
	if GameState.magic < 20.0:
		hud.set_hint("Нужно 20 магии. Поглоти плоть (E).")
		Sfx.play("sfx_lowmagic", -8.0)
		return
	GameState.spend_magic(20.0)
	Sfx.play("sfx_chain", -5.0)
	var sprite: Sprite2D = p["sprite"]
	sprite.texture = Art.tex("res://assets/props/cell_door_1.png")
	if p.has("body"):
		var b: StaticBody2D = p["body"]
		b.queue_free()
		p["body"] = null
	p["used"] = true
	shake(4.0, 0.2)
	_set_objective("Выйти в коридор")
	hud.set_hint("Свобода за решёткой")


func _pull_lever(p: Dictionary) -> void:
	if p.get("used", false):
		return
	p["used"] = true
	var spr: Sprite2D = p["sprite"]
	spr.texture = Art.tex("res://assets/props/lever_1.png")
	Sfx.play("sfx_gate_open", -6.0)
	shake(3.0, 0.3)
	var gate_id := ""
	if p["id"] == "lever_gate":
		gate_id = "gate_barracks"
	elif p["id"] == "lever_forge":
		gate_id = "gate_forge"
	for g in props:
		if g["id"] == gate_id:
			var gs: Sprite2D = g["sprite"]
			gs.texture = Art.tex("res://assets/props/gate_1.png")
			g["used"] = true
			if g.has("body"):
				var body: StaticBody2D = g["body"]
				body.queue_free()
	if gate_id == "gate_barracks":
		_set_objective("Пройти через казарму к кузне")
	elif gate_id == "gate_forge":
		_set_objective("Войти в кузню оков")


func _try_escape() -> void:
	if not GameState.boss_dead:
		hud.set_hint("Выход заперт. Надзиратель Гхарн всё ещё жив.")
		Sfx.play("sfx_lowmagic", -8.0)
		return
	if ended:
		return
	ended = true
	GameState.escaped = true
	player.control_enabled = false
	await _final_scene()
	mission_finished.emit(true)


# ---------------------------------------------------------------------------
# Селена и выбор
# ---------------------------------------------------------------------------

func _selena_choice() -> void:
	if flags.get("selena_done", false):
		await hud.say([
			{"name": "Селена", "portrait": "selena", "text": "Ты уже решил. Иди."},
		])
		return
	busy = true
	player.control_enabled = false
	await hud.say([
		{"name": "Селена Вейн", "portrait": "selena",
		 "text": "Гном. Живой. Значит, это правда — вы едите нас и получаете силу."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Я не ел... Я выживал. Это разные вещи. Иногда."},
		{"name": "Селена Вейн", "portrait": "selena",
		 "text": "Мой брат Орлан погиб в горах семь лет назад. Скажи мне, что ты не..."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Я знал его."},
	])
	var choice: int = await hud.ask("Что делать с пленницей?",
		["Открыть камеру и освободить", "Забрать её магию. Она мертва для мира", "Уйти и не оглядываться"])
	flags["selena_done"] = true
	if choice == 0:
		GameState.selena = "freed"
		GameState.add_trust(25)
		for pp in props:
			if pp.get("id", "") == "door_b":
				var dspo: Sprite2D = pp["sprite"]
				dspo.texture = Art.tex("res://assets/props/cell_door_1.png")
				pp["used"] = true
				if pp.has("body") and pp["body"] != null:
					pp["body"].queue_free()
					pp["body"] = null
		Sfx.play("sfx_trust", -5.0)
		await hud.say([
			{"name": "Селена Вейн", "portrait": "selena",
			 "text": "Ты... отпускаешь меня? Тогда слушай: есть ритуал. Он выжигает магию из крови — любую. Я знаю его."},
			{"name": "Торвин", "portrait": "hero",
			 "text": "Сначала выберись отсюда. Потом поговорим о ритуалах."},
		])
		_set_objective("Добраться до кухни отбросов")
	elif choice == 1:
		GameState.selena = "devoured"
		GameState.add_trust(-30)
		GameState.add_magic(40.0)
		GameState.add_craving(25.0)
		GameState.flesh_eaten += 1
		Sfx.play("sfx_absorb", -4.0)
		_spawn_blood_burst(Vector2(22 * TILE + 16, 29 * TILE + 10))
		if selena_node:
			selena_node.visible = false
		shake(6.0, 0.5)
		await hud.say([
			{"name": "Торвин", "portrait": "hero",
			 "text": "Прости. Внутри меня слишком много голода, чтобы быть человеком."},
		])
		_set_objective("Добраться до кухни отбросов")
	else:
		GameState.add_trust(-5)
		await hud.say([
			{"name": "Торвин", "portrait": "hero",
			 "text": "Есть выборы, которых я не могу себе позволить. Ни один из них."},
		])
		_set_objective("Найти другой путь")
	busy = false
	player.control_enabled = true
	_refresh_objective()


# ---------------------------------------------------------------------------
# события, цели, триггеры
# ---------------------------------------------------------------------------

var _objective_id_v := 0


func _objective_id() -> int:
	return _objective_id_v


func _set_objective(text: String) -> void:
	objective_text = text
	_objective_id_v += 1
	if hud:
		hud.set_objective(text)


func _refresh_objective() -> void:
	if hud and objective_text != "":
		hud.set_objective(objective_text)


func _register_triggers() -> void:
	pass


func _check_triggers() -> void:
	var p: Vector2 = player.global_position
	# коридор камер
	if not flags.get("corridor", false) and p.y < 26 * TILE and p.y > 21 * TILE and p.x > 10 * TILE:
		flags["corridor"] = true
		_set_objective("Пройти мимо стражи к камере 13")
		_dialogue_once("corridor", [
			{"name": "Торвин", "portrait": "hero",
			 "text": "Коридор. Двое стражников. Цепи на запястьях — тяжёлые, но привычные."},
		])
	# камера Селены
	if not flags.get("sele_zone", false) and p.x > 19 * TILE and p.x < 27 * TILE and p.y > 25 * TILE:
		flags["sele_zone"] = true
		_set_objective("Камера 13: пленница (F)")
	# кухня
	if not flags.get("kitchen", false) and p.x > 34 * TILE and p.y > 23 * TILE:
		flags["kitchen"] = true
		_set_objective("Найти рычаг ворот в казарму")
		_dialogue_once("kitchen", [
			{"name": "Торвин", "portrait": "hero",
			 "text": "Отбросы. Кухня, где варят похлёбку из того, что осталось от магов."},
			{"name": "Торвин", "portrait": "hero",
			 "text": "Семь лет назад я поклялся, что больше не съем ни куска. Клятвы — роскошь для сытых."},
		])
	# казарма
	if not flags.get("barracks", false) and p.y < 21 * TILE and p.x > 36 * TILE:
		flags["barracks"] = true
		_set_objective("Пройти казарму и кузню")
	# кузня — босс
	if not flags.get("forge", false) and p.x < 34 * TILE and p.y > 12 * TILE and p.y < 22 * TILE:
		flags["forge"] = true
		_start_boss_fight()
	# шахта
	if not flags.get("shaft", false) and p.y < 9 * TILE:
		flags["shaft"] = true
		if GameState.boss_dead:
			_set_objective("Подняться к шахте (F)")
		else:
			_set_objective("Шахта заперта. Надзиратель ещё жив.")


func _dialogue_once(id: String, entries: Array) -> void:
	if flags.get("dlg_" + id, false):
		return
	flags["dlg_" + id] = true
	busy = true
	player.control_enabled = false
	await hud.say(entries)
	busy = false
	player.control_enabled = true


func _intro() -> void:
	busy = true
	player.control_enabled = false
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 1.2)
	await hud.say([
		{"name": "Торвин Грим", "portrait": "hero",
		 "text": "Просыпайся, гном. Просыпайся, пока сердце ещё стучит."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Шахта «Кровавый Клык». Год седьмой после Раскола. Дно, ниже которого только смерть."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Кандалы. Пустая камера. И запах — сладковатый, знакомый. Плоть. Гнилая, но всё ещё полная силы."},
	])
	busy = false
	player.control_enabled = true
	_set_objective("Поглотить гнилую плоть (E)")
	hud.set_hint("Подойди к куче отбросов и удерживай E")


func _on_guard_died(guard) -> void:
	guards.erase(guard)


func on_guard_alerted(from_guard) -> void:
	for g in guards:
		if not is_instance_valid(g) or g == from_guard or g.is_dead or g.knocked_out:
			continue
		if g.global_position.distance_to(from_guard.global_position) < 260.0 and g.state != "alert":
			g._enter_alert(player)


func _on_player_died() -> void:
	if ended:
		return
	ended = true
	hud.show_death()


# ---------------------------------------------------------------------------
# босс
# ---------------------------------------------------------------------------

func _start_boss_fight() -> void:
	busy = true
	player.control_enabled = false
	Sfx.loop("music_boss", -12.0, 1.5)
	await hud.say([
		{"name": "Надзиратель Гхарн", "portrait": "gharn",
		 "text": "Пациент Ноль. Живой. И, судя по глазам, голодный."},
		{"name": "Надзиратель Гхарн", "portrait": "gharn",
		 "text": "Знаешь, что делают с теми, кто жрёт отбросы? Их спускают в шахту. Насовсем."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Я спускался ниже. Я поднимусь выше."},
	])
	boss = load("res://scripts/boss.gd").new()
	boss.position = Vector2(22 * TILE, 16 * TILE)
	boss.mission = self
	world.add_child(boss)
	boss.died.connect(_on_boss_died)
	hud.show_boss("НАДЗИРАТЕЛЬ ГХАРН", 1.0)
	busy = false
	player.control_enabled = true
	_set_objective("Победить надзирателя Гхарна")
	Sfx.play("sfx_boss_roar", -4.0)
	shake(8.0, 0.6)


func _on_boss_died() -> void:
	if GameState.boss_dead:
		return
	GameState.boss_dead = true
	hud.hide_boss()
	Sfx.stop_loop("music_boss", 1.5)
	Sfx.play("sfx_chain", -4.0)
	shake(10.0, 0.8)
	_set_objective("Бежать к шахте (вверх)")
	flags["dlg_boss_dead"] = true
	busy = true
	player.control_enabled = false
	await get_tree().create_timer(1.0).timeout
	await hud.say([
		{"name": "Торвин", "portrait": "hero",
		 "text": "Всё. Хватит. Я больше не буду тем, кем меня сделали."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Шахта. Воздух. Снег. Свобода — на самом деле она пахнет холодом."},
	])


func _final_scene() -> void:
	await hud.fade_to(1.0, 1.6)
	await hud.say([
		{"name": "Торвин", "portrait": "hero",
		 "text": "Я вышел из земли. Над горами — кровавая луна, и в её свете снег кажется пеплом."},
		{"name": "Торвин", "portrait": "hero",
		 "text": "Первый шаг сделан. Теперь — война."},
	])


# ---------------------------------------------------------------------------
# автоматический тест (запуск: godot --headless -- --mission --test)
# ---------------------------------------------------------------------------

func _run_test() -> void:
	hud.auto = true
	await get_tree().create_timer(0.4).timeout
	print("TEST start magic=", GameState.magic, " hp=", GameState.health, " props=", props.size(), " guards=", guards.size())
	var refuse = null
	for p in props:
		if p["type"] == "refuse":
			refuse = p
			break
	if refuse:
		_absorb(refuse)
	print("TEST absorb magic=", GameState.magic, " craving=", GameState.craving)
	for p in props:
		if p.get("id", "") == "door_start":
			_break_chains(p)
			print("TEST door broken used=", p["used"])
	var g = guards[0]
	if g and is_instance_valid(g):
		g.knockout()
		print("TEST knockout spared=", GameState.guards_spared)
	if guards.size() > 1 and is_instance_valid(guards[1]):
		guards[1]._enter_alert(player)
	await get_tree().create_timer(1.0).timeout
	print("TEST guard state=", guards[1].state if is_instance_valid(guards[1]) else "dead")
	_spawn_blood_burst(player.global_position)
	player.take_damage(12.0, player.global_position + Vector2(10, 0))
	print("TEST hurt hp=", GameState.health, " state=", player.state)
	_start_boss_fight()
	await get_tree().create_timer(1.2).timeout
	print("TEST boss=", boss != null)
	if boss and is_instance_valid(boss):
		boss.take_damage(300.0)
	await get_tree().create_timer(2.0).timeout
	print("TEST boss_dead=", GameState.boss_dead, " objective=", objective_text)
	_try_escape()
	await get_tree().create_timer(2.5).timeout
	print("TEST DONE escaped=", GameState.escaped, " trust=", GameState.trust)
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/shot_%s.png" % name)
	print("SHOT ", name)


func _run_tour() -> void:
	hud.auto = true
	await get_tree().create_timer(0.6).timeout
	var spots := [
		["cell", Vector2(6 * TILE + 16, 29 * TILE + 8)],
		["corridor", Vector2(17 * TILE, 24 * TILE)],
		["kitchen", Vector2(41 * TILE, 27 * TILE)],
		["barracks", Vector2(45 * TILE, 16 * TILE)],
		["shaft", Vector2(29 * TILE, 5 * TILE)],
		["forge", Vector2(24 * TILE, 18 * TILE)],
	]
	for s in spots:
		player.global_position = s[1]
		cam.global_position = s[1]
		if s[0] == "forge" and boss == null:
			_flags_for_tour()
		await get_tree().create_timer(0.9).timeout
		await _shot("tour_" + s[0])
	get_tree().quit()


func _flags_for_tour() -> void:
	GameState.magic = 70.0
	GameState.craving = 55.0
	for pp in props:
		if pp["type"] == "gate":
			pp["sprite"].texture = Art.tex("res://assets/props/gate_1.png")
			if pp.has("body") and pp["body"] != null:
				pp["body"].queue_free()
	boss = load("res://scripts/boss.gd").new()
	boss.position = Vector2(22 * TILE, 16 * TILE)
	boss.mission = self
	world.add_child(boss)
	boss.died.connect(_on_boss_died)
	hud.show_boss("НАДЗИРАТЕЛЬ ГХАРН", 0.72)
