extends Node3D
## 3D-подземелье: пол, стены, потолок, свет и реквизит из карты m1.txt.

class_name Dungeon

const T := 2.0
## Высота стен: гребень свода модуля стены набора Medieval Underground Dungeon
## (4,844 м). Потолок ложится точно на эту плоскость, и на стыке нет щели.
const WALL_H := 4.844
## Набор PBR-модулей: стены, арки, пол, факелы. Собран src/build_dungeon_kit.py.
const KIT := "res://assets/models/dungeon_kit/dungeon_kit.glb"
## Какие грани обнажены — по одной клетке на направление.
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Проход арки набора: полуширина проёма и толщина косяка (метры).
const ARCH_HALF := 0.72
const ARCH_JAMB := 0.28
## Выше этой высоты проём арочного модуля перекрыт кладкой.
const ARCH_TOP := 3.0

var lines: Array = []
var map_w := 0
var map_h := 0
var grid: Array = []
## dist[y][x] — клеток до ближайшей стены (у стены 0).
var dist: Array = []
## ceil_h[y][x] — нижняя грань потолка над открытой клеткой: плоскость гребня
## свода модуля стены.
var ceil_h: Array = []
## wtop[y][x] — верх стенового блока: должен доставать до свода соседних залов.
var wtop: Array = []
## pier[y][x] — стеновой блок стоит отдельно и превращён в столб.
var pier: Array = []
## Кластеры таких блоков: центр, полуразмеры, верх.
var piers: Array = []
## Поставленные арки: клетка и нормаль её лицевой грани.
var arches: Array = []

var mat_floor: ShaderMaterial
var mat_wall: ShaderMaterial
## Потолок светлее стен: тёмная нижняя грань свода читалась как дыра над залом.
var mat_ceil: ShaderMaterial
var mat_metal: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_glow: StandardMaterial3D
var mat_flame: StandardMaterial3D
var mat_flame_core: StandardMaterial3D
## Ткань знамён: двусторонняя, иначе с обратной стороны видна чёрная заглушка.
var mat_banner: StandardMaterial3D
## Светлый тёсаный камень: плинт, карниз, капители столбов.
var mat_cap: ShaderMaterial
var lights: Array = []
var flames: Array = []
var shadow_t := 0.0
var _glow_tex: GradientTexture2D
var _banner_tex: ImageTexture
## Процедурные текстуры копоти/мха/сырости: один раз на уровень.
var _grime_cache := {}
## Модули набора: имя → Mesh, и материалы glTF (albedo+normal+roughness).
var kit: Dictionary = {}
var kit_ok := false
## Материал заплаток земли с приглушённым альбедо (см. _dirt_material).
var _mat_dirt: Material = null


func _ready() -> void:
	add_to_group("dungeon")


func build() -> void:
	_load_kit()
	_materials()
	_load_map()
	_shapes()
	_build_floor()
	_build_walls()
	_build_arches()
	_build_ceiling()
	_build_piers()
	_build_collision()
	_build_props()
	_dress_rooms()
	_scatter_torches()
	_build_environment()
	_add_atmosphere()


## Загрузка набора модулей. Модули уже стоят в своих системах координат
## (лицо стены на z=0, зал при z<0), поэтому в генераторе они ставятся
## обычным Transform3D без доводки геометрии на ходу.
func _load_kit() -> void:
	if not ResourceLoader.exists(KIT):
		push_warning("НЕТ набора dungeon_kit — подземелье соберётся из простых плит")
		return
	var packed: PackedScene = load(KIT)
	if packed == null:
		push_warning("набор dungeon_kit не загрузился")
		return
	var scene: Node = packed.instantiate()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			kit[n.name] = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	scene.free()
	kit_ok = kit.has("wall_4m") and kit.has("wall_2m") and kit.has("floor_4m")
	if not kit_ok:
		push_warning("в наборе dungeon_kit нет нужных модулей")



## Базис грани стены: X — вдоль стены, Z — из зала в толщу стены.
## Разворачивать модуль на 180° для разнообразия кладки нельзя: свод уходит
## внутрь стены и в кадре зияет чёрный фон. Для этого в наборе есть
## зеркальные варианты мешей (_b).
func _face_basis(d: Vector2i) -> Basis:
	var x := Vector3(-d.y, 0.0, d.x)
	var z := Vector3(-d.x, 0.0, -d.y)
	return Basis(x, Vector3.UP, z)


## Меш модуля: mirrored берёт зеркальный вариант того же модуля.
func _kit_mesh(mesh_name: String, mirrored: bool) -> Mesh:
	if mirrored and kit.has(mesh_name + "_b"):
		return kit[mesh_name + "_b"]
	return kit.get(mesh_name)


func _kit_place(mesh_name: String, xform: Transform3D, shadows := true,
		mirrored := false) -> MeshInstance3D:
	var m: Mesh = _kit_mesh(mesh_name, mirrored)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Детерминированный «шум» на клетку: без него модули читаются копипастой.
func _cell_hash(x: int, y: int, salt: int = 0) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return absi(h >> 3)


func _tex(name: String) -> Texture2D:
	var path := "res://assets/tex3d/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Камень: свой трипланар-шейдер, а не StandardMaterial3D. У встроенного
## трипланара строка текстуры на гранях вдоль X уходит по вертикали, и ряды
## кладки на половине стен бегут вверх по стене.
func _make_stone(tex_name: String, tint: Color, rough: float, uv: float,
		nscale: float) -> ShaderMaterial:
	var sh: Shader = load("res://assets/shaders/stone_triplanar.gdshader")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", _tex(tex_name + "_albedo"))
	m.set_shader_parameter("normal_tex", _tex(tex_name + "_normal"))
	m.set_shader_parameter("rough_tex", _tex(tex_name + "_rough"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("normal_scale", nscale)
	m.set_shader_parameter("roughness_mult", rough)
	return m


func _make_mat(tex_name: String, tint: Color, rough: float, metal: float, uv: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var a := _tex(tex_name + "_albedo")
	var n := _tex(tex_name + "_normal")
	var r := _tex(tex_name + "_rough")
	if a:
		m.albedo_texture = a
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.45
	if r:
		m.roughness_texture = r
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	m.uv1_scale = Vector3(uv, uv, uv)
	m.uv1_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _materials() -> void:
	if not ResourceLoader.exists("res://assets/tex3d/stone_wall_albedo.png"):
		push_warning("НЕТ ТЕКСТУР tex3d — стены будут плоскими")
	# Этап A: у пола, стен, свода и трима разные роли. Холодный пол, тёплый
	# камень стен и копчёный свод дают иерархию, которой не было у одного tint.
	mat_floor = _make_stone("stone_floor", Color(0.87, 0.86, 0.85), 0.68, 0.45, 1.3)
	mat_wall = _make_stone("stone_wall", Color(0.9, 0.86, 0.81), 0.9, 0.4, 1.5)
	# Свод не должен спорить с полом: копчёный холодный камень уходит в тень,
	# а тёплый свет остаётся на стенах и реквизите.
	mat_ceil = _make_stone("stone_wall", Color(0.34, 0.29, 0.25), 1.0, 1.5, 0.9)
	# Тёсаный камень ступеней и порталов. Прежний почти белый тинт в кадре
	# читался светящимся пластиком рядом с кладкой набора.
	mat_cap = _make_stone("stone_wall", Color(0.66, 0.6, 0.54), 0.85, 0.9, 1.1)
	mat_metal = _make_mat("metal", Color(0.8, 0.82, 0.9), 0.45, 0.85, 1.2)
	mat_wood = _make_mat("wood", Color(0.9, 0.85, 0.8), 0.8, 0.0, 1.0)
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.05, 0.06)
	mat_dark.roughness = 0.95
	mat_banner = StandardMaterial3D.new()
	mat_banner.albedo_texture = _banner_texture()
	mat_banner.roughness = 0.9
	mat_banner.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_banner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat_banner.alpha_scissor_threshold = 0.5
	# В тёмном зале ткань без подсветки читается чёрной доской. Слабое
	# самосвечение оставляет её тёмной, но показывает цвет и рисунок.
	mat_banner.emission_enabled = true
	mat_banner.emission = Color(0.3, 0.035, 0.045)
	mat_banner.emission_energy_multiplier = 0.45
	mat_banner.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = Color(0.9, 0.4, 0.2)
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(1.0, 0.4, 0.1)
	# 4.0 выжигало пламя в белый шар из-за bloom: теперь оно тлеющее-рыжее
	mat_glow.emission_energy_multiplier = 1.8
	# пламя рисуем unshaded: иначе собственный свет факела подсвечивает его же
	mat_flame = StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.42, 0.1)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.4, 0.09)
	mat_flame.emission_energy_multiplier = 2.6
	mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_flame_core = StandardMaterial3D.new()
	mat_flame_core.albedo_color = Color(1.0, 0.8, 0.42)
	mat_flame_core.emission_enabled = true
	mat_flame_core.emission = Color(1.0, 0.74, 0.34)
	mat_flame_core.emission_energy_multiplier = 4.2
	mat_flame_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flame_core.cull_mode = BaseMaterial3D.CULL_DISABLED


