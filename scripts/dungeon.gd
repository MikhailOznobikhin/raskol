extends Node3D
## 3D-подземелье: пол, стены, потолок, свет и реквизит из карты m1.txt.

class_name Dungeon

const T := 2.0
const WALL_H := 4.2
## Свод поднимается над залами ступенями: узкий проход остаётся низким, зал
## получает объём. Без этого весь уровень — коробка высотой 4,2 м.
const CEIL_RISE := 0.62
## Толщина потолочной плиты: ступени свода перекрываются без щелей.
const SLAB := 1.4
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var lines: Array = []
var map_w := 0
var map_h := 0
var grid: Array = []
## dist[y][x] — клеток до ближайшей стены (у стены 0).
var dist: Array = []
## rdist[y][x] — то же, но по осям X/Y по отдельности: границы ступеней свода
## идут параллельно стенам, а не ромбом.
var rdist: Array = []
## ceil_h[y][x] — нижняя грань потолка над открытой клеткой.
var ceil_h: Array = []
## wtop[y][x] — верх стенового блока: должен доставать до свода соседних залов.
var wtop: Array = []
## pier[y][x] — стеновой блок стоит отдельно и превращён в столб.
var pier: Array = []
## Кластеры таких блоков: центр, полуразмеры, верх.
var piers: Array = []

var mat_floor: ShaderMaterial
var mat_wall: ShaderMaterial
var mat_metal: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_glow: StandardMaterial3D
var mat_flame: StandardMaterial3D
var mat_flame_core: StandardMaterial3D
## Светлый тёсаный камень: плинт, карниз, капители столбов.
var mat_cap: ShaderMaterial
var lights: Array = []
var flames: Array = []
var shadow_t := 0.0
var _glow_tex: GradientTexture2D


func _ready() -> void:
	add_to_group("dungeon")


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
	_build_props()
	_dress_rooms()
	_scatter_torches()
	_build_environment()


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
	mat_floor = _make_stone("stone_floor", Color(0.92, 0.92, 0.96), 0.72, 0.45, 1.3)
	mat_wall = _make_stone("stone_wall", Color(0.88, 0.87, 0.9), 0.88, 0.4, 1.5)
	mat_cap = _make_stone("stone_wall", Color(0.95, 0.92, 0.87), 0.8, 0.9, 1.1)
	mat_metal = _make_mat("metal", Color(0.8, 0.82, 0.9), 0.45, 0.85, 1.2)
	mat_wood = _make_mat("wood", Color(0.9, 0.85, 0.8), 0.8, 0.0, 1.0)
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.05, 0.06)
	mat_dark.roughness = 0.95
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


## Верх стенового блока над клеткой — нужен, чтобы камень кладки доставал
## до свода зала, а не до условных 4,2 м.
func wall_top(tx: int, ty: int) -> float:
	if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
		return WALL_H
	if not grid[ty][tx]:
		return WALL_H
	return wtop[ty][tx]


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
	# Прямоугольное вложение клетки в помещение: сколько клеток до ближайшей
	# стены по X и по Y по отдельности. Ромб из поля расстояний поднимал свод
	# ступенями по диагонали, и потолок над залом выглядел как обвал; здесь
	# границы уровней идут параллельно стенам, как у кессонного перекрытия.
	rdist = []
	for y in map_h:
		var row: Array = []
		for x in map_w:
			if grid[y][x]:
				row.append(0)
				continue
			var near := map_w + map_h
			var k := x - 1
			while k >= 0 and not grid[y][k]:
				k -= 1
			near = mini(near, x - k)
			k = x + 1
			while k < map_w and not grid[y][k]:
				k += 1
			near = mini(near, k - x)
			k = y - 1
			while k >= 0 and not grid[k][x]:
				k -= 1
			near = mini(near, y - k)
			k = y + 1
			while k < map_h and not grid[k][x]:
				k += 1
			near = mini(near, k - y)
			row.append(near)
		rdist.append(row)
	ceil_h = []
	for y in map_h:
		var row: Array = []
		for x in map_w:
			var dd: int = int(rdist[y][x])
			# Ступени широкие, по две клетки. Лестница из шести уровней по
			# 0,42 м с ромбовидными границами сверху выглядела как обвал.
			var rise: float = 0.0
			if dd == 2:
				rise = CEIL_RISE
			elif dd <= 4:
				rise = CEIL_RISE * 2.0
			elif dd >= 5:
				rise = CEIL_RISE * 3.0
			row.append(WALL_H + rise)
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


