extends Node3D
class_name DungeonAudio
## Звук подземелья (этап 10): тон помещения на весь уровень, зона реверба
## на каждую комнату и случайные далёкие звуки в ней.
##
## В m1.txt комнаты не размечены, поэтому они выводятся из сетки: ядро
## комнаты — клетки не ближе ROOM_CORE_DIST к стене (в коридоре шириной
## в две клетки таких нет), к ядру добавляется пристенный ободок.
## Коридоры остаются без зоны — там звук сухой.

const ROOM_CORE_DIST := 2
## Ядро меньше этого — расширение коридора, а не комната.
const MIN_CORE_CELLS := 4
## С этой площади (в клетках 2×2 м) комната «большая»: Reverb_Large.
const LARGE_ROOM_CELLS := 60
## Площадь, на которой количество реверба доходит до максимума 0.8.
const HUGE_ROOM_CELLS := 300
const ROOM_TONE := "res://audio/ambience/room_tone.wav"
const ROOM_TONE_DB := -18.0

## {cells: Array[Vector2i], large: bool, area: Area3D, oneshots: RoomOneShots}
var rooms: Array[Dictionary] = []
var room_tone: AudioStreamPlayer


func build(d: Dungeon) -> void:
	_find_rooms(d)
	for i in rooms.size():
		_add_reverb_zone(rooms[i], i)
		_add_oneshots(d, rooms[i], i)
	_add_room_tone()
	var large := rooms.filter(func(r): return r["large"]).size()
	print("AUDIO rooms=", rooms.size(), " large=", large)


func _find_rooms(d: Dungeon) -> void:
	var owner_of := {}
	for y in d.map_h:
		for x in d.map_w:
			var c := Vector2i(x, y)
			if owner_of.has(c) or not _is_core(d, c):
				continue
			var core: Array[Vector2i] = [c]
			owner_of[c] = -1
			var head := 0
			while head < core.size():
				var cur: Vector2i = core[head]
				head += 1
				for dir in Dungeon.DIRS:
					var n: Vector2i = cur + dir
					if not owner_of.has(n) and _is_core(d, n):
						owner_of[n] = -1
						core.append(n)
			if core.size() < MIN_CORE_CELLS:
				continue
			for cc in core:
				owner_of[cc] = rooms.size()
			rooms.append({"cells": core})
	# Пристенный ободок: открытые клетки у стены, касающиеся ядра хотя бы углом.
	for y in d.map_h:
		for x in d.map_w:
			var c := Vector2i(x, y)
			if d.is_wall(x, y) or owner_of.has(c):
				continue
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := Vector2i(x + dx, y + dy)
					if owner_of.has(n) and int(owner_of[n]) >= 0:
						var idx: int = owner_of[n]
						rooms[idx]["cells"].append(c)
						owner_of[c] = -2 - idx
						break
				if owner_of.has(c):
					break
	for room in rooms:
		room["large"] = (room["cells"] as Array).size() >= LARGE_ROOM_CELLS


func _is_core(d: Dungeon, c: Vector2i) -> bool:
	return not d.is_wall(c.x, c.y) and int(d.dist[c.y][c.x]) >= ROOM_CORE_DIST


## Одна Area3D на комнату: коробка на каждый горизонтальный отрезок клеток,
## чтобы зона повторяла Г-образные залы и обходила опоры.
func _add_reverb_zone(room: Dictionary, index: int) -> void:
	var area := Area3D.new()
	area.name = "ReverbZone%d" % index
	area.collision_layer = Sfx.AUDIO_ZONE_MASK
	area.collision_mask = 0
	area.monitoring = false
	var size: int = (room["cells"] as Array).size()
	area.reverb_bus_enabled = true
	area.reverb_bus_name = &"Reverb_Large" if room["large"] else &"Reverb_Small"
	area.reverb_bus_amount = lerpf(0.5, 0.8,
		clampf(float(size - MIN_CORE_CELLS) / float(HUGE_ROOM_CELLS), 0.0, 1.0))
	var rows := {}
	for c in room["cells"]:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == prev + 1:
				prev = xs[i]
				continue
			_add_run_box(area, start, prev, y)
			if i < xs.size():
				start = xs[i]
				prev = xs[i]
	add_child(area)
	room["area"] = area


func _add_run_box(area: Area3D, x0: int, x1: int, y: int) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(x1 - x0 + 1) * Dungeon.T, Dungeon.WALL_H, Dungeon.T)
	shape.shape = box
	shape.position = Vector3((float(x0 + x1) * 0.5 + 0.5) * Dungeon.T,
		Dungeon.WALL_H * 0.5, (float(y) + 0.5) * Dungeon.T)
	area.add_child(shape)


func _add_oneshots(d: Dungeon, room: Dictionary, index: int) -> void:
	var shots := RoomOneShots.new()
	shots.name = "OneShots%d" % index
	shots.cell_size = Dungeon.T
	shots.height_range = Vector2(0.4, Dungeon.WALL_H - 0.6)
	for c in room["cells"]:
		shots.cells.append(d.cell_center(c.x, c.y))
	add_child(shots)
	room["oneshots"] = shots


func _add_room_tone() -> void:
	if not ResourceLoader.exists(ROOM_TONE):
		push_warning("нет тона помещения " + ROOM_TONE)
		return
	room_tone = AudioStreamPlayer.new()
	room_tone.name = "RoomTone"
	room_tone.stream = load(ROOM_TONE)
	room_tone.bus = "Ambience"
	room_tone.volume_db = ROOM_TONE_DB
	room_tone.autoplay = true
	add_child(room_tone)


## Комната, в которой лежит точка (по клеткам), или пустой словарь.
func room_at(pos: Vector3) -> Dictionary:
	var c := Vector2i(floori(pos.x / Dungeon.T), floori(pos.z / Dungeon.T))
	for room in rooms:
		if (room["cells"] as Array).has(c):
			return room
	return {}