func _load_map() -> void:
	var f := FileAccess.open("res://assets/level/m1.txt", FileAccess.READ)
	if f == null:
		push_error("нет карты 3D")
		return
	for l in f.get_as_text().split("\n"):
		if l.strip_edges().length() > 0:
			lines.append(l)
	map_h = lines.size()
	map_w = lines[0].length()
	for y in map_h:
		var row: Array = []
		for x in map_w:
			row.append(lines[y].substr(x, 1) == "#")
		grid.append(row)


func is_wall(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
		return true
	return grid[ty][tx]


func cell_center(tx: int, ty: int) -> Vector3:
	return Vector3((tx + 0.5) * T, 0.0, (ty + 0.5) * T)


## Нижняя грань потолка над клеткой (для открытой клетки).
func cell_ceil(tx: int, ty: int) -> float:
	if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
		return WALL_H
	if grid[ty][tx]:
		return WALL_H
	return ceil_h[ty][tx]


func _in(tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < map_w and ty < map_h


## Поле расстояний от стен и всё, что из него следует: ступени свода,
## высота стен, список отдельно стоящих опор.
func _shapes() -> void:
	var far := map_w * map_h
	dist = []
	var q: Array[Vector2i] = []
	for y in map_h:
		var row: Array = []
		for x in map_w:
			if grid[y][x]:
				row.append(0)
				q.append(Vector2i(x, y))
			else:
				row.append(far)
		dist.append(row)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var next_d: int = int(dist[c.y][c.x]) + 1
		for d in DIRS:
			var n: Vector2i = c + d
			# продвигаем только ту клетку, которой действительно стало ближе
			if not _in(n.x, n.y) or int(dist[n.y][n.x]) <= next_d:
				continue
			dist[n.y][n.x] = next_d
			q.append(n)
	# Потолок — плоскость гребня свода модуля стены. Ступенчатые подъёмы свода
	# над залами убраны: китовый модуль несёт свой свод с гребнем на 4,844 м,
	# и поднятый потолок отрывался от верха стены, открывая чёрный фон.
	ceil_h = []
	for y in map_h:
		var row: Array = []
		for x in map_w:
			row.append(WALL_H)
		ceil_h.append(row)
	wtop = []
	pier = []
	for y in map_h:
		var hr: Array = []
		var pr: Array = []
		for x in map_w:
			var h: float = WALL_H
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if _in(nx, ny) and not grid[ny][nx]:
					h = maxf(h, float(ceil_h[ny][nx]))
			hr.append(h + 0.1)
			pr.append(false)
		wtop.append(hr)
		pier.append(pr)
	_find_piers()


## Куски стены, которые не примыкают к границе уровня и не длиннее четырёх
## клеток, — это не стены, а опоры в зале. Кубы-опоры и есть главный источник
## «всё квадратное», поэтому превращаем их в восьмигранные столбы.
func _find_piers() -> void:
	var seen: Array = []
	for y in map_h:
		var row: Array = []
		for x in map_w:
			row.append(false)
		seen.append(row)
	for y in map_h:
		for x in map_w:
			if not grid[y][x] or seen[y][x]:
				continue
			var comp: Array[Vector2i] = [Vector2i(x, y)]
			seen[y][x] = true
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			var edge := x == 0 or y == 0 or x == map_w - 1 or y == map_h - 1
			var top := WALL_H
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				top = maxf(top, float(wtop[c.y][c.x]))
				for d in DIRS:
					var n: Vector2i = c + d
					if not _in(n.x, n.y) or not grid[n.y][n.x] or seen[n.y][n.x]:
						continue
					seen[n.y][n.x] = true
					if n.x == 0 or n.y == 0 or n.x == map_w - 1 or n.y == map_h - 1:
						edge = true
					comp.append(n)
					stack.append(n)
			if edge or comp.size() > 4:
				continue
			var minx := comp[0].x
			var maxx := comp[0].x
			var miny := comp[0].y
			var maxy := comp[0].y
			for c in comp:
				pier[c.y][c.x] = true
				minx = mini(minx, c.x)
				maxx = maxi(maxx, c.x)
				miny = mini(miny, c.y)
				maxy = maxi(maxy, c.y)
			piers.append({
				"pos": Vector3((minx + maxx + 1) * 0.5 * T, 0.0, (miny + maxy + 1) * 0.5 * T),
				"rx": (maxx - minx + 1) * T * 0.5,
				"rz": (maxy - miny + 1) * T * 0.5,
				"top": top,
			})


func _multimesh(mesh: Mesh, count: int, mat: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: Material = mat.duplicate()
	var sm := m as StandardMaterial3D
	if sm:
		sm.vertex_color_use_as_albedo = true
	mmi.material_override = m
	add_child(mmi)
	return mmi


func _open_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if not grid[y][x]:
				out.append(Vector2i(x, y))
	return out


## Пол из плит набора: модуль 4×4 м ложится ровно на блок 2×2 клетки, поэтому
## швов между блоками нет, а плита заходит под кладку стен и щелей не оставляет.
func _build_floor() -> void:
	if not kit_ok:
		_build_floor_plain()
		return
	var laid := 0
	for by in range(0, map_h, 2):
		for bx in range(0, map_w, 2):
			if not _block_has_floor(bx, by):
				continue
			var yaw: float = float(_cell_hash(bx, by, 5) % 4) * PI * 0.5
			_kit_place("floor_4m", Transform3D(Basis(Vector3.UP, yaw),
				Vector3((bx + 1) * T, 0.0, (by + 1) * T)), false)
			laid += 1
	print("FLOOR kit tiles=", laid)
	_scatter_dirt()


## Нужен ли блоку 2×2 пол: в нём есть проходимая клетка, клетка со столбом
## или стена, обшитая модулями набора. У модуля стены нет собственного пола:
## свод сходится с основанием кладки только на 1,6 м в глубину клетки, и без
## плиты вдоль основания стены остаётся чёрная щель (в диагностических
## кадрах — чёрная полоса у плинтуса).
func _block_has_floor(bx: int, by: int) -> bool:
	for dy in 2:
		for dx in 2:
			var x := bx + dx
			var y := by + dy
			if not _in(x, y):
				continue
			if not grid[y][x] or pier[y][x]:
				return true
			for d in SIDES:
				if _exposed(x, y, d):
					return true
	return false


## Материал заплатки земли: родной «песок» набора светлее каменного пола и в
## тёмном зале читается белым листом бумаги. Глушим альбедо до сырой земли,
## карты набора (normal и metallic-roughness) остаются родными.
func _dirt_material() -> Material:
	if _mat_dirt != null:
		return _mat_dirt
	var mesh: Mesh = _kit_mesh("dirt", false)
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var src: Material = mesh.surface_get_material(0)
	if src is StandardMaterial3D:
		var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
		m.albedo_color = Color(0.34, 0.3, 0.26)
		_mat_dirt = m
	else:
		_mat_dirt = src
	return _mat_dirt


## Заплатки земли из набора: сбивают регулярность плит, ставятся по одной
## на далёкий от стен блок.
func _scatter_dirt() -> void:
	if not kit.has("dirt"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	var placed := 0
	for by in range(2, map_h - 3, 2):
		for bx in range(2, map_w - 3, 2):
			if placed >= 14:
				break
			var c := Vector2i(bx, by)
			if not _is_open_cell(c) or int(dist[by][bx]) < 3:
				continue
			if rng.randf() > 0.12:
				continue
			var yaw: float = rng.randf() * TAU
			var mi := _kit_place("dirt", Transform3D(Basis(Vector3.UP, yaw),
				Vector3((bx + 1) * T, 0.012, (by + 1) * T)), false)
			if mi != null:
				mi.material_override = _dirt_material()
				placed += 1
	print("FLOOR dirt patches=", placed)


## Аварийная мостовая, если набор не загрузился: уровень должен оставаться
## проходимым, а не превращаться в пустоту.
func _build_floor_plain() -> void:
	var cells := _open_cells()
	for y in map_h:
		for x in map_w:
			if grid[y][x] and pier[y][x]:
				cells.append(Vector2i(x, y))
	var base := BoxMesh.new()
	base.size = Vector3(T, 0.3, T)
	var bmi := _multimesh(base, cells.size(), mat_floor, false)
	for i in cells.size():
		var c := cells[i]
		bmi.multimesh.set_instance_transform(i,
			Transform3D(Basis(), Vector3((c.x + 0.5) * T, -0.15, (c.y + 0.5) * T)))
		bmi.multimesh.set_instance_color(i, Color(0.9, 0.92, 1.0))


func _ceil_cell_height(tx: int, ty: int) -> float:
	if not _in(tx, ty):
		return WALL_H
	if not grid[ty][tx]:
		return float(ceil_h[ty][tx])
	if not pier[ty][tx]:
		return WALL_H
	# Над восьмигранной опорой угол клетки не занят камнем: без потолочной
	# заплаты там оставалась треугольная дыра в чёрный фон. Высоту берём у
	# соседних открытых клеток, чтобы заплата не провисала.
	var total := 0.0
	var count := 0
	for d in DIRS:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		if _in(nx, ny) and not grid[ny][nx]:
			total += float(ceil_h[ny][nx])
			count += 1
	if count == 0:
		return WALL_H
	return total / float(count)


## Высота свода в углу клеток. Ступени ceil_h сглаживаются по общей вершине:
## вместо вертикальных «полок» получается пологий свод, и в потолке больше
## нет тёмных прямоугольников — боковых граней блоков 2×2 м.
func _ceil_corner_h(cx: int, cz: int) -> float:
	var total := 0.0
	var count := 0
	for dy in [-1, 0]:
		for dx in [-1, 0]:
			var tx: int = cx + dx
			var ty: int = cz + dy
			if _in(tx, ty) and (not grid[ty][tx] or pier[ty][tx]):
				total += _ceil_cell_height(tx, ty)
				count += 1
	if count == 0:
		return WALL_H
	return total / float(count)


func _ceil_corner_normal(cx: int, cz: int) -> Vector3:
	var dx: float = _ceil_corner_h(cx + 1, cz) - _ceil_corner_h(cx - 1, cz)
	var dz: float = _ceil_corner_h(cx, cz + 1) - _ceil_corner_h(cx, cz - 1)
	return Vector3(dx, -2.0 * T, dz).normalized()


func _build_ceiling() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index_of := {}
	var count := 0
	for y in map_h:
		for x in map_w:
			# потолок кладётся и над клетками стен: свод модуля стены поднимается
			# до плоскости потолка, и без заплаты над стеной в зал смотрит пустота
			var ids: Array[int] = []
			var corners: Array[Vector2i] = [
				Vector2i(x, y), Vector2i(x + 1, y),
				Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
			]
			for c in corners:
				if not index_of.has(c):
					var p := Vector3(c.x * T, _ceil_corner_h(c.x, c.y), c.y * T)
					st.set_color(Color(0.95, 0.92, 0.86))
					st.set_normal(_ceil_corner_normal(c.x, c.y))
					st.add_vertex(p)
					index_of[c] = count
					count += 1
				var id: int = index_of[c]
				ids.append(id)
			st.add_index(ids[0])
			st.add_index(ids[2])
			st.add_index(ids[1])
			st.add_index(ids[1])
			st.add_index(ids[2])
			st.add_index(ids[3])
	var mesh: ArrayMesh = st.commit()
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat_ceil
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Обнажена ли грань клетки-стены наружу — в том числе у столба.
func _exposed(x: int, y: int, d: Vector2i) -> bool:
	if not _in(x, y) or not grid[y][x] or pier[y][x]:
		return false
	return _open_in(x, y, d)


## Соседняя клетка по направлению d не занята камнем.
func _open_in(x: int, y: int, d: Vector2i) -> bool:
	var nx := x + d.x
	var ny := y + d.y
	return _in(nx, ny) and not grid[ny][nx]


## Есть ли у открытой клетки стена с указанной стороны.
func _wall_at(open_cell: Vector2i, d: Vector2i) -> bool:
	return _exposed(open_cell.x + d.x, open_cell.y + d.y, Vector2i(-d.x, -d.y))


## Преобразование модуля на грань: origin — середина грани на полу, Z смотрит
## из зала в толщу стены.
func _face_xform(pair: Array, d: Vector2i) -> Transform3D:
	var out := Vector3(d.x, 0.0, d.y)
	var mid := Vector3.ZERO
	for c0 in pair:
		var c: Vector2i = c0
		mid += cell_center(c.x, c.y) + out * (T * 0.5)
	return Transform3D(_face_basis(d), mid / float(pair.size()))


## Стены из кладки набора: на каждую обнажённую грань — модуль 4 м (две
## клетки) или 2 м (одна). Лицо кладки ложится точно на плоскость грани
## клетки по сетке m1.txt, поэтому щелей и разрывов между модулями нет.
func _build_walls() -> void:
	if not kit_ok:
		_build_walls_plain()
		return
	var four := 0
	var two := 0
	for d in SIDES:
		var t := Vector2i(-d.y, d.x)
		var used := {}
		for y in map_h:
			for x in map_w:
				var c := Vector2i(x, y)
				if used.has(c) or not _exposed(x, y, d):
					continue
				var pair: Array = [c]
				var n := c + t
				if _in(n.x, n.y) and not used.has(n) and _exposed(n.x, n.y, d):
					pair.append(n)
				var flip: bool = _cell_hash(x, y, 11) % 2 == 0
				_kit_place("wall_4m" if pair.size() == 2 else "wall_2m",
					_face_xform(pair, d), true, flip)
				if pair.size() == 2:
					four += 1
				else:
					two += 1
				for cc in pair:
					used[cc] = true
	print("WALLS kit 4m=", four, " 2m=", two)


## Аварийные стены, если набор не загрузился.
func _build_walls_plain() -> void:
	var cells: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if grid[y][x] and not pier[y][x]:
				cells.append(Vector2i(x, y))
	var box := BoxMesh.new()
	box.size = Vector3(T, 1.0, T)
	var mmi := _multimesh(box, cells.size(), mat_wall)
	for i in cells.size():
		var c := cells[i]
		var h: float = wtop[c.y][c.x]
		mmi.multimesh.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(1.0, h, 1.0)),
			Vector3((c.x + 0.5) * T, h * 0.5, (c.y + 0.5) * T)))
		mmi.multimesh.set_instance_color(i, Color(0.86, 0.87, 0.92))


## Проёмы: клетка-разрыв в стене — это готовый модуль набора с арочным
## проходом. Он закрывает разрыв по сетке и ставит настоящую кладёную арку
## вместо прежних процедурных рёбер из коробок.
func _build_arches() -> void:
	arches.clear()
	if not kit.has("arch_2m"):
		return
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if grid[y][x]:
				continue
			var wall_x: bool = is_wall(x - 1, y) and is_wall(x + 1, y)
			var wall_z: bool = is_wall(x, y - 1) and is_wall(x, y + 1)
			var open_x: bool = not is_wall(x - 1, y) and not is_wall(x + 1, y)
			var open_z: bool = not is_wall(x, y - 1) and not is_wall(x, y + 1)
			var d := Vector2i.ZERO
			if wall_x and open_z:
				d = Vector2i(0, -1)   # стена идёт по X, проход по Z
			elif wall_z and open_x:
				d = Vector2i(-1, 0)   # стена идёт по Z, проход по X
			if d == Vector2i.ZERO:
				continue
			var c := Vector2i(x, y)
			var flip: bool = _cell_hash(x, y, 29) % 2 == 0
			_kit_place("arch_2m", _face_xform([c], d), true, flip)
			arches.append({"cell": c, "d": d})
	print("ARCHES kit=", arches.size())


## Отдельная опора: клетка-столб обшивается модулями 2 м по каждой
## обнажённой грани. В зале стоит кладёный столб 2×2 со сводом у верха —
## гранёные барабаны и капители больше не нужны.
func _build_piers() -> void:
	var faces := 0
	if kit_ok:
		for y in map_h:
			for x in map_w:
				if not grid[y][x] or not pier[y][x]:
					continue
				for d in SIDES:
					if not _open_in(x, y, d):
						continue
					_kit_place("wall_2m", _face_xform([Vector2i(x, y)], d), true,
						_cell_hash(x, y, 17) % 2 == 0)
					faces += 1
	if faces == 0:
		_build_piers_plain()
	print("PIERS kit faces=", faces, " clusters=", piers.size())


## Аварийные столбы простыми блоками.
func _build_piers_plain() -> void:
	for p0 in piers:
		var p: Dictionary = p0
		_box(Vector3(float(p["rx"]) * 1.8, WALL_H, float(p["rz"]) * 1.8),
			Vector3(p["pos"].x, WALL_H * 0.5, p["pos"].z), mat_wall)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(map_w * T, 0.6, map_h * T)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(map_w * T * 0.5, -0.3, map_h * T * 0.5)
	body.add_child(floor_col)

	for y in map_h:
		var x := 0
		while x < map_w:
			if grid[y][x] and not pier[y][x]:
				var start := x
				while x < map_w and grid[y][x] and not pier[y][x]:
					x += 1
				var run := x - start
				var shape := BoxShape3D.new()
				shape.size = Vector3(run * T, WALL_H, T)
				var col := CollisionShape3D.new()
				col.shape = shape
				col.position = Vector3((start + run * 0.5) * T, WALL_H * 0.5, (y + 0.5) * T)
				body.add_child(col)
			else:
				x += 1
	# столбы: квадрат в размер клетки — ровно то, что видно как кладёный столб
	for y in map_h:
		for x in map_w:
			if grid[y][x] and pier[y][x]:
				_box_collision(body, Vector3(T, WALL_H, T),
					Vector3((x + 0.5) * T, WALL_H * 0.5, (y + 0.5) * T))
	# косяки и переклад арок: без них игрок проходит сквозь камень арки
	for a0 in arches:
		var a: Dictionary = a0
		var c: Vector2i = a["cell"]
		var d: Vector2i = a["d"]
		var center := cell_center(c.x, c.y)
		# ось кладки арки — вдоль стены, то есть поперёк нормали d
		var along := Vector3(-d.y, 0.0, d.x)
		var nx := absf(along.x)
		var nz := absf(along.z)
		for s in [-1.0, 1.0]:
			var off: Vector3 = along * (ARCH_HALF + ARCH_JAMB * 0.5) * s
			_box_collision(body, Vector3(
				nx * ARCH_JAMB + (1.0 - nx) * T, WALL_H,
				nz * ARCH_JAMB + (1.0 - nz) * T),
				Vector3(center.x + off.x, WALL_H * 0.5, center.z + off.z))
		_box_collision(body, Vector3(
			nx * ARCH_HALF * 2.0 + (1.0 - nx) * T, WALL_H - ARCH_TOP,
			nz * ARCH_HALF * 2.0 + (1.0 - nz) * T),
			Vector3(center.x, (WALL_H + ARCH_TOP) * 0.5, center.z))


func _box_collision(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)


## Уже есть свет в этом радиусе — новый факел не нужен.
func _light_near(pos: Vector3, radius: float) -> bool:
	var probe := pos + Vector3(0, 1.4, 0)
	for entry in lights:
		var l: OmniLight3D = entry.get("light")
		if l != null and is_instance_valid(l) \
				and l.global_position.distance_to(probe) < radius:
			return true
	return false


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Тёплый слабый ambient: тёмные теплённые тени, факелы ведут кадр
	env.ambient_light_color = Color(0.1, 0.08, 0.07)
	env.ambient_light_energy = 0.3
	# ACES — кинематографичный тон-маппинг, как в меню игры.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.34
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.085, 0.09, 0.115)
	# Немного реже Dense fog, чтобы свет доходил дальше
	env.fog_density = 0.009
	env.ssao_enabled = true
	# Контактные тени в стыках кладки: без них камень выглядит пластиком.
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	# SSIL добивает свет в углах и на нижних гранях свода, где ambient слаб.
	env.ssil_enabled = true
	env.ssil_radius = 2.0
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.98
	# объёмный туман даёт световые конусы от факелов. Плотность 0.02 у мыши
	# факела героя выбеливала полкадра и прятала кладку набора: свели к 0.01.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	# Тёплый туман подхватывает цвет ambient и свет факелов
	env.volumetric_fog_albedo = Color(0.12, 0.1, 0.08)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 40.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.08
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.98
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# холодный заполняющий свет: без него коридор утопает в красно-коричневом
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.58, 0.66, 0.86)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-55.0, 32.0, 0.0)
	add_child(fill)


