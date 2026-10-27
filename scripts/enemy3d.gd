extends CharacterBody3D
## Стражник-Пожиратель (и босс в том же риге): патруль, погоня, бой.

class_name Enemy3D

signal died(enemy)

var is_boss := false
var xp_reward := Balance.XP_GUARD
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

# --- скрытность: внимание, зрение, слух ---
var alertness := 0.0
var sees_target := false
var hero_light := 0.0
var light_t := 0.0
var last_seen := Vector3.ZERO
var has_last := false
var heard_pos := Vector3.ZERO
var lose_t := 0.0
var search_t := 0.0
var scan_t := 0.0
var home := Vector3.ZERO

var rig: Node3D
var body_root: Node3D
var head: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_l: Node3D
var leg_r: Node3D
var bar_fill: MeshInstance3D
var bar_bg: MeshInstance3D
var mat_cloth: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_dark: StandardMaterial3D
var flash := 0.0
var stagger_t := 0.0
var phase := 0.0
var bark_cd := 4.0

var use_model := false
var model_root: Node3D
var anim: AnimationPlayer
var anim_tree: AnimationTree
var anim_state: AnimationNodeStateMachinePlayback
var flash_mat: StandardMaterial3D
var anim_was_dead := false

static var barks: Array = []


func setup(kind: String) -> void:
	if kind == "boss":
		is_boss = true
		xp_reward = Balance.XP_BOSS
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
	home = global_position
	collision_layer = 4
	collision_mask = 1
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34 if not is_boss else 0.55
	cap.height = 1.3 if not is_boss else 2.1
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position = Vector3(0, 0.65 if not is_boss else 1.05, 0)
	add_child(col)
	_build_rig()
	_attach_model()
	_build_bar()
	_build_hurtbox()
	_add_blob_shadow(0.5 if not is_boss else 0.9)


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


## Надевает glTF-модель (гном-страж из Mixamo; босс — бронированный вариант).
func _attach_model() -> void:
	ModelUtil.hide_meshes(rig)
	rig.scale = Vector3.ONE
	var path := "res://assets/boss_mixamo.glb" if is_boss else "res://assets/guard_mixamo.glb"
	var h := Balance.BOSS_MODEL_HEIGHT if is_boss else Balance.GUARD_MODEL_HEIGHT
	var model := ModelUtil.spawn(rig, path, h)
	if model == null:
		ModelUtil.show_meshes(rig)
		if is_boss:
			rig.scale = Vector3(1.35, 1.35, 1.35)
		return
	use_model = true
	model_root = model
	anim = ModelUtil.find_anim_player(model)
	if anim != null:
		_build_anim_tree()
	flash_mat = ModelUtil.make_flash_material()
	ModelUtil.apply_overlay(model, flash_mat)
	_attach_weapon(model)
	if anim != null and anim_tree == null:
		ModelUtil.play_key(anim, ["Idle"], true)


