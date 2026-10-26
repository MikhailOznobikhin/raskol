extends CharacterBody2D
## Стражник-Пожиратель: патруль, подозрение, тревога, бой.

class_name Guard

signal died(guard)
signal noticed

const HP := 60.0
const PATROL_SPEED := 44.0
const CHASE_SPEED := 86.0
const VISION_RANGE := 165.0
const SNEAK_RANGE := 92.0
const VISION_DOT := 0.55          # ~57 градусов в каждую сторону? нет: 0.55 => ~56° полный
const ATTACK_RANGE := 26.0
const ATTACK_DAMAGE := 8.0
const ATTACK_WINDUP := 0.38

var hp := HP
var is_dead := false
var knocked_out := false
var state := "patrol"
var state_t := 0.0
var facing := Vector2.DOWN
var dir_name := "down"
var patrol: Array = []
var patrol_i := 0
var wait_t := 0.0
var last_seen := Vector2.ZERO
var lost_t := 0.0
var attack_cd := 0.0
var alert_level := 0

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var mark: Label
var cone: Polygon2D
var _last_anim := ""


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)

	shadow = Sprite2D.new()
	shadow.texture = _shadow_texture()
	shadow.position = Vector2(0, -2)
	shadow.modulate = Color(1, 1, 1, 0.5)
	add_child(shadow)

	cone = Polygon2D.new()
	cone.color = Color(0.95, 0.85, 0.5, 0.07)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var a := -0.5 + i * (1.0 / 12.0)
		pts.append(Vector2(cos(a), sin(a)) * VISION_RANGE)
	cone.polygon = pts
	cone.position = Vector2(0, -14)
	cone.z_index = -1
	add_child(cone)

	sprite = Art.make_sprite("guard", "down", "idle")
	sprite.offset = Vector2(0, -32)
	add_child(sprite)

	mark = Label.new()
	mark.text = "?"
	mark.add_theme_font_size_override("font_size", 16)
	mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	mark.position = Vector2(-4, -76)
	mark.visible = false
	add_child(mark)


func _shadow_texture() -> ImageTexture:
	var img := Image.create(24, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 24:
			var dx := (x - 12.0) / 12.0
			var dy := (y - 4.5) / 4.5
			var d := sqrt(dx * dx + dy * dy)
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.5 * pow(1.0 - d, 1.4)))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	state_t += delta
	attack_cd = max(0.0, attack_cd - delta)
	if is_dead or knocked_out:
		return
	var mission := get_tree().current_scene
	if mission == null or not mission.has_method("is_wall_between"):
		return
	var player = mission.player
	if player == null:
		return

	var sees := _can_see(player, mission)
	match state:
		"patrol":
			mark.visible = false
			cone.color = Color(0.95, 0.85, 0.5, 0.06)
			_patrol(delta)
			if sees:
				_enter_suspicious(player)
		"suspicious":
			mark.visible = true
			mark.text = "?"
			mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			cone.color = Color(1.0, 0.8, 0.3, 0.10)
			velocity = Vector2.ZERO
			if player:
				_face_to(player.global_position - global_position)
			if state_t > 1.5:
				_enter_alert(player)
		"alert":
			mark.visible = true
			mark.text = "!"
			mark.add_theme_color_override("font_color", Color(1.0, 0.25, 0.3))
			cone.color = Color(1.0, 0.25, 0.3, 0.12)
			if player:
				var to: Vector2 = player.global_position - global_position
				last_seen = player.global_position
				if sees:
					lost_t = 0.0
				else:
					lost_t += delta
				_face_to(to)
				if to.length() > ATTACK_RANGE:
					velocity = to.normalized() * CHASE_SPEED
					move_and_slide()
					if to.length() < 220.0 and sees:
						Sfx.play_varied("sfx_step", -26.0, 0.2)
				else:
					velocity = Vector2.ZERO
					if attack_cd <= 0.0:
						_attack(player)
				if lost_t > 4.0:
					state = "search"
					state_t = 0.0
		"search":
			mark.visible = true
			mark.text = "?"
			cone.color = Color(1.0, 0.8, 0.3, 0.08)
			var to2 := last_seen - global_position
			if to2.length() > 12.0:
				velocity = to2.normalized() * PATROL_SPEED * 1.3
				move_and_slide()
				_face_to(to2)
			else:
				velocity = Vector2.ZERO
			if sees:
				_enter_alert(player)
			if state_t > 6.0:
				_enter_patrol()
	_animate()


