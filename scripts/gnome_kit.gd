extends RefCounted
## «Гномья» экипировка поверх человеческой модели: остроконечная шляпа.
## Отдельный файл, чтобы вид героя можно было показать tools/gnome_sheet.gd
## без запуска игры.
##
## Готовой CC0-модели гнома с нужным ригом нет, поэтому силуэт собираем из
## примитивов и вешаем на кость Head — анимации при этом не страдают.
## Бороду и нос не добавляем: у Adventurer из Quaternius они уже запечены
## в текстуре лица, а примитивы поверх них только портят морду.

class_name GnomeKit

const HAT := Color(0.30, 0.17, 0.15)
const HAT_BAND := Color(0.16, 0.13, 0.12)


static func decorate(model: Node3D) -> void:
	var att := ModelUtil.bone_attach(model, ["Head", "mixamorig:Head", "head"])
	if att == null:
		return
	# Компенсируем РЕАЛЬНЫЙ масштаб кости, а не rest-оценку из bone_attach:
	# у glTF-скелета кость Head приходит с масштабом ~77 (100 см/м × масштаб
	# модели), и get_bone_global_rest() её недооценивает.
	var w: Vector3 = att.global_transform.basis.get_scale()
	if w.x > 0.0001 and w.y > 0.0001 and w.z > 0.0001:
		att.scale = Vector3(att.scale.x / w.x, att.scale.y / w.y, att.scale.z / w.z)
	# локальная система кости Head: начало примерно у подбородка, +Y вверх, +Z вперёд

	# тулья: конус, основание стоит на полях и накрывает причёску,
	# кончик отклонён назад
	_part(att, _cyl(0.132, 0.30, 12, 0.008), Vector3(0, 0.262, -0.004), Vector3(-6, 0, 0), HAT)
	# поля шляпы
	_part(att, _cyl(0.158, 0.020, 16), Vector3(0, 0.112, 0), Vector3.ZERO, HAT)
	# кожаный ремешок у основания тульи
	_part(att, _cyl(0.139, 0.034, 16), Vector3(0, 0.132, 0), Vector3.ZERO, HAT_BAND)


static func _cyl(r: float, h: float, seg: int, top_r: float = -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if top_r < 0.0 else top_r
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	m.metallic = 0.0
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi
