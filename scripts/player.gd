extends CharacterBody2D
## Торвин Грим — игрок. Стелс, ближний бой, кровная магия, поглощение.

class_name Player

signal died
signal magic_cast(kind: String)

const SPEED := 116.0
const SNEAK_SPEED := 58.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.18
const DASH_COST := 15.0
const DASH_CD := 0.6
const SPDASH_INVULN := 0.28
const SPIKE_COST := 10.0
const SPIKE_CD := 0.85
const SPIKE_DMG := 18.0
const LIGHT_DMG := 12.0
const HEAVY_DMG := 26.0
const HEAVY_WINDUP := 0.45
const HURT_INVULN := 0.7

var control_enabled := true
var sneaking := false
var facing := Vector2.DOWN
var dir_name := "down"
var noise := 0.0            # 0..1, насколько герой шумит прямо сейчас
var busy := false           # занят каналом/диалогом
var in_shadow := false

var state := "idle"
var state_t := 0.0
var dash_cd := 0.0
var spike_cd := 0.0
var invuln := 0.0
var hurt_flash := 0.0
var channel_progress := 0.0

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var aura: PointLight2D
var _last_anim := ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)

	shadow = Sprite2D.new()
	shadow.texture = _shadow_texture()
	shadow.position = Vector2(0, -2)
	shadow.modulate = Color(1, 1, 1, 0.55)
	add_child(shadow)

	sprite = Art.make_sprite("hero", "down", "idle")
	sprite.offset = Vector2(0, -32)
	sprite.position = Vector2(0, 0)
	add_child(sprite)

	aura = PointLight2D.new()
	aura.texture = Art.tex("res://assets/fx/light_red.png")
	aura.color = Color(0.9, 0.2, 0.3)
	aura.energy = 0.0
	aura.texture_scale = 0.7
	aura.position = Vector2(0, -20)
	add_child(aura)


