extends CanvasLayer
## HUD: полосы, задачи, подсказки, диалоги с выбором, пауза, смерть.

signal advance_pressed
signal choice_made(index)
signal resumed
signal restart_requested
signal menu_requested

var objective_label: Label
var objective_panel: Control
var objective_header: Label
var hp_fill: TextureRect
var magic_fill: TextureRect
var craving_fill: TextureRect
var xp_fill: TextureRect
var level_label: Label
var points_label: Label
var r_icon: TextureRect
var r_label: Label
var development_root: Control
var _dev_closed_frame := -1
var trust_fill: TextureRect
var trust_label: Label
var prompt_label: Label
var hint_label: Label
var counters_label: Label
var dialogue_root: Control
var dialogue_panel: NinePatchRect
var portrait: TextureRect
var speaker_label: Label
var text_label: Label
var choice_root: VBoxContainer
var channel_root: Control
var channel_fill: TextureRect
var boss_root: Control
var boss_fill: TextureRect
var boss_name: Label
var fade_rect: ColorRect
var damage_rect: ColorRect
var pause_root: Control
var settings_root: Control
var inventory_root: Control
var _settings_closed_frame := -1
var _inventory_closed_frame := -1
var _i_down := false
var death_root: Control
var typing := false
var waiting_advance := false
var choices_open := false
var auto := false

const BAR_W := 132


func _ready() -> void:
	layer = 10
	_build()
	GameState.stats_changed.connect(_refresh_stats)
	GameState.xp_changed.connect(_refresh_progression)
	GameState.skills_changed.connect(_refresh_progression)
	GameState.xp_gained.connect(_on_xp_gained)
	GameState.level_up.connect(_on_level_up)
	_refresh_stats()
	_refresh_progression()