## Мостовая: раствор под плитами неровной резки. Одинаковая сетка 2×2
## сверху и снизу — то, что выдаёт «комнату из кубов».
func _build_floor() -> void:
	var cells := _open_cells()
	# под столбами-пилястрами тоже нужен пол: барабан уже клетки, и без плиты
	# вокруг основания зияет двухметровая чёрная дыра
	for y in map_h:
		for x in map_w:
			if grid[y][x] and pier[y][x]:
				cells.append(Vector2i(x, y))
	var grout: ShaderMaterial = mat_floor.duplicate() as ShaderMaterial
	grout.set_shader_parameter("tint", Color(0.52, 0.51, 0.55))
	var base := BoxMesh.new()
	base.size = Vector3(T, 0.3, T)
	var bmi := _multimesh(base, cells.size(), grout, false)
	for i in cells.size():
		var c := cells[i]
		# раствор почти вровень с плитами: глубокая щель читается не как шов,
		# а как провал в полу
		bmi.multimesh.set_instance_transform(i,
			Transform3D(Basis(), Vector3((c.x + 0.5) * T, -0.16, (c.y + 0.5) * T)))
		bmi.multimesh.set_instance_color(i, Color(0.9, 0.92, 1.0))

	var plates: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for cl in cells:
		var rects: Array = []
		_split(Rect2(Vector2(0.012, 0.012), Vector2(T - 0.024, T - 0.024)), 2, rng, rects)
		for r in rects:
			var rc: Rect2 = r
			if rc.size.x < 0.24 or rc.size.y < 0.24:
				continue
			plates.append({
				"pos": Vector3(cl.x * T + rc.position.x + rc.size.x * 0.5, 0.0,
					cl.y * T + rc.position.y + rc.size.y * 0.5),
				"w": rc.size.x - 0.018,
				"d": rc.size.y - 0.018,
				"th": rng.randf_range(0.14, 0.2),
				"top": rng.randf_range(-0.008, 0.02),
				"spin": rng.randf_range(-1.2, 1.2),
				"tilt": rng.randf_range(-0.7, 0.7),
				"tone": rng.randf_range(-0.05, 0.05),
			})
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var pmi := _multimesh(box, plates.size(), mat_floor, false)
	for i in plates.size():
		var p: Dictionary = plates[i]
		var b := Basis(Vector3.UP, deg_to_rad(float(p["spin"])))
		b = Basis(Vector3.RIGHT, deg_to_rad(float(p["tilt"]))) * b
		pmi.multimesh.set_instance_transform(i, Transform3D(
			b.scaled(Vector3(float(p["w"]), float(p["th"]), float(p["d"]))),
			Vector3(p["pos"].x, float(p["top"]) - float(p["th"]) * 0.5, p["pos"].z)))
		var t: float = p["tone"]
		pmi.multimesh.set_instance_color(i, Color(0.9 + t, 0.9 - t * 0.5, 0.93 - t))


## Рекурсивно дробит прямоугольник клетки на плиты разрезкой, поэтому
## плиты не перекрываются и между ними остаются швы-щели.
func _split(rect: Rect2, depth: int, rng: RandomNumberGenerator, out: Array) -> void:
	if depth <= 0 or (rect.size.x < 1.05 and rect.size.y < 1.05):
		out.append(rect)
		return
	var f: float = rng.randf_range(0.36, 0.64)
	# шов между плитами одного кольца — 2,5 см: wider шов читается не как
	# цементная линия, а как чёрная дыра в полу
	var cut: float = 0.025
	if rect.size.y > rect.size.x:
		var h: float = rect.size.y * f
		_split(Rect2(rect.position, Vector2(rect.size.x, h - cut)), depth - 1, rng, out)
		_split(Rect2(rect.position + Vector2(0, h),
			Vector2(rect.size.x, rect.size.y - h - cut)), depth - 1, rng, out)
	else:
		var w: float = rect.size.x * f
		_split(Rect2(rect.position, Vector2(w - cut, rect.size.y)), depth - 1, rng, out)
		_split(Rect2(rect.position + Vector2(w, 0),
			Vector2(rect.size.x - w - cut, rect.size.y)), depth - 1, rng, out)


