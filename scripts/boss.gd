extends CharacterBody2D
## Надзиратель Гхарн — мини-босс кузни оков. Две фазы.

signal died

const MAX_HP := 280.0

var mission = null
var hp := MAX_HP
var is_dead := false
var phase2 := false
var state := "idle"
var state_t := 0.0
var facing := Vector2.DOWN
var dir_name := "down"
var attack_cd := 1.2
var bolt_cd := 5.0
var speed := 46.0
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var cone: Polygon2D
var aoe: Sprite2D
var _last_anim := ""
var busy_attack := false
var _invuln := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)

	shadow = Sprite2D.new()
	shadow.texture = _shadow_texture()
	shadow.position = Vector2(0, -2)
	shadow.modulate = Color(1, 1, 1, 0.55)
	add_child(shadow)

	cone = Polygon2D.new()
	cone.color = Color(0.9, 0.2, 0.25, 0.10)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 11:
		var a := -0.65 + i * (1.3 / 10.0)
		pts.append(Vector2(cos(a), sin(a)) * 105.0)
	cone.polygon = pts
	cone.position = Vector2(0, -16)
	cone.z_index = -1
	cone.visible = false
	add_child(cone)

	aoe = Sprite2D.new()
	aoe.texture = _ring_texture()
	aoe.position = Vector2(0, -10)
	aoe.z_index = -1
	aoe.visible = false
	add_child(aoe)

	sprite = Art.make_sprite("gharn", "down", "idle")
	sprite.offset = Vector2(0, -32)
	sprite.scale = Vector2(1.5, 1.5)
	add_child(sprite)
	shadow.scale = Vector2(1.4, 1.3)


func _shadow_texture() -> ImageTexture:
	var img := Image.create(34, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 34:
			var dx := (x - 17.0) / 17.0
			var dy := (y - 6.0) / 6.0
			var d := sqrt(dx * dx + dy * dy)
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.55 * pow(1.0 - d, 1.3)))
	return ImageTexture.create_from_image(img)


func _ring_texture() -> ImageTexture:
	var img := Image.create(140, 140, false, Image.FORMAT_RGBA8)
	for y in 140:
		for x in 140:
			var dx := (x - 70.0) / 70.0
			var dy := (y - 70.0) / 70.0
			var d := sqrt(dx * dx + dy * dy)
			if d < 1.0:
				var a := 0.0
				if d > 0.82:
					a = 0.85
				elif d > 0.6:
					a = 0.25
				else:
					a = 0.08
				img.set_pixel(x, y, Color(0.85, 0.15, 0.2, a))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	state_t += delta
	attack_cd = max(0.0, attack_cd - delta)
	bolt_cd = max(0.0, bolt_cd - delta)
	_invuln = max(0.0, _invuln - delta)
	if is_dead:
		return
	if mission == null or mission.player == null:
		return
	var player = mission.player
	var to: Vector2 = player.global_position - global_position
	_face_to(to)

	if busy_attack:
		velocity = Vector2.ZERO
		_animate()
		return

	if phase2 and bolt_cd <= 0.0:
		bolt_cd = 4.5
		_cast_bolts(player)
		return

	if attack_cd <= 0.0:
		if to.length() < 110.0:
			_lash(player)
		else:
			_leap(player)
		return

	if to.length() > 64.0:
		velocity = to.normalized() * speed
		move_and_slide()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	_animate()


func _face_to(v: Vector2) -> void:
	if v.length() < 0.1:
		return
	facing = v.normalized()
	if abs(facing.x) > abs(facing.y):
		dir_name = "right" if facing.x > 0 else "left"
	else:
		dir_name = "down" if facing.y > 0 else "up"
	cone.rotation = facing.angle()


func _lash(player) -> void:
	busy_attack = true
	attack_cd = 2.1
	cone.visible = true
	sprite.sprite_frames = Art.frames("gharn", dir_name, "heavy")
	sprite.play("heavy")
	Sfx.play("sfx_swing", -8.0, 0.7)
	var target: Vector2 = player.global_position
	await get_tree().create_timer(0.55).timeout
	if is_dead:
		return
	cone.visible = false
	mission.shake(5.0, 0.2)
	if player.global_position.distance_to(global_position) < 118.0:
		var dir_to: Vector2 = (player.global_position - global_position).normalized()
		if facing.dot(dir_to) > 0.2:
			player.take_damage(14.0, global_position)
	_spawn_blood(Vector2(target.x, target.y))
	await get_tree().create_timer(0.45).timeout
	busy_attack = false
	_animate()


