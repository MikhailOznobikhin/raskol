extends Node3D
## 3D-подземелье: пол, стены, потолок, свет и реквизит из карты m1.txt.

class_name Dungeon

const T := 2.0
const WALL_H := 4.2

var lines: Array = []
var map_w := 0
var map_h := 0
var grid: Array = []

var mat_floor: StandardMaterial3D
var mat_wall: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_dark: StandardMaterial3D
var mat_glow: StandardMaterial3D
var lights: Array = []
var flames: Array = []
var shadow_t := 0.0


func build() -> void:
	_materials()
	_load_map()
	_build_floor()
	_build_walls()
	_build_ceiling()
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
		m.normal_scale = 1.2
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
	mat_floor = _make_mat("stone_floor", Color(0.92, 0.94, 1.0), 0.85, 0.0, 0.45)
	mat_wall = _make_mat("stone_wall", Color(0.86, 0.88, 0.95), 0.9, 0.0, 0.4)
	mat_metal = _make_mat("metal", Color(0.8, 0.82, 0.9), 0.45, 0.85, 1.2)
	mat_wood = _make_mat("wood", Color(0.9, 0.85, 0.8), 0.8, 0.0, 1.0)
	mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.05, 0.05, 0.06)
	mat_dark.roughness = 0.95
	mat_glow = StandardMaterial3D.new()
	mat_glow.albedo_color = Color(0.9, 0.4, 0.2)
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(1.0, 0.45, 0.15)
	mat_glow.emission_energy_multiplier = 4.0


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


func _multimesh(mesh: Mesh, count: int, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := mat.duplicate() as StandardMaterial3D
	if m:
		m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	add_child(mmi)
	return mmi


func _build_floor() -> void:
	var cells: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if not grid[y][x]:
				cells.append(Vector2i(x, y))
	var box := BoxMesh.new()
	box.size = Vector3(T, 0.3, T)
	var mmi := _multimesh(box, cells.size(), mat_floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in cells.size():
		var c := cells[i]
		var pos := Vector3((c.x + 0.5) * T, -0.15, (c.y + 0.5) * T)
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		mmi.multimesh.set_instance_color(i, Color(0.85, 0.87, 0.95).darkened(rng.randf() * 0.18))


func _build_ceiling() -> void:
	var cells: Array[Vector2i] = []
	for y in map_h:
		for x in map_w:
			if not grid[y][x]:
				cells.append(Vector2i(x, y))
	var box := BoxMesh.new()
	box.size = Vector3(T, 0.3, T)
	var mmi := _multimesh(box, cells.size(), mat_wall)
	for i in cells.size():
		var c := cells[i]
		var pos := Vector3((c.x + 0.5) * T, WALL_H + 0.15, (c.y + 0.5) * T)
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		mmi.multimesh.set_instance_color(i, Color(0.7, 0.72, 0.8))


func _build_walls() -> void:
	var count := 0
	for y in map_h:
		for x in map_w:
			if grid[y][x]:
				count += 1
	var box := BoxMesh.new()
	box.size = Vector3(T, WALL_H, T)
	var mmi := _multimesh(box, count, mat_wall)
	var idx := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in map_h:
		for x in map_w:
			if not grid[y][x]:
				continue
			var pos := Vector3((x + 0.5) * T, WALL_H * 0.5, (y + 0.5) * T)
			mmi.multimesh.set_instance_transform(idx, Transform3D(Basis(), pos))
			mmi.multimesh.set_instance_color(idx, Color(0.8, 0.82, 0.9).darkened(rng.randf() * 0.22))
			idx += 1


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
			if grid[y][x]:
				var start := x
				while x < map_w and grid[y][x]:
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


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.56)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.1)
	env.fog_density = 0.02
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.5, 0.55, 0.7)
	env.volumetric_fog_emission_energy = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


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


func _torch(pos: Vector3) -> void:
	# стоящий факел: древко от пола, чаша, пламя и тёплый свет
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_cyl(0.05, 1.9, Vector3(0, 0.95, 0), mat_wood, root)
	_cyl(0.22, 0.12, Vector3(0, 0.06, 0), mat_metal, root)
	var bowl := _cyl(0.17, 0.24, Vector3(0, 1.9, 0), mat_metal, root)
	var flame := MeshInstance3D.new()
	var fmesh := SphereMesh.new()
	fmesh.radius = 0.16
	fmesh.height = 0.52
	flame.mesh = fmesh
	flame.material_override = mat_glow
	flame.position = Vector3(0, 2.12, 0)
	root.add_child(flame)
	flames.append(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 5.0
	light.omni_range = 14.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = true
	light.position = Vector3(0, 2.2, 0)
	root.add_child(light)
	lights.append({"light": light, "base": 4.2, "seed": randf() * 10.0, "flame": flame})


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
	for p in data.get("props", []):
		var type: String = p.get("type", "")
		if type in ["bones", "straw_bed", "bucket", "winch", "bars"]:
			continue
		var pos := Vector3(float(p.get("x", 0)) / 32.0 * T, 0.0, float(p.get("y", 0)) / 32.0 * T)
		_prop(type, pos)


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
			var near_wall := false
			if y > 0 and grid[y - 1][x]:
				near_wall = true
			if y < map_h - 1 and grid[y + 1][x]:
				near_wall = true
			if not near_wall:
				continue
			if (x * 5 + y * 11) % step != 0:
				continue
			var pos := Vector3((x + 0.5) * T, 0.0, (y + 0.35) * T if y > 0 and grid[y - 1][x] else (y + 0.65) * T)
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
	}
	for kind in spots.keys():
		for pos in spots[kind]:
			_prop(kind, pos)
