extends Dungeon
## Уровень 2 «Разлом Собора»: ротонда, неф с алтарём, затопленная крипта,
## боковой придел, усопальня и петля обхода для стражи.
##
## Наследуется от Dungeon специально, чтобы не трогать m1: базовый класс даёт
## материалы, кладку, своды, колонны и реквизит, этот — легенду карты, арочные
## порталы, ниши со статуями, воду и подиумы с пандусами.

class_name Level2Builder

const MAP_PATH := "res://assets/level/m2.txt"
## Высота подиума: 0,9 м — на него ведёт пандус, под него не пройти.
const DAIS_H := 0.9
## Пандус в три клетки (6 м) даёт подъём ~8,6°: CharacterBody3D идёт по нему
## без шага-переступания, который hero3d.gd не умеет.
const RAMP_RUN := 3

## cells[y][x] — символ легенды; grid у базового класса знает только «стена».
var cells: Array = []
var spawn_cell := Vector2i(-1, -1)
var exit_cell := Vector2i(-1, -1)
var boss_cell := Vector2i(-1, -1)
var guard_cells: Array[Vector2i] = []
var arch_cells: Array[Vector2i] = []
var niche_cells: Array[Vector2i] = []
var water_cells: Array[Vector2i] = []
var dais_cells: Array[Vector2i] = []
var sign_cells: Array[Vector2i] = []
var sconce_count := 0
## Клетка пробитого свода — самая дальняя от стен; нужна полигону для кадров.
var breach_cell := Vector2i(-1, -1)
## Счётчики для самопроверки: «зал без пандуса» видно не в кадре, а в логе.
var dais_count := 0
var ramp_count := 0
var arch_count := 0
var niche_count := 0
var mat_water: StandardMaterial3D
var water_root: Node3D
## Общий MultiMesh на все арки, ниши и порталы: блоки одинаковые, их ~400.
var arch_parts: Array = []


func build() -> void:
	_materials()
	_load_map()
	_shapes()
	_build_floor()
	_build_walls()
	_build_cladding()
	_build_ceiling()
	_build_corbels()
	_build_ribs()
	_build_beams()
	_build_piers()
	_build_collision()
	_build_daises()
	_build_water()
	_build_signs()
	_build_arches()
	_build_niches()
	_flush_arches()
	_dress_rooms()
	_build_sconces()
	_build_breach()
	_build_environment()


# ---------------------------------------------------------------------------
# легенда карты
# ---------------------------------------------------------------------------

func _load_map() -> void:
	if not FileAccess.file_exists(MAP_PATH):
		push_error("нет карты уровня 2: " + MAP_PATH)
		return
	for l in FileAccess.get_file_as_string(MAP_PATH).split("\n"):
		if l.strip_edges().length() > 0:
			lines.append(l)
	map_h = lines.size()
	map_w = lines[0].length()
	for y in map_h:
		var row: Array = []
		var crow: Array = []
		for x in map_w:
			var ch: String = lines[y].substr(x, 1)
			crow.append(ch)
			row.append(ch == "#")
		grid.append(row)
		cells.append(crow)
	_collect_legend()


func _collect_legend() -> void:
	for y in map_h:
		for x in map_w:
			var ch: String = cells[y][x]
			var c := Vector2i(x, y)
			match ch:
				"P":
					spawn_cell = c
				"X":
					exit_cell = c
				"O":
					boss_cell = c
				"G":
					guard_cells.append(c)
				"a":
					arch_cells.append(c)
				"n":
					niche_cells.append(c)
				"w":
					water_cells.append(c)
				"d":
					dais_cells.append(c)
				"B", "s":
					sign_cells.append(c)
				_:
					pass
	if spawn_cell.x < 0 or exit_cell.x < 0:
		push_error("на карте нет P или X")


