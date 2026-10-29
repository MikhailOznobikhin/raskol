extends RefCounted
## Загрузка glTF/GLB моделей, подгонка по росту и поиск анимаций.
## Внешние модели лежат в assets/*.glb и грузятся через GLTFDocument.

class_name ModelUtil

## «Натуральная» высота модели при scale=1, измеренная рендером.
## AABB скиннованных мешей в Godot врёт (масштаб костей), поэтому
## для встроенных ассетов берём проверенные числа, а для прочих — AABB.
const NATIVE_HEIGHT := {
	"res://assets/player.glb": 1.83,
	"res://assets/hero_mixamo.glb": 2.047,
	"res://assets/guard_mixamo.glb": 2.058,
	"res://assets/boss_mixamo.glb": 2.152,
	"res://assets/guard.glb": 4.99,
	"res://assets/guard_zombie.glb": 4.05,
	"res://assets/monster.glb": 2.84,
}


static func instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_warning("ModelUtil: не удалось прочитать " + path)
		return null
	var scene: Node3D = doc.generate_scene(state)
	return scene


## Ставит модель в parent, масштабирует до target_height и опускает ступни на y=0.
## face_yaw_deg: glTF-модели обычно смотрят в +Z, а герой в Godot — в -Z,
## поэтому по умолчанию разворачиваем на 180°.
static func spawn(parent: Node3D, path: String, target_height: float, face_yaw_deg: float = 180.0) -> Node3D:
	var model := instantiate(path)
	if model == null:
		return null
	model.rotate_y(deg_to_rad(face_yaw_deg))
	parent.add_child(model)
	var native: float = float(NATIVE_HEIGHT.get(path, 0.0))
	if native > 0.001:
		var k: float = target_height / native
		model.scale = Vector3(k, k, k)
		_center_xz(model)
	else:
		fit_to_height(model, target_height)
	_setup_meshes(model)
	return model


static func _center_xz(model: Node3D) -> void:
	var box := aabb_local_unskinned(model)
	if box.size.x < 0.0001 and box.size.z < 0.0001:
		return
	var c := box.get_center()
	model.position.x -= c.x
	model.position.z -= c.z


## AABB только по обычным мешам: у скиннованных get_aabb() в Godot
## раздут масштабом костей, и центрировать по нему нельзя.
static func aabb_local_unskinned(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in meshes(root):
		if mi.skin != null:
			continue
		var b: AABB = inv * (mi.global_transform * mi.get_aabb())
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


## Визуальный слой персонажей. Лужи — проецирующие декали, и они не должны
## красить сапоги гнома: меши героя и врагов живут на слое 2, а у декалей
## (лужи, копоть, мох) cull_mask = 1 — только слой 1. Камера и источники
## света по умолчанию видят все слои, поэтому на вид персонажей это не влияет.
const CHARACTER_LAYER := 2


## Все меши поддерева — на один визуальный слой (VisualInstance3D.layers).
static func set_visual_layer(root: Node, layer: int) -> void:
	if layer < 1 or layer > 20:
		return
	var mask := 1 << (layer - 1)
	for mi in meshes(root):
		mi.layers = mask


## Скрывает примитивы рига, когда сверху надет glTF-меш.
static func hide_meshes(root: Node) -> void:
	for mi in meshes(root):
		mi.visible = false


static func show_meshes(root: Node) -> void:
	for mi in meshes(root):
		mi.visible = true


static func fit_to_height(model: Node3D, target_height: float) -> void:
	var box := aabb_local(model)
	if box.size.y < 0.0001:
		return
	var k: float = target_height / box.size.y
	model.scale = Vector3(k, k, k)
	box = aabb_local(model)
	model.position.y -= box.position.y
	var c := box.get_center()
	model.position.x -= c.x
	model.position.z -= c.z


## AABB всех мешей в системе координат самого root (учитывает скейл root).
static func aabb_local(root: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in meshes(root):
		var b: AABB = inv * (mi.global_transform * mi.get_aabb())
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


static func meshes(root: Node) -> Array:
	var res: Array = []
	if root is MeshInstance3D:
		res.append(root)
	for c in root.get_children():
		res.append_array(meshes(c))
	return res


static func _setup_meshes(root: Node) -> void:
	for mi in meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var r := find_anim_player(c)
		if r != null:
			return r
	return null


static func find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for c in root.get_children():
		var r := find_skeleton(c)
		if r != null:
			return r
	return null


## Ищет анимацию по списку ключей: сначала точное совпадение по суффиксу
## после «|», затем вхождение подстроки. Возвращает имя или "".
static func pick_anim(ap: AnimationPlayer, keys: Array) -> String:
	if ap == null:
		return ""
	var list := ap.get_animation_list()
	for key in keys:
		var k := String(key).to_lower()
		for n in list:
			var low := String(n).to_lower()
			if low == k or low.ends_with("|" + k):
				return String(n)
	for key in keys:
		var k2 := String(key).to_lower()
		for n in list:
			if String(n).to_lower().contains(k2):
				return String(n)
	return ""


## Проигрывает анимацию по ключу и настраивает зацикливание.
## fade — время перехода: удары и рывок должны «щёлкать» быстрее, чем шаг.
static func play_key(ap: AnimationPlayer, keys: Array, loop: bool, speed: float = 1.0, fade: float = 0.15) -> String:
	var name := pick_anim(ap, keys)
	if name == "":
		return ""
	var a: Animation = ap.get_animation(name)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	ap.speed_scale = speed
	var cur := ap.current_animation
	if cur != name:
		ap.play(name, fade)
	elif not ap.is_playing():
		ap.play(name, 0.0)
	return name


## Точка крепления к кости (кисть, спина и т.п.).
## Возвращает узел с единичным масштабом: кости glTF часто приходят с
## масштабом 100 (сантиметры), и без компенсации молот становится 100-метровым.
static func bone_attach(root: Node, bone_names: Array) -> Node3D:
	var sk := find_skeleton(root)
	if sk == null:
		return null
	var bone := ""
	for want in bone_names:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i) == String(want):
				bone = String(want)
				break
		if bone != "":
			break
	if bone == "":
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	sk.add_child(att)
	var idx := sk.find_bone(bone)
	var s: Vector3 = sk.get_bone_global_rest(idx).basis.get_scale()
	if s.x < 0.0001 or s.y < 0.0001 or s.z < 0.0001:
		s = Vector3.ONE
	var comp := Node3D.new()
	comp.name = "AttachPoint"
	comp.scale = Vector3(1.0 / s.x, 1.0 / s.y, 1.0 / s.z)
	att.add_child(comp)
	return comp


## Общий «вспыхивающий» оверлей для всех поверхностей модели (реакция на удар).
static func make_flash_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.3, 0.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func apply_overlay(root: Node, mat: Material) -> void:
	for mi in meshes(root):
		mi.material_overlay = mat