# ---------------------------------------------------------------------------
# этап A: атмосфера (косые лучи, пыль, копоть, мох, сырость)

func _add_atmosphere() -> void:
	_add_light_shafts()
	_add_grime_decals()


## Два холодных конуса из щелей свода: дают контровой свет и видимый объём
## туману. Тени не включаем: теневой бюджет занят факелами у игрока.
func _add_light_shafts() -> void:
	# Два зала на маршруте камеры: коридор у старта и зал с колоннами.
	# Случайный поиск уводил лучи в невидимые комнаты на другом конце карты.
	var anchors := [Vector3(46.0, 0.0, 50.0), Vector3(58.0, 0.0, 44.0)]
	var cells: Array[Vector2i] = []
	for a in anchors:
		var c := _nearest_open_cell(a)
		if not cells.has(c):
			cells.append(c)
	for i in mini(2, cells.size()):
		var c: Vector2i = cells[i]
		var top: float = cell_ceil(c.x, c.y)
		var center := cell_center(c.x, c.y)
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.55, 0.68, 1.0)
		spot.light_energy = 8.0
		spot.spot_range = top + 1.0
		spot.spot_angle = 30.0
		spot.spot_attenuation = 1.2
		spot.shadow_enabled = false
		spot.position = center + Vector3(0, top - 0.12, 0)
		# SpotLight3D светит вдоль -Z; поворот на -90° направляет его вниз.
		spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(spot)
		_add_dust(center, top)


