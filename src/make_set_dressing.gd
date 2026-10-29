extends SceneTree
## Сборка библиотеки реквизита и декалей (Этап 8).
##
## Источники — CC0-модели Poly Haven в res://assets/props3d/<id>/ и текстуры
## ambientCG / пака в tools/assets_incoming (см. assets/CREDITS.md).
## На выходе:
##   res://scenes/props/<имя>.tscn   — одна сцена на предмет, группа "prop"
##   res://textures/decals/*.png      — маски декалей
##   res://scenes/decals/<имя>.tscn  — сцены декалей
##
## Запуск (после импорта ассетов):
##   godot --headless --path . --script res://src/make_set_dressing.gd
##   ... -- --probe   — только напечатать габариты моделей, ничего не писать

const PROP_SCRIPT := "res://scenes/props/prop.gd"
const DIR_PROPS := "res://scenes/props"
const DIR_DECALS := "res://scenes/decals"
const DIR_TEX := "res://textures/decals"
const SRC_ACG := "res://tools/assets_incoming/stage8_cc0/ambientcg"
const SAND_TEX := "res://assets/models/dungeon_kit/textures/sand_basecolor.jpg"

enum { LARGE, MEDIUM, SMALL, DEBRIS }

## имя сцены: [id модели, класс, поворот модели в градусах, меш-часть]
## Поворот кладёт длинные предметы (топор, булава) на пол: в модели они стоят.
## Меш-часть — суффикс имени узла: наборы Poly Haven (бочки с обломками,
## камни) разложены по площадке в несколько метров, из них берём по предмету.
const PROPS := {
	"barrel_wine": ["wine_barrel_01", LARGE, Vector3.ZERO, ""],
	"barrel_a": ["wooden_barrels_01", LARGE, Vector3.ZERO, "barrel01"],
	"barrel_b": ["wooden_barrels_01", LARGE, Vector3.ZERO, "barrel02"],
	"plank_a": ["wooden_barrels_01", DEBRIS, Vector3.ZERO, "piece01"],
	"plank_b": ["wooden_barrels_01", DEBRIS, Vector3.ZERO, "piece03"],
	"plank_c": ["wooden_barrels_01", DEBRIS, Vector3.ZERO, "piece08"],
	"plank_d": ["wooden_barrels_01", DEBRIS, Vector3.ZERO, "piece10"],
	"plank_e": ["wooden_barrels_01", DEBRIS, Vector3.ZERO, "piece15"],
	"crate_long": ["wooden_crate_02", LARGE, Vector3.ZERO, ""],
	"crate_low": ["wooden_crate_01", MEDIUM, Vector3.ZERO, ""],
	"shelf_wall": ["Shelf_01", LARGE, Vector3.ZERO, ""],
	"bookshelf": ["wooden_bookshelf_worn", LARGE, Vector3.ZERO, ""],
	"table": ["WoodenTable_01", LARGE, Vector3.ZERO, ""],
	"table_round": ["round_wooden_table_01", LARGE, Vector3.ZERO, ""],
	"stool": ["wooden_stool_01", MEDIUM, Vector3.ZERO, ""],
	"bucket": ["wooden_bucket_01", MEDIUM, Vector3.ZERO, ""],
	"bucket_b": ["wooden_bucket_02", MEDIUM, Vector3.ZERO, ""],
	"pot": ["ceramic_pot", MEDIUM, Vector3.ZERO, ""],
	"shield": ["kite_shield", MEDIUM, Vector3.ZERO, ""],
	"jug": ["jug_01", SMALL, Vector3.ZERO, ""],
	"bowl": ["wooden_bowl_01", SMALL, Vector3.ZERO, ""],
	"plate": ["carved_wooden_plate", SMALL, Vector3.ZERO, ""],
	"candle": ["wooden_candlestick", SMALL, Vector3.ZERO, ""],
	"lantern": ["wooden_lantern_01", SMALL, Vector3.ZERO, ""],
	"axe": ["wooden_axe", SMALL, Vector3(90, 0, 0), ""],
	"mace": ["ornate_medieval_mace", SMALL, Vector3(90, 0, 0), ""],
	"stone": ["rock_07", DEBRIS, Vector3.ZERO, ""],
	"boulder_a": ["rock_moss_set_01", LARGE, Vector3.ZERO, "rock01"],
	"boulder_b": ["rock_moss_set_01", LARGE, Vector3.ZERO, "rock02"],
	"boulder_c": ["rock_moss_set_01", LARGE, Vector3.ZERO, "rock05"],
	"rock_a": ["rock_moss_set_02", MEDIUM, Vector3.ZERO, "rock08"],
	"rock_b": ["rock_moss_set_02", MEDIUM, Vector3.ZERO, "rock09"],
	"rock_c": ["rock_moss_set_02", MEDIUM, Vector3.ZERO, "rock12"],
	"rock_d": ["rock_moss_set_02", MEDIUM, Vector3.ZERO, "rock07"],
}