func _build_ceiling() -> void:
	var cells := _open_cells()
	var box := BoxMesh.new()
	box.size = Vector3(T, SLAB, T)
	var mmi := _multimesh(box, cells.size(), mat_wall, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 511
	for i in cells.size():
		var c := cells[i]
		var h: float = ceil_h[c.y][c.x]
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(),
			Vector3((c.x + 0.5) * T, h + SLAB * 0.5, (c.y + 0.5) * T)))
		var shade: float = 1.0 - rng.randf() * 0.16
		mmi.multimesh.set_instance_color(i, Color(0.5 * shade, 0.52 * shade, 0.58 * shade))


## Ступень свода: уступ без каменной тяги читается как дыра в потолке.
func _build_corbels() -> void:
	var spots: Array = []
	for y in map_h:
		for x in map_w:
			if grid[y][x]:
				continue
			var hi: float = ceil_h[y][x]
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if not _in(nx, ny) or grid[ny][nx]:
					continue
				var lo: float = ceil_h[ny][nx]
				if lo >= hi - 0.01:
					continue
				var px: float = (x + d.x * 0.5) * T - d.x * 0.13
				var pz: float = (y + d.y * 0.5) * T - d.y * 0.13
				var size: Vector3 = Vector3(0.26, 0.24, T + 0.02) if d.x != 0 \
					else Vector3(T + 0.02, 0.24, 0.26)
				# тягу ставим НА нижний потолок: висящая между уровнями планка
				# читается как лезвие, а не как карниз уступа
				spots.append({"pos": Vector3(px, lo + 0.12, pz), "size": size})
	if spots.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	# тяга в тот же камень, что и потолок: светлый карниз подчёркивал каждый
	# уступ, и свод распадался на лесенку ярких полок
	var mmi := _multimesh(box, spots.size(), mat_wall, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 607
	for i in spots.size():
		var s: Dictionary = spots[i]
		mmi.multimesh.set_instance_transform(i, Transform3D(
			Basis().scaled(s["size"]), s["pos"]))
		mmi.multimesh.set_instance_color(i, Color(0.86, 0.84, 0.8).darkened(rng.randf() * 0.18))


func _build_walls() -> void:
	var cells: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if grid[y][x] and not pier[y][x]:
				cells.append(Vector2i(x, y))
	var box := BoxMesh.new()
	box.size = Vector3(T, 1.0, T)
	var mmi := _multimesh(box, cells.size(), mat_wall)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in cells.size():
		var c := cells[i]
		var h: float = wtop[c.y][c.x]
		mmi.multimesh.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(1.0, h, 1.0)),
			Vector3((c.x + 0.5) * T, h * 0.5, (c.y + 0.5) * T)))
		# тон почти одинаковый у соседних клеток: 22% разброса рисовали по
		# стене шахматную сетку из двухметровых клеток — главный признак «куба»
		var shade: float = 1.0 - rng.randf() * 0.05
		var jitter: float = rng.randf_range(-0.012, 0.012)
		mmi.multimesh.set_instance_color(i,
			Color(0.86 * shade + jitter, 0.87 * shade, 0.92 * shade - jitter))