func _leap(player) -> void:
	busy_attack = true
	attack_cd = 2.6
	aoe.visible = true
	aoe.global_position = player.global_position - Vector2(0, 10)
	aoe.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(aoe, "scale", Vector2.ONE, 0.75)
	sprite.sprite_frames = Art.frames("gharn", dir_name, "attack")
	sprite.play("attack")
	await get_tree().create_timer(0.75).timeout
	if is_dead:
		return
	var target := aoe.global_position
	aoe.visible = false
	global_position = target + Vector2(0, 10)
	mission.shake(7.0, 0.3)
	Sfx.play("sfx_hit_heavy", -3.0, 0.7)
	if player.global_position.distance_to(global_position) < 74.0:
		player.take_damage(18.0, global_position)
	_spawn_blood(global_position)
	await get_tree().create_timer(0.5).timeout
	busy_attack = false
	_animate()


func _cast_bolts(player) -> void:
	busy_attack = true
	sprite.sprite_frames = Art.frames("gharn", dir_name, "attack")
	sprite.play("attack")
	Sfx.play("sfx_cast", -6.0, 0.8)
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	for i in 3:
		var spike := Area2D.new()
		var spr := Sprite2D.new()
		spr.texture = Art.tex("res://assets/fx/spike.png")
		spike.add_child(spr)
		spike.global_position = global_position + Vector2(0, -24)
		var dir := base_dir.rotated(deg_to_rad(-14 + i * 14))
		spr.rotation = dir.angle()
		spike.set_meta("dir", dir)
		spike.set_meta("life", 2.2)
		spike.set_meta("hit", [])
		spike.set_meta("boss", true)
		get_tree().current_scene.add_child(spike)
		spike.set_script(preload("res://scripts/spike.gd"))
	await get_tree().create_timer(0.5).timeout
	busy_attack = false
	_animate()


func _has_anim(name: String) -> bool:
	return Art.frames("gharn", dir_name, name).has_animation(name)


func _spawn_blood(pos: Vector2) -> void:
	var burst := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_speed("burst", 14.0)
	frames.set_animation_loop("burst", false)
	for i in 4:
		var path := "res://assets/fx/impact_%d.png" % i
		if ResourceLoader.exists(path):
			frames.add_frame("burst", Art.tex(path))
	burst.sprite_frames = frames
	burst.global_position = pos
	burst.z_index = 30
	get_tree().current_scene.add_child(burst)
	burst.play("burst")
	burst.animation_finished.connect(burst.queue_free)
	burst.modulate = Color(1.3, 0.4, 0.5)


func take_damage(amount: float, from := Vector2.ZERO) -> void:
	if is_dead or _invuln > 0.0:
		return
	_invuln = 0.05
	hp -= amount
	sprite.modulate = Color(2.2, 1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.16)
	if mission and mission.hud:
		mission.hud.show_boss("НАДЗИРАТЕЛЬ ГХАРН", hp / MAX_HP)
	if not phase2 and hp <= MAX_HP * 0.5:
		phase2 = true
		speed = 68.0
		Sfx.play("sfx_boss_roar", -3.0)
		mission.shake(9.0, 0.5)
		mission.hud.set_hint("Гхарн в ярости! Он стал быстрее.")
	if hp <= 0.0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	speed = 0.0
	collision_layer = 0
	collision_mask = 0
	cone.visible = false
	aoe.visible = false
	sprite.sprite_frames = Art.frames("gharn", dir_name, "dead")
	sprite.play("dead")
	Sfx.play("sfx_death", -2.0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.2)
	tw.tween_callback(queue_free)
	died.emit()


func _animate() -> void:
	if is_dead:
		return
	var anim := "idle"
	if velocity.length() > 6.0:
		anim = "walk"
	var key := dir_name + "|" + anim
	if key != _last_anim:
		_last_anim = key
		sprite.sprite_frames = Art.frames("gharn", dir_name, anim)
		sprite.play(anim)