func _shadow_texture() -> ImageTexture:
	var img := Image.create(26, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 26:
			var dx := (x - 13.0) / 13.0
			var dy := (y - 5.0) / 5.0
			var d := sqrt(dx * dx + dy * dy)
			if d < 1.0:
				var a := int(150.0 * pow(1.0 - d, 1.4))
				img.set_pixel(x, y, Color(0, 0, 0, a / 255.0))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	dash_cd = max(0.0, dash_cd - delta)
	spike_cd = max(0.0, spike_cd - delta)
	invuln = max(0.0, invuln - delta)
	hurt_flash = max(0.0, hurt_flash - delta)
	state_t += delta

	if hurt_flash > 0.0:
		sprite.modulate = Color(1.6, 0.7, 0.7) if int(hurt_flash * 30.0) % 2 == 0 else Color.WHITE
	else:
		sprite.modulate = Color.WHITE

	# аура Жажды
	var craving := GameState.craving / 100.0
	aura.energy = lerp(aura.energy, craving * 1.1, delta * 4.0)
	aura.position = Vector2(0, -20) + Vector2(sin(Time.get_ticks_msec() * 0.004) * 2.0, 0)

	if GameState.health <= 0.0:
		_die()
		return

	if not control_enabled or busy:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_animate(delta)
		return

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input.length() > 1.0:
		input = input.normalized()
	sneaking = Input.is_action_pressed("sneak") and state == "idle"

	match state:
		"dash":
			velocity = facing * DASH_SPEED
			if state_t >= DASH_TIME:
				_set_state("idle")
		"attack":
			velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
			if state_t >= 0.26:
				_set_state("idle")
		"heavy":
			velocity = input * SPEED * 0.28
			if state_t >= HEAVY_WINDUP + 0.25:
				_set_state("idle")
		"cast":
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			if state_t >= 0.32:
				_set_state("idle")
		"hurt":
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if state_t >= 0.3:
				_set_state("idle")
		_:
			var spd := SNEAK_SPEED if sneaking else SPEED
			velocity = input * spd
			noise = 0.5 if (input.length() > 0.1 and not sneaking) else (0.15 if input.length() > 0.1 else 0.0)
			if input.length() > 0.1:
				facing = input.normalized()
				_update_dir()

	_handle_actions()
	move_and_slide()
	_animate(delta)


func _handle_actions() -> void:
	if state in ["dash", "attack", "heavy", "cast", "hurt"]:
		return
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
		if GameState.spend_magic(DASH_COST):
			_set_state("dash")
			invuln = SPDASH_INVULN
			dash_cd = DASH_CD
			noise = 0.7
			Sfx.play("sfx_swing", -12.0, 1.35)
			_spawn_afterimage()
		else:
			Sfx.play("sfx_lowmagic", -14.0)
		return
	if Input.is_action_just_pressed("spike") and spike_cd <= 0.0:
		if GameState.spend_magic(SPIKE_COST):
			_set_state("cast")
			spike_cd = SPIKE_CD
			noise = 0.6
			magic_cast.emit("spike")
			Sfx.play("sfx_cast", -8.0)
			_spawn_spike()
		else:
			Sfx.play("sfx_lowmagic", -14.0)
		return
	if Input.is_action_just_pressed("heavy"):
		_set_state("heavy")
		noise = 0.8
		Sfx.play("sfx_swing", -10.0, 0.8)
		get_tree().create_timer(HEAVY_WINDUP).timeout.connect(_heavy_hit)
		return
	if Input.is_action_just_pressed("attack"):
		_set_state("attack")
		noise = 0.7
		Sfx.play_varied("sfx_swing", -11.0)
		get_tree().create_timer(0.1).timeout.connect(_light_hit)


func _heavy_hit() -> void:
	if state == "dead":
		return
	screen_shake(6.0, 0.18)
	_hit_arc(46.0, deg_to_rad(70.0), HEAVY_DMG)
	Sfx.play("sfx_hit_heavy", -7.0)


func _light_hit() -> void:
	if state == "dead":
		return
	_hit_arc(38.0, deg_to_rad(62.0), LIGHT_DMG)
	Sfx.play_varied("sfx_hit", -9.0)


func _hit_arc(radius: float, half_angle: float, base_damage: float) -> void:
	var dmg := base_damage * GameState.craving_damage_mult()
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_dead:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > radius + 10.0:
			continue
		if to.length() < 0.1 or facing.angle_to(to) < half_angle or facing.angle_to(to) > -half_angle:
			if abs(facing.angle_to(to)) <= half_angle:
				e.take_damage(dmg, facing)
				hit_any = true
	if hit_any:
		screen_shake(2.5, 0.08)


func _spawn_spike() -> void:
	var spike := Area2D.new()
	spike.collision_layer = 0
	spike.collision_mask = 0
	var spr := Sprite2D.new()
	spr.texture = Art.tex("res://assets/fx/spike.png")
	spike.add_child(spr)
	spike.global_position = global_position + Vector2(0, -20)
	spike.set_meta("dir", facing)
	spike.set_meta("life", 1.1)
	spike.set_meta("hit", [])
	spr.rotation = facing.angle()
	get_tree().current_scene.add_child(spike)
	var glow := PointLight2D.new()
	glow.texture = Art.tex("res://assets/fx/light_red.png")
	glow.color = Color(0.9, 0.2, 0.25)
	glow.energy = 0.8
	glow.texture_scale = 0.35
	spike.add_child(glow)
	spike.set_script(preload("res://scripts/spike.gd"))


func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = global_position
	ghost.offset = Vector2(0, -32)
	ghost.modulate = Color(0.8, 0.15, 0.25, 0.55)
	ghost.flip_h = sprite.flip_h
	get_tree().current_scene.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _update_dir() -> void:
	if abs(facing.x) > abs(facing.y):
		dir_name = "right" if facing.x > 0 else "left"
	else:
		dir_name = "down" if facing.y > 0 else "up"


func _animate(_delta: float) -> void:
	var anim := "idle"
	match state:
		"dash": anim = "dash"
		"attack": anim = "attack"
		"heavy": anim = "heavy"
		"cast": anim = "cast"
		"hurt": anim = "hurt"
		_:
			if velocity.length() > 8.0:
				anim = "sneak" if sneaking else "walk"
			else:
				anim = "idle"
	var key := dir_name + "|" + anim
	if key != _last_anim:
		_last_anim = key
		sprite.sprite_frames = Art.frames("hero", dir_name, anim)
		sprite.play(anim)
	# тень под ногами
	shadow.scale = Vector2(1.0, 1.0) * (0.8 if sneaking else 1.0)


func take_damage(amount: float, from := Vector2.ZERO) -> void:
	if invuln > 0.0 or state == "dead":
		return
	invuln = HURT_INVULN
	hurt_flash = 0.35
	GameState.damage(amount)
	Sfx.play("sfx_hit", -6.0)
	screen_shake(5.0, 0.2)
	if from != Vector2.ZERO:
		velocity = (global_position - from).normalized() * 150.0
	_set_state("hurt")
	if GameState.health <= 0.0:
		_die()


func _die() -> void:
	if state == "dead":
		return
	_set_state("dead")
	Sfx.play("sfx_death", -6.0)
	sprite.sprite_frames = Art.frames("hero", dir_name, "dead")
	sprite.play("dead")
	died.emit()


func screen_shake(amount: float, duration: float) -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount, duration)