## Архитектурный рельеф граней стены: плинт, карниз, пилястр и каменная пыль
## у пола. Мелкие блоки по всей плоскости читались как гофра поверх кирпичной
## текстуры, поэтому рельеф редкий и крупный — он членит стену на прясла.
func _build_cladding() -> void:
	var faces: Array = []
	for y in map_h:
		for x in map_w:
			if not grid[y][x] or pier[y][x]:
				continue
			for di in DIRS.size():
				var dd: Vector2i = DIRS[di]
				var ax: int = x + dd.x
				var ay: int = y + dd.y
				if not _in(ax, ay) or grid[ay][ax]:
					continue
				faces.append({"x": x, "y": y, "d": di, "h": ceil_h[ay][ax]})
	var trim: Array = []
	var chips: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240
	for f0 in faces:
		var f: Dictionary = f0
		var d: Vector2i = DIRS[int(f["d"])]
		var n3 := Vector3(d.x, 0.0, d.y)
		var tg := Vector3(-n3.z, 0.0, n3.x)
		var b0 := Basis(tg, Vector3.UP, n3)
		var cx := (int(f["x"]) + 0.5) * T
		var cz := (int(f["y"]) + 0.5) * T
		var plane := Vector3(cx, 0.0, cz) + n3 * (T * 0.5)
		var top: float = float(f["h"])
		rng.seed = int(f["x"]) * 7919 + int(f["y"]) * 104729 + int(f["d"]) * 313
		# плинт и карниз: без них стена — это параллелепипед, висящий в воздухе
		trim.append({"t": Transform3D(b0.scaled(Vector3(T + 0.04, 0.52, 0.2)),
			plane + n3 * 0.1 + Vector3(0, 0.26, 0)), "k": 0})
		trim.append({"t": Transform3D(b0.scaled(Vector3(T + 0.04, 0.26, 0.24)),
			plane + n3 * 0.13 + Vector3(0, top - 0.2, 0)), "k": 1})
		# пилястр — на каждую третью клетку, чтобы длинная стена получила членение
		if (int(f["x"]) * 7 + int(f["y"]) * 13) % 3 == 0:
			var pw := 0.56
			var pd := 0.2
			trim.append({"t": Transform3D(b0.scaled(Vector3(pw, top - 1.0, pd)),
				plane + n3 * (pd * 0.5 - 0.01) + Vector3(0, top * 0.5, 0)), "k": 2})
			trim.append({"t": Transform3D(b0.scaled(Vector3(pw + 0.2, 0.34, pd + 0.12)),
				plane + n3 * ((pd + 0.12) * 0.5 - 0.01) + Vector3(0, 0.67, 0)), "k": 0})
			trim.append({"t": Transform3D(b0.scaled(Vector3(pw + 0.2, 0.3, pd + 0.12)),
				plane + n3 * ((pd + 0.12) * 0.5 - 0.01) + Vector3(0, top - 0.62, 0)), "k": 1})
		# у самого пола каменная пыль и осколки: прямая линия «стена-пол»
		# разрушает геометрию быстрее, чем любая кладка
		for i in 3:
			var off := rng.randf_range(-0.85, 0.85)
			var ch: float = rng.randf_range(0.08, 0.2)
			chips.append({"t": Transform3D(
				Basis(Vector3.UP, rng.randf_range(0.0, PI)).scaled(
					Vector3(rng.randf_range(0.12, 0.3), ch, rng.randf_range(0.12, 0.3))),
				plane + tg * off + n3 * rng.randf_range(0.02, 0.14)
					+ Vector3(0, ch * 0.35, 0)), "c": rng.randf()})
	if trim.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var tmm := _multimesh(box, trim.size(), mat_cap)
	for i in trim.size():
		var t: Dictionary = trim[i]
		tmm.multimesh.set_instance_transform(i, t["t"])
		var warm: float = 0.06 if int(t["k"]) == 0 else 0.0
		tmm.multimesh.set_instance_color(i, Color(0.86 + warm, 0.84, 0.79 - warm))
	var cmm := _multimesh(box, chips.size(), mat_wall, false)
	for i in chips.size():
		var c: Dictionary = chips[i]
		cmm.multimesh.set_instance_transform(i, c["t"])
		var s2: float = 0.6 + float(c["c"]) * 0.4
		cmm.multimesh.set_instance_color(i, Color(s2 * 0.9, s2 * 0.88, s2 * 0.82))


## Каменные арки поперёк узких проходов: низкий плоский потолок — вторая
## половина «квадратности».
func _build_ribs() -> void:
	var parts: Array = []
	for y in map_h:
		for x in map_w:
			if grid[y][x] or int(dist[y][x]) != 1:
				continue
			if (x * 5 + y * 3) % 4 != 0:
				continue
			var ns: bool = is_wall(x, y - 1) and is_wall(x, y + 1)
			var ew: bool = is_wall(x - 1, y) and is_wall(x + 1, y)
			if not ns and not ew:
				continue
			var span: Vector3 = Vector3(0, 0, 1) if ns else Vector3(1, 0, 0)
			var h: float = ceil_h[y][x]
			var c := Vector3((x + 0.5) * T, h - 0.78, (y + 0.5) * T)
			var th: Vector3 = span.cross(Vector3.UP)
			# 16 сегментов вместо девяти: на девяти хорда по 0,8 м, а тело
			# ребра — 0,38 м, и арка разваливалась на лестницу из планок.
			for i in 17:
				var a: float = lerp(0.0, PI, i / 16.0)
				var rad := span * cos(a) + Vector3.UP * sin(a)
				var zz: Vector3 = th.cross(rad)
				parts.append(Transform3D(Basis(th, rad, zz).scaled(
					Vector3(0.3, 0.22, 0.34)),
					c + span * (cos(a) * T * 0.5) + Vector3.UP * (sin(a) * 0.62)))
	if parts.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mmi := _multimesh(box, parts.size(), mat_cap)
	for i in parts.size():
		mmi.multimesh.set_instance_transform(i, parts[i])
		# цвет у ребра один на всю арку: разброс по сегментам превращал
		# гладкую тягу в пёструю лесенку
		var k := i / 17
		var v: float = float((k * 7919) % 100) / 100.0
		mmi.multimesh.set_instance_color(i,
			Color(0.9, 0.87, 0.82).darkened(v * 0.16))


