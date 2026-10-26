extends Control
## Интерактивный пролог: шесть сцен, три решения, титр.

signal finished

var bg: TextureRect
var narration: Label
var hint: Label
var fade: ColorRect
var choice_box: VBoxContainer
var typing := false
var _skip := false


func _ready() -> void:
	size = Vector2(640, 360)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = Art.tex("res://assets/art/prologue_1_golden.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	bg.modulate = Color(0.9, 0.9, 1.0)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.85))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 8
	gtex.height = 128
	var strip := TextureRect.new()
	strip.texture = gtex
	strip.position = Vector2(0, 200)
	strip.size = Vector2(640, 122)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(strip)

	narration = Label.new()
	narration.position = Vector2(60, 240)
	narration.size = Vector2(520, 76)
	narration.add_theme_font_size_override("font_size", 13)
	narration.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	narration.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	narration.add_theme_constant_override("shadow_offset_x", 1)
	narration.add_theme_constant_override("shadow_offset_y", 1)
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(narration)

	hint = Label.new()
	hint.text = "Space — далее     Esc — пропустить"
	hint.position = Vector2(0, 338)
	hint.size = Vector2(640, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5))
	add_child(hint)

	var bar_top := ColorRect.new()
	bar_top.color = Color(0, 0, 0, 0.85)
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(640, 24)
	add_child(bar_top)
	var bar_bot := ColorRect.new()
	bar_bot.color = Color(0, 0, 0, 0.85)
	bar_bot.position = Vector2(0, 322)
	bar_bot.size = Vector2(640, 38)
	add_child(bar_bot)

	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(150, 150)
	choice_box.size = Vector2(340, 110)
	choice_box.visible = false
	choice_box.add_theme_constant_override("separation", 8)
	add_child(choice_box)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_run()


func _process(delta: float) -> void:
	if typing:
		var total := narration.get_total_character_count()
		narration.visible_characters += int(delta * 46.0) + 1
		if narration.visible_characters >= total:
			narration.visible_characters = total
			typing = false


func _wait_advance() -> void:
	while true:
		await get_tree().process_frame
		if _skip:
			return
		if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack"):
			return


func _line(art_path: String, text: String) -> void:
	if art_path != "":
		bg.texture = Art.tex(art_path)
	narration.text = text
	narration.visible_characters = 0
	typing = true
	fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8)
	await tw.finished
	await _wait_advance()
	if typing:
		typing = false
		narration.visible_characters = narrative_total()
	Sfx.play("sfx_click", -20.0, 0.9)


func narrative_total() -> int:
	return narration.get_total_character_count()


func _ask(options: Array) -> int:
	choice_box.visible = true
	for c in choice_box.get_children():
		c.queue_free()
	var pressed := [-1]
	var idx := 0
	for opt in options:
		var i := idx
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, opt]
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(340, 26)
		b.pressed.connect(func():
			Sfx.play("sfx_click", -6.0)
			pressed[0] = i)
		choice_box.add_child(b)
		idx += 1
	while pressed[0] < 0:
		await get_tree().process_frame
		if Input.is_action_just_pressed("choice_1"):
			pressed[0] = 0
		elif Input.is_action_just_pressed("choice_2"):
			pressed[0] = 1
		elif Input.is_action_just_pressed("choice_3"):
			pressed[0] = 2
	choice_box.visible = false
	return pressed[0]


func _run() -> void:
	GameState.reset_run()
	fade.color.a = 1.0
	await get_tree().create_timer(0.4).timeout

	await _line("res://assets/art/prologue_1_golden.png",
		"Эпоха Золотого Мира. Люди, эльфы и гномы торговали, строили и делали вид, что равны.")
	await _line("",
		"Трое изгоев — волшебник Орлан Вейн, эльф Тиэль Лунный Шёпот и гном Торвин Грим — ушли в горы за рудой. Они нашли больше, чем искали.")
	await _line("res://assets/art/prologue_2_cave.png",
		"Обвал. Три дня в темноте. Орлан умер первым: рана оказалась глубже, чем надежда.")
	await _line("",
		"Тиэль отказался есть плоть друга — для эльфа это несмываемый грех. Он умер на вторые сутки, с открытыми глазами.")
	await _line("",
		"Гном остался один. Голод сильнее клятв. Он съел мясо друга — и выжил.")

	var c1: int = await _ask(["Съесть — и выжить, любой ценой", "Отвернуться и ждать смерти рядом с ними"])
	if c1 == 0:
		GameState.magic = 55.0
		GameState.craving = 12.0
		await _line("",
			"Плоть легла в живот тёплым углём. А потом в крови проснулось то, чего у гномов не было никогда: магия.")
	else:
		GameState.magic = 30.0
		GameState.craving = 6.0
		await _line("",
			"Он отвернулся. И всё равно съел — руками, в темноте, давясь и ненавидя себя. Утром в его крови пела магия.")

	await _line("res://assets/art/prologue_3_rise.png",
		"Слух о гноме, получившем магию, дошёл до кланов. Плоть магов стала товаром: за тушу платили золотом.")
	await _line("",
		"Пожиратели построили культ. Торвин поднял восстание — и его подавили. Всех гномов объявили чудовищами. Без разбора.")
	await _line("",
		"Год седьмой после Раскола. Шахта-тюрьма «Кровавый Клык». Дно, ниже которого только смерть.")

	var c2: int = await _ask(["Сжать кулаки и запомнить лица", "Позволить себе забыть"])
	if c2 == 0:
		GameState.add_craving(4.0)
		await _line("", "Он запомнил. Каждое лицо. Это единственное, что у него осталось.")
	else:
		GameState.health = 100.0
		await _line("", "Он позволил тьме стереть имена. Осталась только цель.")

	GameState.saw_prologue = true
	await _line("", "Миссия 1. Побег.")
	fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	await tw.finished
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_skip = true