## Вешает меч в правую кисть стража (в Mixamo-меше оружия нет).
## Босс дерётся руками — хлыст/цепь по роадмапу C4 добавим позже.
func _attach_weapon(model: Node3D) -> void:
	if is_boss:
		return
	var att := ModelUtil.bone_attach(model, ["Wrist.R", "mixamorig_RightHand", "RightHand"])
	if att == null:
		return
	var grip := Node3D.new()
	att.add_child(grip)
	# кости glTF приходят с масштабом ~100 (сантиметры) — компенсируем
	var ws: Vector3 = att.global_transform.basis.get_scale()
	if ws.x > 0.0001 and ws.y > 0.0001 and ws.z > 0.0001:
		grip.scale = Vector3(1.0 / ws.x, 1.0 / ws.y, 1.0 / ws.z)
	var tool := ModelUtil.spawn(grip, "res://assets/weapon_sword.glb", 0.85, 0.0)
	if tool == null:
		return
	tool.rotation_degrees = Vector3(0, 0, 90)
	tool.position = Vector3(0, 0.3, 0)


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
	bg.position = Vector3(0, 1.75 if not is_boss else 2.65, 0)
	add_child(bg)
	bar_bg = bg

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
		# труп не должен скользить: гасим остаток скорости погони/отдачи,
		# иначе move_and_slide() продолжает тащить тело по полу.
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= 18.0 * delta
		move_and_slide()
		return
	if target == null or not is_instance_valid(target):
		return
	_update_detection(delta)
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
			_patrol(delta)
			if alertness >= _suspicion_threshold():
				_become_suspicious()
		"return":
			_return_to_post()
			if alertness >= _suspicion_threshold():
				_become_suspicious()
		"suspicious":
			velocity.x = 0.0
			velocity.z = 0.0
			var look: Vector3 = last_seen if has_last else target.global_position
			_face(look - global_position)
			if alertness >= Balance.GUARD_ALERT_MAX:
				_start_chase()
			elif state_t > Balance.GUARD_SUSPICIOUS_TIME:
				if has_last:
					_enter_search()
				else:
					state = "return"
					state_t = 0.0
		"search":
			if sees_target and alertness >= Balance.GUARD_ALERT_MAX:
				_start_chase()
			else:
				_search(delta)
				if search_t <= 0.0:
					state = "return"
					state_t = 0.0
		"chase":
			if lose_t > Balance.GUARD_LOSE_TIME:
				_enter_search()
			elif dist > attack_range:
				velocity.x = to.normalized().x * chase_speed
				velocity.z = to.normalized().z * chase_speed
				_face(to)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				if attack_cd <= 0.0:
					_attack()
		"attack":
			velocity.x = 0.0
			velocity.z = 0.0
			if state_t > 0.75:
				state = "chase"
				state_t = 0.0
	_apply_gravity(delta)
	move_and_slide()
	_animate(delta)
	if bar_fill:
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		bar_fill.scale = Vector3(ratio, 1.0, 1.0)
		bar_fill.position.x = -(1.0 - ratio) * 0.48
		if bar_bg:
			# полоска живёт в мире: вблизи камеру заслоняла бы метровым щитом.
			# Держим примерно постоянный размер на экране и прячем у целых спокойных врагов.
			var cam := get_viewport().get_camera_3d()
			if cam:
				var d: float = cam.global_position.distance_to(bar_bg.global_position)
				var k: float = clampf(d / 11.0, 0.10, 1.0)
				bar_bg.scale = Vector3(k, k, k)
				# вблизи полоска опускается к черепу, иначе «висит» в пустоте
				bar_bg.position.y = lerpf(2.85, 3.05, k) if is_boss else lerpf(2.0, 2.2, k)
			var calm: bool = state == "patrol" or state == "return"
			bar_bg.visible = not dead and not (calm and ratio > 0.999)


func _apply_gravity(dt: float) -> void:
	velocity.y -= 20.0 * dt
	if is_on_floor():
		velocity.y = 0.0


func _suspicion_threshold() -> float:
	return Balance.GUARD_ALERT_MAX * 0.35


## Слух: шум в радиусе (стены глушат вдвое) заставляет стражу идти проверять.
func hear_noise(pos: Vector3, radius: float) -> void:
	if dead or radius <= 0.0:
		return
	var heard := radius
	if not _path_clear(global_position + Vector3(0, 1.3, 0), pos + Vector3(0, 0.7, 0)):
		heard *= 0.5
	if global_position.distance_to(pos) > heard:
		return
	heard_pos = pos
	last_seen = pos
	has_last = true
	alertness = maxf(alertness, Balance.GUARD_ALERT_MAX * 0.55)
	if state in ["patrol", "return", "suspicious"]:
		_enter_search()
	elif state == "search":
		search_t = Balance.GUARD_SEARCH_TIME
	_bark()


func _enter_search() -> void:
	state = "search"
	state_t = 0.0
	search_t = Balance.GUARD_SEARCH_TIME
	scan_t = 0.0


func _become_suspicious() -> void:
	if state == "suspicious":
		return
	state = "suspicious"
	state_t = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	Sfx.play("sfx_alert", -22.0, 1.25)
	_bark()


func _start_chase() -> void:
	if state != "chase":
		Sfx.play("sfx_alert", -12.0, 1.0)
	state = "chase"
	state_t = 0.0
	alertness = Balance.GUARD_ALERT_MAX
	lose_t = 0.0


## Собирает внимание к герою: свет, стойка, конус зрения и линия видимости.
func _update_detection(dt: float) -> void:
	light_t -= dt
	if light_t <= 0.0:
		light_t = 0.2
		hero_light = _sample_hero_light()
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var range_now := _vision_range()
	var visible: bool = dist <= range_now and _in_cone(target.global_position) and _has_los(target)
	# вплотную страж чувствует героя даже за спиной
	if not visible and dist < 1.8:
		visible = _path_clear(global_position + Vector3(0, 1.2, 0),
			target.global_position + Vector3(0, 1.0, 0))
	sees_target = visible
	if visible:
		var closeness: float = clampf(1.0 - dist / maxf(range_now, 0.1), 0.0, 1.0)
		var gain: float = 40.0 + 110.0 * closeness
		if target.has_method("is_crouching") and target.is_crouching():
			gain *= 0.7
		if GameState.craving >= Balance.CRAVING_DETECT:
			gain *= Balance.GUARD_CRAVING_MULT
		alertness = minf(Balance.GUARD_ALERT_MAX, alertness + gain * dt)
		last_seen = target.global_position
		has_last = true
		lose_t = 0.0
	else:
		alertness = maxf(0.0, alertness - 22.0 * dt)
		lose_t += dt