func _init() -> void:
	var probe := "--probe" in OS.get_cmdline_user_args()
	for prop_name in PROPS:
		var def: Array = PROPS[prop_name]
		var path := "res://assets/props3d/%s/%s_1k.gltf" % [def[0], def[0]]
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("нет модели " + path)
			continue
		var model: Node3D = packed.instantiate()
		if def[3] != "":
			model = _part_model(model, def[0], def[3])
		model.rotation_degrees = def[2]
		var box := _aabb(model, Transform3D(Basis.from_euler(model.rotation), Vector3.ZERO))
		print("PROP %-13s %-22s size=(%.2f, %.2f, %.2f) meshes=%d" % [prop_name, def[0],
			box.size.x, box.size.y, box.size.z,
			model.find_children("*", "MeshInstance3D", true, false).size()])
		if probe:
			model.free()
			continue
		_save_prop(prop_name, model, box, def[1])
	if not probe:
		_make_decals()
	quit()


## Один меш-узел набора (по суффиксу имени) как отдельная модель. Удалить
## лишние узлы у вложенной glTF-сцены нельзя — при сохранении они вернутся,
## поэтому меш части пишется в свой .res, а модель собирается заново.
func _part_model(full: Node3D, id: String, part: String) -> Node3D:
	var out := Node3D.new()
	for n in full.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not String(mi.name).ends_with(part):
			continue
		var dir := "res://assets/props3d/%s/parts" % id
		DirAccess.make_dir_recursive_absolute(dir)
		var res_path := "%s/%s.res" % [dir, part]
		ResourceSaver.save(mi.mesh, res_path)
		var copy := MeshInstance3D.new()
		copy.name = part.to_pascal_case()
		copy.mesh = load(res_path)
		# поворот и масштаб узла сохраняем, сдвиг по площадке набора — нет
		copy.basis = (full.global_transform.affine_inverse() * mi.global_transform).basis \
			if mi.is_inside_tree() else mi.basis
		out.add_child(copy)
	full.free()
	return out