## Пыль в луче: дешёвые частицы на весь объём зала, без оверлея на экран.
func _add_dust(center: Vector3, top: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 9.0
	p.preprocess = 5.0
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-3.0, -top, -3.0), Vector3(6.0, top * 2.0, 6.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.6, top * 0.32, 1.6)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.09
	pm.gravity = Vector3(0.0, -0.01, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 1.5
	pm.color = Color(0.85, 0.82, 0.72, 0.55)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _radial_glow_texture()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = center + Vector3(0, top * 0.5, 0)
	add_child(p)


## Копоть над огнём, мох у пола и лужицы: процедурные Decal вместо новых
## текстур, чтобы грязь не повторялась и не стоила ассетов.
func _add_grime_decals() -> void:
	var soot := _grime_texture("soot")
	var moss := _grime_texture("moss")
	var wet := _grime_texture("wet")
	var soot_n := 0
	for entry in lights:
		if soot_n >= 10:
			break
		var l: OmniLight3D = entry.get("light")
		if l == null or not is_instance_valid(l):
			continue
		var wall := _nearest_wall(l.global_position)
		if wall.is_empty():
			continue
		var n: Vector3 = wall["normal"]
		var p: Vector3 = wall["pos"] + n * 0.05
		p.y = clampf(l.global_position.y + 0.75, 2.2, WALL_H + 0.6)
		_decal(p, n, Vector3(2.4, 0.7, 2.2), soot, Color(1, 1, 1, 0.8))
		soot_n += 1

	var moss_n := 0
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if moss_n >= 7:
				break
			if grid[y][x] or (x * 11 + y * 17) % 29 != 0:
				continue
			var wall := _nearest_wall(cell_center(x, y))
			if wall.is_empty():
				continue
			var n: Vector3 = wall["normal"]
			var p: Vector3 = wall["pos"] + n * 0.04
			p.y = 0.35
			_decal(p, n, Vector3(1.6, 0.45, 1.2), moss, Color(1, 1, 1, 0.65))
			moss_n += 1

	var wet_n := 0
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if wet_n >= 5:
				break
			if grid[y][x] or (x * 7 + y * 19) % 41 != 0:
				continue
			var p := cell_center(x, y) + Vector3(0, 0.06, 0)
			_decal(p, Vector3.UP, Vector3(1.4, 0.5, 1.1), wet, Color(1, 1, 1, 0.8))
			wet_n += 1


## Ближайшая к точке стена: позиция на её лице и нормаль в сторону комнаты.
func _nearest_wall(pos: Vector3) -> Dictionary:
	var tx := int(floor(pos.x / T))
	var ty := int(floor(pos.z / T))
	for d in DIRS:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		if not _in(nx, ny) or not grid[ny][nx]:
			continue
		return {
			"pos": Vector3((nx + 0.5) * T - d.x * T * 0.5, 0.0,
				(ny + 0.5) * T - d.y * T * 0.5),
			"normal": Vector3(-d.x, 0.0, -d.y),
		}
	return {}


func _decal(pos: Vector3, normal: Vector3, size_v: Vector3, tex: Texture2D,
		tint: Color) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size_v
	d.modulate = tint
	d.albedo_mix = 1.0
	d.cull_mask = 1
	# Decal проецирует вдоль локальной -Y: ставим Y вдоль нормали стены/пола.
	var y := normal.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	d.basis = Basis(x, y, z)
	d.position = pos
	add_child(d)


## Мягкое пятно с неровным краем: копоть, мох или сырость.
func _grime_texture(kind: String) -> Texture2D:
	if _grime_cache.has(kind):
		return _grime_cache[kind]
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := float(x) / float(w)
			var v := float(y) / float(h)
			var dx := u - 0.5
			var dy := v - 0.5
			var fall := clampf(1.0 - sqrt(dx * dx + dy * dy) * 2.0, 0.0, 1.0)
			var n := 0.5 + 0.5 * sin(u * 21.0 + sin(v * 13.0) * 2.3) \
				* sin(v * 17.0 + sin(u * 9.0) * 2.0)
			var a := fall * (0.25 + 0.75 * n)
			var c := Color(0.06, 0.09, 0.11, a * 0.55)
			if kind == "soot":
				c = Color(0.03, 0.02, 0.015, a * 0.85)
			elif kind == "moss":
				c = Color(0.1, 0.14, 0.06, a * 0.7)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_grime_cache[kind] = tex
	return tex


# ---------------------------------------------------------------------------
# реквизит
# ---------------------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.05
	c.height = h
	c.radial_segments = 16
	m.mesh = c
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _sphere(r: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 12
	m.mesh = s
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _torus(inner: float, outer: float, pos: Vector3, mat: Material,
		parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 12
	t.ring_segments = 6
	m.mesh = t
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _is_open_cell(c: Vector2i) -> bool:
	return _in(c.x, c.y) and not grid[c.y][c.x]


## Клетка пола, ближайшая к точке. Реквизит из m1_props.json местами стоит
## ровно на границе стены; без этого он наполовину утопает в камне.
func _nearest_open_cell(pos: Vector3, max_r: int = 6) -> Vector2i:
	var base := Vector2i(int(floor(pos.x / T)), int(floor(pos.z / T)))
	if _is_open_cell(base):
		return base
	var best := base
	var best_d := INF
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := base + Vector2i(dx, dy)
				if not _is_open_cell(c):
					continue
				var d := float(dx * dx + dy * dy)
				if d < best_d:
					best_d = d
					best = c
		if best_d < INF:
			break
	return best


## Опускает напольный предмет в открытую клетку и не даёт ему залезть в стену.
func _floor_safe(pos: Vector3, clearance: float) -> Vector3:
	var c := _nearest_open_cell(pos)
	var center := cell_center(c.x, c.y)
	var margin: float = minf(clearance, T * 0.5 - 0.06)
	var x: float = clampf(pos.x, center.x - (T * 0.5 - margin),
		center.x + (T * 0.5 - margin))
	var z: float = clampf(pos.z, center.z - (T * 0.5 - margin),
		center.z + (T * 0.5 - margin))
	return Vector3(x, 0.0, z)


func _prop_clearance(type: String) -> float:
	match type:
		"table", "bed":
			return 0.95
		"ore_cart":
			return 0.88
		"shelf":
			return 0.78
		"rack", "weapon_rack":
			return 0.68
		"crate", "anvil":
			return 0.56
		"barrel", "brazier", "forge_fire":
			return 0.5
		"rubble", "refuse":
			return 0.32
		_:
			return 0.4


## Ближайшее к точке место на стене: позиция на лицевой грани и нормаль внутрь
## комнаты. Если стены рядом нет, возвращает пустой словарь — лучше не ставить
## знамя, чем оставить его висеть посреди зала.
func _nearest_wall_anchor(pos: Vector3, max_r: int = 7) -> Dictionary:
	var base := Vector2i(int(floor(pos.x / T)), int(floor(pos.z / T)))
	var best := {}
	var best_d := INF
	for r in range(0, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := base + Vector2i(dx, dy)
				if not _is_open_cell(c):
					continue
				var center := cell_center(c.x, c.y)
				for d in DIRS:
					var wx: int = c.x + d.x
					var wy: int = c.y + d.y
					if not _in(wx, wy) or not grid[wy][wx]:
						continue
					var p := center + Vector3(d.x, 0.0, d.y) * (T * 0.5 - 0.05)
					var dist := p.distance_squared_to(pos)
					if dist < best_d:
						best_d = dist
						best = {
							"pos": p,
							"normal": Vector3(-d.x, 0.0, -d.y),
						}
		if not best.is_empty() and r >= 1:
			break
	return best


## Узел на стене: локальная +Z смотрит в комнату, +X идёт вдоль стены.
func _wall_root(anchor: Dictionary) -> Node3D:
	var root := Node3D.new()
	var n: Vector3 = anchor["normal"]
	var tangent: Vector3 = Vector3.UP.cross(n).normalized()
	root.transform = Transform3D(Basis(tangent, Vector3.UP, n), anchor["pos"])
	add_child(root)
	return root


## Знамя: полотно на двустороннем материале, деревянный стержень и кронштейны.
## Раньше это был чёрный бокс без ориентации: у стены он торчал ребром и с
## обратной стороны был просто чёрным.
func _banner_prop(pos: Vector3) -> void:
	var anchor := _nearest_wall_anchor(pos)
	if anchor.is_empty():
		return
	var root := _wall_root(anchor)
	_box(Vector3(1.34, 0.09, 0.09), Vector3(0, 3.53, 0.07), mat_wood, root)
	for dx in [-0.69, 0.69]:
		_sphere(0.055, Vector3(dx, 3.53, 0.07), mat_metal, root)
		_box(Vector3(0.07, 0.07, 0.2), Vector3(dx * 0.74, 3.53, 0.01), mat_metal, root)
	var cloth := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.04, 2.16)
	cloth.mesh = quad
	cloth.material_override = mat_banner
	cloth.position = Vector3(0, 2.4, 0.045)
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloth)
	_box(Vector3(1.04, 0.05, 0.05), Vector3(0, 1.31, 0.05), mat_metal, root)


## Цепь: тор-звенья вместо стопки сплюснутых цилиндров. Верх крепится к стене
## (или к своду, если стены рядом нет), иначе цепь читается как парящие кольца.
func _chain_prop(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	var anchor := _nearest_wall_anchor(pos, 8)
	if anchor.is_empty():
		var c := _nearest_open_cell(pos)
		var p := cell_center(c.x, c.y)
		var top: float = cell_ceil(c.x, c.y) - 0.1
		root.position = p
		_box(Vector3(0.34, 0.06, 0.34), Vector3(0, top + 0.02, 0), mat_metal, root)
		for i in 10:
			var link := _torus(0.035, 0.085,
				Vector3(0.0, top - 0.16 - i * 0.18, 0.0), mat_metal, root)
			link.rotation_degrees = Vector3(90.0, 90.0 if i % 2 else 0.0, 0.0)
		return
	var n: Vector3 = anchor["normal"]
	var tangent2: Vector3 = Vector3.UP.cross(n).normalized()
	root.transform = Transform3D(Basis(tangent2, Vector3.UP, n), anchor["pos"])
	var top := 3.34
	_box(Vector3(0.24, 0.44, 0.06), Vector3(0, 3.25, 0.0), mat_metal, root)
	_box(Vector3(0.1, 0.1, 0.28), Vector3(0, top, 0.13), mat_metal, root)
	for i in 8:
		var link := _torus(0.035, 0.085,
			Vector3(0.0, top - 0.1 - i * 0.18, 0.27), mat_metal, root)
		link.rotation_degrees = Vector3(90.0, 90.0 if i % 2 else 0.0, 0.0)
	# кандалы на нижнем звене: цепь больше не обрывается в воздухе
	_torus(0.055, 0.11, Vector3(0, 1.68, 0.27), mat_metal, root)
	_torus(0.055, 0.11, Vector3(0, 1.52, 0.27), mat_metal, root)


func _brazier_prop(pos: Vector3) -> void:
	# Жаровня стоит на ножках-треноге, а не висит чашей в воздухе. Раньше
	# корень поднимали на 0,6 м, и от земли до чаши не было вообще ничего.
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_cyl(0.33, 0.08, Vector3(0, 0.04, 0), mat_metal, root)
	for i in 3:
		var a: float = TAU * float(i) / 3.0
		var foot := _box(Vector3(0.18, 0.1, 0.46),
			Vector3(cos(a) * 0.28, 0.05, sin(a) * 0.28), mat_metal, root)
		foot.rotation.y = -a
	_cyl(0.11, 0.58, Vector3(0, 0.36, 0), mat_metal, root)
	_cyl(0.32, 0.08, Vector3(0, 0.68, 0), mat_metal, root)
	_cyl(0.44, 0.3, Vector3(0, 0.86, 0), mat_metal, root)
	_cyl(0.47, 0.05, Vector3(0, 1.0, 0), mat_metal, root)
	var coals := _sphere(0.3, Vector3(0, 1.02, 0), mat_glow, root)
	coals.scale = Vector3(1, 0.32, 1)
	var flame := Node3D.new()
	flame.position = Vector3(0, 1.08, 0)
	root.add_child(flame)
	var outer := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.01
	fm.bottom_radius = 0.1
	fm.height = 0.3
	fm.radial_segments = 7
	outer.mesh = fm
	outer.position = Vector3(0, 0.11, 0)
	outer.material_override = mat_flame
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(outer)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.05
	cm.height = 0.18
	cm.radial_segments = 6
	core.mesh = cm
	core.position = Vector3(0, 0.02, 0)
	core.material_override = mat_flame_core
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(core)
	flames.append(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 3.6
	light.omni_range = 9.0
	light.shadow_enabled = true
	light.position = Vector3(0, 1.35, 0)
	root.add_child(light)
	lights.append({"light": light, "base": 3.2, "seed": randf() * 10.0, "flame": flame})


## Ткань знамени: простая процедурная текстура с каймой и ромбом. Одна
## текстура на все знамёна, чтобы не тащить отдельный ассет ради декора.
func _banner_texture() -> ImageTexture:
	if _banner_tex != null:
		return _banner_tex
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cloth := Color(0.3, 0.045, 0.06)
	var cloth_hi := Color(0.4, 0.07, 0.08)
	var gold := Color(0.62, 0.46, 0.17)
	for y in h:
		for x in w:
			# мягкие вертикальные складки, чтобы плоский прямоугольник не
			# выглядел наклейкой на стену
			var fold: float = 0.5 + 0.5 * sin(float(x) / w * TAU * 3.0)
			var c: Color = cloth.lerp(cloth_hi, fold * 0.32)
			if x < 5 or x >= w - 5 or y < 5 or y >= h - 5:
				c = gold
			var dx: int = absi(x - w / 2)
			var dy: int = absi(y - h / 2)
			if dx + dy < 13 and dx + dy > 8:
				c = gold
			img.set_pixel(x, y, c)
	# нижняя кромка с двумя зубцами: ровный низ читался как чёрная доска
	for x in w:
		var cut: int = 0
		if x < 10 or x > w - 10:
			cut = 5
		elif x > w / 2 - 6 and x < w / 2 + 6:
			cut = 10
		for y in range(h - 5 - cut, h):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	_banner_tex = ImageTexture.create_from_image(img)
	return _banner_tex


## Радиальный градиент для аддитивного ореола пламени (одна текстура на все факелы).
func _radial_glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


func _torch(pos: Vector3) -> void:
	# стоящий факел: древко от пола, чаша, пламя и тёплый свет
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_cyl(0.05, 1.9, Vector3(0, 0.95, 0), mat_wood, root)
	_cyl(0.22, 0.12, Vector3(0, 0.06, 0), mat_metal, root)
	var bowl := _cyl(0.17, 0.24, Vector3(0, 1.9, 0), mat_metal, root)
	var flame := Node3D.new()
	flame.position = Vector3(0, 2.02, 0)
	root.add_child(flame)
	# язык пламени: конус + раскалённая сердцевина (шар читался как «яйцо»).
	# Тени от пламени выключены: иначе меш вокруг лампы гасит весь свет факела.
	var outer := MeshInstance3D.new()
	var fmesh := CylinderMesh.new()
	fmesh.top_radius = 0.012
	fmesh.bottom_radius = 0.11
	fmesh.height = 0.36
	fmesh.radial_segments = 7
	outer.mesh = fmesh
	outer.position = Vector3(0, 0.12, 0)
	outer.material_override = mat_flame
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(outer)
	var core := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.006
	cmesh.bottom_radius = 0.055
	cmesh.height = 0.2
	cmesh.radial_segments = 6
	core.mesh = cmesh
	core.position = Vector3(0, 0.03, 0)
	core.material_override = mat_flame_core
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(core)
	# мягкий ореол вокруг пламени: убирает «трафаретный» вид конуса
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.7, 0.7)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(1.0, 0.52, 0.18, 0.55)
	hm.albedo_texture = _radial_glow_texture()
	halo.material_override = hm
	halo.position = Vector3(0, 0.15, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(halo)
	flames.append(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 5.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = true
	# лампа выше языка пламени: так свет не оказывается внутри меша
	light.position = Vector3(0, 2.42, 0)
	root.add_child(light)
	lights.append({"light": light, "base": 4.2, "seed": randf() * 10.0, "flame": flame})


## Освещённость точки (0…100) с учётом затухания и стен между светом и точкой.
## Страж использует это для дальности зрения: тень — укрытие, факел — риск.
func light_at(pos: Vector3) -> float:
	var sample := pos + Vector3(0, 1.0, 0)
	var total := 0.0
	for entry in lights:
		var l: OmniLight3D = entry.get("light")
		if l == null or not is_instance_valid(l):
			continue
		var lp := l.global_position
		var r := l.omni_range
		var dist := lp.distance_to(sample)
		if dist > r:
			continue
		if not _light_clear(lp, sample):
			continue
		var fall: float = pow(clampf(1.0 - dist / maxf(r, 0.1), 0.0, 1.0), 0.9)
		total += 35.0 * fall
	return clampf(total, 0.0, 100.0)


func _light_clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _prop(type: String, pos: Vector3) -> void:
	match type:
		"torch":
			# Второй факел в трёх метрах от первого только пересвечивает
			# комнату и съедает теневой бюджет.
			if _light_near(pos, 3.2):
				return
			# у стены — настенный факел из набора, в зале без стены — напольный
			if not _wall_torch_near(pos):
				_torch(pos)
		"brazier", "forge_fire":
			_brazier_prop(pos)
		"barrel":
			_cyl(0.4, 1.0, pos + Vector3(0, 0.5, 0), mat_wood)
			_cyl(0.44, 0.08, pos + Vector3(0, 0.25, 0), mat_metal)
			_cyl(0.44, 0.08, pos + Vector3(0, 0.75, 0), mat_metal)
		"crate":
			_box(Vector3(0.9, 0.9, 0.9), pos + Vector3(0, 0.45, 0), mat_wood)
		"table":
			_box(Vector3(1.8, 0.1, 0.9), pos + Vector3(0, 0.9, 0), mat_wood)
			for dx in [-0.75, 0.75]:
				for dz in [-0.35, 0.35]:
					_box(Vector3(0.1, 0.9, 0.1), pos + Vector3(dx, 0.45, dz), mat_wood)
		"anvil":
			_box(Vector3(1.0, 0.4, 0.5), pos + Vector3(0, 0.6, 0), mat_metal)
			_box(Vector3(0.5, 0.4, 0.4), pos + Vector3(0, 0.2, 0), mat_metal)
		"ore_cart":
			_box(Vector3(1.6, 0.8, 1.0), pos + Vector3(0, 0.6, 0), mat_metal)
			for dx in [-0.55, 0.55]:
				var w := _cyl(0.35, 0.12, pos + Vector3(dx, 0.35, 0.5), mat_metal)
				w.rotation_degrees = Vector3(90, 0, 0)
		"gate", "cell_door":
			var root2 := Node3D.new()
			root2.position = pos + Vector3(0, 0, 0)
			add_child(root2)
			for i in 5:
				_box(Vector3(0.1, 3.0, 0.1), Vector3(-0.8 + i * 0.4, 1.5, 0), mat_metal, root2)
			_box(Vector3(1.9, 0.12, 0.12), Vector3(0, 1.1, 0), mat_metal, root2)
			_box(Vector3(1.9, 0.12, 0.12), Vector3(0, 2.4, 0), mat_metal, root2)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.9, 3.0, 0.3)
			cs.shape = bs
			cs.position = Vector3(0, 1.5, 0)
			body.add_child(cs)
			root2.add_child(body)
		"chain":
			_chain_prop(pos)
		"refuse":
			for i in 6:
				_sphere(0.25 + randf() * 0.12, pos + Vector3(randf_range(-0.5, 0.5), 0.15, randf_range(-0.5, 0.5)), mat_dark)
		"stairs":
			# Сплошные ступени с подступенками: пять отдельных плит висели
			# в воздухе и читались как тонкие листы бумаги.
			for i in 5:
				var top: float = 0.22 * float(i + 1)
				_box(Vector3(2.0, top, 0.5),
					pos + Vector3(0, top * 0.5, -i * 0.5), mat_wall)
				_box(Vector3(2.04, 0.04, 0.54),
					pos + Vector3(0, top + 0.02, -i * 0.5), mat_cap)
		"banner":
			_banner_prop(pos)
		"arch":
			var aroot := Node3D.new()
			aroot.position = pos
			add_child(aroot)
			_box(Vector3(0.4, 3.0, 0.6), Vector3(-1.2, 1.5, 0), mat_wall, aroot)
			_box(Vector3(0.4, 3.0, 0.6), Vector3(1.2, 1.5, 0), mat_wall, aroot)
			_box(Vector3(2.8, 0.5, 0.6), Vector3(0, 2.75, 0), mat_wall, aroot)
		"pillar":
			# колонна подгоняется под высоту свода над своей клеткой: иначе в
			# зале она короткая и висящая, а в коридоре протыкает потолок
			var ph: float = cell_ceil(int(floor(pos.x / T)), int(floor(pos.z / T)))
			_cyl(0.38, ph, pos + Vector3(0, ph * 0.5, 0), mat_wall)
			_cyl(0.46, 0.24, pos + Vector3(0, 0.12, 0), mat_metal)
			_cyl(0.46, 0.24, pos + Vector3(0, ph - 0.12, 0), mat_metal)
		"shelf":
			_box(Vector3(1.4, 1.9, 0.45), pos + Vector3(0, 0.95, 0), mat_wood)
			for i in 3:
				_box(Vector3(1.25, 0.05, 0.4), pos + Vector3(0, 0.5 + i * 0.55, 0.03), mat_metal)
				_box(Vector3(0.3, 0.25, 0.25), pos + Vector3(-0.35 + i * 0.35, 0.65 + i * 0.55, 0.05), mat_wood)
		"bed":
			_box(Vector3(1.9, 0.32, 0.85), pos + Vector3(0, 0.16, 0), mat_wood)
			var straw := _box(Vector3(1.75, 0.12, 0.7), pos + Vector3(0, 0.36, 0), mat_wood)
			straw.material_override = mat_metal
			_box(Vector3(0.5, 0.16, 0.7), pos + Vector3(-0.6, 0.46, 0), mat_wood)
		"rubble":
			for i in 7:
				_sphere(0.12 + randf() * 0.14, pos + Vector3(randf_range(-0.7, 0.7), 0.1, randf_range(-0.7, 0.7)), mat_wall)
		"rack":
			_box(Vector3(1.2, 0.12, 0.4), pos + Vector3(0, 0.06, 0), mat_wood)
			for i in 3:
				_cyl(0.03, 1.7, pos + Vector3(-0.35 + i * 0.35, 0.85, 0), mat_metal)
			_box(Vector3(1.2, 0.1, 0.35), pos + Vector3(0, 1.55, 0), mat_metal)
		"lever":
			# Рычаг, а не столб с парящим шаром: плита, стойка, шарнир и
			# наклонная рукоять. Светящийся шар на палке читался как лампа.
			var lroot := Node3D.new()
			lroot.position = pos
			add_child(lroot)
			_cyl(0.34, 0.12, Vector3(0, 0.06, 0), mat_cap, lroot)
			_cyl(0.09, 0.92, Vector3(0, 0.52, 0), mat_metal, lroot)
			_box(Vector3(0.24, 0.2, 0.24), Vector3(0, 0.98, 0), mat_metal, lroot)
			var arm := _cyl(0.05, 0.66, Vector3(0.17, 1.14, 0), mat_metal, lroot)
			arm.rotation_degrees = Vector3(0, 0, -38)
			_sphere(0.1, Vector3(0.37, 1.4, 0), mat_metal, lroot)
		"shelf":
			for i in 3:
				_box(Vector3(1.6, 0.06, 0.4), pos + Vector3(0, 0.6 + i * 0.6, 0), mat_wood)
			_box(Vector3(0.1, 1.8, 0.4), pos + Vector3(-0.75, 0.9, 0), mat_wood)
			_box(Vector3(0.1, 1.8, 0.4), pos + Vector3(0.75, 0.9, 0), mat_wood)
		"bed":
			_box(Vector3(1.9, 0.35, 1.0), pos + Vector3(0, 0.2, 0), mat_wood)
			_box(Vector3(1.9, 0.1, 1.0), pos + Vector3(0, 0.42, 0), mat_wood)
			_box(Vector3(0.6, 0.25, 1.0), pos + Vector3(-0.65, 0.55, 0), mat_wood)
		"rubble":
			for i in 8:
				_sphere(0.18 + randf() * 0.12, pos + Vector3(randf_range(-0.6, 0.6), 0.12, randf_range(-0.6, 0.6)), mat_dark)
		"brazier_stand":
			_cyl(0.12, 1.6, pos + Vector3(0, 0.8, 0), mat_metal)
			var bowl := _cyl(0.35, 0.2, pos + Vector3(0, 1.65, 0), mat_metal)
			var coals := _sphere(0.25, pos + Vector3(0, 1.75, 0), mat_glow)
			coals.scale = Vector3(1, 0.4, 1)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.5, 0.2)
			light.light_energy = 3.4
			light.omni_range = 9.0
			light.shadow_enabled = true
			light.position = pos + Vector3(0, 1.9, 0)
			add_child(light)
			lights.append({"light": light, "base": 3.0, "seed": randf() * 10.0, "flame": coals})
		"weapon_rack":
			_box(Vector3(1.6, 0.1, 0.3), pos + Vector3(0, 1.2, 0), mat_wood)
			_box(Vector3(0.1, 1.4, 0.1), pos + Vector3(-0.7, 0.7, 0), mat_wood)
			_box(Vector3(0.1, 1.4, 0.1), pos + Vector3(0.7, 0.7, 0), mat_wood)
			for i in 3:
				_box(Vector3(0.06, 0.7, 0.06), pos + Vector3(-0.4 + i * 0.4, 0.85, 0.1), mat_metal)
		"puddle":
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.6, 1.2)
			q.mesh = pm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.12, 0.18, 0.25, 0.6)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
			m.metallic = 0.2
			q.material_override = m
			q.position = pos + Vector3(0, 0.02, 0)
			add_child(q)
		_:
			pass

func _build_props() -> void:
	var txt := FileAccess.get_file_as_string("res://assets/level/m1_props.json")
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		return
	for p0 in data.get("props", []):
		var p: Dictionary = p0
		var type: String = p.get("type", "")
		if type in ["bones", "straw_bed", "bucket", "winch", "bars"]:
			continue
		var pos := Vector3(float(p.get("x", 0)) / 32.0 * T, 0.0, float(p.get("y", 0)) / 32.0 * T)
		# Двери, ворота, рычаг и лестница привязаны к координатам событий
		# миссии — их не двигаем. Остальной реквизит ставим в открытую клетку:
		# старые 2D-координаты часто попадают ровно на грань стены.
		if type in ["banner", "chain", "cell_door", "gate", "lever", "stairs"]:
			_prop(type, pos)
		else:
			_prop(type, _floor_safe(pos, _prop_clearance(type)))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for l in lights:
		var s: float = l["seed"]
		var base: float = l["base"]
		l["light"].light_energy = base * (0.86 + 0.1 * sin(t * 7.1 + s) + 0.06 * sin(t * 17.3 + s * 2.0))
	for f in flames:
		if is_instance_valid(f):
			var s2: float = float(f.get_instance_id() % 100) / 13.0
			f.scale = Vector3(1.0, 1.05 + 0.18 * sin(t * 9.0 + s2), 1.0)
	# тени только у ближайших источников — экономия GPU
	shadow_t += delta
	if shadow_t > 0.3:
		shadow_t = 0.0
		var player := get_tree().get_first_node_in_group("player")
		var center := Vector3.ZERO
		if player != null:
			center = player.global_position
		var ranked: Array = []
		for l in lights:
			var li: OmniLight3D = l["light"]
			if not is_instance_valid(li):
				continue
			ranked.append({"l": li, "d": li.global_position.distance_to(center)})
		ranked.sort_custom(func(a, b): return a["d"] < b["d"])
		for i in ranked.size():
			ranked[i]["l"].shadow_enabled = i < 4 and ranked[i]["d"] < 15.0


## Настенный факел набора: крепление в плоскости стены, рожок в зал.
## Свет тот же, что у напольного: без него коридоры остаются чёрными.
func _wall_torch(open_cell: Vector2i, d: Vector2i, shadows := false) -> bool:
	if not kit.has("torch"):
		return false
	var xf := _face_xform([open_cell], d)
	var root := Node3D.new()
	root.transform = Transform3D(xf.basis, xf.origin + Vector3(0.0, 2.05, 0.0))
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = kit["torch"]
	root.add_child(mi)
	# ореол пламени: в модуле огонь только в текстуре, живой язычок — квад-биллборд
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.8, 0.8)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(1.0, 0.5, 0.16, 0.5)
	hm.albedo_texture = _radial_glow_texture()
	halo.material_override = hm
	halo.position = Vector3(0.0, 1.2, -0.2)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	flames.append(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 5.0
	light.omni_range = 11.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = shadows
	light.position = Vector3(0.0, 1.4, -0.5)
	root.add_child(light)
	lights.append({"light": light, "base": 4.0, "seed": randf() * 10.0, "flame": halo})
	return true


## Настенный факел у ближайшей грани стены. Если стены рядом нет — false,
## и вызывающий ставит напольный.
func _wall_torch_near(pos: Vector3) -> bool:
	if not kit.has("torch"):
		return false
	var c := _nearest_open_cell(pos)
	var best := INF
	var best_d := Vector2i.ZERO
	for d in SIDES:
		if not _wall_at(c, d):
			continue
		var p := cell_center(c.x, c.y) + Vector3(d.x, 0.0, d.y) * (T * 0.5)
		var dd := p.distance_squared_to(pos)
		if dd < best:
			best = dd
			best_d = d
	if best_d == Vector2i.ZERO:
		return false
	return _wall_torch(c, best_d)


func _scatter_torches(max_count: int = 12) -> void:
	"""Ставит факелы на стены, чтобы коридоры не были чёрными."""
	var placed := 0
	var step := 7
	for y in map_h:
		for x in map_w:
			if placed >= max_count:
				return
			if grid[y][x]:
				continue
			var d := Vector2i.ZERO
			if y > 0 and grid[y - 1][x]:
				d = Vector2i(0, -1)
			elif y < map_h - 1 and grid[y + 1][x]:
				d = Vector2i(0, 1)
			elif x > 0 and grid[y][x - 1]:
				d = Vector2i(-1, 0)
			elif x < map_w - 1 and grid[y][x + 1]:
				d = Vector2i(1, 0)
			if d == Vector2i.ZERO:
				continue
			if (x * 5 + y * 11) % step != 0:
				continue
			var pos := cell_center(x, y) + Vector3(d.x, 0.0, d.y) * (T * 0.5)
			if _light_near(pos + Vector3(0.0, 1.4, 0.0), 2.6):
				continue
			# у декоративных факелов тени отключаем: иначе теневой атлас
			# переполняется и свет пропадает
			_wall_torch(Vector2i(x, y), d, false)
			placed += 1


func _dress_rooms() -> void:
	var spots := {
		"shelf": [Vector3(20, 0, 60), Vector3(60, 0, 52), Vector3(96, 0, 40)],
		"bed": [Vector3(24, 0, 62), Vector3(100, 0, 36), Vector3(88, 0, 30)],
		"rubble": [Vector3(34, 0, 58), Vector3(70, 0, 50), Vector3(50, 0, 40), Vector3(104, 0, 46)],
		"rack": [Vector3(30, 0, 50), Vector3(86, 0, 34), Vector3(45, 0, 28)],
		# Стартовая камера: один тёплый ключ у решётки, иначе первый кадр
		# остаётся тёмным пятном без читаемого силуэта.
		"brazier_stand": [Vector3(9, 0, 54)],
		"pillar": [Vector3(38, 0, 54), Vector3(66, 0, 48), Vector3(78, 0, 42)],
		"arch": [Vector3(48, 0, 50), Vector3(58, 0, 44)],
	}
	for kind in spots.keys():
		for pos in spots[kind]:
			if kind == "arch":
				_prop(kind, pos)
			else:
				_prop(kind, _floor_safe(pos, _prop_clearance(kind)))
