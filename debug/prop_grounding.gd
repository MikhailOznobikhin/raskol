class_name PropGrounding
extends RefCounted
## Этап 8, шаг 4: стоит ли реквизит на полу.
##
## Для каждого узла группы "prop" — луч вниз из центра его AABB (по мешам).
## Низ AABB выше точки попадания больше чем на 2 см — висит, ниже больше
## чем на 5 см — утонул. С snap = true узел сдвигается по Y так, чтобы низ
## AABB лёг ровно на точку попадания.
## Луч бьёт по слою 1 (мир и крупный реквизит): мелочь на столе садится на
## коллизию стола. Собственная коллизия предмета исключается.
##
## Зовут: tools/snap_props_to_floor.gd (редактор, открытая сцена) и
## --test3d в main3d.gd (процедурный M1 собирается только в игре).

const FLOAT_TOL := 0.02
const SINK_TOL := 0.05
const RAY_DOWN := 3.0


static func check(root: Node, space: PhysicsDirectSpaceState3D, snap: bool) -> Dictionary:
	var out := {"checked": 0, "floating": 0, "sunken": 0, "no_floor": 0, "snapped": 0,
		"lines": [] as Array[String]}
	for n in root.get_tree().get_nodes_in_group("prop"):
		var p := n as Node3D
		if p == null or not (p == root or root.is_ancestor_of(p)):
			continue
		var box := world_aabb(p)
		if box.size == Vector3.ZERO:
			continue
		out["checked"] += 1
		var center := box.get_center()
		var q := PhysicsRayQueryParameters3D.create(center,
			center - Vector3(0, box.size.y * 0.5 + RAY_DOWN, 0), 1)
		var ex: Array[RID] = []
		for body in p.find_children("*", "CollisionObject3D", true, false):
			ex.append((body as CollisionObject3D).get_rid())
		if p is CollisionObject3D:
			ex.append((p as CollisionObject3D).get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			out["no_floor"] += 1
			out["lines"].append("PROP no_floor %s at %s" % [p.get_path(), p.global_position])
			continue
		var gap: float = box.position.y - (hit["position"] as Vector3).y
		if gap > FLOAT_TOL:
			out["floating"] += 1
			out["lines"].append("PROP floating %+.3f m %s at %s" % [gap, p.name, p.global_position])
		elif gap < -SINK_TOL:
			out["sunken"] += 1
			out["lines"].append("PROP sunken %+.3f m %s at %s" % [gap, p.name, p.global_position])
		else:
			continue
		if snap:
			p.global_position.y -= gap
			out["snapped"] += 1
	return out


## AABB всех видимых мешей узла в мировых координатах.
static func world_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var b: AABB = g.global_transform * g.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
