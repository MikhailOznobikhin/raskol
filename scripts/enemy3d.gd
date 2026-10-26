extends CharacterBody3D
## Стражник-Пожиратель (и босс в том же риге): патруль, погоня, бой.

class_name Enemy3D

signal died(enemy)

var is_boss := false
var hp := 60.0
var max_hp := 60.0
var dead := false
var state := "patrol"
var state_t := 0.0
var attack_cd := 0.0
var patrol: Array = []
var patrol_i := 0
var target: Node3D
var speed := Balance.GUARD_SPEED
var chase_speed := Balance.GUARD_CHASE
var attack_range := Balance.GUARD_RANGE
var attack_damage := Balance.GUARD_DMG
var detect_range := Balance.GUARD_DETECT

var rig: Node3D
var body_root: Node3D
var head: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_l: Node3D
var leg_r: Node3D
var bar_fill: MeshInstance3D
var mat_cloth: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_dark: StandardMaterial3D
var flash := 0.0
var stagger_t := 0.0
var phase := 0.0
var bark_cd := 4.0

static var barks: Array = []


func setup(kind: String) -> void:
	if kind == "boss":
		is_boss = true
		hp = Balance.BOSS_HP
		speed = 2.2
		chase_speed = 2.9
		attack_range = Balance.BOSS_RANGE
		attack_damage = Balance.BOSS_DMG
		detect_range = Balance.BOSS_DETECT
	else:
		hp = Balance.GUARD_HP
		speed = Balance.GUARD_SPEED
		chase_speed = Balance.GUARD_CHASE
		attack_range = Balance.GUARD_RANGE
		attack_damage = Balance.GUARD_DMG
		detect_range = Balance.GUARD_DETECT
	max_hp = hp


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38 if not is_boss else 0.55
	cap.height = 1.6 if not is_boss else 2.1
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	_build_rig()
	_build_bar()
	_build_hurtbox()
	_add_blob_shadow(0.6 if not is_boss else 0.95)


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	return m


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _box(parent: Node3D, size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _build_rig() -> void:
	mat_cloth = _mat(Color(0.42, 0.09, 0.12))
	mat_skin = _mat(Color(0.55, 0.4, 0.3))
	mat_metal = _mat(Color(0.38, 0.4, 0.46), 0.5, 0.75)
	mat_dark = _mat(Color(0.12, 0.09, 0.09), 0.9)

	rig = Node3D.new()
	add_child(rig)
	var hips := _joint(rig, Vector3(0, 0.92, 0))
	_box(hips, Vector3(0.52, 0.24, 0.36), Vector3(0, 0, 0), mat_dark)
	var chest := _joint(hips, Vector3(0, 0.14, 0))
	_box(chest, Vector3(0.68, 0.5, 0.44), Vector3(0, 0.28, 0), mat_cloth)
	_box(chest, Vector3(0.72, 0.16, 0.48), Vector3(0, 0.5, 0), mat_metal)
	_box(chest, Vector3(0.5, 0.3, 0.02), Vector3(0, 0.3, 0.23), mat_dark)
	head = _joint(chest, Vector3(0, 0.58, 0))
	_box(head, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.12, 0), mat_metal)
	_box(head, Vector3(0.26, 0.06, 0.02), Vector3(0, 0.12, 0.16), _mat(Color(1.0, 0.2, 0.2), 0.3))
	_box(head, Vector3(0.06, 0.22, 0.06), Vector3(0, -0.04, 0.14), mat_metal)

	arm_l = _joint(chest, Vector3(-0.42, 0.44, 0))
	_box(arm_l, Vector3(0.18, 0.4, 0.18), Vector3(0, -0.2, 0), mat_cloth)
	arm_r = _joint(chest, Vector3(0.42, 0.44, 0))
	_box(arm_r, Vector3(0.18, 0.4, 0.18), Vector3(0, -0.2, 0), mat_cloth)
	# дубина
	var club := Node3D.new()
	club.position = Vector3(0, -0.42, 0.05)
	arm_r.add_child(club)
	_box(club, Vector3(0.09, 0.9, 0.09), Vector3(0, -0.45, 0.1), mat_dark)
	_box(club, Vector3(0.24, 0.28, 0.24), Vector3(0, -0.9, 0.15), mat_metal)

	leg_l = _joint(hips, Vector3(-0.17, -0.06, 0))
	_box(leg_l, Vector3(0.22, 0.44, 0.24), Vector3(0, -0.22, 0), mat_dark)
	leg_r = _joint(hips, Vector3(0.17, -0.06, 0))
	_box(leg_r, Vector3(0.22, 0.44, 0.24), Vector3(0, -0.22, 0), mat_dark)

	if is_boss:
		rig.scale = Vector3(1.35, 1.35, 1.35)
		_box(head, Vector3(0.1, 0.3, 0.24), Vector3(0, 0.34, 0), mat_metal)
		for sx in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.01
			cone.bottom_radius = 0.07
			cone.height = 0.34
			horn.mesh = cone
			horn.material_override = mat_metal
			horn.position = Vector3(0.13 * sx, 0.3, 0.02)
			horn.rotation_degrees = Vector3(0, 0, 28 * sx)
			head.add_child(horn)


func _build_bar() -> void:
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	bg.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.03, 0.03)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.material_override = m
	bg.position = Vector3(0, 2.2 if not is_boss else 2.9, 0)
	add_child(bg)

	bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.07)
	bar_fill.mesh = q2
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.72, 0.16, 0.2)
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_fill.material_override = m2
	bar_fill.position = Vector3(0, 0, 0.01)
	bg.add_child(bar_fill)


