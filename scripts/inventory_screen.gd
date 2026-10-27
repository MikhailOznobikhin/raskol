extends Control
## Экран инвентаря: экипировка, сумка, карточка предмета и характеристики.
## Как и settings/development, собран в координатах 1280×720 — вызывающий HUD
## растянут ×2, поэтому он ставит этому контролу scale = 0.5.

signal closed

const PANEL_W := 960.0
const PANEL_H := 600.0
const PANEL_X := (1280.0 - PANEL_W) * 0.5
const PANEL_Y := (720.0 - PANEL_H) * 0.5

const C_TITLE := Color(0.88, 0.8, 0.62)
const C_TEXT := Color(0.86, 0.82, 0.74)
const C_DIM := Color(0.58, 0.56, 0.5)
const C_ACCENT := Color(1.0, 0.92, 0.72)
const C_BORDER := Color(0.55, 0.45, 0.2, 0.9)

const CELL := 52.0
const CELL_GAP := 6.0
const GRID_COLS := 5
const GRID_ROWS := 4
const SLOT_BOX := 84.0

var _selected := ""
var _selected_slot := ""   # если выбран надетый предмет, а не содержимое сумки
var _cells: Array[Button] = []
var _slot_box := {}       # slot -> Button
var _slot_icon := {}      # slot -> TextureRect
var _slot_name := {}      # slot -> Label
var bag_label: Label
var detail_name: Label
var detail_kind: Label
var detail_bonus: Label
var detail_desc: Label
var action_button: Button
var stat_values := {}     # key -> Label


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build()
	GameState.inventory_changed.connect(_refresh)
	GameState.stats_changed.connect(_refresh)
	_refresh()


# ---------------------------------------------------------------------------
# помощники вёрстки
# ---------------------------------------------------------------------------

func _label(text: String, pos: Vector2, sz: Vector2, fsize: int, color: Color,
		wrap := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(l)
	return l


func _flat(bg: Color, border: Color, width := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	return sb


## Кнопка-ячейка: иконка внутри, подпись поверх, состояние задаётся стайлбоксами.
func _cell(pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", _flat(Color(0.075, 0.085, 0.11, 0.95), Color(0.28, 0.32, 0.4, 0.9)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.11, 0.12, 0.16, 0.95), Color(0.55, 0.48, 0.25, 0.95)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.13, 0.1, 0.08, 0.95), C_BORDER, 2))
	b.add_theme_stylebox_override("disabled", _flat(Color(0.05, 0.055, 0.07, 0.9), Color(0.18, 0.2, 0.25, 0.9)))
	add_child(b)
	return b


# ---------------------------------------------------------------------------
# сборка
# ---------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _flat(
		Color(0.055, 0.06, 0.08, 0.98), C_BORDER, 2))
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var title := _label("ИНВЕНТАРЬ", Vector2(0, PANEL_Y + 12), Vector2(1280, 36),
		26, C_TITLE, false, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.02, 0.04, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)

	_build_equipment()
	_build_bag()
	_build_details()
	_build_stats()

	var close := Button.new()
	close.text = "ЗАКРЫТЬ (Esc / I)"
	close.position = Vector2((1280.0 - 300.0) * 0.5, PANEL_Y + PANEL_H + 8)
	close.size = Vector2(300, 34)
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 17)
	close.add_theme_color_override("font_color", C_TEXT)
	close.add_theme_color_override("font_hover_color", C_ACCENT)
	close.pressed.connect(request_close)
	add_child(close)