func cell_char(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return "#"
	return cells[y][x]


func is_floor(x: int, y: int) -> bool:
	return cell_char(x, y) != "#"


func is_plain(x: int, y: int) -> bool:
	## Чистый пол: годится под реквизит и под пандус (вода и ниша — нет).
	var ch := cell_char(x, y)
	return ch == "." or ch == "B" or ch == "s" or ch == "G" or ch == "P" \
		or ch == "X" or ch == "O" or ch == "a"


func world_of(x: int, y: int) -> Vector3:
	return Vector3((x + 0.5) * T, 0.0, (y + 0.5) * T)


## Высота пола под ногами: на подиуме пол поднят на пандус.
func surface_y(x: int, y: int) -> float:
	return DAIS_H if cell_char(x, y) == "d" else 0.0


func pos_of(x: int, y: int) -> Vector3:
	return world_of(x, y) + Vector3(0.0, surface_y(x, y), 0.0)


static func _hash(x: int, y: int, salt: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return absi(h)


## Нормаль ближайшей стены из клетки (-1..1); Vector2i.ZERO, если стен нет.
func wall_face(x: int, y: int) -> Vector2i:
	var out := Vector2i.ZERO
	for d in DIRS:
		if not is_floor(x + d.x, y + d.y):
			out = -d
	return out


# ---------------------------------------------------------------------------
# подиумы с пандусами: намёк на вертикаль без многоуровневого лабиринта
# ---------------------------------------------------------------------------

func _build_daises() -> void:
	var seen := {}
	for c0 in dais_cells:
		var seed_cell: Vector2i = c0
		if seen.has(seed_cell):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [seed_cell]
		seen[seed_cell] = true
		while not stack.is_empty():
			var k: Vector2i = stack.pop_back()
			comp.append(k)
			for d in DIRS:
				var n: Vector2i = k + d
				if not seen.has(n) and cell_char(n.x, n.y) == "d":
					seen[n] = true
					stack.append(n)
		_build_dais(comp)


func _build_dais(comp: Array[Vector2i]) -> void:
	var minx := comp[0].x
	var maxx := comp[0].x
	var miny := comp[0].y
	var maxy := comp[0].y
	for c in comp:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		miny = mini(miny, c.y)
		maxy = maxi(maxy, c.y)
	var w := float(maxx - minx + 1) * T
	var d := float(maxy - miny + 1) * T
	dais_count += 1
	var ctr := Vector3((minx + maxx + 1) * 0.5 * T, 0.0, (miny + maxy + 1) * 0.5 * T)
	# масса чуть уже плиты: получается прочерченный профиль уступа, а не куб
	_box(Vector3(w - 0.2, DAIS_H - 0.16, d - 0.2), ctr + Vector3(0, (DAIS_H - 0.16) * 0.5, 0), mat_wall)
	_box(Vector3(w, 0.16, d), ctr + Vector3(0, DAIS_H - 0.08, 0), mat_cap)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, DAIS_H, d)
	col.shape = shape
	col.position = ctr + Vector3(0, DAIS_H * 0.5, 0)
	body.add_child(col)
	add_child(body)
	_add_dais_ramp(minx, miny, maxx, maxy)


## Пандус ставим с одной стороны — с самой длинной полосой чистого пола,
## иначе вокруг подиума вырастает четыре съезжающихся клина.
func _add_dais_ramp(minx: int, miny: int, maxx: int, maxy: int) -> void:
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var best_lanes: Array[Vector2i] = []
	var best_dir := Vector2i.ZERO
	for dir in dirs:
		var lanes: Array[Vector2i] = []
		for c in _edge_lanes(minx, miny, maxx, maxy, dir):
			if _ramp_clear(c, dir):
				lanes.append(c)
		var run := _longest_run(lanes, dir)
		if run.size() > best_lanes.size():
			best_lanes = run
			best_dir = dir
	if best_lanes.is_empty():
		push_warning("подиум без пандуса: некуда положить съезд")
		return
	var wide := float(best_lanes.size()) * T
	# начало съезда — середина полосы, иначе широкий пандус съезжает вбок
	var mid := Vector2.ZERO
	for c in best_lanes:
		mid += Vector2(c.x, c.y)
	mid /= float(best_lanes.size())
	var origin := Vector3((mid.x + 0.5) * T, 0.0, (mid.y + 0.5) * T) \
		+ Vector3(best_dir.x, 0.0, best_dir.y) * (T * 0.5)
	var node := Node3D.new()
	node.position = origin
	node.rotation.y = atan2(float(best_dir.x), float(best_dir.y))
	add_child(node)
	ramp_count += 1
	var mi := MeshInstance3D.new()
	var length := float(RAMP_RUN) * T
	mi.mesh = _wedge(wide, length, DAIS_H)
	# на клин пандуса нужен двусторонний материал, а шейдерный камень
	# односторонний: для одной детали проще собрать обычный материал
	var wm: StandardMaterial3D = _make_mat(
		"stone_wall", Color(0.88, 0.87, 0.9), 0.88, 0.0, 0.4)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = wm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	# форма живёт в StaticBody3D: у голого Node3D коллизии нет, герой провалится
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	node.add_child(body)
	var cs := CollisionShape3D.new()
	# create_trimesh_shape уже возвращает готовую форму, а не меш
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	# ступени поверх съезда: читается как лестница, а не как горка
	var steps := RAMP_RUN * 2
	for i in steps:
		var z := (float(i) + 0.5) / float(steps) * length
		var y: float = DAIS_H * (1.0 - z / length)
		_box(Vector3(wide - 0.1, 0.08, 0.2), Vector3(0, y + 0.02, z), mat_cap, node)
	# парапет по бокам пандуса
	for sx in [-1, 1]:
		_box(Vector3(0.22, 0.5, length),
			Vector3(sx * (wide * 0.5 + 0.1), DAIS_H * 0.34, length * 0.5), mat_cap, node)


func _edge_lanes(minx: int, miny: int, maxx: int, maxy: int, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dir.x != 0:
		var x := minx if dir.x < 0 else maxx
		for y in range(miny, maxy + 1):
			out.append(Vector2i(x, y))
	else:
		var y := miny if dir.y < 0 else maxy
		for x in range(minx, maxx + 1):
			out.append(Vector2i(x, y))
	return out


func _ramp_clear(edge: Vector2i, dir: Vector2i) -> bool:
	for step in range(1, RAMP_RUN + 1):
		var c := edge + dir * step
		if not is_plain(c.x, c.y):
			return false
	return true


func _longest_run(lanes: Array[Vector2i], dir: Vector2i) -> Array[Vector2i]:
	if lanes.is_empty():
		return lanes
	var key := func(c: Vector2i) -> int:
		return c.x if dir.x != 0 else c.y
	lanes.sort_custom(func(a, b) -> bool: return key.call(a) < key.call(b))
	var best: Array[Vector2i] = [lanes[0]]
	var cur: Array[Vector2i] = [lanes[0]]
	for i in range(1, lanes.size()):
		if key.call(lanes[i]) == key.call(lanes[i - 1]) + 1:
			cur.append(lanes[i])
		else:
			cur = [lanes[i]]
		if cur.size() > best.size():
			best = cur.duplicate()
	# ширину держим в пределах трёх клеток: шире — уже не пандус, а эстрада
	if best.size() > RAMP_RUN:
		var from := (best.size() - RAMP_RUN) / 2
		best = best.slice(from, from + RAMP_RUN)
	return best


## Клин пандуса: верхний торец на уровне подиума (z=0), низкий — на полу (z=L).
func _wedge(wide: float, length: float, height: float) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var hw := wide * 0.5
	var slope := Vector3(0.0, length, height).normalized()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# нормаль каждой грани задаём явно: у наклонной плоскости она не совпадает
	# с векторным произведением случайной обхода и без этого грань темнеет
	_im_face(im, [Vector3(-hw, height, 0), Vector3(hw, height, 0),
		Vector3(hw, 0.0, length), Vector3(-hw, 0.0, length)], slope)
	_im_face(im, [Vector3(-hw, 0.0, length), Vector3(hw, 0.0, length),
		Vector3(hw, 0.0, 0), Vector3(-hw, 0.0, 0)], Vector3.DOWN)
	_im_face(im, [Vector3(hw, 0.0, 0), Vector3(-hw, 0.0, 0),
		Vector3(-hw, height, 0), Vector3(hw, height, 0)], Vector3.FORWARD)
	_im_face(im, [Vector3(-hw, 0.0, length), Vector3(-hw, 0.0, 0),
		Vector3(-hw, height, 0)], Vector3.LEFT)
	_im_face(im, [Vector3(hw, 0.0, 0), Vector3(hw, 0.0, length),
		Vector3(hw, height, 0)], Vector3.RIGHT)
	im.surface_end()
	return im


## Веер из 3+ точек; многоугольники у клина выпуклые, разбиения «от первого» хватает.
func _im_face(im: ImmediateMesh, pts: Array, n: Vector3) -> void:
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			im.surface_set_normal(n)
			im.surface_set_uv(Vector2(p.x + 0.5, p.z + 0.5))
			im.surface_add_vertex(p)


# ---------------------------------------------------------------------------
# вода затопленного зала
# ---------------------------------------------------------------------------

func _build_water() -> void:
	if water_cells.is_empty():
		return
	mat_water = StandardMaterial3D.new()
	var a := _tex("stone_floor_albedo")
	var n := _tex("stone_floor_normal")
	if a:
		mat_water.albedo_texture = a
	if n:
		mat_water.normal_enabled = true
		mat_water.normal_texture = n
	mat_water.albedo_color = Color(0.13, 0.3, 0.34, 0.9)
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water.roughness = 0.03
	mat_water.metallic = 0.45
	mat_water.metallic_specular = 0.9
	# лёгкое свечение: без него вода в тёмном зале — просто чёрная дыра
	mat_water.emission_enabled = true
	mat_water.emission = Color(0.05, 0.14, 0.17)
	mat_water.emission_energy_multiplier = 1.4
	mat_water.uv1_scale = Vector3(0.28, 0.28, 0.28)
	water_root = Node3D.new()
	add_child(water_root)
	var curbs: Array = []
	var y := 0
	while y < map_h:
		var x := 0
		while x < map_w:
			if cell_char(x, y) != "w":
				x += 1
				continue
			var start := x
			while x < map_w and cell_char(x, y) == "w":
				x += 1
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(float(x - start) * T + 0.06, T + 0.06)
			q.mesh = pm
			q.material_override = mat_water
			q.position = Vector3((start + x) * 0.5 * T, 0.18, (y + 0.5) * T)
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			water_root.add_child(q)
			for cx in range(start, x):
				_water_curbs(cx, y, curbs)
		y += 1
	_ice_multimesh(curbs)


func _water_curbs(x: int, y: int, curbs: Array) -> void:
	for d in DIRS:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if is_floor(nx, ny) and cell_char(nx, ny) != "w":
			var size := Vector3(T + 0.06, 0.2, 0.3) if d.x == 0 else Vector3(0.3, 0.2, T + 0.06)
			curbs.append(Transform3D(Basis().scaled(size),
				world_of(x, y) + Vector3(d.x, 0.1, d.y) * (T * 0.5 - 0.14)))


## Бортик вокруг воды — один MultiMesh: их сотни, по одному узлу не потянем.
func _ice_multimesh(parts: Array) -> void:
	if parts.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mmi := _multimesh(box, parts.size(), mat_cap, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in parts.size():
		mmi.multimesh.set_instance_transform(i, parts[i])
		mmi.multimesh.set_instance_color(i, Color(0.84, 0.82, 0.78).darkened(rng.randf() * 0.2))


# ---------------------------------------------------------------------------
# арочные порталы, ниши, саркофаги
# ---------------------------------------------------------------------------

## Портал ставим там, где проход ограничен стенами с обеих сторон: ось,
## в которой ряд клеток упирается в стену, и есть пролёт арки.
func _span_of(c: Vector2i) -> Dictionary:
	var best := {}
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for ax in axes:
		var a := c
		while is_floor(a.x - ax.x, a.y - ax.y):
			a -= ax
		var lo := a + ax
		var b := c
		while is_floor(b.x + ax.x, b.y + ax.y):
			b += ax
		var hi := b - ax
		var n: int = (absi(hi.x - lo.x) + absi(hi.y - lo.y)) + 1
		if n >= 2 and n <= 7 and not best.has("n"):
			best = {"lo": lo, "hi": hi, "n": n}
	return best


func _build_arches() -> void:
	for c in arch_cells:
		var span := _span_of(c)
		if span.is_empty():
			continue
		var lo: Vector2i = span["lo"]
		var hi: Vector2i = span["hi"]
		_arch_at(c, lo, hi)


func _arch_at(c: Vector2i, lo: Vector2i, hi: Vector2i) -> void:
	arch_count += 1
	var spanv := Vector3(1.0, 0.0, 0.0) if lo.x != hi.x else Vector3(0.0, 0.0, 1.0)
	var perp := Vector3(spanv.z, 0.0, spanv.x)
	var span_w := float(absi(hi.x - lo.x) + absi(hi.y - lo.y) + 1) * T
	var base := world_of(c.x, c.y)
	var ceil_here: float = cell_ceil(c.x, c.y)
	# подъём арки: пологая, чтобы влезать под свод и не съедать свет
	var rise: float = clampf(span_w * 0.17, 0.5, 1.3)
	var spring := minf(ceil_here - rise - 0.3, 2.75)
	if spring < 1.9:
		spring = minf(1.9, ceil_here - rise - 0.2)
	# пятки: две приплюснутые колонны по краям пролёта
	var sides: Array[int] = [-1, 1]
	for side in sides:
		var foot: Vector2i = lo if side < 0 else hi
		var p := world_of(foot.x, foot.y) + spanv * (T * 0.5 * side)
		var root := Node3D.new()
		root.position = p
		add_child(root)
		var plinth := MeshInstance3D.new()
		plinth.mesh = _prism(0.46, spring + 0.1)
		plinth.material_override = mat_cap
		plinth.position = Vector3(0, (spring + 0.1) * 0.5, 0)
		plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plinth)
		var ring := MeshInstance3D.new()
		ring.mesh = _prism(0.56, 0.24)
		ring.material_override = mat_cap
		ring.position = Vector3(0, spring + 0.02, 0)
		root.add_child(ring)
	# клинья арки: 13 сегментов по эллипсу, как в рёбрах базового класса
	var steps := 13
	for i in steps + 1:
		var ang := lerpf(0.0, PI, i / float(steps))
		var rad := Vector3.UP * sin(ang) + spanv * cos(ang)
		var zz := perp.cross(rad)
		var b0 := Basis(perp, rad, zz).scaled(Vector3(0.3, 0.34, 0.42))
		var off := spanv * (cos(ang) * span_w * 0.5) + Vector3.UP * (sin(ang) * rise)
		arch_parts.append({"t": Transform3D(b0, base + off + Vector3(0, spring, 0)),
			"c": float(_hash(c.x, c.y, i) % 100) / 100.0})
	# замок в вершине и плитняк порога
	arch_parts.append({"t": Transform3D(Basis().scaled(Vector3(0.42, 0.5, 0.5)),
		base + Vector3(0, spring + rise + 0.08, 0)), "c": 0.9})
	arch_parts.append({"t": Transform3D(Basis().scaled(Vector3(span_w + 0.5, 0.12, 0.9)),
		base + Vector3(0, 0.03, 0)), "c": 0.75})


func _build_niches() -> void:
	for c in niche_cells:
		var d := wall_face(c.x, c.y)
		if d == Vector2i.ZERO:
			continue
		niche_count += 1
		var back := world_of(c.x, c.y) + Vector3(d.x, 0.0, d.y) * (T * 0.5 - 0.1)
		var here := Vector3(d.x, 0.0, d.y)
		var yaw := atan2(here.x, here.z)
		var root := Node3D.new()
		root.position = back
		root.rotation.y = yaw
		add_child(root)
		# головка ниши: половина арки в стене, чтобы заглушка не была ящиком.
		# блоки строим в локальной системе ниши и поворачиваем к стене: без rot
		# арка ниши в торцевой стене легла бы поперёк зала.
		var rot := Basis(Vector3.UP, yaw)
		for i in 8:
			var ang: float = lerpf(0.0, PI * 0.5, i / 7.0)
			var rad := Vector3.RIGHT * cos(ang) + Vector3.UP * sin(ang)
			var tan := Vector3.RIGHT * -sin(ang) + Vector3.UP * cos(ang)
			var b_loc := Basis(tan, rad, Vector3.FORWARD).scaled(Vector3(0.3, 0.26, 1.2))
			var loc := rad * 0.85 + Vector3(0.0, 2.0, 0.0)
			arch_parts.append({"t": Transform3D(rot * b_loc, back + rot * loc),
				"c": float(_hash(c.x, c.y, i) % 100) / 100.0})
		var kind := _hash(c.x, c.y, 7) % 3
		if kind == 0:
			_statue(root)
		elif kind == 1:
			_sarcophagus(0.0, root)
		else:
			_box(Vector3(0.7, 0.9, 0.7), Vector3(0, 0.45, 0), mat_cap, root)
			_cyl(0.26, 0.5, Vector3(0, 1.15, 0), mat_metal, root)
			_sphere(0.3, Vector3(0, 1.45, 0), mat_glow, root)


## Гном-труженик в камне: постамент, восьмигранный стан, плечи и голова.
func _statue(parent: Node3D) -> void:
	_box(Vector3(0.9, 0.5, 0.9), Vector3(0, 0.25, 0), mat_cap, parent)
	var torso := MeshInstance3D.new()
	torso.mesh = _prism(0.36, 1.0)
	torso.material_override = mat_cap
	torso.position = Vector3(0, 1.0, 0)
	torso.rotation_degrees = Vector3(0, 22.5, 0)
	parent.add_child(torso)
	var shoulders := MeshInstance3D.new()
	shoulders.mesh = _prism(0.5, 0.26)
	shoulders.material_override = mat_cap
	shoulders.position = Vector3(0, 1.62, 0)
	parent.add_child(shoulders)
	_sphere(0.24, Vector3(0, 1.92, 0), mat_cap, parent)
	_box(Vector3(0.5, 0.3, 0.16), Vector3(0, 1.32, -0.34), mat_cap, parent)


func _sarcophagus(y: float, parent: Node3D) -> void:
	_box(Vector3(1.9, 0.4, 1.0), Vector3(0, y + 0.2, 0), mat_wall, parent)
	var lid := _box(Vector3(2.0, 0.26, 1.1), Vector3(0, y + 0.53, 0), mat_cap, parent)
	lid.rotation_degrees = Vector3(0, 0, 1.2)
	_box(Vector3(0.5, 0.1, 0.7), Vector3(-0.45, y + 0.68, 0), mat_cap, parent)


func _build_signs() -> void:
	for c in sign_cells:
		var ch: String = cell_char(c.x, c.y)
		if ch == "B":
			_prop("brazier", pos_of(c.x, c.y))
			continue
		var d := wall_face(c.x, c.y)
		var root := Node3D.new()
		root.position = pos_of(c.x, c.y)
		root.rotation.y = atan2(float(-d.x), float(-d.y)) if d != Vector2i.ZERO else 0.0
		add_child(root)
		_sarcophagus(surface_y(c.x, c.y), root)


func _flush_arches() -> void:
	if arch_parts.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mmi := _multimesh(box, arch_parts.size(), mat_cap)
	for i in arch_parts.size():
		var p: Dictionary = arch_parts[i]
		mmi.multimesh.set_instance_transform(i, p["t"])
		var v: float = p["c"]
		mmi.multimesh.set_instance_color(i, Color(0.9 + v * 0.1, 0.87 + v * 0.08, 0.8 + v * 0.06))


# ---------------------------------------------------------------------------
# настенные светильники вместо стоящих факелов m1
# ---------------------------------------------------------------------------

func _build_sconces() -> void:
	var used := {}
	for y in map_h:
		for x in map_w:
			if not is_plain(x, y):
				continue
			if int(dist[y][x]) > 2:
				continue
			var d := wall_face(x, y)
			if d == Vector2i.ZERO:
				continue
			if sconce_count >= 34 or (x * 7 + y * 13) % 13 != 0:
				continue
			var key := Vector2i(x + d.x * 2, y + d.y * 2)
			if used.has(key):
				continue
			used[key] = true
			sconce_count += 1
			_sconce(world_of(x, y) + Vector3(d.x, 2.3, d.y) * (T * 0.5 - 0.3), d)


func _sconce(pos: Vector3, dir: Vector2i) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = atan2(float(-dir.x), float(-dir.y))
	add_child(root)
	_box(Vector3(0.12, 0.12, 0.42), Vector3(0, 0.0, 0.16), mat_metal, root)
	_box(Vector3(0.1, 0.36, 0.1), Vector3(0, 0.18, 0.34), mat_metal, root)
	_cyl(0.16, 0.16, Vector3(0, 0.36, 0.34), mat_metal, root)
	var flame := Node3D.new()
	flame.position = Vector3(0, 0.46, 0.34)
	root.add_child(flame)
	var outer := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.01
	fm.bottom_radius = 0.09
	fm.height = 0.3
	fm.radial_segments = 7
	outer.mesh = fm
	outer.material_override = mat_flame
	outer.position = Vector3(0, 0.1, 0)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(outer)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.005
	cm.bottom_radius = 0.045
	cm.height = 0.16
	cm.radial_segments = 6
	core.mesh = cm
	core.material_override = mat_flame_core
	core.position = Vector3(0, 0.02, 0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(core)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.6, 0.6)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(1.0, 0.5, 0.18, 0.5)
	hm.albedo_texture = _radial_glow_texture()
	halo.material_override = hm
	halo.position = Vector3(0, 0.12, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(halo)
	flames.append(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 4.6
	light.omni_range = 14.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.62, 0.4)
	root.add_child(light)
	lights.append({"light": light, "base": 4.0, "seed": randf() * 10.0, "flame": flame})


# ---------------------------------------------------------------------------
# обстановка: вместо координат m1 — хеш по клетке
# ---------------------------------------------------------------------------

func _dress_rooms() -> void:
	# «stairs» в пул не берём: базовые ступени — без коллизии, в случайном
	# месте они выглядят как парящая лесенка. «brazier_stand» тоже: он даёт
	# четвёртый теневой источник, а бюджет теней и так занят светильниками.
	var pool := ["barrel", "crate", "crate", "refuse", "rubble", "shelf", "bed",
		"table", "rack", "weapon_rack", "anvil", "ore_cart", "chain", "banner",
		"lever", "puddle"]
	var used := {}
	for y in map_h:
		for x in map_w:
			if not is_plain(x, y):
				continue
			if int(dist[y][x]) > 1:
				continue
			if wall_face(x, y) == Vector2i.ZERO:
				continue
			if _hash(x, y, 3) % 21 != 0:
				continue
			if used.has(Vector2i(x, y)) or used.has(Vector2i(x - 1, y)) \
				or used.has(Vector2i(x + 1, y)) or used.has(Vector2i(x, y - 1)) \
				or used.has(Vector2i(x, y + 1)):
				continue
			var kind: String = pool[_hash(x, y, 11) % pool.size()]
			used[Vector2i(x, y)] = true
			var d := wall_face(x, y)
			var p := pos_of(x, y) + Vector3(d.x, 0.0, d.y) * 0.45
			# поворот к стене: иначе лавка стоит поперёк и выглядит случайностью
			if kind in ["bed", "shelf", "rack", "weapon_rack", "table", "ore_cart", "anvil"]:
				var root := Node3D.new()
				root.position = p
				root.rotation.y = atan2(float(-d.x), float(-d.y))
				add_child(root)
				_prop_at(kind, root)
				continue
			_prop(kind, p)


## Base-class `_prop` рисует в координатах подземелья; тут то же самое,
## но родителем выступает развёрнутый узел, а не сам тайлодержатель.
func _prop_at(kind: String, parent: Node3D) -> void:
	match kind:
		"bed":
			_box(Vector3(1.9, 0.35, 1.0), Vector3(0, 0.2, 0), mat_wood, parent)
			_box(Vector3(1.9, 0.1, 1.0), Vector3(0, 0.42, 0), mat_wood, parent)
			_box(Vector3(0.6, 0.25, 1.0), Vector3(-0.65, 0.55, 0), mat_wood, parent)
		"shelf":
			for i in 3:
				_box(Vector3(1.6, 0.06, 0.4), Vector3(0, 0.6 + i * 0.6, 0), mat_wood, parent)
			_box(Vector3(0.1, 1.8, 0.4), Vector3(-0.75, 0.9, 0), mat_wood, parent)
			_box(Vector3(0.1, 1.8, 0.4), Vector3(0.75, 0.9, 0), mat_wood, parent)
		"rack":
			_box(Vector3(1.2, 0.12, 0.4), Vector3(0, 0.06, 0), mat_wood, parent)
			for i in 3:
				_cyl(0.03, 1.7, Vector3(-0.35 + i * 0.35, 0.85, 0), mat_metal, parent)
			_box(Vector3(1.2, 0.1, 0.35), Vector3(0, 1.55, 0), mat_metal, parent)
		"weapon_rack":
			_box(Vector3(1.6, 0.1, 0.3), Vector3(0, 1.2, 0), mat_wood, parent)
			_box(Vector3(0.1, 1.4, 0.1), Vector3(-0.7, 0.7, 0), mat_wood, parent)
			_box(Vector3(0.1, 1.4, 0.1), Vector3(0.7, 0.7, 0), mat_wood, parent)
		"table":
			_box(Vector3(1.8, 0.1, 0.9), Vector3(0, 0.9, 0), mat_wood, parent)
			for dx in [-0.75, 0.75]:
				for dz in [-0.35, 0.35]:
					_box(Vector3(0.1, 0.9, 0.1), Vector3(dx, 0.45, dz), mat_wood, parent)
		"ore_cart":
			_box(Vector3(1.6, 0.8, 1.0), Vector3(0, 0.6, 0), mat_metal, parent)
			for dx in [-0.55, 0.55]:
				var w := _cyl(0.35, 0.12, Vector3(dx, 0.35, 0.5), mat_metal, parent)
				w.rotation_degrees = Vector3(90, 0, 0)
		"anvil":
			_box(Vector3(1.0, 0.4, 0.5), Vector3(0, 0.6, 0), mat_metal, parent)
			_box(Vector3(0.5, 0.4, 0.4), Vector3(0, 0.2, 0), mat_metal, parent)


# ---------------------------------------------------------------------------
# свет и атмосфера уровня 2
# ---------------------------------------------------------------------------

## Пробитый свод над самым большим залом: дыра в потолке, обрушенный камень
## и холодный столб света — единственная «не факельная» подсветка уровня.
func _build_breach() -> void:
	var best := Vector2i(-1, -1)
	var far := 0
	for y in map_h:
		for x in map_w:
			if not is_floor(x, y) or cell_char(x, y) == "w":
				continue
			var d := int(dist[y][x])
			if d > far:
				far = d
				best = Vector2i(x, y)
	if best.x < 0 or far < 4:
		return
	breach_cell = best
	var p := world_of(best.x, best.y)
	var top: float = cell_ceil(best.x, best.y)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.16
	disc.radial_segments = 12
	hole.mesh = disc
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.5, 0.58, 0.7)
	hm.emission_enabled = true
	# 2.2 выжигал диск в белое пятно с жёстким краем: небо из пробоя холодное
	# и приглушённое, иначе оно читается как лежащий под сводом лист фанеры.
	hm.emission = Color(0.42, 0.54, 0.76)
	hm.emission_energy_multiplier = 1.05
	hole.material_override = hm
	hole.position = Vector3(p.x, top + 0.06, p.z)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 14:
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(1.5, 2.4)
		_box(Vector3(rng.randf_range(0.3, 0.7), rng.randf_range(0.2, 0.45),
			rng.randf_range(0.3, 0.7)),
			Vector3(p.x + cos(ang) * rad, top - rng.randf_range(0.0, 0.3),
				p.z + sin(ang) * rad), mat_wall)
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(0.66, 0.74, 0.95)
	shaft.light_energy = 4.0
	shaft.spot_range = 13.0
	shaft.spot_angle = 34.0
	shaft.shadow_enabled = false
	shaft.position = Vector3(p.x, top + 3.2, p.z)
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(shaft)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.42, 0.58)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.28
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.07
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.12)
	env.fog_density = 0.014
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.68, 0.82)
	env.volumetric_fog_anisotropy = 0.62
	env.volumetric_fog_length = 44.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.18
	env.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.64, 0.88)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	add_child(fill)


func _process(delta: float) -> void:
	super(delta)
	if water_root != null:
		var t := Time.get_ticks_msec() / 1000.0
		# вода «дышит»: уровень поднимается на пару сантиметров, как в крипте
		water_root.position.y = sin(t * 0.55) * 0.02
		water_root.rotation.y = sin(t * 0.12) * 0.004