func _panel(pos: Vector2, size: Vector2) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = Art.tex("res://assets/ui/panel.png")
	p.patch_margin_left = 5
	p.patch_margin_right = 5
	p.patch_margin_top = 5
	p.patch_margin_bottom = 5
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(text: String, pos: Vector2, size: Vector2, fsize := 11, color := Color(0.85, 0.82, 0.74)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _bar(pos: Vector2, tex_path: String, icon_path: String) -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = Art.tex("res://assets/ui/bar_bg.png")
	bg.position = pos
	bg.size = Vector2(BAR_W, 7)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var fill := TextureRect.new()
	fill.texture = Art.tex(tex_path)
	fill.position = pos + Vector2(1, 1)
	fill.size = Vector2(BAR_W - 2, 5)
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fill)
	var icon := TextureRect.new()
	icon.texture = Art.tex(icon_path)
	icon.position = pos + Vector2(-14, -6)
	icon.size = Vector2(12, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	return fill


func _build() -> void:
	# --- задача слева сверху ---
	objective_panel = _panel(Vector2(8, 8), Vector2(268, 40))
	objective_header = _label("ЗАДАЧА", Vector2(16, 11), Vector2(60, 12), 8, Color(0.72, 0.62, 0.42))
	objective_label = _label("", Vector2(16, 22), Vector2(252, 22), 11)
	objective_panel.visible = false
	objective_header.visible = false
	_panel(Vector2(8, 52), Vector2(180, 20))
	counters_label = _label("Записки: 0/5 · Предметы: 0/6", Vector2(14, 56), Vector2(170, 14), 8,
		Color(0.72, 0.68, 0.58))

	# --- уровень и полоса опыта ---
	_panel(Vector2(8, 76), Vector2(180, 20))
	level_label = _label("УР. 1", Vector2(14, 80), Vector2(70, 12), 8, Color(0.86, 0.8, 0.6))
	var xbg := TextureRect.new()
	xbg.texture = Art.tex("res://assets/ui/bar_bg.png")
	xbg.position = Vector2(86, 83)
	xbg.size = Vector2(94, 6)
	xbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xbg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(xbg)
	xp_fill = TextureRect.new()
	xp_fill.texture = Art.tex("res://assets/ui/bar_trust.png")
	xp_fill.position = Vector2(87, 84)
	xp_fill.size = Vector2(0, 4)
	xp_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	xp_fill.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(xp_fill)
	points_label = _label("", Vector2(8, 98), Vector2(196, 12), 7, Color(1.0, 0.9, 0.62))

	# --- доверие справа сверху ---
	_panel(Vector2(470, 8), Vector2(162, 34))
	_label("ДОВЕРИЕ АЛЬЯНСА", Vector2(478, 11), Vector2(150, 12), 7, Color(0.62, 0.66, 0.72))
	var tb := TextureRect.new()
	tb.texture = Art.tex("res://assets/ui/bar_bg.png")
	tb.position = Vector2(478, 24)
	tb.size = Vector2(120, 7)
	tb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tb.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tb)
	trust_fill = TextureRect.new()
	trust_fill.texture = Art.tex("res://assets/ui/bar_trust.png")
	trust_fill.position = Vector2(479, 25)
	trust_fill.size = Vector2(60, 5)
	trust_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trust_fill.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(trust_fill)
	trust_label = _label("-40", Vector2(602, 22), Vector2(30, 12), 9, Color(0.7, 0.78, 0.85))

	# --- панель героя слева снизу ---
	_panel(Vector2(8, 302), Vector2(228, 50))
	_label("ТОРВИН ГРИМ", Vector2(16, 305), Vector2(140, 14), 9, Color(0.78, 0.70, 0.55))
	hp_fill = _bar(Vector2(28, 318), "res://assets/ui/bar_health.png", "res://assets/ui/icon_heart.png")
	magic_fill = _bar(Vector2(28, 331), "res://assets/ui/bar_magic.png", "res://assets/ui/icon_spike.png")
	craving_fill = _bar(Vector2(28, 344), "res://assets/ui/bar_craving.png", "res://assets/ui/icon_eye.png")

	# --- способности справа снизу ---
	_panel(Vector2(456, 306), Vector2(176, 46))
	var names := ["ЛКМ", "ПКМ", "Space", "Q", "R"]
	var icons := ["icon_attack", "icon_eat", "icon_dash", "icon_spike", "icon_eye"]
	for i in 5:
		var icon := TextureRect.new()
		icon.texture = Art.tex("res://assets/ui/%s.png" % icons[i])
		icon.position = Vector2(462 + i * 34, 310)
		icon.size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
		var key_label := _label(names[i], Vector2(462 + i * 34, 330), Vector2(30, 12), 7,
			Color(0.62, 0.60, 0.54))
		if i == 4:
			# слот R показываем только после изучения «Кровавой новы»
			r_icon = icon
			r_label = key_label
			icon.visible = false
			key_label.visible = false

	# --- подсказка взаимодействия ---
	prompt_label = _label("", Vector2(0, 258), Vector2(640, 18), 11, Color(0.95, 0.88, 0.7))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label("", Vector2(0, 274), Vector2(640, 18), 10, Color(0.72, 0.72, 0.7))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- канал поглощения ---
	channel_root = Control.new()
	channel_root.position = Vector2(268, 232)
	channel_root.size = Vector2(104, 10)
	channel_root.visible = false
	add_child(channel_root)
	var cbg := NinePatchRect.new()
	cbg.texture = Art.tex("res://assets/ui/panel.png")
	cbg.patch_margin_left = 5
	cbg.patch_margin_right = 5
	cbg.patch_margin_top = 5
	cbg.patch_margin_bottom = 5
	cbg.size = Vector2(104, 10)
	channel_root.add_child(cbg)
	channel_fill = TextureRect.new()
	channel_fill.texture = Art.tex("res://assets/ui/bar_magic.png")
	channel_fill.position = Vector2(2, 2)
	channel_fill.size = Vector2(0, 6)
	channel_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	channel_fill.stretch_mode = TextureRect.STRETCH_SCALE
	channel_root.add_child(channel_fill)

	# --- диалог ---
	dialogue_root = Control.new()
	dialogue_root.visible = false
	dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_root)
	var dpanel := NinePatchRect.new()
	dpanel.texture = Art.tex("res://assets/ui/panel.png")
	dpanel.patch_margin_left = 6
	dpanel.patch_margin_right = 6
	dpanel.patch_margin_top = 6
	dpanel.patch_margin_bottom = 6
	dpanel.position = Vector2(36, 268)
	dpanel.size = Vector2(568, 80)
	dialogue_root.add_child(dpanel)
	dialogue_panel = dpanel
	portrait = TextureRect.new()
	portrait.position = Vector2(44, 274)
	portrait.size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialogue_root.add_child(portrait)
	speaker_label = Label.new()
	speaker_label.position = Vector2(120, 272)
	speaker_label.size = Vector2(420, 16)
	speaker_label.add_theme_font_size_override("font_size", 12)
	speaker_label.add_theme_color_override("font_color", Color(0.86, 0.74, 0.48))
	dialogue_root.add_child(speaker_label)
	text_label = Label.new()
	text_label.position = Vector2(120, 290)
	text_label.size = Vector2(470, 48)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_root.add_child(text_label)

	# --- варианты выбора ---
	choice_root = VBoxContainer.new()
	choice_root.position = Vector2(180, 150)
	choice_root.size = Vector2(280, 90)
	choice_root.visible = false
	choice_root.add_theme_constant_override("separation", 6)
	add_child(choice_root)

	# --- босс ---
	boss_root = Control.new()
	boss_root.visible = false
	add_child(boss_root)
	boss_name = Label.new()
	boss_name.position = Vector2(300, 47)
	boss_name.size = Vector2(320, 16)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 12)
	boss_name.add_theme_color_override("font_color", Color(0.86, 0.4, 0.42))
	boss_root.add_child(boss_name)
	var bpanel := NinePatchRect.new()
	bpanel.texture = Art.tex("res://assets/ui/panel.png")
	bpanel.patch_margin_left = 5
	bpanel.patch_margin_right = 5
	bpanel.patch_margin_top = 5
	bpanel.patch_margin_bottom = 5
	bpanel.position = Vector2(300, 44)
	bpanel.size = Vector2(320, 38)
	boss_root.add_child(bpanel)
	var bbg := TextureRect.new()
	bbg.texture = Art.tex("res://assets/ui/bar_bg.png")
	bbg.position = Vector2(320, 66)
	bbg.size = Vector2(280, 8)
	bbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bbg.stretch_mode = TextureRect.STRETCH_SCALE
	boss_root.add_child(bbg)
	boss_fill = TextureRect.new()
	boss_fill.texture = Art.tex("res://assets/ui/bar_health.png")
	boss_fill.position = Vector2(321, 67)
	boss_fill.size = Vector2(278, 6)
	boss_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_fill.stretch_mode = TextureRect.STRETCH_SCALE
	boss_root.add_child(boss_fill)
	boss_name.move_to_front()

	# --- пауза ---
	pause_root = Control.new()
	pause_root.visible = false
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)
	var pt := Label.new()
	pt.text = "ПАУЗА"
	pt.position = Vector2(0, 110)
	pt.size = Vector2(640, 30)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_theme_font_size_override("font_size", 24)
	pt.add_theme_color_override("font_color", Color(0.86, 0.78, 0.6))
	pause_root.add_child(pt)
	_pause_button("Продолжить", 160, func(): toggle_pause(false))
	_pause_button("Начать заново", 194, func(): restart_requested.emit())
	_pause_button("Настройки", 228, _open_settings)
	_pause_button("В главное меню", 262, func(): menu_requested.emit())
	_pause_button("Выйти из игры", 296, func(): get_tree().quit())

	# --- смерть ---
	death_root = Control.new()
	death_root.visible = false
	death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(death_root)
	var ddim := ColorRect.new()
	ddim.color = Color(0.12, 0.01, 0.03, 0.7)
	ddim.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(ddim)
	var dt := Label.new()
	dt.text = "ТЬМА ЗАБРАЛА ТЕБЯ"
	dt.position = Vector2(0, 130)
	dt.size = Vector2(640, 30)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dt.add_theme_font_size_override("font_size", 22)
	dt.add_theme_color_override("font_color", Color(0.8, 0.3, 0.32))
	death_root.add_child(dt)
	var db := Button.new()
	db.text = "Попробовать снова"
	db.position = Vector2(250, 190)
	db.size = Vector2(140, 26)
	db.add_theme_font_size_override("font_size", 13)
	db.pressed.connect(func(): restart_requested.emit())
	death_root.add_child(db)

	# --- затухание ---
	damage_rect = ColorRect.new()
	damage_rect.color = Color(0.55, 0.02, 0.03, 0.0)
	damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_rect)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)


