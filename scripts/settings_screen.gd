extends Control
## Экран настроек: разрешение окна, полный экран, громкость, покачивание и
## тряска камеры, графика.
## Работает и как отдельная страница меню (1280×720), и как оверлей паузы
## (тогда вызывающий ставит scale = 0.5, т.к. HUD живёт в 640×360).

signal closed

## 32, а не 34: с 14 строками кнопка «Назад» иначе вылезает за панель.
const ROW_H := 32.0
const SECTION_H := 34.0
const PANEL_W := 660.0
const PANEL_H := 660.0
const PANEL_X := (1280.0 - PANEL_W) * 0.5
const PANEL_Y := (720.0 - PANEL_H) * 0.5
const ROW_LABEL_X := PANEL_X + 34.0
const VALUE_X := PANEL_X + 330.0
const VALUE_W := 220.0
const ARROW_L_X := PANEL_X + 290.0
const ARROW_R_X := VALUE_X + VALUE_W + 4.0

const C_TITLE := Color(0.88, 0.8, 0.62)
const C_TEXT := Color(0.86, 0.82, 0.74)
const C_DIM := Color(0.55, 0.53, 0.48)
const C_ACCENT := Color(1.0, 0.92, 0.72)
const C_BORDER := Color(0.55, 0.45, 0.2, 0.9)

## Строки экрана. text — подпись; value() — текст значения; on() — false
## приглушает значение; change(step) — стрелки/клик. section — заголовок
## раздела над строкой.
var specs: Array[Dictionary] = [
	{"text": "РАЗРЕШЕНИЕ", "value": Settings.resolution_label,
		# в полном экране размер окна не действует — приглушаем строку
		"on": func(): return not Settings.fullscreen,
		"change": Settings.cycle_resolution},
	{"text": "ПОЛНЫЙ ЭКРАН",
		"value": func(): return "ВКЛ" if Settings.fullscreen else "ВЫКЛ",
		"on": func(): return true,
		"change": func(_step: int): Settings.toggle_fullscreen()},
	{"text": "ЗВУК", "value": Settings.volume_label,
		"on": func(): return Settings.volume > 0.001,
		"change": Settings.cycle_volume},
	{"text": "ПОКАЧИВАНИЕ", "value": Settings.bob_label,
		"on": func(): return Settings.camera_bob > 0.001,
		"change": Settings.cycle_camera_bob},
	{"text": "ТРЯСКА КАМЕРЫ",
		"value": func(): return "ВКЛ" if Settings.camera_shake else "ВЫКЛ",
		"on": func(): return Settings.camera_shake,
		"change": func(_step: int): Settings.toggle_camera_shake()},
	{"text": "КАЧЕСТВО", "section": "ГРАФИКА", "value": Settings.quality_label,
		"on": func(): return true,
		"change": Settings.cycle_quality},
	_gfx_spec("СГЛАЖИВАНИЕ", "aa"),
	_gfx_spec("МАСШТАБ 3D", "render_scale"),
	_gfx_spec("ТЕНИ", "shadows"),
	_gfx_spec("ОБЪЁМНЫЙ ТУМАН", "volfog"),
	_gfx_spec("ДЫМКА И ПЫЛЬ", "air"),
	_gfx_spec("ОТРАЖЕНИЯ", "ssr"),
	_gfx_spec("НЕПРЯМОЙ СВЕТ", "ssil"),
	_gfx_spec("ВИНЬЕТКА И ЗЕРНО", "post_fx"),
]

var row_index := 0
var rows: Array[Label] = []
var row_bases: Array[String] = []
var values: Array[Label] = []


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	# в паузе дерево остановлено — этот экран должен работать всё равно
	set_process_input(true)
	_build()
	_refresh()
	_select(0)


func _gfx_spec(text: String, key: String) -> Dictionary:
	return {"text": text,
		"value": func(): return Settings.gfx_label(key),
		"on": func(): return Settings.gfx_on(key),
		"change": func(step: int): Settings.cycle_gfx(key, step)}


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
	title.text = "НАСТРОЙКИ"
	title.position = Vector2(0, PANEL_Y + 18)
	title.size = Vector2(1280, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.02, 0.04, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)

	var y := PANEL_Y + 78
	for i in specs.size():
		var spec: Dictionary = specs[i]
		if spec.has("section"):
			_section_label(spec["section"], y)
			y += SECTION_H
		rows.append(_row_label(spec["text"], y))
		values.append(_value_label(y))
		_hit_row(y, func():
			_select(i)
			_change(1))
		_arrow("‹", ARROW_L_X, y, func():
			_select(i)
			_change(-1))
		_arrow("›", ARROW_R_X, y, func():
			_select(i)
			_change(1))
		y += ROW_H

	var hint := Label.new()
	hint.text = "← → изменить · ↑ ↓ строка · Esc — назад"
	hint.position = Vector2(0, y + 8)
	hint.size = Vector2(1280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", C_DIM)
	add_child(hint)

	var back := Button.new()
	back.text = "Назад"
	back.position = Vector2(PANEL_X, y + 38)
	back.size = Vector2(PANEL_W, 36)
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", C_TEXT)
	back.add_theme_color_override("font_hover_color", C_ACCENT)
	back.pressed.connect(_close)
	add_child(back)


## Заголовок раздела: тонкая подпись по центру, строкой не считается.
func _section_label(text: String, y: float) -> void:
	var l := Label.new()
	l.text = "— " + text + " —"
	l.position = Vector2(PANEL_X, y + 4)
	l.size = Vector2(PANEL_W, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", C_TITLE)
	add_child(l)


func _row_label(text: String, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(ROW_LABEL_X, y)
	l.size = Vector2(250, 30)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", C_TEXT)
	add_child(l)
	row_bases.append(text)
	return l


func _value_label(y: float) -> Label:
	var l := Label.new()
	l.text = ""
	l.position = Vector2(VALUE_X, y)
	l.size = Vector2(VALUE_W, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", C_ACCENT)
	add_child(l)
	return l


func _arrow(text: String, x: float, y: float, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, y - 4)
	b.size = Vector2(34, 34)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", C_DIM)
	b.add_theme_color_override("font_hover_color", C_ACCENT)
	b.pressed.connect(func():
		Sfx.play("sfx_click", -20.0, 1.2)
		action.call())
	add_child(b)


## Клик по строке целиком: выбирает её и переключает значение.
func _hit_row(y: float, action: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(PANEL_X + 30, y - 4)
	b.size = Vector2(PANEL_W - 60, ROW_H)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	add_child(b)


func _refresh() -> void:
	for i in specs.size():
		var spec: Dictionary = specs[i]
		values[i].text = (spec["value"] as Callable).call()
		var on: bool = (spec["on"] as Callable).call()
		values[i].add_theme_color_override("font_color", C_ACCENT if on else C_DIM)


func _select(index: int) -> void:
	row_index = clampi(index, 0, rows.size() - 1)
	for i in rows.size():
		var on := i == row_index
		rows[i].add_theme_color_override("font_color", C_ACCENT if on else C_TEXT)
		var base: String = row_bases[i] if i < row_bases.size() else rows[i].text
		rows[i].text = ("▸ " if on else "  ") + base


func _change(step: int) -> void:
	(specs[row_index]["change"] as Callable).call(step)
	# пресет качества меняет сразу несколько строк — обновляем все
	_refresh()


func _close() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_select(row_index - 1)
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_select(row_index + 1)
	elif event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_change(-1)
	elif event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_change(1)