## Дальность зрения: темнота 7.5 м, яркий факел 17 м, стойка и жажда учитываются.
func _vision_range() -> float:
	var vis: float = clampf((20.0 + hero_light) * _hero_vis_mult(), 0.0, 100.0)
	var r: float = lerpf(Balance.GUARD_DETECT_DARK, Balance.GUARD_DETECT_BRIGHT, vis / 100.0)
	if detect_range > Balance.GUARD_DETECT:
		r *= detect_range / Balance.GUARD_DETECT
	return r


func _hero_vis_mult() -> float:
	if target != null and is_instance_valid(target) and target.has_method("visibility_mult"):
		return target.visibility_mult()
	return 1.0


func _sample_hero_light() -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	for d in get_tree().get_nodes_in_group("dungeon"):
		if d != null and is_instance_valid(d) and d.has_method("light_at"):
			return d.light_at(target.global_position)
	return 0.0


func _in_cone(pos: Vector3) -> bool:
	var fwd: Vector3 = _gaze_dir()
	var to: Vector3 = pos - global_position
	to.y = 0.0
	if fwd.length() < 0.01 or to.length() < 0.01:
		return true
	return rad_to_deg(fwd.normalized().angle_to(to.normalized())) <= Balance.GUARD_FOV * 0.5


## Куда страж реально смотрит: glTF-модель развёрнута в -Z, примитивный риг — в +Z.
func _gaze_dir() -> Vector3:
	var fwd: Vector3 = rig.global_transform.basis.z
	if use_model:
		fwd = -fwd
	fwd.y = 0.0
	return fwd


func _path_clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _has_los(t: Node3D) -> bool:
	return _path_clear(global_position + Vector3(0, 1.5, 0), t.global_position + Vector3(0, 1.1, 0))


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


## Поиск: идёт к последней замеченной точке и осматривается.
func _search(dt: float) -> void:
	search_t -= dt
	if not has_last:
		state = "return"
		state_t = 0.0
		return
	var to: Vector3 = last_seen - global_position
	to.y = 0.0
	if to.length() > 1.2:
		velocity.x = to.normalized().x * speed
		velocity.z = to.normalized().z * speed
		_face(to)
		scan_t = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		scan_t += dt
		rig.rotation.y += dt * 1.4


func _return_to_post() -> void:
	var to: Vector3 = home - global_position
	to.y = 0.0
	if to.length() < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		state = "patrol"
		state_t = 0.0
		return
	velocity.x = to.normalized().x * speed
	velocity.z = to.normalized().z * speed
	_face(to)


func _face(dir: Vector3) -> void:
	if dir.length() < 0.05:
		return
	# у примитивного рига лицо в +Z, у glTF-модели — в -Z
	var want := atan2(dir.x, dir.z)
	if use_model:
		want = atan2(-dir.x, -dir.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, want, 0.2)


func _attack() -> void:
	state = "attack"
	state_t = 0.0
	attack_cd = 1.3
	Sfx.play_at("sfx_swing", global_position + Vector3(0, 1.1, 0), -10.0, 0.9)
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
	alertness = Balance.GUARD_ALERT_MAX
	lose_t = 0.0
	has_last = true
	last_seen = from if from != Vector3.ZERO else global_position
	_start_chase()
	Sfx.play_at("sfx_hit", global_position + Vector3(0, 1.1, 0), -8.0)
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
	velocity.x = 0.0
	velocity.z = 0.0
	add_to_group("dead")
	GameState.guards_killed += 1
	GameState.add_xp(xp_reward)
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
	if use_model:
		_animate_model(dt)
		return
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
		# патруль топает медленно и тихо, погоня — часто и громко
		var hunting: bool = state in ["chase", "attack"]
		var st: float = get_meta("step_t")
		st += dt
		if st > (0.32 if hunting else 0.55):
			st = 0.0
			Sfx.play_at_varied("sfx_step", global_position, -22.0 if hunting else -28.0)
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