## AABB всех мешей поддерева в системе координат родителя модели.
func _aabb(root: Node3D, root_xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := root_xf
		var chain: Array[Node3D] = []
		var cur: Node = mi
		while cur != root:
			chain.push_front(cur as Node3D)
			cur = cur.get_parent()
		for c in chain:
			xf = xf * c.transform
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _save_prop(prop_name: String, model: Node3D, box: AABB, size_class: int) -> void:
	var root: Node3D
	if size_class == LARGE or size_class == MEDIUM:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = prop_name.to_pascal_case()
	root.set_script(load(PROP_SCRIPT))
	root.set("size_class", size_class)
	root.set("footprint", box.size)
	root.add_to_group("prop", true)
	# низ AABB — на пол, центр — на ось Y
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	if model.scene_file_path.is_empty():
		for c in model.get_children():
			c.owner = root
	if root is StaticBody3D:
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		var shape := BoxShape3D.new()
		# коробка чуть уже модели: ручки и выступы не цепляют героя
		shape.size = Vector3(box.size.x * 0.92, box.size.y, box.size.z * 0.92)
		cs.shape = shape
		cs.position = Vector3(0, box.size.y * 0.5, 0)
		root.add_child(cs)
		cs.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var out := "%s/%s.tscn" % [DIR_PROPS, prop_name]
	if ResourceSaver.save(ps, out) != OK:
		push_error("не сохранить " + out)
	root.free()


# ---------------------------------------------------------------------------
# декали

func _make_decals() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_DECALS)
	var acg := ProjectSettings.globalize_path(SRC_ACG)
	var smear := Image.load_from_file(acg + "/Leaking006/Leaking006_1K-JPG_Opacity.jpg")
	var moss := Image.load_from_file(acg + "/Moss002/Moss002_1K-JPG_Color.jpg")
	var moss_n := Image.load_from_file(acg + "/Moss002/Moss002_1K-JPG_NormalGL.jpg")
	# headless-рендер не отдаёт пиксели импортированных текстур: читаем файл
	var sand_img := Image.load_from_file(ProjectSettings.globalize_path(SAND_TEX))

	# Копоть и сырость: мазок Leaking006 — напыление из точек, сам по себе на
	# кладке читается пунктиром. Берём его размытым как неровность внутри
	# мягкого «шлейфа»: копоть сужается к пламени внизу, потёк — к источнику вверху.
	_save_png(_plume(smear, Color(0.02, 0.018, 0.016), 0.92, true), "soot_streak")
	_save_png(_plume(smear, Color(0.05, 0.056, 0.05), 0.7, false), "damp_streak")
	_save_png(_textured_blot(moss, 512, 11, 0.55, 1.6), "moss_patch")
	moss_n.resize(512, 512)
	_save_png(moss_n, "moss_normal")
	_save_png(_textured_blot(sand_img, 512, 23, 0.45, 1.0, Color(0.55, 0.5, 0.45)), "dirt_patch")
	for i in 3:
		_save_png(_crack(512, 101 + i * 17), "crack_%d" % i)

	_decal_scene("soot_streak", Vector3(0.8, 0.5, 1.0), ["soot_streak"], 1.0)
	_decal_scene("damp_streak", Vector3(0.7, 0.5, 1.6), ["damp_streak"], 1.0)
	_decal_scene("moss_patch", Vector3(1.4, 0.5, 0.7), ["moss_patch", "moss_normal"], 1.0)
	_decal_scene("dirt_patch", Vector3(1.2, 0.4, 1.2), ["dirt_patch"], 1.0)
	_decal_scene("crack_wall", Vector3(1.0, 0.5, 1.0), ["crack_0"], 1.0)
	_decal_scene("crack_floor", Vector3(1.2, 0.4, 1.2), ["crack_1"], 1.0)


## Шлейф: гаусс по ширине, расширяется к «дальнему» концу; внутри —
## размытый мазок как неровность. narrow_bottom — узкий конец внизу (копоть).
func _plume(mask: Image, c: Color, max_a: float, narrow_bottom: bool) -> Image:
	var m := mask.duplicate() as Image
	m.convert(Image.FORMAT_L8)
	if narrow_bottom:
		m.flip_y()
	var w := m.get_width()
	var h := m.get_height()
	m.resize(w / 8, h / 8, Image.INTERPOLATE_BILINEAR)
	m.resize(w, h, Image.INTERPOLATE_CUBIC)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / float(h - 1)
		# far — 0 у узкого конца, 1 у широкого
		var far := 1.0 - v if narrow_bottom else v
		var hw := 0.1 + 0.3 * far
		var fade := smoothstep(1.0, 0.72, far) * smoothstep(0.0, 0.06, far)
		var dens := 1.0 - 0.45 * far
		for x in w:
			var u := (float(x) / float(w - 1) - 0.5) / hw
			var g := exp(-u * u * 2.2)
			var a := g * fade * dens * (0.55 + 0.9 * m.get_pixel(x, y).r)
			out.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, max_a)))
	return out


