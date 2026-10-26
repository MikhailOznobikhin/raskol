extends CharacterBody3D
## Торвин в 3D: риг из примитивов, движение от камеры, бой, рывок.

class_name Hero3D

const SPEED: float = Balance.HERO_SPEED
const RUN: float = Balance.HERO_RUN
const ACCEL := Balance.HERO_ACCEL
const DODGE_SPEED: float = Balance.HERO_DODGE_SPEED
const DODGE_TIME: float = Balance.HERO_DODGE_TIME
const LIGHT_DMG: float = Balance.HERO_LIGHT_DMG
const HEAVY_DMG: float = Balance.HERO_HEAVY_DMG
const HEAVY_WINDUP: float = Balance.HERO_HEAVY_WINDUP
const ATTACK_TIME := Balance.HERO_ATTACK_TIME

var state := "idle"
var state_t := 0.0
var attack_done := false
var invuln := 0.0
var dead := false
var control_enabled := true

var rig: Node3D
var hips: Node3D
var chest: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var weapon: Node3D

var phase := 0.0
var combo_step := 0
var attack_queued := false
var step_t := 0.0
var facing_yaw := 0.0
var move_dir := Vector3.ZERO
var mat_cloth: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_leather: StandardMaterial3D
var mat_cloth_dark: StandardMaterial3D
var mat_metal_dark: StandardMaterial3D

signal died


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.5
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.78, 0)
	add_child(col)
	_build_rig()


func _mat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
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
	s.radial_segments = 14
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi



func _cyl(r: float, h: float, offset: Vector3, mat: Material, parent: Node3D, bottom := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if bottom < 0.0 else bottom
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float, offset: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 6
	mi.mesh = c
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi

func _build_rig() -> void:
	mat_cloth = _mat(Color(0.24, 0.3, 0.46), 0.85)
	mat_cloth_dark = _mat(Color(0.15, 0.19, 0.3), 0.9)
	mat_skin = _mat(Color(0.66, 0.48, 0.36), 0.7)
	mat_metal = _mat(Color(0.55, 0.58, 0.66), 0.35, 0.85)
	mat_metal_dark = _mat(Color(0.3, 0.32, 0.38), 0.5, 0.8)
	mat_hair = _mat(Color(0.45, 0.24, 0.11), 0.9)
	mat_leather = _mat(Color(0.32, 0.23, 0.15), 0.8)

	rig = Node3D.new()
	add_child(rig)

	hips = _joint(rig, Vector3(0, 0.9, 0))
	_box(hips, Vector3(0.46, 0.2, 0.34), Vector3(0, 0, 0), mat_leather)
	_box(hips, Vector3(0.52, 0.1, 0.36), Vector3(0, 0.08, 0), mat_metal_dark)
	_box(hips, Vector3(0.12, 0.09, 0.03), Vector3(0, 0.08, 0.19), mat_metal)

	chest = _joint(hips, Vector3(0, 0.12, 0))
	_box(chest, Vector3(0.56, 0.42, 0.38), Vector3(0, 0.24, 0), mat_cloth)
	_box(chest, Vector3(0.6, 0.3, 0.4), Vector3(0, 0.34, 0.005), mat_cloth)
	# нагрудная пластина и перевязь
	_box(chest, Vector3(0.34, 0.26, 0.03), Vector3(0, 0.28, 0.2), mat_metal_dark)
	_box(chest, Vector3(0.07, 0.46, 0.02), Vector3(0.12, 0.26, 0.21), mat_leather)
	_box(chest, Vector3(0.62, 0.1, 0.42), Vector3(0, 0.47, 0), mat_metal)
	# наплечники
	_sphere(chest, 0.14, Vector3(-0.38, 0.43, 0), mat_metal)
	_sphere(chest, 0.14, Vector3(0.38, 0.43, 0), mat_metal)
	# плащ из сегментов
	var cloak := _box(chest, Vector3(0.5, 0.72, 0.04), Vector3(0, 0.16, -0.235), mat_cloth_dark)
	cloak.rotation_degrees = Vector3(-6, 0, 0)
	_box(chest, Vector3(0.48, 0.18, 0.03), Vector3(0, -0.16, -0.245), mat_cloth_dark)
	_box(chest, Vector3(0.42, 0.16, 0.03), Vector3(0, -0.31, -0.255), mat_cloth_dark)
	# ремень с пряжкой
	_box(hips, Vector3(0.48, 0.06, 0.36), Vector3(0, 0.02, 0), mat_leather)
	_box(hips, Vector3(0.08, 0.08, 0.03), Vector3(0, 0.02, 0.19), mat_metal)

	# голова
	head = _joint(chest, Vector3(0, 0.52, 0))
	_sphere(head, 0.18, Vector3(0, 0.14, 0), mat_skin)
	_box(head, Vector3(0.26, 0.16, 0.26), Vector3(0, 0.02, 0.02), mat_skin)
	# волосы: шапка сзади и по бокам
	var hair := _sphere(head, 0.19, Vector3(0, 0.19, -0.06), mat_hair)
	hair.scale = Vector3(1.0, 0.7, 0.95)
	_box(head, Vector3(0.32, 0.1, 0.26), Vector3(0, 0.27, -0.05), mat_hair)
	# борода-клин
	_cyl(0.15, 0.34, Vector3(0, -0.08, 0.07), mat_hair, head, 0.05)
	_box(head, Vector3(0.3, 0.1, 0.16), Vector3(0, 0.04, 0.13), mat_hair)
	# нос и глаза
	_box(head, Vector3(0.07, 0.08, 0.09), Vector3(0, 0.12, 0.18), mat_skin)
	var eye_mat := _mat(Color(1.0, 0.72, 0.28), 0.3)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.62, 0.2)
	eye_mat.emission_energy_multiplier = 1.6
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(-0.075, 0.16, 0.17), eye_mat)
	_box(head, Vector3(0.05, 0.03, 0.02), Vector3(0.075, 0.16, 0.17), eye_mat)

	# руки
	arm_l = _joint(chest, Vector3(-0.34, 0.42, 0))
	_capsule(0.09, 0.36, Vector3(0, -0.18, 0), mat_cloth, arm_l)
	_sphere(arm_l, 0.12, Vector3(0, -0.01, 0), mat_metal)
	forearm_l = _joint(arm_l, Vector3(0, -0.36, 0))
	_capsule(0.075, 0.3, Vector3(0, -0.15, 0), mat_leather, forearm_l)
	_sphere(forearm_l, 0.08, Vector3(0, -0.33, 0), mat_skin)

	arm_r = _joint(chest, Vector3(0.34, 0.42, 0))
	_capsule(0.09, 0.36, Vector3(0, -0.18, 0), mat_cloth, arm_r)
	_sphere(arm_r, 0.12, Vector3(0, -0.01, 0), mat_metal)
	forearm_r = _joint(arm_r, Vector3(0, -0.36, 0))
	_capsule(0.075, 0.3, Vector3(0, -0.15, 0), mat_leather, forearm_r)
	_sphere(forearm_r, 0.08, Vector3(0, -0.33, 0), mat_skin)

	# молот
	weapon = Node3D.new()
	weapon.position = Vector3(0, -0.34, 0)
	forearm_r.add_child(weapon)
	_box(weapon, Vector3(0.055, 0.72, 0.055), Vector3(0, -0.34, 0.12), mat_leather)
	_box(weapon, Vector3(0.2, 0.2, 0.28), Vector3(0, -0.68, 0.24), mat_metal_dark)
	_box(weapon, Vector3(0.22, 0.06, 0.3), Vector3(0, -0.6, 0.24), mat_metal)

	# ноги
	leg_l = _joint(hips, Vector3(-0.14, -0.06, 0))
	_capsule(0.1, 0.42, Vector3(0, -0.21, 0), mat_cloth_dark, leg_l)
	shin_l = _joint(leg_l, Vector3(0, -0.42, 0))
	_capsule(0.09, 0.34, Vector3(0, -0.17, 0), mat_leather, shin_l)
	_box(shin_l, Vector3(0.21, 0.14, 0.34), Vector3(0, -0.36, 0.05), mat_leather)

	leg_r = _joint(hips, Vector3(0.14, -0.06, 0))
	_capsule(0.1, 0.42, Vector3(0, -0.21, 0), mat_cloth_dark, leg_r)
	shin_r = _joint(leg_r, Vector3(0, -0.42, 0))
	_capsule(0.09, 0.34, Vector3(0, -0.17, 0), mat_leather, shin_r)
	_box(shin_r, Vector3(0.21, 0.14, 0.34), Vector3(0, -0.36, 0.05), mat_leather)

	_add_blob_shadow(0.55)