func _build_anim_tree() -> void:
	if anim == null or anim_tree != null:
		return
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimTree"
	var p := anim.get_parent()
	if p:
		p.add_child(anim_tree)
	else:
		add_child(anim_tree)
	anim_tree.tree_root = AnimationNodeStateMachine.new()
	var sm: AnimationNodeStateMachine = anim_tree.tree_root
	# у стражи и босса одинаковый набор клипов (Mixamo-риг), ключи общие
	var idle := ModelUtil.pick_anim(anim, ["Idle"])
	var walk := ModelUtil.pick_anim(anim, ["Walk", "Running"])
	var attack := ModelUtil.pick_anim(anim, ["Attack", "Headbutt", "Punch"])
	var die := ModelUtil.pick_anim(anim, ["Die", "Death"])
	if idle != "":
		sm.add_node("Idle", AnimationNodeAnimation.new()); sm.get_node("Idle").animation = idle
	if walk != "":
		sm.add_node("Move", AnimationNodeAnimation.new()); sm.get_node("Move").animation = walk
	if attack != "":
		# у AnimationNodeAnimation нет speed_scale: взмах на 1.3x задаём длиной
		# custom timeline, чтобы контакт клипа совпал с моментом урона (0.35 с)
		var an := AnimationNodeAnimation.new()
		an.animation = attack
		an.use_custom_timeline = true
		an.stretch_time_scale = true
		var aa: Animation = anim.get_animation(attack)
		var alen: float = aa.length if aa != null else 0.72
		an.timeline_length = alen / 1.3
		sm.add_node("Attack", an)
	if die != "":
		sm.add_node("Death", AnimationNodeAnimation.new()); sm.get_node("Death").animation = die
	sm.add_transition("Idle", "Move", _xfade(0.15))
	sm.add_transition("Move", "Idle", _xfade(0.15))
	sm.add_transition("Idle", "Attack", _xfade(0.08))
	sm.add_transition("Move", "Attack", _xfade(0.08))
	sm.add_transition("Attack", "Idle", _xfade(0.12))
	sm.add_transition("Attack", "Move", _xfade(0.12))
	sm.add_transition("Idle", "Death", _xfade(0.12))
	sm.add_transition("Move", "Death", _xfade(0.12))
	anim_tree.active = true
	anim_tree.anim_player = anim.get_path()
	anim_state = anim_tree.get("parameters/playback")


func _xfade(fade: float) -> AnimationNodeStateMachineTransition:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = fade
	return tr


## Анимации модели: Idle/Walk/Attack/Death — набор клипов у стражи и босса общий.
func _animate_model(dt: float) -> void:
	if anim == null:
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	if dead:
		if anim_state != null and anim_state.has_method("travel"):
			anim_state.travel("Death")
		else:
			ModelUtil.play_key(anim, ["Die", "Death"], false)
		return
	if state == "attack":
		# клип-взмах 0.72 с: контакт на 0.50 с при 1.3x ≈ 0.38 с — рядом с уроном (0.35 с)
		if anim_state != null and anim_state.has_method("travel"):
			anim_state.travel("Attack")
		else:
			ModelUtil.play_key(anim, ["Attack"], false, 1.3)
		return
	if anim_state != null and anim_state.has_method("travel"):
		if sp > 0.25:
			anim_state.travel("Move")
			if anim_tree != null:
				var sc := clampf(sp / 2.6, 0.8, 1.8)
				anim_tree.set("parameters/Move/speed_scale", sc)
		else:
			anim_state.travel("Idle")
	else:
		if sp > 0.25:
			ModelUtil.play_key(anim, ["Walk", "Running"], true, clampf(sp / 2.6, 0.8, 1.8))
		else:
			ModelUtil.play_key(anim, ["Idle"], true)
	if flash_mat != null:
		flash_mat.albedo_color.a = clampf(flash / 0.18, 0.0, 1.0) * 0.5


func _bark() -> void:
	if bark_cd > 0.0 or barks.is_empty():
		return
	bark_cd = 9.0
	var text: String = barks[randi() % barks.size()]
	var l := Label3D.new()
	l.text = text
	l.font_size = 32
	l.pixel_size = 0.0065
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.95, 0.86, 0.7, 0.0)
	l.outline_size = 8
	l.position = Vector3(0, 1.9 if not is_boss else 2.9, 0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d: float = cam.global_position.distance_to(global_position)
		l.scale = Vector3.ONE * clampf(d / 10.0, 0.3, 1.0)
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
	cap.height = 1.2 if not is_boss else 2.0
	cs.shape = cap
	cs.position = Vector3(0, 0.75 if not is_boss else 1.2, 0)
	hurt.add_child(cs)
	add_child(hurt)