## Балки перекрытия: высокий свод без дерева выглядит гладкой плитой, а
## поперечные балки дают ритм и читаемую высоту. Ряд режем по ступеням свода:
## балка обязана идти под камнем своего уровня, иначе она прячется в плите.
func _build_beams() -> void:
	var parts: Array = []
	for y in map_h:
		if y % 3 != 1:
			continue
		var x := 0
		while x < map_w:
			if grid[y][x] or int(rdist[y][x]) < 3:
				x += 1
				continue
			var start := x
			var lv := float(ceil_h[y][x])
			while x < map_w and not grid[y][x] and int(rdist[y][x]) >= 3 \
					and absf(float(ceil_h[y][x]) - lv) < 0.01:
				x += 1
			if x - start < 2:
				continue
			parts.append({
				"pos": Vector3((start + x) * T * 0.5, lv - 0.16, (y + 0.5) * T),
				"size": Vector3((x - start) * T + 0.6, 0.26, 0.22),
			})
	if parts.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mmi := _multimesh(box, parts.size(), mat_wood, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in parts.size():
		var p: Dictionary = parts[i]
		var pos: Vector3 = p["pos"]
		mmi.multimesh.set_instance_transform(i,
			Transform3D(Basis().scaled(p["size"]), pos))
		mmi.multimesh.set_instance_color(i,
			Color(0.85, 0.8, 0.74).darkened(rng.randf() * 0.3))


## Отдельная опора в зале: восьмигранный столб из колон с базой и капителью.
## Полуразмеры не превышают прежнюю клетку-коробку, поэтому столб не торчит
## там, где раньше можно было пройти.
func _build_piers() -> void:
	for p0 in piers:
		var p: Dictionary = p0
		var rx: float = p["rx"]
		var rz: float = p["rz"]
		var top: float = p["top"]
		var root := Node3D.new()
		root.position = p["pos"]
		add_child(root)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(p["pos"].x * 31.0) * 7919 + int(p["pos"].z * 31.0) * 104729
		var sc := Vector3(rx * 0.99, 1.0, rz * 0.99)
		# база и капитель выступают максимум на 22 см: иначе игрок проходит
		# сквозь камень
		var bs := Vector3(minf(rx * 1.22, rx + 0.22), 1.0, minf(rz * 1.22, rz + 0.22))
		var cs := Vector3(minf(rx * 1.18, rx + 0.18), 1.0, minf(rz * 1.18, rz + 0.18))
		var plinth := MeshInstance3D.new()
		plinth.mesh = _prism(1.0, 0.34)
		plinth.material_override = mat_cap
		plinth.scale = bs
		plinth.position = Vector3(0, 0.17, 0)
		root.add_child(plinth)
		var base := MeshInstance3D.new()
		base.mesh = _prism(1.0, 0.22)
		base.material_override = mat_cap
		base.scale = bs * 0.92
		base.position = Vector3(0, 0.45, 0)
		root.add_child(base)
		var y := 0.56
		var drums: Array = []
		while y < top - 0.7:
			var h: float = minf(rng.randf_range(0.95, 1.5), top - 0.7 - y)
			if h < 0.35:
				break
			drums.append({"y": y + h * 0.5, "h": h, "s": rng.randf_range(-9.0, 9.0),
				"w": rng.randf_range(0.95, 1.0), "c": rng.randf()})
			y += h + 0.03
		# гранёный барабан можно довернуть только круглой опоре: прямоугольник
		# при повороте вылезает за пределы своего пятна
		var round_pier: bool = absf(rx - rz) < 0.05
		for d0 in drums:
			var d: Dictionary = d0
			var mi := MeshInstance3D.new()
			mi.mesh = _prism(1.0, float(d["h"]))
			var m: ShaderMaterial = mat_wall.duplicate() as ShaderMaterial
			var v: float = d["c"]
			m.set_shader_parameter("tint",
				Color(0.7 + v * 0.24, 0.68 + v * 0.22, 0.66 + v * 0.2))
			mi.material_override = m
			mi.scale = sc * float(d["w"])
			mi.position = Vector3(0, float(d["y"]), 0)
			mi.rotation_degrees = Vector3(0, 22.5 + (float(d["s"]) if round_pier else 0.0), 0)
			root.add_child(mi)
		# капитель: шайба и абака, упирающаяся в свод. Верх абаки совпадает с
		# верхом стены, иначе между колонной и плитой потолка остаётся щель.
		var ring := MeshInstance3D.new()
		ring.mesh = _prism(1.0, 0.2)
		ring.material_override = mat_cap
		ring.scale = cs
		ring.position = Vector3(0, top - 0.4, 0)
		root.add_child(ring)
		var abacus := MeshInstance3D.new()
		abacus.mesh = _prism(1.0, 0.3)
		abacus.material_override = mat_cap
		abacus.scale = cs * 1.12
		abacus.position = Vector3(0, top - 0.15, 0)
		root.add_child(abacus)


func _prism(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = maxf(h, 0.05)
	c.radial_segments = 8
	c.rings = 1
	return c


## Восьмигранный профиль опоры — ровно те же точки, что и у визуального
## столба, чтобы не было невидимых углов.
func _octagon_points(rx: float, rz: float, top: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in 8:
		var a: float = deg_to_rad(45.0 * k + 22.5)
		out.append(Vector3(cos(a) * rx, 0.0, sin(a) * rz))
		out.append(Vector3(cos(a) * rx, top, sin(a) * rz))
	return out


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
	# опоры: горизонтальный срез — восьмигранная призма, как и сама колонна
	for p0 in piers:
		var p: Dictionary = p0
		var rx: float = p["rx"]
		var rz: float = p["rz"]
		var origin: Vector3 = p["pos"]
		var plinth_shape := ConvexPolygonShape3D.new()
		plinth_shape.points = _octagon_points(
			minf(rx * 1.22, rx + 0.22), minf(rz * 1.22, rz + 0.22), 0.76)
		var pc := CollisionShape3D.new()
		pc.shape = plinth_shape
		pc.position = origin
		body.add_child(pc)
		var shaft_shape := ConvexPolygonShape3D.new()
		shaft_shape.points = _octagon_points(rx * 0.99, rz * 0.99, WALL_H)
		var sc := CollisionShape3D.new()
		sc.shape = shaft_shape
		sc.position = origin
		body.add_child(sc)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.37, 0.41, 0.52)
	env.ambient_light_energy = 0.70
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.10
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.1)
	env.fog_density = 0.018
	env.ssao_enabled = true
	# радиус 1,5 м в двухметровом коридоре затемняет почти всё: поверхность
	# считает себя закрытой наполовину, и ambient не достаёт ни до стены,
	# ни до потолка. Мягкая тень нужна на уровне швов, а не на уровне помещения.
	env.ssao_radius = 0.55
	env.ssao_intensity = 0.8
	# объёмный туман даёт световые конусы от факелов; плотность низкая,
	# чтобы не съедать fps на ноутбучной видеокарте
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.62, 0.66, 0.78)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# холодный заполняющий свет: без него коридор утопает в красно-коричневом
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.68, 0.85)
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-55.0, 32.0, 0.0)
	add_child(fill)


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
	light.light_energy = 5.0
	light.omni_range = 14.0
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
			_torch(pos)
		"brazier", "forge_fire":
			var root := Node3D.new()
			root.position = pos + Vector3(0, 0.6, 0)
			add_child(root)
			_cyl(0.42, 0.5, Vector3(0, 0.2, 0), mat_metal, root)
			var coals := _sphere(0.3, Vector3(0, 0.5, 0), mat_glow, root)
			coals.scale = Vector3(1, 0.4, 1)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.5, 0.2)
			light.light_energy = 4.0
			light.omni_range = 10.0
			light.shadow_enabled = true
			light.position = Vector3(0, 0.9, 0)
			root.add_child(light)
			lights.append({"light": light, "base": 3.2, "seed": randf() * 10.0, "flame": coals})
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
			for i in 7:
				var link := _cyl(0.07, 0.16, pos + Vector3(0, 3.4 - i * 0.22, 0), mat_metal)
				link.rotation_degrees = Vector3(0, 0, 90 if i % 2 else 0)
		"refuse":
			for i in 6:
				_sphere(0.25 + randf() * 0.12, pos + Vector3(randf_range(-0.5, 0.5), 0.15, randf_range(-0.5, 0.5)), mat_dark)
		"stairs":
			for i in 5:
				_box(Vector3(2.0, 0.22, 0.5), pos + Vector3(0, 0.11 + i * 0.22, -i * 0.5), mat_wall)
		"banner":
			_box(Vector3(0.04, 2.4, 1.0), pos + Vector3(0, 2.6, 0), mat_dark)
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
			_cyl(0.1, 1.0, pos + Vector3(0, 0.5, 0), mat_metal)
			_sphere(0.14, pos + Vector3(0, 1.05, 0), mat_glow)
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
			light.light_energy = 3.0
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
		# каменная облицовка и плинт выступают в проход на 20 см: предмет
		# у стены иначе тонет в камне
		pos += _wall_out(pos)
		_prop(type, pos)


