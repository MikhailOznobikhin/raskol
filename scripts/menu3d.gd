extends Control
## Главное меню 3D-версии: фото-постер, титул, вход в историю.

signal continue_game
signal start_story
signal start_mission
signal quit_game

var buttons: Array[Button] = []
var selected := 0


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := TextureRect.new()
	bg.texture = Art.tex("res://assets/art/menu_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1280, 720)
	add_child(bg)
	bg.modulate = Color(0.75, 0.72, 0.7)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.35)
	shade.size = Vector2(1280, 720)
	add_child(shade)

	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.95))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 8
	gtex.height = 256
	var strip := TextureRect.new()
	strip.texture = gtex
	strip.position = Vector2(0, 440)
	strip.size = Vector2(1280, 280)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(strip)

	var title := Label.new()
	title.text = "КРОВАВАЯ МАГИЯ"
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", Color(0.88, 0.8, 0.62))
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.02, 0.04, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.position = Vector2(0, 78)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := Label.new()
	sub.text = "и   р а с к о л"
	sub.add_theme_font_size_override("font_size", 32)
	sub.add_theme_color_override("font_color", Color(0.74, 0.66, 0.52))
	sub.position = Vector2(0, 158)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var tag := Label.new()
	tag.text = "3D-RPG · пролог и Миссия 1 «Побег»"
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	tag.position = Vector2(0, 198)
	tag.size = Vector2(1280, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)

	var has_save := SaveSystem.has_save()
	var y := 470.0
	if has_save:
		_button("Продолжить", y, continue_game.emit)
		y += 50.0
	_button("Начать историю", y, start_story.emit)
	y += 50.0
	_button("Сразу к миссии", y, start_mission.emit)
	y += 50.0
	_button("Выход", y, quit_game.emit)

	var hint := Label.new()
	hint.text = "WASD — идти · Shift — бег · ЛКМ — удар · ПКМ — тяжёлый · Space — рывок · E — поглощать · F — действие · Esc — пауза"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.45, 0.44, 0.4))
	hint.position = Vector2(0, 702)
	hint.size = Vector2(1280, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	if not buttons.is_empty():
		_select(0)


func _button(text: String, y: float, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
	b.position = Vector2(490, y)
	b.size = Vector2(300, 40)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("sfx_click", -6.0)
		action.call())
	b.mouse_entered.connect(func():
		Sfx.play("sfx_click", -20.0, 1.3)
		_select(buttons.find(b)))
	add_child(b)
	buttons.append(b)


func _select(index: int) -> void:
	if buttons.is_empty():
		return
	selected = clampi(index, 0, buttons.size() - 1)
	for i in buttons.size():
		var c := Color(1.0, 0.92, 0.72) if i == selected else Color(0.86, 0.82, 0.74)
		buttons[i].add_theme_color_override("font_color", c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_select(selected - 1)
		Sfx.play("sfx_click", -18.0, 1.2)
	elif event.is_action_pressed("move_down"):
		_select(selected + 1)
		Sfx.play("sfx_click", -18.0, 1.2)
	elif event.is_action_pressed("confirm"):
		if not buttons.is_empty():
			buttons[selected].pressed.emit()