## Левая колонка: шесть слотов экипировки. Клик — посмотреть, двойной — снять.
func _build_equipment() -> void:
	var x0 := PANEL_X + 28.0
	_label("ЭКИПИРОВКА", Vector2(x0, PANEL_Y + 58), Vector2(300, 22), 15, C_TITLE)
	var i := 0
	for slot in GameState.EQUIP_SLOTS:
		var col := i % 2
		var row := floori(float(i) / 2.0)
		var bx: float = x0 + float(col) * (SLOT_BOX + 62.0)
		var by: float = PANEL_Y + 86.0 + float(row) * 104.0
		var cap := String(GameState.SLOT_TITLES.get(slot, String(slot).to_upper()))
		_label(cap, Vector2(bx, by), Vector2(SLOT_BOX, 16), 11, C_DIM,
			false, HORIZONTAL_ALIGNMENT_CENTER)
		var b := _cell(Vector2(bx, by + 18.0), Vector2(SLOT_BOX, SLOT_BOX))
		b.pressed.connect(_on_slot_pressed.bind(String(slot)))
		b.gui_input.connect(_on_slot_input.bind(String(slot)))
		b.tooltip_text = cap
		var ic := TextureRect.new()
		ic.position = Vector2(14, 8)
		ic.size = Vector2(SLOT_BOX - 28.0, SLOT_BOX - 32.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var nm := _label("", Vector2(bx + 2, by + 18.0 + SLOT_BOX - 19.0),
			Vector2(SLOT_BOX - 4, 14), 9, C_TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
		nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		nm.add_theme_constant_override("shadow_offset_x", 1)
		nm.add_theme_constant_override("shadow_offset_y", 1)
		_slot_box[slot] = b
		_slot_icon[slot] = ic
		_slot_name[slot] = nm
		i += 1


## Средняя колонка: сумка сеткой 5×4. Ячейки пустые, пока предмета нет.
func _build_bag() -> void:
	var x0 := PANEL_X + 344.0
	_label("СУМКА", Vector2(x0, PANEL_Y + 58), Vector2(284, 22), 15, C_TITLE)
	for idx in GRID_COLS * GRID_ROWS:
		var col := idx % GRID_COLS
		var row := floori(float(idx) / float(GRID_COLS))
		var pos := Vector2(x0 + float(col) * (CELL + CELL_GAP),
			PANEL_Y + 86.0 + float(row) * (CELL + CELL_GAP))
		var b := _cell(pos, Vector2(CELL, CELL))
		b.disabled = true
		var cnt := Label.new()
		cnt.size = Vector2(CELL - 6.0, 15)
		cnt.position = Vector2(3, CELL - 18.0)
		cnt.add_theme_font_size_override("font_size", 11)
		cnt.add_theme_color_override("font_color", C_ACCENT)
		cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		cnt.add_theme_constant_override("shadow_offset_x", 1)
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cnt)
		b.set_meta("count", cnt)
		b.pressed.connect(_on_cell_pressed.bind(idx))
		b.gui_input.connect(_on_cell_input.bind(idx))
		_cells.append(b)
	var below := PANEL_Y + 86.0 + float(GRID_ROWS) * (CELL + CELL_GAP)
	bag_label = _label("", Vector2(x0, below + 2.0), Vector2(284, 20), 13, C_DIM)
	var hint := _label(
		"Клик — посмотреть. Двойной клик — надеть или использовать.\n"
		+ "Двойной клик по надетому слоту снимает предмет в сумку.",
		Vector2(x0, below + 26.0), Vector2(284, 56), 12, C_DIM, true)
	hint.add_theme_constant_override("line_spacing", 3)


func _build_details() -> void:
	var x0 := PANEL_X + 660.0
	var w := PANEL_W - 688.0
	_label("ПРЕДМЕТ", Vector2(x0, PANEL_Y + 58), Vector2(w, 22), 15, C_TITLE)
	var por := TextureRect.new()
	por.texture = Art.tex("res://assets/ui/portrait_hero.png")
	por.position = Vector2(x0, PANEL_Y + 86.0)
	por.size = Vector2(96, 96)
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(por)
	detail_name = _label("Ничего не выбрано", Vector2(x0 + 106.0, PANEL_Y + 86.0),
		Vector2(w - 106.0, 44), 16, C_TEXT, true)
	detail_kind = _label("", Vector2(x0 + 106.0, PANEL_Y + 132.0),
		Vector2(w - 106.0, 18), 12, C_DIM)
	detail_bonus = _label("", Vector2(x0 + 106.0, PANEL_Y + 152.0),
		Vector2(w - 106.0, 32), 12, C_ACCENT, true)
	detail_desc = _label("", Vector2(x0, PANEL_Y + 192.0), Vector2(w, 104), 13, C_TEXT, true)
	detail_desc.add_theme_constant_override("line_spacing", 3)
	action_button = Button.new()
	action_button.text = "—"
	action_button.position = Vector2(x0, PANEL_Y + 302.0)
	action_button.size = Vector2(w, 34)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_size_override("font_size", 15)
	action_button.pressed.connect(_on_action)
	add_child(action_button)


## Характеристики списком: одна строка — один показатель. В одну длинную
## строку они не влезали и обрезались по правому краю панели.
func _build_stats() -> void:
	var x0 := PANEL_X + 28.0
	_label("ХАРАКТЕРИСТИКИ", Vector2(x0, PANEL_Y + 412.0), Vector2(300, 22), 15, C_TITLE)
	var rows := [["health", "Здоровье"], ["magic", "Магия"], ["armor", "Броня"],
		["dmg", "Урон"], ["noise", "Шум"], ["level", "Уровень"]]
	for i in rows.size():
		var y: float = PANEL_Y + 440.0 + float(i) * 24.0
		_label(String(rows[i][1]), Vector2(x0, y), Vector2(110, 20), 13, C_DIM)
		stat_values[rows[i][0]] = _label("", Vector2(x0 + 110.0, y), Vector2(190, 20),
			13, C_TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT)


# ---------------------------------------------------------------------------
# перерисовка
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if not is_node_ready() or bag_label == null:
		return
	var list: Array = GameState.inventory
	for i in _cells.size():
		var b := _cells[i]
		var cnt: Label = b.get_meta("count")
		var has := i < list.size() and (list[i] is Dictionary)
		b.disabled = not has
		var sel := false
		if has:
			var item: Dictionary = list[i]
			b.icon = _icon(String(item.get("icon", "")))
			b.tooltip_text = String(item.get("name", ""))
			var n := int(item.get("count", 1))
			cnt.text = "x%d" % n if n > 1 else ""
			sel = String(item.get("id", "")) == _selected
		else:
			b.icon = null
			b.tooltip_text = ""
			cnt.text = ""
		# выделение — рамкой, а не modulate: тонировка гасит и иконку, и цифру
		b.add_theme_stylebox_override("normal",
			_flat(Color(0.13, 0.1, 0.08, 0.95), C_ACCENT, 2) if sel
			else _flat(Color(0.075, 0.085, 0.11, 0.95), Color(0.28, 0.32, 0.4, 0.9)))
	bag_label.text = "Сумка пуста" if list.is_empty() else "Предметов: %d из %d" % [
		list.size(), _cells.size()]
	_refresh_slots()
	_refresh_details()
	_refresh_stats()


func _icon(kind: String) -> Texture2D:
	if kind == "":
		return null
	var path := "res://assets/ui/icon_%s.png" % kind
	return Art.tex(path) if ResourceLoader.exists(path) else null


func _refresh_slots() -> void:
	for slot in _slot_box.keys():
		var b: Button = _slot_box[slot]
		var it = GameState.equipped.get(slot)
		var ic: TextureRect = _slot_icon[slot]
		var nm: Label = _slot_name[slot]
		if it is Dictionary:
			b.icon = null
			ic.texture = _icon(String(it.get("icon", "")))
			nm.text = String(it.get("name", ""))
			nm.add_theme_color_override("font_color", C_TEXT)
		else:
			ic.texture = null
			nm.text = "пусто"
			nm.add_theme_color_override("font_color", Color(0.4, 0.4, 0.42))
		b.add_theme_stylebox_override("normal",
			_flat(Color(0.13, 0.1, 0.08, 0.95), C_ACCENT, 2) if String(slot) == _selected_slot
			else _flat(Color(0.075, 0.085, 0.11, 0.95), Color(0.28, 0.32, 0.4, 0.9)))


func _refresh_details() -> void:
	var item := _selected_item()
	if item.is_empty():
		detail_name.text = "Ничего не выбрано"
		detail_kind.text = ""
		detail_bonus.text = ""
		detail_desc.text = "Подбери предметы в подземелье — они появятся в сумке."
		action_button.visible = false
		return
	action_button.visible = true
	var kind := String(item.get("kind", ""))
	detail_name.text = String(item.get("name", ""))
	if _selected_slot != "":
		var worn := String(GameState.SLOT_TITLES.get(_selected_slot, ""))
		detail_kind.text = "Надето · слот «%s»" % worn
		detail_bonus.text = GameState.item_bonuses_text(item)
		detail_desc.text = String(item.get("desc", ""))
		action_button.text = "СНЯТЬ"
		return
	if kind == "equip":
		var slot_title := String(GameState.SLOT_TITLES.get(String(item.get("slot", "")), ""))
		detail_kind.text = "Снаряжение · слот «%s»" % slot_title
	else:
		detail_kind.text = "Расходник"
	detail_bonus.text = GameState.item_bonuses_text(item)
	detail_desc.text = String(item.get("desc", ""))
	var cnt := int(item.get("count", 1))
	action_button.text = "ИСПОЛЬЗОВАТЬ" if kind == "use" else "НАДЕТЬ"
	if cnt > 1:
		action_button.text += "  (x%d)" % cnt


func _refresh_stats() -> void:
	var hp_max: float = GameState.get_max_health()
	stat_values["health"].text = "%d / %d" % [int(GameState.health), int(hp_max)]
	stat_values["magic"].text = "%d / %d" % [int(GameState.magic), int(GameState.get_max_magic())]
	var red := int(GameState.armor_reduction() * 100.0)
	stat_values["armor"].text = "-%d%% урона" % red if red > 0 else "нет брони"
	stat_values["dmg"].text = "x%.2f" % GameState.melee_damage_mult()
	stat_values["noise"].text = "x%.2f" % GameState.noise_mult()
	stat_values["level"].text = "%d  (%d/%d опыта)" % [GameState.level, GameState.xp, GameState.xp_need()]


## Выбранный предмет: надетого в сумке уже нет, поэтому сначала смотрим в слот.
func _selected_item() -> Dictionary:
	if _selected == "":
		return {}
	if _selected_slot != "":
		var it = GameState.equipped.get(_selected_slot)
		if it is Dictionary and String(it.get("id", "")) == _selected:
			return it
		_selected_slot = ""
	return GameState.item_by_id(_selected)


# ---------------------------------------------------------------------------
# ввод
# ---------------------------------------------------------------------------

func _on_cell_pressed(idx: int) -> void:
	var list: Array = GameState.inventory
	if idx >= list.size() or not (list[idx] is Dictionary):
		return
	_selected = String(list[idx].get("id", ""))
	_selected_slot = ""
	Sfx.play("sfx_click", -20.0)
	_refresh()


## Двойной клик по ячейке — быстрое действие, не тянувшись к кнопке.
func _on_cell_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_on_cell_pressed(idx)
		_on_action()


## Клик по слоту — только посмотреть: снимать предмет одним нажатием слишком
## обидно, он и так надет.
func _on_slot_pressed(slot: String) -> void:
	var it = GameState.equipped.get(slot)
	if it is Dictionary:
		_selected = String(it.get("id", ""))
		_selected_slot = slot
	else:
		_selected = ""
		_selected_slot = ""
	Sfx.play("sfx_click", -20.0)
	_refresh()


func _on_slot_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.double_click \
			and GameState.equipped.get(slot) is Dictionary:
		GameState.unequip(slot)
		_selected = ""
		_selected_slot = ""
		Sfx.play("sfx_click", -18.0)
	_refresh()


func _on_action() -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var id := String(item.get("id", ""))
	if _selected_slot != "":
		GameState.unequip(_selected_slot)
		_selected = ""
		_selected_slot = ""
		Sfx.play("sfx_click", -18.0)
		_refresh()
		return
	var kind := String(item.get("kind", ""))
	if kind == "use":
		if GameState.use_item(id):
			Sfx.play("sfx_absorb", -10.0)
			if GameState.item_by_id(id).is_empty():
				_selected = ""
		else:
			Sfx.play("sfx_lowmagic", -16.0)
	elif GameState.equip_item(id):
		# предмет переехал в слот — карточка остаётся на нём, а не гаснет
		_selected_slot = String(item.get("slot", ""))
		Sfx.play("sfx_chain", -14.0)
	else:
		Sfx.play("sfx_lowmagic", -16.0)
	_refresh()


func request_close() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	var close := event.is_action_pressed("ui_cancel")
	if InputMap.has_action("pause") and event.is_action_pressed("pause"):
		close = true
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_I:
		close = true
	if close:
		get_viewport().set_input_as_handled()
		request_close()
