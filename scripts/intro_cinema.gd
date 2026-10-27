extends Control
## Кинематик-пролог: постер «Пожиратели» и AI-видео пира, с субтитрами.

signal finished

const VIDEO := "res://assets/video/feast.ogv"

var poster: TextureRect
var title: Label
var subtitle: Label
var quote: Label
var player: VideoStreamPlayer
var caption: Label
var hint: Label
var fade: ColorRect
var skip_hint: Label
var time := 0.0
var phase := "poster"
var ended := false

const CAPTIONS := [
	[0.3, 3.1, "Пир в честь первой туши. Кланы Гхарн едят плоть магов."],
	[3.3, 6.2, "Они называют это причастием. Год седьмой после Раскола."],
	[6.4, 8.0, "А внизу, в шахте «Кровавый Клык», просыпается Пациент Ноль."],
]


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_PASS

	poster = TextureRect.new()
	poster.texture = Art.tex("res://assets/art/poster_feast.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.set_anchors_preset(Control.PRESET_FULL_RECT)
	poster.modulate = Color(0.9, 0.88, 0.86, 0.0)
	add_child(poster)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	title = _label("КРОВАВАЯ МАГИЯ", 24, Color(0.88, 0.80, 0.62))
	title.position = Vector2(0, 26)
	title.size = Vector2(640, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = _label("И   Р А С К О Л", 12, Color(0.72, 0.66, 0.55))
	subtitle.position = Vector2(0, 62)
	subtitle.size = Vector2(640, 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	quote = _label("«Они не убивают ради власти. Они ужинают.»", 11, Color(0.86, 0.82, 0.74))
	quote.position = Vector2(0, 318)
	quote.size = Vector2(640, 18)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar_top := ColorRect.new()
	bar_top.color = Color(0, 0, 0, 0.9)
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(640, 18)
	add_child(bar_top)
	var bar_bot := ColorRect.new()
	bar_bot.color = Color(0, 0, 0, 0.9)
	bar_bot.position = Vector2(0, 342)
	bar_bot.size = Vector2(640, 18)
	add_child(bar_bot)

	player = VideoStreamPlayer.new()
	player.stream = load(VIDEO)
	if player.stream == null:
		push_error("Кинематик не загрузился: " + VIDEO)
	else:
		var length_sec = 0.0
		if player.stream != null and player.stream.has_method("get_length"):
			length_sec = float(player.stream.get_length())
		print("CINEMA OK length=", length_sec)
	player.size = Vector2(640, 360)
	player.position = Vector2.ZERO
	player.expand = true
	player.volume_db = -2.0
	player.visible = false
	add_child(player)
	player.finished.connect(_on_video_finished)

	var cgrad := Gradient.new()
	cgrad.set_color(0, Color(0, 0, 0, 0.0))
	cgrad.set_color(1, Color(0, 0, 0, 0.8))
	var ctex := GradientTexture2D.new()
	ctex.gradient = cgrad
	ctex.fill_from = Vector2(0, 0)
	ctex.fill_to = Vector2(0, 1)
	ctex.width = 8
	ctex.height = 96
	var cstrip := TextureRect.new()
	cstrip.texture = ctex
	cstrip.position = Vector2(0, 268)
	cstrip.size = Vector2(640, 74)
	cstrip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cstrip.stretch_mode = TextureRect.STRETCH_SCALE
	cstrip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cstrip)

	caption = _label("", 12, Color(0.94, 0.91, 0.84))
	caption.position = Vector2(30, 300)
	caption.size = Vector2(580, 40)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	caption.visible = false

	skip_hint = _label("Esc — пропустить", 8, Color(0.55, 0.53, 0.5))
	skip_hint.position = Vector2(540, 348)
	skip_hint.size = Vector2(96, 12)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_run()


func _label(text: String, fsize: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _run() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.2)
	tw.parallel().tween_property(poster, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(3.4).timeout
	if ended:
		return
	# переход к видео
	phase = "video"
	var tw2 := create_tween()
	tw2.tween_property(poster, "modulate:a", 0.0, 0.5)
	tw2.parallel().tween_property(title, "modulate:a", 0.0, 0.5)
	tw2.parallel().tween_property(subtitle, "modulate:a", 0.0, 0.5)
	tw2.parallel().tween_property(quote, "modulate:a", 0.0, 0.5)
	await tw2.finished
	title.visible = false
	subtitle.visible = false
	quote.visible = false
	poster.visible = false
	player.visible = true
	caption.visible = true
	player.play()
	time = 0.0


func _process(delta: float) -> void:
	if ended:
		return
	time += delta
	if phase == "video" and player != null and player.visible:
		# держим размер кадра: плеер норовит растянуться до нативного 1280x720
		player.size = Vector2(640, 360)
		player.position = Vector2.ZERO
		var pos := player.stream_position
		caption.text = ""
		for c in CAPTIONS:
			if pos >= c[0] and pos <= c[1]:
				caption.text = c[2]
		if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("confirm"):
			_finish()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if ended:
		return
	ended = true
	if player:
		player.stop()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	await tw.finished
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish()