## Насколько сдвинуть придверный реквизит от стены, чтобы предмет стоял перед
## новой каменной облицовкой, а не внутри неё.
func _wall_out(pos: Vector3) -> Vector3:
	var tx := int(floor(pos.x / T))
	var ty := int(floor(pos.z / T))
	for d in DIRS:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		if not _in(nx, ny) or not grid[ny][nx]:
			continue
		return Vector3(d.x, 0.0, d.y) * 0.32
	return Vector3.ZERO


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
			ranked[i]["l"].shadow_enabled = i < 3 and ranked[i]["d"] < 16.0


func _scatter_torches(max_count: int = 14) -> void:
	"""Ставит факелы вдоль стен, чтобы коридоры не были чёрными."""
	var placed := 0
	var step := 7
	for y in map_h:
		for x in map_w:
			if placed >= max_count:
				return
			if grid[y][x]:
				continue
			# нормаль стены: факел придвигается вплотную к новому каменному
			# лицу, а не втыкается в него древком
			var out := Vector3.ZERO
			if y > 0 and grid[y - 1][x]:
				out = Vector3(0, 0, -1)
			elif y < map_h - 1 and grid[y + 1][x]:
				out = Vector3(0, 0, 1)
			elif x > 0 and grid[y][x - 1]:
				out = Vector3(-1, 0, 0)
			elif x < map_w - 1 and grid[y][x + 1]:
				out = Vector3(1, 0, 0)
			if out == Vector3.ZERO:
				continue
			if (x * 5 + y * 11) % step != 0:
				continue
			var pos := cell_center(x, y) + out * (T * 0.5 - 0.3)
			_torch(pos)
			# у декоративных факелов тени отключаем: иначе теневой атлас
			# переполняется и свет пропадает
			if lights.size() > 0:
				lights[lights.size() - 1]["light"].shadow_enabled = false
			placed += 1


func _dress_rooms() -> void:
	var spots := {
		"shelf": [Vector3(20, 0, 60), Vector3(60, 0, 52), Vector3(96, 0, 40)],
		"bed": [Vector3(24, 0, 62), Vector3(100, 0, 36), Vector3(88, 0, 30)],
		"rubble": [Vector3(34, 0, 58), Vector3(70, 0, 50), Vector3(50, 0, 40), Vector3(104, 0, 46)],
		"rack": [Vector3(30, 0, 50), Vector3(86, 0, 34), Vector3(45, 0, 28)],
		"pillar": [Vector3(38, 0, 54), Vector3(66, 0, 48), Vector3(78, 0, 42)],
		"arch": [Vector3(48, 0, 50), Vector3(58, 0, 44)],
	}
	for kind in spots.keys():
		for pos in spots[kind]:
			_prop(kind, pos + _wall_out(pos))