func _patrol(delta: float) -> void:
	if patrol.is_empty():
		velocity = Vector2.ZERO
		return
	if wait_t > 0.0:
		wait_t -= delta
		velocity = Vector2.ZERO
		return
	var target: Vector2 = patrol[patrol_i]
	var to := target - global_position
	if to.length() < 8.0:
		patrol_i = (patrol_i + 1) % patrol.size()
		wait_t = 1.4
		return
	velocity = to.normalized() * PATROL_SPEED
	move_and_slide()
	_face_to(to)


func _can_see(player, mission) -> bool:
	if player == null or player.state == "dead":
		return false
	var to: Vector2 = player.global_position - global_position
	var dist := to.length()
	var range_mult: float = 1.0
	var radius := SNEAK_RANGE if player.sneaking else VISION_RANGE
	radius *= GameState.noise_mult() if player.noise > 0.3 else 1.0
	if dist > radius * range_mult:
		return false
	if dist > 46.0:
		var dot := facing.normalized().dot(to.normalized())
		if dot < VISION_DOT and state == "patrol":
			return false
	if mission.is_wall_between(global_position + Vector2(0, -12), player.global_position + Vector2(0, -12)):
		return false
	return true


func _enter_suspicious(player) -> void:
	if state == "alert":
		return
	state = "suspicious"
	state_t = 0.0
	noticed.emit()
	if player:
		_face_to(player.global_position - global_position)
	Sfx.play("sfx_alert", -22.0, 1.3)


func _enter_alert(player) -> void:
	state = "alert"
	state_t = 0.0
	lost_t = 0.0
	mark.visible = true
	if player:
		last_seen = player.global_position
	Sfx.play("sfx_alert", -12.0)
	var mission := get_tree().current_scene
	if mission and mission.has_method("on_guard_alerted"):
		mission.on_guard_alerted(self)


func _enter_patrol() -> void:
	state = "patrol"
	state_t = 0.0
	mark.visible = false


func _face_to(v: Vector2) -> void:
	if v.length() < 0.1:
		return
	facing = v.normalized()
	if abs(facing.x) > abs(facing.y):
		dir_name = "right" if facing.x > 0 else "left"
	else:
		dir_name = "down" if facing.y > 0 else "up"
	cone.rotation = facing.angle() + PI * 0.5


func _attack(player) -> void:
	attack_cd = 1.15
	state = "attack"
	state_t = 0.0
	var target_pos: Vector2 = player.global_position
	sprite.sprite_frames = Art.frames("guard", dir_name, "attack")
	sprite.play("attack")
	Sfx.play("sfx_swing", -12.0, 0.9)
	await get_tree().create_timer(ATTACK_WINDUP).timeout
	if is_dead or player == null or player.state == "dead":
		return
	if global_position.distance_to(target_pos) < ATTACK_RANGE + 8.0:
		player.take_damage(ATTACK_DAMAGE, global_position)
	state = "alert"
	state_t = 0.0


func take_damage(amount: float, from := Vector2.ZERO) -> void:
	if is_dead or knocked_out:
		return
	hp -= amount
	sprite.modulate = Color(2.0, 1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	if from != Vector2.ZERO:
		velocity = (global_position - from).normalized() * 90.0
	if hp <= 0.0:
		_die(true)
	else:
		var player = get_tree().current_scene.player
		_enter_alert(player)


func knockout() -> void:
	if is_dead or knocked_out:
		return
	knocked_out = true
	hp = 0.0
	GameState.guards_spared += 1
	state = "ko"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	mark.visible = false
	cone.visible = false
	sprite.sprite_frames = Art.frames("guard", dir_name, "dead")
	sprite.play("dead")
	Sfx.play("sfx_hit_heavy", -8.0, 0.9)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
	died.emit(self)


func _die(killed := true) -> void:
	if is_dead:
		return
	is_dead = true
	if killed:
		GameState.guards_killed += 1
	collision_layer = 0
	collision_mask = 0
	mark.visible = false
	cone.visible = false
	velocity = Vector2.ZERO
	sprite.sprite_frames = Art.frames("guard", dir_name, "dead")
	sprite.play("dead")
	Sfx.play("sfx_death", -8.0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
	died.emit(self)


func _animate() -> void:
	if is_dead or knocked_out:
		return
	var anim := "idle"
	if state == "attack":
		anim = "attack"
	elif velocity.length() > 6.0:
		anim = "walk"
	var key := dir_name + "|" + anim
	if key != _last_anim:
		_last_anim = key
		sprite.sprite_frames = Art.frames("guard", dir_name, anim)
		sprite.play(anim)