func _pause_button(text: String, y: float, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = Vector2(250, y)
	b.size = Vector2(140, 26)
	b.add_theme_font_size_override("font_size", 13)
	b.flat = true
	b.pressed.connect(action)
	pause_root.add_child(b)


## Инвентарь — отдельный экран в координатах 1280×720, как настройки и развитие:
## в половинной сетке HUD его панель не помещалась, подписи лезли одна на другую.
func is_inventory_open() -> bool:
	return inventory_root != null and is_instance_valid(inventory_root)


func toggle_inventory(on: bool) -> void:
	if on:
		_open_inventory()
	elif is_inventory_open():
		inventory_root.request_close()


func _open_inventory() -> void:
	if is_inventory_open():
		return
	var s: Control = load("res://scripts/inventory_screen.gd").new()
	s.scale = Vector2(0.5, 0.5)
	s.closed.connect(func():
		# Esc/I внутри экрана закрыл его сам — этот же кадр не должен ещё и открыть паузу
		_inventory_closed_frame = Engine.get_process_frames()
		inventory_root = null
		s.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(s)
	inventory_root = s
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Экран настроек поверх паузы: HUD растянут ×2, поэтому компенсируем масштаб.
func _open_settings() -> void:
	if settings_root != null and is_instance_valid(settings_root):
		return
	var s: Control = load("res://scripts/settings_screen.gd").new()
	s.scale = Vector2(0.5, 0.5)
	s.closed.connect(func():
		# Esc закрывает настройки — этот же кадр не должен ещё и снимать паузу
		_settings_closed_frame = Engine.get_process_frames()
		settings_root = null
		s.queue_free())
	add_child(s)
	settings_root = s


func _refresh_stats() -> void:
	if hp_fill == null:
		return
	hp_fill.size.x = int((BAR_W - 2) * clampf(GameState.health / GameState.get_max_health(), 0.0, 1.0))
	magic_fill.size.x = int((BAR_W - 2) * clampf(GameState.magic / GameState.get_max_magic(), 0.0, 1.0))
	craving_fill.size.x = int((BAR_W - 2) * clampf(GameState.craving / GameState.MAX_CRAVING, 0.0, 1.0))
	var t := (GameState.trust + 100.0) / 200.0
	trust_fill.size.x = int(120 * t)
	trust_label.text = ("+" if GameState.trust > 0 else "") + str(GameState.trust)


var _hud_vis := {}


## Полоса опыта, номер уровня и подсказка о неиспользованных очках.
func _refresh_progression() -> void:
	if xp_fill == null:
		return
	var need: int = GameState.xp_need()
	var ratio := 0.0
	if need > 0:
		ratio = clampf(float(GameState.xp) / float(need), 0.0, 1.0)
	xp_fill.size.x = int(92 * ratio)
	level_label.text = "УР. %d" % GameState.level
	var points: int = GameState.stat_points + GameState.skill_points
	if points > 0:
		points_label.text = "K — развитие: %d оч." % points
	else:
		points_label.text = ""
	if r_icon != null:
		var open: bool = GameState.skill_rank("blood_nova") > 0
		r_icon.visible = open
		r_label.visible = open


## Всплывающая надпись: «ОПЫТ +100», «УРОВЕНЬ 2». Живёт в 640×360.
func toast(text: String, color: Color, y: float, fsize := 11) -> void:
	var l := _label(text, Vector2(0, y), Vector2(640, 18), fsize, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_property(l, "position:y", y - 18.0, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1)
	tw.tween_callback(l.queue_free)


func _on_xp_gained(amount: int) -> void:
	toast("ОПЫТ +%d" % amount, Color(0.78, 0.82, 0.92), 244.0)


func _on_level_up(lvl: int) -> void:
	toast("УРОВЕНЬ %d" % lvl, Color(1.0, 0.86, 0.5), 222.0, 14)
	Sfx.play("sfx_trust", -8.0)
	_refresh_progression()


## Экран развития поверх мира: ставим паузу, иначе бой идёт за спиной.
func _open_development() -> void:
	if development_root != null and is_instance_valid(development_root):
		return
	var d: Control = load("res://scripts/development_screen.gd").new()
	d.scale = Vector2(0.5, 0.5)
	d.closed.connect(func():
		# Esc/K закрывают экран — этот же кадр не должен ещё и открыть паузу
		_dev_closed_frame = Engine.get_process_frames()
		development_root = null
		d.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	add_child(d)
	development_root = d
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("sfx_click", -16.0, 1.1)


func hide_play_hud(hide: bool) -> void:
	for c in get_children():
		if c is Control and c.position.y >= 228.0:
			if c in [dialogue_root, choice_root, pause_root, death_root, fade_rect]:
				continue
			if hide:
				_hud_vis[c] = c.visible
				c.visible = false
			else:
				c.visible = _hud_vis.get(c, true)


func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text
		var has_text := text.strip_edges() != ""
		objective_panel.visible = has_text
		objective_header.visible = has_text


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_hint(text: String) -> void:
	hint_label.text = text


func show_boss(name: String, hp_ratio: float) -> void:
	boss_root.visible = true
	boss_name.text = name
	boss_fill.size.x = int(278 * clampf(hp_ratio, 0.0, 1.0))


func hide_boss() -> void:
	boss_root.visible = false


func show_channel(t: float) -> void:
	channel_root.visible = t > 0.0
	channel_fill.size.x = int(100 * clampf(t, 0.0, 1.0))


func say(entries: Array) -> void:
	hide_play_hud(true)
	dialogue_root.visible = true
	for e in entries:
		var data: Dictionary = e
		speaker_label.text = data.get("name", "")
		var pname: String = data.get("portrait", "")
		if pname == "":
			portrait.visible = false
			text_label.position = Vector2(52, 290)
			text_label.size = Vector2(538, 48)
			speaker_label.position = Vector2(52, 272)
		else:
			portrait.visible = true
			portrait.texture = Art.tex("res://assets/ui/portrait_%s.png" % pname)
			text_label.position = Vector2(120, 290)
			text_label.size = Vector2(470, 48)
			speaker_label.position = Vector2(120, 272)
		text_label.text = data.get("text", "")
		Voice.play_for(String(data.get("text", "")))
		text_label.visible_characters = 0
		typing = true
		if auto:
			text_label.visible_characters = -1
			typing = false
		while typing:
			await get_tree().process_frame
		waiting_advance = true
		while waiting_advance:
			if auto:
				waiting_advance = false
				break
			await get_tree().process_frame
	dialogue_root.visible = false
	hide_play_hud(false)


func _process(delta: float) -> void:
	if typing and text_label:
		var total := text_label.get_total_character_count()
		text_label.visible_characters += int(delta * 42.0) + 1
		if text_label.visible_characters >= total:
			text_label.visible_characters = total
			typing = false
	# Инерция по клавише: раньше открытие и закрытие висело на is_key_pressed,
	# поэтому удержанная «I» переключала экран каждый кадр — окно мигало.
	var i_down := Input.is_physical_key_pressed(KEY_I)
	var i_edge := i_down and not _i_down
	_i_down = i_down
	if is_inventory_open():
		return
	if settings_root == null and development_root == null \
			and _settings_closed_frame != Engine.get_process_frames() \
			and _dev_closed_frame != Engine.get_process_frames() \
			and Input.is_action_just_pressed("pause"):
		if pause_root != null and pause_root.visible:
			toggle_pause(false)
			return
		if not death_root.visible and not dialogue_root.visible:
			toggle_pause(true)
			return
	if i_edge and settings_root == null and development_root == null \
			and _inventory_closed_frame != Engine.get_process_frames() \
			and not get_tree().paused and not dialogue_root.visible and not death_root.visible \
			and (pause_root == null or not pause_root.visible):
		_open_inventory()

	# --- экран развития по K ---
	if InputMap.has_action("skills") and development_root == null \
			and _dev_closed_frame != Engine.get_process_frames() \
			and not get_tree().paused and not dialogue_root.visible and not death_root.visible \
			and (pause_root == null or not pause_root.visible) \
			and Input.is_action_just_pressed("skills"):
		_open_development()


func _unhandled_input(event: InputEvent) -> void:
	if dialogue_root == null or not dialogue_root.visible:
		return
	# Пока открыт выбор, Enter/ЛКМ не должны «проглатываться» как перелистывание
	# реплики: выбор делается цифрами 1–3 или мышью по кнопке.
	if choices_open:
		if event.is_action_pressed("choice_1"):
			_select_choice(0)
		elif event.is_action_pressed("choice_2"):
			_select_choice(1)
		elif event.is_action_pressed("choice_3"):
			_select_choice(2)
		return
	var pressed: bool = event.is_action_pressed("confirm") or event.is_action_pressed("attack") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if typing:
		text_label.visible_characters = text_label.get_total_character_count()
		typing = false
	elif waiting_advance:
		waiting_advance = false


func _select_choice(index: int) -> void:
	if not choices_open:
		return
	Sfx.play("sfx_click", -6.0)
	get_viewport().set_input_as_handled()
	choice_made.emit(index)


## Плоская кнопка выбора: в тёмном HUD стандартный серый Button теряется.
func _choice_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb


func ask(prompt: String, options: Array) -> int:
	hide_play_hud(true)
	speaker_label.text = prompt
	text_label.text = "Выберите ответ мышью или клавишами 1–3."
	text_label.visible_characters = -1
	dialogue_root.visible = true
	choices_open = true
	for c in choice_root.get_children():
		c.queue_free()
	var idx := 0
	for opt in options:
		var i := idx
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, opt]
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.62))
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.62))
		b.custom_minimum_size = Vector2(280, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal",
			_choice_style(Color(0.055, 0.065, 0.085, 0.96), Color(0.35, 0.31, 0.22, 0.9)))
		b.add_theme_stylebox_override("hover",
			_choice_style(Color(0.12, 0.11, 0.08, 0.96), Color(0.78, 0.62, 0.28, 0.95)))
		b.add_theme_stylebox_override("focus",
			_choice_style(Color(0.12, 0.11, 0.08, 0.96), Color(0.9, 0.72, 0.32, 1.0)))
		b.add_theme_stylebox_override("pressed",
			_choice_style(Color(0.16, 0.12, 0.07, 0.98), Color(0.95, 0.75, 0.35, 1.0)))
		b.pressed.connect(func(): _select_choice(i))
		choice_root.add_child(b)
		idx += 1
	choice_root.visible = true
	# Варианты выше диалоговой панели: иначе кнопки лежат поверх текста и
	# кажутся частью фона.
	choice_root.position = Vector2(180, 150)
	if auto:
		choice_root.visible = false
		choices_open = false
		dialogue_root.visible = false
		return 0
	# Без видимого курсора кнопки мыши не выбрать: в миссии он захвачен.
	var prev_mouse: int = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first: Button = choice_root.get_child(0) as Button
	if first != null:
		first.grab_focus()
	var choice: int = await choice_made
	choice_root.visible = false
	choices_open = false
	dialogue_root.visible = false
	hide_play_hud(false)
	Input.mouse_mode = prev_mouse if not get_tree().paused else Input.MOUSE_MODE_VISIBLE
	return choice


func toggle_pause(on: bool) -> void:
	pause_root.visible = on
	get_tree().paused = on
	# в паузе курсор обязан быть виден, иначе по кнопкам меню не попасть;
	# при возврате в игру снова захватываем его для обзора камерой
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if not on:
		resumed.emit()


func show_death() -> void:
	death_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fade_to(alpha: float, time := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, time)
	await tw.finished


func flash_damage() -> void:
	if damage_rect == null:
		return
	damage_rect.color.a = 0.32
	var tw := create_tween()
	tw.tween_property(damage_rect, "color:a", 0.0, 0.45)


func set_counters(notes: int, items: int) -> void:
	if counters_label:
		counters_label.text = "Записки: %d/5 · Предметы: %d/6" % [notes, items]