func _physics_process(delta: float) -> void:
	state_t += delta
	bark_cd = max(0.0, bark_cd - delta)
	attack_cd = max(0.0, attack_cd - delta)
	flash = max(0.0, flash - delta)
	stagger_t = max(0.0, stagger_t - delta)
	if dead:
		velocity.y -= 18.0 * delta
		move_and_slide()
		return
	if target == null or not is_instance_valid(target):
		return
	if stagger_t > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_animate(delta)
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0
	var dist := to.length()

	match state:
		"patrol":
			if dist < detect_range and _can_see(target):
				state = "chase"
				Sfx.play("sfx_alert", -16.0, 1.1)
				_bark()
			else:
				_patrol(delta)
		"chase":
			if dist > detect_range * 1.6:
				state = "patrol"
				velocity = Vector3.ZERO
			elif dist > attack_range:
				velocity = to.normalized() * chase_speed
				_face(to)
			else:
				velocity = Vector3.ZERO
				if attack_cd <= 0.0:
					_attack()
		"attack":
			velocity = Vector3.ZERO
			if state_t > 0.75:
				state = "chase"
	_apply_gravity(delta)
	move_and_slide()
	_animate(delta)
	if bar_fill:
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		bar_fill.scale = Vector3(ratio, 1.0, 1.0)
		bar_fill.position.x = -(1.0 - ratio) * 0.48


func _apply_gravity(dt: float) -> void:
	velocity.y -= 20.0 * dt
	if is_on_floor():
		velocity.y = 0.0


func _patrol(_dt: float) -> void:
	if patrol.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var wp: Vector3 = patrol[patrol_i]
	var to := wp - global_position
	to.y = 0
	if to.length() < 1.0:
		patrol_i = (patrol_i + 1) % patrol.size()
		return
	velocity.x = to.normalized().x * speed
	velocity.z = to.normalized().z * speed
	_face(to)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.05:
		return
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), 0.2)


func _can_see(t: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.5, 0)
	var to := t.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _attack() -> void:
	state = "attack"
	state_t = 0.0
	attack_cd = 1.3
	Sfx.play("sfx_swing", -10.0, 0.9)
	await get_tree().create_timer(0.35).timeout
	if dead or target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= attack_range + 0.6:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, global_position)


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.18
	stagger_t = 0.24
	state = "chase"
	Sfx.play("sfx_hit", -8.0)
	var away := global_position - from
	away.y = 0
	velocity += away.normalized() * 3.0
	if hp <= 0.0:
		_die()


func knockback(dir: Vector3, force: float) -> void:
	var d := dir
	d.y = 0.0
	if d.length() > 0.01:
		velocity += d.normalized() * force


func _die() -> void:
	if dead:
		return
	dead = true
	add_to_group("dead")
	GameState.guards_killed += 1
	Sfx.play("sfx_death", -6.0)
	if bar_fill:
		bar_fill.get_parent().visible = false
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", 1.45, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(rig, "position:y", -1.2, 1.2)
	tw.tween_callback(queue_free)
	died.emit(self)


func _animate(dt: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.2:
		phase += dt * 7.0
		var s := sin(phase)
		if leg_l:
			leg_l.rotation.x = s * 0.5
			leg_r.rotation.x = -s * 0.5
			arm_l.rotation.x = -s * 0.4
			if state != "attack":
				arm_r.rotation.x = s * 0.4
		# шаги
		if not has_meta("step_t"):
			set_meta("step_t", 0.0)
		var st: float = get_meta("step_t")
		st += dt
		if st > 0.4:
			st = 0.0
			Sfx.play_varied("sfx_step", -24.0)
		set_meta("step_t", st)
	if state == "attack":
		var t: float = clampf(state_t / 0.35, 0.0, 1.0)
		arm_r.rotation.x = lerp(-1.8, 0.6, t)
	else:
		arm_r.rotation.x = lerp(arm_r.rotation.x, 0.0, dt * 8.0)
	if flash > 0.0 and mat_cloth:
		mat_cloth.albedo_color = Color(1, 0.6, 0.6)
	elif mat_cloth:
		mat_cloth.albedo_color = Color(0.42, 0.09, 0.12)


func _bark() -> void:
	if bark_cd > 0.0 or barks.is_empty():
		return
	bark_cd = 9.0
	var text: String = barks[randi() % barks.size()]
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0045
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.95, 0.86, 0.7, 0.0)
	l.outline_size = 10
	l.position = Vector3(0, 2.35 if not is_boss else 3.1, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _add_blob_shadow(radius: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.5))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.2, radius * 2.2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0, 0, 0, 0.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0.03, 0)
	add_child(mi)


func _build_hurtbox() -> void:
	var hurt := Area3D.new()
	hurt.collision_layer = 8
	hurt.collision_mask = 0
	hurt.monitoring = false
	hurt.monitorable = true
	hurt.add_to_group("enemy_hurtbox")
	hurt.set_meta("owner_enemy", self)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 if not is_boss else 0.8
	cap.height = 1.4 if not is_boss else 2.0
	cs.shape = cap
	cs.position = Vector3(0, 0.9 if not is_boss else 1.2, 0)
	hurt.add_child(cs)
	add_child(hurt)
