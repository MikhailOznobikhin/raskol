extends Control
## Главное меню.

signal start_prologue
signal start_mission
signal quit_game

var _t := 0.0


func _ready() -> void:
	size = Vector2(640, 360)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := TextureRect.new()
	bg.texture = Art.tex("res://assets/art/title.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.82, 0.84, 0.92)
	add_child(bg)

	# затемнение под текстом
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var title := Label.new()
	title.text = "КРОВАВАЯ МАГИЯ"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
	title.add_theme_color_override("font_shadow_color", Color(0.25, 0.02, 0.06, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 118)
	title.size = Vector2(640, 60)
	add_child(title)

	var sub := Label.new()
	sub.text = "и   р а с к о л"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("shadow_offset_x", 2)
	sub.add_theme_constant_override("shadow_offset_y", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 174)
	sub.size = Vector2(640, 30)
	add_child(sub)

	var tag := Label.new()
	tag.text = "вертикальный срез  ·  пролог и миссия 1 «Побег»"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.62, 0.60, 0.54))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(0, 206)
	tag.size = Vector2(640, 18)
	add_child(tag)

	_add_button("Начать историю", 236, start_prologue.emit)
	_add_button("Сразу к миссии", 268, start_mission.emit)
	_add_button("Выход", 300, quit_game.emit)

	var hint := Label.new()
	hint.text = "WASD — идти · ЛКМ — удар · ПКМ — тяжёлый · Space — рывок\nQ — шип · E — поглощать · F — действие · Shift — крадучись"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.48, 0.47, 0.43))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 330)
	hint.size = Vector2(640, 22)
	add_child(hint)


func _add_button(text: String, y: float, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
	b.add_theme_color_override("font_pressed_color", Color(0.95, 0.6, 0.6))
	b.position = Vector2(232, y)
	b.size = Vector2(176, 26)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("sfx_click", -6.0)
		action.call())
	b.mouse_entered.connect(func(): Sfx.play("sfx_click", -18.0, 1.3))
	add_child(b)


func _process(delta: float) -> void:
	_t += delta
