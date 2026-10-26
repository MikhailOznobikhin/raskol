extends Control
## Экран завершения миссии: итог, статистика, намёк на концовку.

signal back_to_menu

var escaped := true


func _ready() -> void:
	size = Vector2(640, 360)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var art := TextureRect.new()
	art.texture = Art.tex("res://assets/art/title.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.45, 0.45, 0.55, 0.5)
	add_child(art)

	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.01, 0.02, 0.66)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var title := Label.new()
	title.text = "СВОБОДА" if escaped else "ТЬМА"
	title.position = Vector2(0, 78)
	title.size = Vector2(640, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.86, 0.78, 0.6) if escaped else Color(0.75, 0.28, 0.3))
	add_child(title)

	var sub := Label.new()
	sub.text = "Миссия 1 «Побег» завершена" if escaped else "Миссия провалена"
	sub.position = Vector2(0, 118)
	sub.size = Vector2(640, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	add_child(sub)

	var lines: Array = []
	if escaped:
		lines.append("Время: %s" % _time_text())
		lines.append("Поглощено плоти: %d" % GameState.flesh_eaten)
		lines.append("Стражников убито: %d   ·   оглушено: %d" % [GameState.guards_killed, GameState.guards_spared])
		lines.append("Доверие Альянса: %+d" % GameState.trust)
		lines.append("Селена: %s" % ("освобождена" if GameState.selena == "freed" else ("поглощена" if GameState.selena == "devoured" else "оставлена")))
		lines.append("")
		match GameState.ending():
			"A":
				lines.append("Твой путь ведёт к «Горькой жертве»: союз с Альянсом и ритуал, выжигающий магию.")
			"C":
				lines.append("Ты слишком глубоко пил силу. Это путь «Множественного выбора» — гномы заплатят за неё.")
			_:
				lines.append("Альянс не поверит тебе. Это путь «Изгнания» — на север, в снега.")
	else:
		lines.append("Торвин Грим не увидел снега. Кровавый Клык забрал ещё одного.")

	var stats := Label.new()
	stats.text = "\n".join(lines)
	stats.position = Vector2(120, 150)
	stats.size = Vector2(400, 130)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(stats)

	var b := Button.new()
	b.text = "В главное меню"
	b.position = Vector2(250, 296)
	b.size = Vector2(140, 26)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func():
		Sfx.play("sfx_click", -6.0)
		back_to_menu.emit())
	add_child(b)


func _time_text() -> String:
	var t := int(GameState.playtime)
	return "%d:%02d" % [t / 60, t % 60]
