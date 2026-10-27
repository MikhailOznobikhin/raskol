extends Control
## Экран развития: характеристики и навыки. Открывается по K в игре.
## Как и settings_screen, рассчитан на 1280×720; в HUD вызывающий ставит scale = 0.5.

signal closed

const PANEL_W := 880.0
const PANEL_H := 560.0
const PANEL_X := (1280.0 - PANEL_W) * 0.5
const PANEL_Y := (720.0 - PANEL_H) * 0.5

const C_TITLE := Color(0.88, 0.8, 0.62)
const C_TEXT := Color(0.86, 0.82, 0.74)
const C_DIM := Color(0.58, 0.56, 0.5)
const C_ACCENT := Color(1.0, 0.92, 0.72)
const C_BORDER := Color(0.55, 0.45, 0.2, 0.9)

const STAT_IDS := ["strength", "vitality", "spirit"]
const STAT_TITLES := ["СИЛА", "ЖИВУЧЕСТЬ", "ДУХ"]
const STAT_DESCS := ["+8% урона в ближнем бою", "+15 к максимуму здоровья", "+12 к максимуму магии"]

var header: Label
var stat_values: Array[Label] = []
var stat_buttons: Array[Button] = []
var skill_names: Array[Label] = []
var skill_infos: Array[Label] = []
var skill_buttons: Array[Button] = []


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build()
	GameState.xp_changed.connect(_refresh)
	GameState.skills_changed.connect(_refresh)
	_refresh()


func _label(text: String, pos: Vector2, size_v: Vector2, fsize: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size_v
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.06, 0.08, 0.98)
	sb.border_color = C_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size = Vector2(PANEL_W, PANEL_H)
	add_child(panel)

	var title := Label.new()
	title.text = "РАЗВИТИЕ"
	title.position = Vector2(0, PANEL_Y + 18)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.02, 0.04, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)

	header = _label("", Vector2(PANEL_X + 40, PANEL_Y + 72), Vector2(PANEL_W - 80, 26), 17, C_ACCENT)

	# --- характеристики ---
	_label("ХАРАКТЕРИСТИКИ", Vector2(PANEL_X + 40, PANEL_Y + 116), Vector2(300, 24), 16, C_TITLE)
	for i in STAT_IDS.size():
		var y: float = PANEL_Y + 156 + float(i) * 68.0
		_label(String(STAT_TITLES[i]), Vector2(PANEL_X + 40, y), Vector2(200, 24), 19, C_TEXT)
		_label(String(STAT_DESCS[i]), Vector2(PANEL_X + 40, y + 24), Vector2(240, 18), 12, C_DIM)
		stat_values.append(_label("", Vector2(PANEL_X + 270, y + 2), Vector2(90, 24), 17, C_DIM))
		stat_values[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := Button.new()
		b.text = "ВЛОЖИТЬ"
		b.position = Vector2(PANEL_X + 360, y)
		b.size = Vector2(100, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var stat_id := String(STAT_IDS[i])
		b.pressed.connect(_buy_stat.bind(stat_id))
		add_child(b)
		stat_buttons.append(b)

	var hint := _label(
		"Очки дают уровни: за опыт с врагов.\n"
		+ "Сила — урон, живучесть — здоровье, дух — магия.\n"
		+ "Навыки открываются с определённого уровня.",
		Vector2(PANEL_X + 40, PANEL_Y + 380), Vector2(430, 90), 13, C_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- навыки ---
	_label("НАВЫКИ", Vector2(PANEL_X + 470, PANEL_Y + 116), Vector2(300, 24), 16, C_TITLE)
	var row := 0
	for id in Progression.SKILLS.keys():
		var y: float = PANEL_Y + 156 + float(row) * 58.0
		var name_label := _label("", Vector2(PANEL_X + 470, y), Vector2(320, 22), 18, C_TEXT)
		var info_label := _label("", Vector2(PANEL_X + 470, y + 23), Vector2(340, 18), 12, C_DIM)
		skill_names.append(name_label)
		skill_infos.append(info_label)
		var b := Button.new()
		b.text = "ИЗУЧИТЬ"
		b.position = Vector2(PANEL_X + 740, y + 2)
		b.size = Vector2(130, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var skill_id := String(id)
		b.pressed.connect(_buy_skill.bind(skill_id))
		add_child(b)
		skill_buttons.append(b)
		row += 1

	var back := Button.new()
	back.text = "НАЗАД (Esc / K)"
	back.position = Vector2(PANEL_X + 290, PANEL_Y + PANEL_H - 52)
	back.size = Vector2(300, 34)
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", C_TEXT)
	back.add_theme_color_override("font_hover_color", C_ACCENT)
	back.pressed.connect(_close)
	add_child(back)


## Перерисовка цифр: вызывается и при покупке, и по сигналам GameState.
func _refresh() -> void:
	if header == null:
		return
	var need: int = GameState.xp_need()
	var xp_text := "максимальный уровень" if need <= 0 else "ОПЫТ %d / %d" % [GameState.xp, need]
	header.text = "УРОВЕНЬ %d   ·   %s   ·   ОЧКИ: %d характеристик, %d навыков" % [
		GameState.level, xp_text, GameState.stat_points, GameState.skill_points]

	for i in STAT_IDS.size():
		var id := String(STAT_IDS[i])
		var rank: int = int(GameState.stats.get(id, 0))
		stat_values[i].text = "%d / %d" % [rank, Balance.STAT_MAX_RANK]
		stat_buttons[i].disabled = GameState.stat_points <= 0 or rank >= Balance.STAT_MAX_RANK
		stat_buttons[i].text = "ВЛОЖИТЬ" if GameState.stat_points > 0 else "НЕТ ОЧКОВ"

	var i2 := 0
	for id in Progression.SKILLS.keys():
		var data: Dictionary = Progression.SKILLS[id]
		var rank2: int = GameState.skill_rank(String(id))
		var max_rank: int = int(data.get("max_rank", 1))
		var need_level: int = int(data.get("level", 1))
		skill_names[i2].text = String(data.get("name", ""))
		var info := String(data.get("desc", ""))
		info += "  ·  ранг %d/%d" % [rank2, max_rank]
		if GameState.level < need_level:
			info += "  ·  нужен %d ур." % need_level
		skill_infos[i2].text = info
		skill_infos[i2].add_theme_color_override(
			"font_color", C_DIM if GameState.level < need_level else C_TEXT)
		var b: Button = skill_buttons[i2]
		if rank2 >= max_rank:
			b.text = "МАКС"
			b.disabled = true
		elif GameState.level < need_level:
			b.text = "ЗАКРЫТ"
			b.disabled = true
		elif GameState.skill_points <= 0:
			b.text = "НЕТ ОЧКОВ"
			b.disabled = true
		else:
			b.text = "ИЗУЧИТЬ"
			b.disabled = false
		i2 += 1


func _buy_stat(id: String) -> void:
	if GameState.add_stat(id):
		Sfx.play("sfx_trust", -14.0)
	else:
		Sfx.play("sfx_lowmagic", -18.0)
	_refresh()


func _buy_skill(id: String) -> void:
	if GameState.unlock_skill(id):
		Sfx.play("sfx_absorb", -14.0)
	else:
		Sfx.play("sfx_lowmagic", -18.0)
	_refresh()


func _close() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	var close := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if InputMap.has_action("skills") and event.is_action_pressed("skills"):
		close = true
	if close:
		get_viewport().set_input_as_handled()
		_close()
