@tool
extends EditorScript
## Этап 8, шаг 4: проверка посадки реквизита (группа "prop") в открытой сцене.
##
## Редактор: открыть сцену, в редакторе скриптов File → Run (Ctrl+Shift+X).
## Печатает предметы, у которых низ AABB выше пола больше чем на 2 см или
## ниже больше чем на 5 см. SNAP = true — ещё и посадить их (Ctrl+S сохранит).
## Логика — PropGrounding (debug/prop_grounding.gd). M1 собирается кодом в
## игре, поэтому для него та же проверка идёт в --test3d (строка TEST props).

const SNAP := false


func _run() -> void:
	var root := get_scene() as Node3D
	if root == null:
		print("snap_props_to_floor: открой 3D-сцену")
		return
	var r := PropGrounding.check(root, root.get_world_3d().direct_space_state, SNAP)
	for line in r["lines"]:
		print(line)
	print("snap_props_to_floor: checked=%d floating=%d sunken=%d no_floor=%d snapped=%d" % [
		r["checked"], r["floating"], r["sunken"], r["no_floor"], r["snapped"]])