func _add_blob_shadow(radius: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
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
	m.albedo_color = Color(0, 0, 0, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0.03, 0)
	add_child(mi)


func _physics_process(delta: float) -> void:
	state_t += delta
	invuln = max(0.0, invuln - delta)
	if dead:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		velocity.y -= 18.0 * delta
		move_and_slide()
		return

	var input := Vector2.ZERO
	if control_enabled and not get_tree().paused:
		input = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
	var cam := get_viewport().get_camera_3d()
	var yaw := 0.0
	if cam:
		yaw = cam.global_rotation.y
	var dir := Vector3(input.x, 0, input.y)
	dir = dir.rotated(Vector3.UP, yaw)
	if dir.length() > 1.0:
		dir = dir.normalized()
	move_dir = dir

	var target_speed := 0.0
	match state:
		"dodge":
			velocity = dir * DODGE_SPEED if dir.length() > 0.1 else -rig.global_transform.basis.z * DODGE_SPEED
			if state_t > DODGE_TIME:
				_set_state("idle")
		"attack":
			target_speed = SPEED * 0.25
			if state_t > 0.16 and not attack_done:
				attack_done = true
				_hit(false)
			if state_t > ATTACK_TIME:
				if attack_queued and combo_step < 2:
					attack_queued = false
					combo_step += 1
					_start_attack()
				else:
					attack_queued = false
					combo_step = 0
					_set_state("idle")
		"heavy":
			target_speed = SPEED * 0.1
			if state_t > HEAVY_WINDUP and not attack_done:
				attack_done = true
				_hit(true)
			if state_t > HEAVY_WINDUP + 0.3:
				_set_state("idle")
		"hurt":
			target_speed = 0.0
			if state_t > 0.35:
				_set_state("idle")
		_:
			var run := Input.is_action_pressed("sneak")
			target_speed = RUN if run else SPEED
			if input.length() < 0.1:
				target_speed = 0.0
	_handle_input()

	var desired := dir * target_speed
	if state != "dodge":
		velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)
	velocity.y -= 18.0 * delta
	if is_on_floor():
		velocity.y = 0.0
	move_and_slide()

	# поворот рига по движению
	if dir.length() > 0.1 and state in ["idle", "run"]:
		var want := atan2(dir.x, dir.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, want, 12.0 * delta)
	_animate(delta)


func _handle_input() -> void:
	if not control_enabled or state in ["attack", "heavy", "dodge", "hurt"]:
		return
	if Input.is_action_just_pressed("dash") and GameState.spend_magic(Balance.DODGE_COST):
		_set_state("dodge")
		invuln = Balance.HERO_INVULN_DODGE
		Sfx.play("sfx_swing", -10.0, 1.4)
		return
	if Input.is_action_just_pressed("attack"):
		if state == "attack":
			if state_t > 0.12:
				attack_queued = true
			return
		combo_step = 0
		_start_attack()
		return
	if Input.is_action_just_pressed("heavy"):
		_set_state("heavy")
		attack_done = false
		var fwd := -rig.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.05:
			velocity = fwd.normalized() * 4.0
		Sfx.play("sfx_swing", -8.0, 0.8)


func _start_attack() -> void:
	_set_state("attack")
	attack_done = false
	Sfx.play_varied("sfx_swing", -9.0, 0.92 + 0.06 * combo_step)


func _hit(heavy: bool) -> void:
	var step_mult := 1.0
	if not heavy:
		step_mult = [1.0, 14.0 / 12.0, 20.0 / 12.0][combo_step]
	var dmg := (HEAVY_DMG if heavy else LIGHT_DMG) * step_mult * GameState.craving_damage_mult()
	var reach := 2.6 if heavy else 2.2
	var fwd := -rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = reach * 0.62
	params.shape = sphere
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0) + fwd * reach * 0.55)
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := space.intersect_shape(params, 8)

	var hit_any := false
	var hit_pos := Vector3.ZERO
	var seen: Array = []
	for h in hits:
		var area = h.get("collider")
		if area == null:
			continue
		var enemy = area.get_meta("owner_enemy", null)
		if enemy == null or not is_instance_valid(enemy) or enemy.dead or seen.has(enemy):
			continue
		seen.append(enemy)
		enemy.take_damage(dmg, global_position)
		if not heavy and combo_step == 2 and enemy.has_method("knockback"):
			enemy.knockback(fwd, 5.0)
		hit_pos = enemy.global_position + Vector3(0, 1.1, 0)
		hit_any = true

	# страховка: если Area3D-хитбокс не сработал (например, враг без хуртбокса),
	# добираем попадания по группе врагов в пределах дуги
	if not hit_any:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var center: Vector3 = e.global_position + Vector3(0, 1.0, 0)
			var to: Vector3 = center - (global_position + Vector3(0, 1.0, 0))
			if to.length() > reach + 0.7:
				continue
			var flat := Vector3(to.x, 0, to.z)
			if flat.length() > 0.05 and fwd.dot(flat.normalized()) < 0.2:
				continue
			e.take_damage(dmg, global_position)
			if not heavy and combo_step == 2 and e.has_method("knockback"):
				e.knockback(fwd, 5.0)
			hit_pos = center
			hit_any = true

	if hit_any:
		Sfx.play("sfx_hit_heavy" if heavy else "sfx_hit", -6.0)
		_impact(hit_pos, heavy)
		_hitstop()
	else:
		Sfx.play("sfx_swing", -14.0, 1.2)


func take_damage(amount: float, from := Vector3.ZERO) -> void:
	if invuln > 0.0 or dead:
		return
	invuln = 0.6
	GameState.damage(amount)
	_bark_damage()
	Sfx.play("sfx_hit", -5.0)
	_set_state("hurt")
	if from != Vector3.ZERO:
		var away := (global_position - from)
		away.y = 0
		velocity = away.normalized() * 6.0
	if GameState.health <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	Sfx.play("sfx_death", -4.0)
	var tw := create_tween()
	tw.tween_property(rig, "rotation:x", -1.35, 0.6)
	tw.parallel().tween_property(rig, "position:y", 0.15, 0.6)
	died.emit()


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _animate(dt: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.4
	phase += dt * (6.0 if speed < 4.5 else 8.5) * (1.0 if moving else 0.0)
	var swing := sin(phase)
	var amp: float = clampf(speed / RUN, 0.0, 1.0)

	var l_target := 0.0
	var r_target := 0.0
	var al := 0.0
	var ar := 0.0
	var elbow_l := 0.0
	var elbow_r := 0.0



	if state == "attack" or state == "heavy":
		var t: float = clampf(state_t / (ATTACK_TIME if state == "attack" else HEAVY_WINDUP + 0.3), 0.0, 1.0)
		var wind := 0.0
		var strike := 0.0
		if t < 0.4:
			wind = t / 0.4
			strike = 0.0
		else:
			wind = 1.0 - (t - 0.4) / 0.6
			strike = (t - 0.4) / 0.6
		ar = lerp(0.4, -2.2 - 0.5 * combo_step, wind) + strike * (3.0 + 0.6 * combo_step)
		al = -0.3 - strike * 0.4
		chest.rotation.y = lerp(0.0, 0.5, wind) - strike * 0.9
		chest.rotation.x = -0.15 + strike * 0.5
		head.rotation.x = 0.1
	else:
		chest.rotation.y = lerp(chest.rotation.y, 0.0, dt * 10.0)
		chest.rotation.x = lerp(chest.rotation.x, 0.0, dt * 10.0)
		head.rotation.x = lerp(head.rotation.x, 0.0, dt * 8.0)
		if moving:
			l_target = swing * 0.6 * amp
			r_target = -swing * 0.6 * amp
			al = -swing * 0.5 * amp
			ar = swing * 0.5 * amp
			elbow_l = max(0.0, -swing) * 0.7
			elbow_r = max(0.0, swing) * 0.7
			hips.position.y = 0.86 + abs(sin(phase * 2.0)) * 0.025 * amp
		else:
			l_target = sin(Time.get_ticks_msec() / 900.0) * 0.03
			r_target = -l_target
			al = sin(Time.get_ticks_msec() / 1100.0) * 0.05
			ar = -al
			hips.position.y = lerp(hips.position.y, 0.86, dt * 6.0)

	if state == "dodge":
		rig.rotation.x = lerp(rig.rotation.x, -0.35, dt * 14.0)
	else:
		rig.rotation.x = lerp(rig.rotation.x, 0.0, dt * 10.0)

	leg_l.rotation.x = lerp(leg_l.rotation.x, l_target, dt * 14.0)
	leg_r.rotation.x = lerp(leg_r.rotation.x, r_target, dt * 14.0)
	shin_l.rotation.x = lerp(shin_l.rotation.x, max(0.0, -swing) * 0.9 * amp, dt * 14.0)
	shin_r.rotation.x = lerp(shin_r.rotation.x, max(0.0, swing) * 0.9 * amp, dt * 14.0)
	arm_l.rotation.x = lerp(arm_l.rotation.x, al, dt * 14.0)
	forearm_l.rotation.x = lerp(forearm_l.rotation.x, elbow_l, dt * 14.0)
	if state != "attack" and state != "heavy":
		arm_r.rotation.x = lerp(arm_r.rotation.x, ar, dt * 14.0)
		forearm_r.rotation.x = lerp(forearm_r.rotation.x, elbow_r, dt * 14.0)
	else:
		arm_r.rotation.x = lerp(arm_r.rotation.x, ar, dt * 22.0)
		forearm_r.rotation.x = lerp(forearm_r.rotation.x, -0.3, dt * 18.0)

	# шаги
	if moving and is_on_floor():
		step_t += dt
		if step_t > (0.42 if speed < 4.5 else 0.3):
			step_t = 0.0
			Sfx.play_varied("sfx_step", -24.0)


func _impact(pos: Vector3, heavy: bool) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16 if not heavy else 0.24
	sph.height = sph.radius * 2.0
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.25, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.15)
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.global_position = pos
	get_tree().current_scene.add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(3.0, 3.0, 3.0), 0.16)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(mi.queue_free)


func _hitstop() -> void:
	Engine.time_scale = 0.4
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0


func _bark_damage() -> void:
	var mission := get_tree().current_scene
	if mission != null and mission.get("hud") != null:
		mission.hud.flash_damage()