## Пятно с рваным краем: цвет из текстуры, альфа — шум с мягким спадом к краю.
## sx > 1 вытягивает пятно по горизонтали (мох у основания стены).
func _textured_blot(src: Image, size: int, seed_v: int, cover: float, sx: float,
		tint := Color(1, 1, 1)) -> Image:
	var tex := src.duplicate() as Image
	tex.convert(Image.FORMAT_RGB8)
	tex.resize(size, size)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) / size - 0.5) * 2.0
			var v := (float(y) / size - 0.5) * 2.0
			var r := sqrt(u * u + v * v * sx * sx) if sx > 1.0 else sqrt(u * u + v * v)
			var fall := clampf(1.0 - r, 0.0, 1.0)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((fall * 1.4 + n - 1.0 + cover * 0.5) * 2.2, 0.0, 1.0)
			var c := tex.get_pixel(x, y) * tint
			out.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return out


## Трещина: ломаная из главной ветви и отростков, тёмная с мягким ореолом.
func _crack(size: int, seed_v: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var alpha := PackedFloat32Array()
	alpha.resize(size * size)
	var branches: Array = [[Vector2(size * 0.5, size * 0.04), PI * 0.5, 1.0, 0]]
	while not branches.is_empty():
		var b: Array = branches.pop_back()
		var p: Vector2 = b[0]
		var ang: float = b[1]
		var width: float = b[2]
		var depth: int = b[3]
		var steps := int(size * (0.9 if depth == 0 else 0.35) / 6.0)
		for i in steps:
			ang += rng.randf_range(-0.45, 0.45)
			ang = lerpf(ang, PI * 0.5, 0.08)
			var np := p + Vector2(cos(ang), sin(ang)) * 6.0
			_stroke(alpha, size, p, np, maxf(width * 3.2, 1.1))
			p = np
			width *= 0.985
			if depth < 2 and rng.randf() < 0.07:
				branches.append([p, ang + rng.randf_range(0.6, 1.1) * (1 if rng.randf() < 0.5 else -1),
					width * 0.6, depth + 1])
			if p.x < 4 or p.y < 4 or p.x > size - 4 or p.y > size - 4:
				break
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			out.set_pixel(x, y, Color(0.02, 0.018, 0.016, alpha[y * size + x]))
	return out


func _stroke(alpha: PackedFloat32Array, size: int, a: Vector2, b: Vector2, r: float) -> void:
	var halo := r * 2.5
	var minx := int(maxf(minf(a.x, b.x) - halo, 0))
	var maxx := int(minf(maxf(a.x, b.x) + halo, size - 1))
	var miny := int(maxf(minf(a.y, b.y) - halo, 0))
	var maxy := int(minf(maxf(a.y, b.y) + halo, size - 1))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			var p := Vector2(x, y)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			# ядро трещины плотное, ореол — лёгкое загрязнение по краю
			var v := 0.95 if d <= r * 0.5 else clampf(0.35 * (1.0 - (d - r * 0.5) / halo), 0.0, 0.35)
			var i := y * size + x
			alpha[i] = maxf(alpha[i], v)


func _save_png(img: Image, file_name: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s.png" % [DIR_TEX, file_name])
	if img.save_png(path) != OK:
		push_error("не сохранить " + path)


## Сцена декали. Настройки как у луж этапа 5: normal_fade 0.5, только слой 1
## (персонажи на слое 2 — ModelUtil.CHARACTER_LAYER), гаснет вдали.
## Текстуры подключаются по пути: после первого прогона нужен импорт.
func _decal_scene(scene_name: String, size_v: Vector3, tex: Array, mix: float) -> void:
	var d := Decal.new()
	d.name = scene_name.to_pascal_case()
	d.size = size_v
	var albedo_path := "%s/%s.png" % [DIR_TEX, tex[0]]
	if ResourceLoader.exists(albedo_path):
		d.texture_albedo = load(albedo_path)
	if tex.size() > 1 and ResourceLoader.exists("%s/%s.png" % [DIR_TEX, tex[1]]):
		d.texture_normal = load("%s/%s.png" % [DIR_TEX, tex[1]])
	d.albedo_mix = mix
	d.normal_fade = 0.5
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.cull_mask = 1
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 8.0
	d.add_to_group("decal", true)
	var ps := PackedScene.new()
	ps.pack(d)
	ResourceSaver.save(ps, "%s/%s.tscn" % [DIR_DECALS, scene_name])
	d.free()
