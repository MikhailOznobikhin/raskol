class_name SetDressing
extends Node3D
## Этап 8: реквизит, декали и рёбра свода по комнатам M1.
##
## У каждой комнаты одна строка истории («кто здесь был и что случилось»),
## и реквизит подобран под неё из библиотеки res://scenes/props/ (CC0-модели
## Poly Haven, собирает src/make_set_dressing.gd). Правила расстановки:
##   - предметы стоят у стен и в углах: крупные и средние прижаты к кладке,
##     глубина ряда не больше 1 м; стена берётся только там, где поперёк
##     комнаты не меньше двух клеток (4 м), — проход остаётся шире 1.5 м;
##   - кластер = 1 крупный + 2 средних + 2–4 мелких; поворот ±15° у
##     стоячих, любой у обломков; масштаб ±10 %;
##   - у основания стен щебень и пыль на ~40 % длины кладки (MultiMesh);
##   - копоть над каждым настенным факелом, трещины, потёки, мох, грязь в углах;
##   - в больших залах — каменные рёбра свода через 3.5 м.
## Расстановка детерминированная: всё случайное берётся из хеша клетки.

const PROP_DIR := "res://scenes/props/"
const DECAL_DIR := "res://scenes/decals/"
## Зазор между предметом и лицом кладки (у кладки рельеф).
const WALL_GAP := 0.06
## Ряд у стены: дальняя грань предмета не дальше этого от кладки.
const ROW_DEPTH := 1.05
## Ширина прохода, которую нельзя занимать.
const PATH_MIN := 1.5
## Доля граней кладки со щебнем у основания (хеш < SEAM_PERCENT).
const SEAM_PERCENT := 42
const RIB_STEP := 3.5
const DEBRIS_TILE := 4
## Визуальный слой реквизита: декали (cull_mask = 1) его не красят.
const PROP_LAYER := 3

## Комнаты: прямоугольник клеток [x0, y0, x1, y1] включительно. Клетка
## принадлежит первой комнате списка, в чей прямоугольник попала.
## kits — наборы кластеров по очереди; clusters — сколько кластеров на
## каждые 10 клеток у стен; objective — у цели только мелочь и средние.
const ROOMS := [
	{"id": "start_cell", "rect": [4, 27, 9, 31], "kits": ["cell"], "density": 0.5,
		"objective": true,
		"story": "Камера Торвина: его приковали к решётке; в дальнем углу ведро, миска и обломки нар, всё остальное стража вынесла."},
	{"id": "prison_cells", "rect": [12, 27, 25, 31], "kits": ["cell", "cell_broken"], "density": 0.8,
		"story": "Камеры пленников: миски и кувшины у стен, ведро вместо отхожего места, нары разломаны на дрова."},
	{"id": "guard_corridor", "rect": [3, 22, 31, 25], "kits": ["guard", "storage"], "density": 0.7,
		"story": "Коридор перед камерами — пост охраны: стол у стены с кувшином и мисками, табуреты, щит и булава под рукой."},
	{"id": "forge_store", "rect": [3, 13, 11, 20], "kits": ["forge_store", "storage"], "density": 1.0,
		"story": "Рудный склад кузни: ящики и бочки с рудой и углём, вёдра воды для закалки."},
	{"id": "forge", "rect": [12, 9, 36, 21], "kits": ["forge", "storage", "broken"], "density": 0.8,
		"story": "Кузня у подъёмника: оружие ждёт починки у стены, ящики с заготовками, разбитая тара после спешных сборов.",
		"ribs": true},
	{"id": "shaft", "rect": [25, 2, 33, 8], "kits": ["storage", "broken"], "density": 1.0,
		"story": "Подъёмник шахты: сюда свозили груз для подъёма — ящики и бочки у стен, одна разбилась при погрузке, брошен фонарь."},
	{"id": "barracks", "rect": [37, 11, 56, 20], "kits": ["barracks_mess", "barracks", "barracks_arms", "storage"], "density": 0.9,
		"story": "Казарма: столы с посудой и свечами после ужина, табуреты, полки со скарбом, оружие у стен.",
		"ribs": true},
	{"id": "kitchen", "rect": [26, 22, 56, 31], "kits": ["kitchen", "storage", "kitchen"], "density": 0.8,
		"story": "Кухня и трапезная гарнизона: котёл, стол с горшками и мисками, бочки вина, ящики провизии.",
		"ribs": true},
	{"id": "cistern", "rect": [57, 15, 75, 20], "kits": ["flooded", "flooded_rot"], "density": 0.9,
		"damp": true,
		"story": "Затопленная цистерна: вода поднялась и сгноила запасы — разбухшие бочки и ящики, вёдра, мох и потёки на стенах."},
	{"id": "lower_mine", "rect": [37, 32, 64, 41], "kits": ["collapse", "broken", "collapse"], "density": 0.9,
		"damp": true, "ribs": true,
		"story": "Нижняя выработка после обвала: камни и щебень у стен, разбитые бочки, брошенный топор."},
]

## Наборы кластеров: large — один, medium — два, small — 2–4 штуки;
## top — мелочь на крышку крупного (стол); span — минимум клеток поперёк.
const KITS := {
	"cell": {"large": [], "medium": ["bucket", "bucket_b"], "small": ["bowl", "jug", "plank_c", "plank_d"]},
	"cell_broken": {"large": [], "medium": ["plank_a", "plank_b", "bucket"],
		"small": ["plank_c", "plank_d", "plank_e", "bowl", "stone"]},
	"guard": {"large": ["table"], "medium": ["stool", "shield"], "small": ["mace", "stone"],
		"top": ["jug", "bowl", "plate", "candle"]},
	"storage": {"large": ["crate_long", "barrel_a", "barrel_wine", "barrel_b"],
		"medium": ["crate_low", "bucket", "pot"], "small": ["plank_c", "plank_d", "stone", "jug"]},
	"broken": {"large": ["barrel_b", "crate_long"], "medium": ["plank_a", "plank_b", "crate_low"],
		"small": ["plank_c", "plank_d", "plank_e", "stone"]},
	"forge_store": {"large": ["crate_long", "barrel_wine"], "medium": ["bucket_b", "crate_low", "bucket"],
		"small": ["stone", "plank_d", "stone"]},
	"forge": {"large": ["crate_long", "barrel_a"], "medium": ["shield", "bucket_b", "crate_low"],
		"small": ["axe", "mace", "stone"]},
	"barracks_mess": {"large": ["table", "table_round"], "medium": ["stool", "crate_low"],
		"small": ["jug", "stone"], "top": ["jug", "bowl", "plate", "candle"]},
	"barracks": {"large": ["bookshelf", "shelf_wall"], "medium": ["stool", "crate_low", "pot"],
		"small": ["lantern", "jug", "bowl", "candle"]},
	"barracks_arms": {"large": ["crate_long"], "medium": ["shield", "stool"], "small": ["axe", "mace", "lantern"]},
	"kitchen": {"large": ["table", "barrel_wine"], "medium": ["pot", "bucket", "crate_low", "stool"],
		"small": ["bowl", "plate", "jug"], "top": ["bowl", "plate", "jug", "candle"]},
	"flooded": {"large": ["barrel_a", "crate_long"], "medium": ["bucket_b", "bucket", "plank_a"],
		"small": ["plank_c", "plank_d", "stone"]},
	"flooded_rot": {"large": ["barrel_b"], "medium": ["plank_b", "crate_low"], "small": ["plank_e", "plank_d", "bowl"]},
	"collapse": {"large": ["boulder_a", "boulder_b", "boulder_c"], "medium": ["rock_a", "rock_b", "rock_c", "rock_d"],
		"small": ["stone", "plank_d", "axe"]},
}

## Камни наборов Poly Haven по 1–3 м: в подземелье это обломки свода.
const BASE_SCALE := {
	"boulder_a": 0.3, "boulder_b": 0.3, "boulder_c": 0.32,
	"rock_a": 0.45, "rock_b": 0.4, "rock_c": 0.4, "rock_d": 0.4,
}
## Предметы без «верха»: им любой поворот (обломки лежат как упали).
const DEBRIS := ["plank_a", "plank_b", "plank_c", "plank_d", "plank_e", "stone", "axe", "mace",
	"rock_a", "rock_b", "rock_c", "rock_d", "boulder_a", "boulder_b", "boulder_c"]

var d: Dungeon
var _packed := {}
var _foot := {}
## Занятые места: {pos, r, solid}
var _placed: Array = []
## Предметы с коллизией у стены — для проверки прохода.
var solids: Array = []
var _room_of := {}
var _debris := {}
var _debris_mesh := {}
var counts := {"props": 0, "decals": 0, "soot": 0, "seam_faces": 0, "faces": 0,
	"debris": 0, "ribs": 0, "corners": 0}
var room_log: Array[String] = []
## Ракурсы для фототура (SHOT_DRESS=1): {name, from, to} — по кадру на комнату.
var views: Array = []


func dress(dungeon: Dungeon) -> void:
	d = dungeon
	name = "SetDressing"
	_assign_rooms()
	for room in ROOMS:
		_dress_room(room)
	_seam_debris()
	_flush_debris()
	_soot()
	_wall_grime()
	_corner_dirt()
	_ceiling_ribs()
	for line in room_log:
		print(line)
	print("DRESS props=%d decals=%d soot=%d seam=%d/%d (%.0f%%) debris=%d ribs=%d corners=%d" % [
		counts["props"], counts["decals"], counts["soot"], counts["seam_faces"], counts["faces"],
		100.0 * counts["seam_faces"] / maxf(1.0, counts["faces"]), counts["debris"],
		counts["ribs"], counts["corners"]])


# ---------------------------------------------------------------------------
# комнаты

func _assign_rooms() -> void:
	for i in ROOMS.size():
		var r: Array = ROOMS[i]["rect"]
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				var c := Vector2i(x, y)
				if d._is_open_cell(c) and not _room_of.has(c):
					_room_of[c] = i


func _room_cells(index: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _room_of:
		if _room_of[c] == index:
			out.append(c)
	out.sort()
	return out


func _dress_room(room: Dictionary) -> void:
	var index := ROOMS.find(room)
	var cells := _room_cells(index)
	var slots := _wall_slots(cells)
	var seeds := _seeds_in(cells)
	var kits: Array = room["kits"]
	var want := maxi(1, int(round(slots.size() / 10.0 * float(room["density"]) * 2.0)))
	var anchors := _pick_anchors(slots, seeds, want, 4.5)
	var before: int = counts["props"]
	if not anchors.is_empty():
		_add_view(room["id"], anchors[0])
	for i in anchors.size():
		var kit: Dictionary = KITS[kits[i % kits.size()]]
		_cluster(anchors[i], kit, room.get("objective", false), index * 1000 + i)
	room_log.append("DRESS room=%s clusters=%d props=%d | %s" % [
		room["id"], anchors.size(), counts["props"] - before, room["story"]])


## Места у стен. Слот — грань открытой клетки, за которой стена; соседние
## клетки вдоль стены тоже упираются в кладку (не край проёма), а поперёк
## комнаты не меньше двух открытых клеток.
func _wall_slots(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for c in cells:
		for dd in Dungeon.DIRS:
			var w: Vector2i = c + dd
			if not d._in(w.x, w.y) or not d.is_wall(w.x, w.y) or d.pier[w.y][w.x]:
				continue
			var t := Vector2i(-dd.y, dd.x)
			var left := _wall_runs(c + t, dd)
			var right := _wall_runs(c - t, dd)
			var corner := 0
			if not left and not right:
				continue
			if not left or not right:
				# угол: соседняя клетка вдоль стены — сама стена
				var side := t if not left else -t
				if not d.is_wall(c.x + side.x, c.y + side.y):
					continue
				corner = 1 if side == t else -1
			var span := 1
			while span < 6 and d._is_open_cell(c - dd * span):
				span += 1
			if span < 2:
				continue
			var face: Vector3 = d._face_xform([c + dd], -dd).origin
			out.append({"cell": c, "dir": dd, "t": t, "corner": corner, "span": span,
				"face": Vector3(face.x, 0.0, face.z), "n": Vector3(-dd.x, 0, -dd.y),
				"tan": Vector3(t.x, 0, t.y)})
	return out


func _wall_runs(c: Vector2i, dd: Vector2i) -> bool:
	return d._is_open_cell(c) and d.is_wall(c.x + dd.x, c.y + dd.y)


## Старые точки бочек/ящиков/столов из m1_props.json — затравки кластеров.
func _seeds_in(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for s in d.legacy_seeds:
		var c := d._nearest_open_cell(s["pos"])
		if c in cells:
			out.append(s)
	return out


## Якоря кластеров: сначала слоты у затравок, потом у факелов (1.5–5 м —
## предмет освещён, но не стоит под огнём), потом остальные по хешу;
## друг от друга не ближе spacing.
func _pick_anchors(slots: Array, seeds: Array, want: int, spacing: float) -> Array:
	var order: Array = []
	for s in seeds:
		var best := {}
		var best_d := 9.0
		for slot in slots:
			var dist: float = (slot["face"] as Vector3).distance_to(s["pos"])
			if dist < best_d:
				best_d = dist
				best = slot
		if not best.is_empty():
			order.append(best)
	var torches := _wall_torches()
	var lit := func(slot: Dictionary) -> int:
		var face: Vector3 = slot["face"]
		for t in torches:
			var dist := Vector2(t.x, t.z).distance_to(Vector2(face.x, face.z))
			if dist >= 1.5 and dist <= 5.0:
				return 0
		return 1
	var rest := slots.duplicate()
	rest.sort_custom(func(a, b):
		var la: int = lit.call(a)
		var lb: int = lit.call(b)
		return la < lb if la != lb else _slot_hash(a) < _slot_hash(b))
	order.append_array(rest)
	var out: Array = []
	for slot in order:
		if out.size() >= want:
			break
		var ok := true
		for a in out:
			if (a["face"] as Vector3).distance_to(slot["face"]) < spacing:
				ok = false
				break
		if ok:
			out.append(slot)
	return out


func _slot_hash(slot: Dictionary) -> int:
	var c: Vector2i = slot["cell"]
	var dd: Vector2i = slot["dir"]
	return d._cell_hash(c.x, c.y, 31 + dd.x * 3 + dd.y * 7)


## Камера на высоте глаз в 2–4 клетках от первого кластера, смотрит на него.
func _add_view(view_name: String, slot: Dictionary) -> void:
	var n: Vector3 = slot["n"]
	var back := mini(int(slot["span"]) - 1, 3)
	var to: Vector3 = slot["face"] + n * 0.5 + Vector3(0, 0.5, 0)
	var from: Vector3 = slot["face"] + n * (back * Dungeon.T + 0.6) 		+ (slot["tan"] as Vector3) * 0.8 + Vector3(0, 1.7, 0)
	views.append({"name": "dress_" + view_name, "from": from, "to": to})


# ---------------------------------------------------------------------------
# кластер

func _cluster(slot: Dictionary, kit: Dictionary, objective: bool, salt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _slot_hash(slot) + salt
	var large: Array = kit["large"]
	var medium: Array = kit["medium"]
	var small: Array = kit["small"]
	# в углу крупный прижат к боковой стене
	var along := 0.0
	var big_w := 0.0
	if not large.is_empty() and not objective:
		# не встал (под факелом, у лужи) — другой крупный или сдвиг вдоль стены
		var names := large.duplicate()
		var first: int = rng.randi() % names.size()
		var big: Node3D = null
		for k in names.size():
			var big_name: String = names[(first + k) % names.size()]
			var w := _wall_width(big_name)
			for shift in [0.0, 0.9, -0.9]:
				along = shift
				if slot["corner"] != 0:
					along = float(slot["corner"]) * (Dungeon.T * 0.5 - w * 0.5 - WALL_GAP - 0.05)
				big = _place_on_wall(big_name, slot, along, 0.0, rng)
				if big:
					break
			if big:
				big_w = w
				if kit.has("top") and big_name.begins_with("table"):
					_place_on_top(big, kit["top"], rng)
					_stools_at(big, slot, rng)
				break
	# два средних по бокам от крупного
	var sides := [1.0, -1.0] if rng.randf() < 0.5 else [-1.0, 1.0]
	for i in 2:
		if medium.is_empty():
			break
		var med_name: String = medium[rng.randi() % medium.size()]
		var off: float = along + sides[i] * (big_w * 0.5 + _wall_width(med_name) * 0.5 + rng.randf_range(0.08, 0.3))
		if big_w == 0.0:
			off = along + sides[i] * rng.randf_range(0.2, 0.7)
		if _place_on_wall(med_name, slot, off, rng.randf_range(0.0, 0.15), rng) == null:
			_place_on_wall(med_name, slot, off + sides[i] * 0.5, 0.0, rng)
	# мелочь вокруг, не дальше ряда от стены
	var n_small := rng.randi_range(2, 4)
	for i in n_small:
		if small.is_empty():
			break
		var sm_name: String = small[rng.randi() % small.size()]
		_place_on_wall(sm_name, slot, along + rng.randf_range(-1.6, 1.6), rng.randf_range(0.0, 0.5), rng)


## Ширина вдоль стены: длинной стороной к кладке.
func _wall_width(prop_name: String) -> float:
	var f := _footprint(prop_name)
	return maxf(f.x, f.z) if not prop_name in DEBRIS else f.x


func _place_on_wall(prop_name: String, slot: Dictionary, along: float, inset: float,
		rng: RandomNumberGenerator) -> Node3D:
	var f := _footprint(prop_name)
	var n: Vector3 = slot["n"]
	var tan: Vector3 = slot["tan"]
	var yaw := atan2(n.x, n.z)
	var w := f.x
	var dep := f.z
	var debris := prop_name in DEBRIS
	if not debris and f.z > f.x:
		yaw += PI * 0.5
		w = f.z
		dep = f.x
	var s := rng.randf_range(0.9, 1.1)
	w *= s
	dep *= s
	if debris:
		yaw = rng.randf_range(0.0, TAU)
		dep = maxf(w, dep)
		w = dep
	else:
		yaw += deg_to_rad(rng.randf_range(-15.0, 15.0))
	if dep + inset > ROW_DEPTH and not debris:
		return null
	var pos: Vector3 = slot["face"] + tan * along + n * (dep * 0.5 + WALL_GAP + inset)
	var solid := _is_solid(prop_name)
	var r := maxf(w, dep) * 0.5
	if not _fits(pos, r, solid, f.y * s):
		return null
	return _spawn(prop_name, pos, yaw, s, slot, solid)


## Мелочь на крышку стола; лежит в пределах крышки с отступом 12 см.
func _place_on_top(base: Node3D, names: Array, rng: RandomNumberGenerator) -> void:
	var f: Vector3 = base.get("footprint") * base.scale.x
	var top := f.y
	var count := rng.randi_range(2, 4)
	for i in count:
		var nm: String = names[rng.randi() % names.size()]
		var local := Vector3(rng.randf_range(-f.x * 0.5 + 0.18, f.x * 0.5 - 0.18), top,
			rng.randf_range(-f.z * 0.5 + 0.14, f.z * 0.5 - 0.14))
		var p := base.global_transform * Vector3(local.x / base.scale.x, 0, local.z / base.scale.x)
		var node := _instance(nm)
		node.position = Vector3(p.x, top, p.z)
		node.rotation.y = rng.randf_range(0.0, TAU)
		add_child(node)
		counts["props"] += 1


## Два табурета перед столом — со стороны комнаты.
func _stools_at(table: Node3D, slot: Dictionary, rng: RandomNumberGenerator) -> void:
	var n: Vector3 = slot["n"]
	var tan: Vector3 = slot["tan"]
	var f: Vector3 = table.get("footprint") * table.scale.x
	var dep := minf(f.x, f.z)
	for side in [-0.45, 0.45]:
		var pos: Vector3 = table.position + n * (dep * 0.5 + 0.32) + tan * side * f.x
		if not _fits(pos, 0.24, true, 0.45):
			continue
		var yaw := rng.randf_range(0.0, TAU)
		if rng.randf() < 0.3:
			# опрокинутый: лежит на боку
			var node := _spawn("stool", pos, yaw, 1.0, slot, true)
			if node:
				node.rotation = Vector3(PI * 0.5, yaw, 0)
				node.position.y = _footprint("stool").z * 0.5
		else:
			_spawn("stool", pos, yaw, 1.0, slot, true)


func _spawn(prop_name: String, pos: Vector3, yaw: float, s: float, slot: Dictionary,
		solid: bool) -> Node3D:
	var node := _instance(prop_name)
	node.position = Vector3(pos.x, 0.0, pos.z)
	node.rotation.y = yaw
	node.scale = Vector3.ONE * s * float(BASE_SCALE.get(prop_name, 1.0))
	add_child(node)
	var f := _footprint(prop_name) * s
	_placed.append({"pos": pos, "r": maxf(f.x, f.z) * 0.5, "solid": solid})
	if solid:
		solids.append({"node": node, "n": slot["n"], "pos": pos,
			"inner": pos + (slot["n"] as Vector3) * minf(f.x, f.z) * 0.5})
	counts["props"] += 1
	return node


func _is_solid(prop_name: String) -> bool:
	var ps: PackedScene = _scene(prop_name)
	return ps != null and ps.get_state().get_node_type(0) == &"StaticBody3D"


## Место свободно: внутри открытых клеток, не на другом предмете, не у
## геймплейных объектов и не под факелом, если предмет высокий.
func _fits(pos: Vector3, r: float, solid: bool, h: float) -> bool:
	for off in [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r), Vector3.ZERO]:
		var c := Vector2i(int(floor((pos.x + off.x) / Dungeon.T)), int(floor((pos.z + off.z) / Dungeon.T)))
		if not d._is_open_cell(c):
			return false
	for p in _placed:
		var gap := 0.04 if (solid and p["solid"]) else -0.08
		if (p["pos"] as Vector3).distance_to(pos) < float(p["r"]) + r + gap:
			return false
	for res in d.reserved:
		if (res["pos"] as Vector3).distance_to(pos) < float(res["r"]) + r:
			return false
	for pud in d.puddles:
		if is_instance_valid(pud) and Vector2(pud.position.x, pud.position.z).distance_to(
				Vector2(pos.x, pos.z)) < 0.7 + r:
			return false
	if h > 1.2:
		for t in _wall_torches():
			if Vector2(t.x, t.z).distance_to(Vector2(pos.x, pos.z)) < 1.0 + r:
				return false
	return true


var _torch_cache: Array = []


func _wall_torches() -> Array:
	if _torch_cache.is_empty():
		for entry in d.lights:
			var l: OmniLight3D = entry.get("light")
			if l == null or not is_instance_valid(l) or not entry.get("self_flicker", false):
				continue
			var torch := l.get_parent() as Node3D
			if torch == null or not torch.transform.origin.is_zero_approx():
				continue
			_torch_cache.append(torch.get_parent())
	var out: Array = []
	for root in _torch_cache:
		out.append((root as Node3D).position)
	return out


func _scene(prop_name: String) -> PackedScene:
	if not _packed.has(prop_name):
		var path := PROP_DIR + prop_name + ".tscn"
		_packed[prop_name] = load(path) if ResourceLoader.exists(path) else null
		if _packed[prop_name] == null:
			push_warning("нет сцены реквизита " + path)
	return _packed[prop_name]


func _instance(prop_name: String) -> Node3D:
	return _scene(prop_name).instantiate()


func _footprint(prop_name: String) -> Vector3:
	if not _foot.has(prop_name):
		var ps := _scene(prop_name)
		var f := Vector3(0.5, 0.5, 0.5)
		var st := ps.get_state()
		for i in st.get_node_property_count(0):
			if st.get_node_property_name(0, i) == &"footprint":
				f = st.get_node_property_value(0, i)
		_foot[prop_name] = f
	return _foot[prop_name] * float(BASE_SCALE.get(prop_name, 1.0))


# ---------------------------------------------------------------------------
# щебень и пыль у основания стен

func _seam_debris() -> void:
	var dirt: PackedScene = load(DECAL_DIR + "dirt_patch.tscn")
	for c in d._open_cells():
		for dd in Dungeon.DIRS:
			if not d.is_wall(c.x + dd.x, c.y + dd.y):
				continue
			counts["faces"] += 1
			var h := d._cell_hash(c.x, c.y, 401 + dd.x * 5 + dd.y * 11)
			if h % 100 >= SEAM_PERCENT:
				continue
			counts["seam_faces"] += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = h
			var face: Vector3 = d._face_xform([c + dd], -dd).origin
			var n := Vector3(-dd.x, 0, -dd.y)
			var tan := Vector3(-dd.y, 0, dd.x)
			var base := Vector3(face.x, 0.0, face.z)
			# полоса пыли вдоль шва: пятно, вытянутое вдоль стены
			var dec: Decal = dirt.instantiate()
			dec.size = Vector3(rng.randf_range(1.6, 2.2), 0.4, rng.randf_range(0.6, 0.9))
			dec.basis = Basis(tan, Vector3.UP, tan.cross(Vector3.UP))
			dec.position = base + n * (dec.size.z * 0.35) + Vector3(0, 0.05, 0)
			add_child(dec)
			counts["decals"] += 1
			var tile := Vector2i(c.x / DEBRIS_TILE, c.y / DEBRIS_TILE)
			for i in rng.randi_range(5, 9):
				var kind := "stone" if rng.randf() < 0.8 else ("plank_d" if rng.randf() < 0.5 else "plank_e")
				var s := rng.randf_range(0.3, 0.9) if kind == "stone" else rng.randf_range(0.6, 1.0)
				var out := pow(rng.randf(), 2.0) * 0.35
				var p := base + tan * rng.randf_range(-0.95, 0.95) + n * (0.06 + out)
				var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU),
					rng.randf_range(-0.2, 0.2)))
				_add_debris(kind, tile, Transform3D(tilt.scaled(Vector3.ONE * s), p))


## Обломок в MultiMesh тайла 8×8 м: дальность у тайла своя, тени выключены.
func _add_debris(kind: String, tile: Vector2i, xf: Transform3D) -> void:
	if not _debris_mesh.has(kind):
		var inst := _instance(kind)
		var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
		var local := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != inst:
			local = (cur as Node3D).transform * local
			cur = cur.get_parent()
		_debris_mesh[kind] = {"mesh": mi.mesh, "local": local}
		inst.free()
	var key := "%s_%d_%d" % [kind, tile.x, tile.y]
	if not _debris.has(key):
		_debris[key] = {"kind": kind, "xf": []}
	_debris[key]["xf"].append(xf * (_debris_mesh[kind]["local"] as Transform3D))
	counts["debris"] += 1


func _flush_debris() -> void:
	for key in _debris:
		var e: Dictionary = _debris[key]
		var xfs: Array = e["xf"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _debris_mesh[e["kind"]]["mesh"]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Debris_" + key
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.layers = 1 << (PROP_LAYER - 1)
		mmi.visibility_range_end = 25.0
		mmi.visibility_range_end_margin = 3.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


# ---------------------------------------------------------------------------
# декали

## Копоть над каждым настенным факелом: узким концом к пламени, 0.4–1.0 м.
func _soot() -> void:
	var soot: PackedScene = load(DECAL_DIR + "soot_streak.tscn")
	_wall_torches()
	for root in _torch_cache:
		var wall_root := root as Node3D
		var n := wall_root.global_basis.z
		var flame_y := wall_root.global_position.y + 1.1
		var rng := RandomNumberGenerator.new()
		rng.seed = int(wall_root.global_position.x * 37.0 + wall_root.global_position.z * 101.0)
		var h := rng.randf_range(0.4, 1.0)
		var bottom := flame_y + 0.1
		var top := minf(bottom + h, Dungeon.WALL_H - 0.6)
		var dec: Decal = soot.instantiate()
		dec.size = Vector3(rng.randf_range(0.45, 0.7), 0.6, top - bottom)
		_wall_decal(dec, wall_root.global_position * Vector3(1, 0, 1) + Vector3(0, (top + bottom) * 0.5, 0),
			n, 0.0)
		if counts["soot"] == 0:
			views.append({"name": "dress_soot_torch",
				"from": wall_root.global_position + n * 2.6 + Vector3(0, 0.6, 0),
				"to": wall_root.global_position + Vector3(0, 1.4, 0)})
		counts["soot"] += 1


## Трещины, сырые потёки и мох у пола по граням кладки; в сырых комнатах чаще.
func _wall_grime() -> void:
	var crack: PackedScene = load(DECAL_DIR + "crack_wall.tscn")
	var damp: PackedScene = load(DECAL_DIR + "damp_streak.tscn")
	var moss: PackedScene = load(DECAL_DIR + "moss_patch.tscn")
	var floor_crack: PackedScene = load(DECAL_DIR + "crack_floor.tscn")
	for c in d._open_cells():
		var wet: bool = _room_of.has(c) and ROOMS[_room_of[c]].get("damp", false)
		for dd in Dungeon.DIRS:
			if not d.is_wall(c.x + dd.x, c.y + dd.y):
				continue
			var h := d._cell_hash(c.x, c.y, 907 + dd.x * 13 + dd.y * 17)
			var rng := RandomNumberGenerator.new()
			rng.seed = h
			var face: Vector3 = d._face_xform([c + dd], -dd).origin
			var n := Vector3(-dd.x, 0, -dd.y)
			var tan := Vector3(-dd.y, 0, dd.x)
			var base := Vector3(face.x, 0, face.z) + tan * rng.randf_range(-0.6, 0.6)
			if h % 100 < 8:
				var dec: Decal = crack.instantiate()
				var s := rng.randf_range(0.8, 1.4)
				dec.size = Vector3(s, 0.5, s)
				_wall_decal(dec, base + Vector3(0, rng.randf_range(0.9, 2.6), 0), n, rng.randf_range(-0.5, 0.5))
			if (h / 100) % 100 < (26 if wet else 6):
				var dec2: Decal = damp.instantiate()
				var len := rng.randf_range(1.2, 2.0)
				dec2.size = Vector3(rng.randf_range(0.45, 0.7), 0.5, len)
				_wall_decal(dec2, base + Vector3(0, 3.6 - len * 0.5, 0), n, 0.0)
			if (h / 10000) % 100 < (32 if wet else 9):
				var dec3: Decal = moss.instantiate()
				dec3.size = Vector3(rng.randf_range(1.1, 1.8), 0.6, rng.randf_range(0.5, 0.7))
				_wall_decal(dec3, base + Vector3(0, 0.22, 0), n, 0.0)
		if _room_of.has(c) and d._cell_hash(c.x, c.y, 77) % 100 < 5:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = d._cell_hash(c.x, c.y, 78)
			var fc: Decal = floor_crack.instantiate()
			var a := rng2.randf_range(0.0, TAU)
			var x := Vector3(cos(a), 0, sin(a))
			fc.basis = Basis(x, Vector3.UP, x.cross(Vector3.UP))
			fc.position = d.cell_center(c.x, c.y) + Vector3(rng2.randf_range(-0.5, 0.5), 0.05,
				rng2.randf_range(-0.5, 0.5))
			add_child(fc)
			counts["decals"] += 1


## Декаль на стене: локальная −Y вдоль −нормали (проекция в кладку),
## +Z вниз — верх текстуры сверху. roll — поворот в плоскости стены.
## Реквизит на PROP_LAYER, поэтому стоящие у стены бочки копоть и мох не ловят.
func _wall_decal(dec: Decal, pos: Vector3, n: Vector3, roll: float) -> void:
	var z := Vector3.DOWN
	var x := n.cross(z).normalized()
	var b := Basis(x, n, z)
	if roll != 0.0:
		b = Basis(n, roll) * b
	dec.basis = b
	dec.position = pos + n * 0.02
	add_child(dec)
	counts["decals"] += 1


## Пыль и грязь во внутренних углах пола.
func _corner_dirt() -> void:
	var dirt: PackedScene = load(DECAL_DIR + "dirt_patch.tscn")
	for c in d._open_cells():
		for dd in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			if not d.is_wall(c.x + dd.x, c.y) or not d.is_wall(c.x, c.y + dd.y):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = d._cell_hash(c.x, c.y, 503 + dd.x * 3 + dd.y)
			var corner := d.cell_center(c.x, c.y) + Vector3(dd.x, 0, dd.y) * (Dungeon.T * 0.5)
			var dec: Decal = dirt.instantiate()
			var s := rng.randf_range(1.2, 1.7)
			dec.size = Vector3(s, 0.4, s)
			var a := rng.randf_range(0.0, TAU)
			var x := Vector3(cos(a), 0, sin(a))
			dec.basis = Basis(x, Vector3.UP, x.cross(Vector3.UP))
			dec.position = corner - Vector3(dd.x, 0, dd.y) * 0.45 + Vector3(0, 0.05, 0)
			add_child(dec)
			counts["decals"] += 1
			counts["corners"] += 1


# ---------------------------------------------------------------------------
# своды

## Поперечные каменные рёбра под плоским сводом больших залов через RIB_STEP:
## ребро идёт от стены до стены по короткой оси зала, только там, где оба
## конца упираются в кладку (а не в проём).
func _ceiling_ribs() -> void:
	var parts: Array[Transform3D] = []
	for i in ROOMS.size():
		if not ROOMS[i].get("ribs", false):
			continue
		var r: Array = ROOMS[i]["rect"]
		var wide: bool = (r[2] - r[0]) >= (r[3] - r[1])
		var lo: float = (r[0] if wide else r[1]) * Dungeon.T
		var hi: float = ((r[2] if wide else r[3]) + 1) * Dungeon.T
		var p := lo + RIB_STEP * 0.5
		while p < hi:
			var line := int(floor(p / Dungeon.T))
			var a: int = r[1] if wide else r[0]
			var b: int = r[3] if wide else r[2]
			var k := a
			while k <= b:
				var cell := Vector2i(line, k) if wide else Vector2i(k, line)
				if not (_room_of.get(cell, -1) == i):
					k += 1
					continue
				var start := k
				while k <= b and _room_of.get(Vector2i(line, k) if wide else Vector2i(k, line), -1) == i:
					k += 1
				var run := k - start
				var before := Vector2i(line, start - 1) if wide else Vector2i(start - 1, line)
				var after := Vector2i(line, k) if wide else Vector2i(k, line)
				if run >= 3 and d.is_wall(before.x, before.y) and d.is_wall(after.x, after.y):
					var mid := (start + k) * 0.5 * Dungeon.T
					var center := Vector3(p, Dungeon.WALL_H - 0.2, mid) if wide \
						else Vector3(mid, Dungeon.WALL_H - 0.2, p)
					var size := Vector3(0.42, 0.4, run * Dungeon.T) if wide \
						else Vector3(run * Dungeon.T, 0.4, 0.42)
					parts.append(Transform3D(Basis.from_scale(size), center))
			p += RIB_STEP
	counts["ribs"] = parts.size()
	if parts.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mmi := d._multimesh(box, parts.size(), d.mat_cap)
	mmi.name = "CeilingRibs"
	for j in parts.size():
		mmi.multimesh.set_instance_transform(j, parts[j])
		mmi.multimesh.set_instance_color(j, Color(0.9, 0.87, 0.82).darkened(float((j * 7919) % 100) / 600.0))


# ---------------------------------------------------------------------------
# проверка прохода

## Свободная ширина перед каждым предметом с коллизией: луч от его внутренней
## грани в комнату до первой стены или другого предмета. Зовётся из
## --test3d в кадре физики.
func check_paths(space: PhysicsDirectSpaceState3D) -> Dictionary:
	var worst := INF
	var narrow := 0
	for s in solids:
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			continue
		var from: Vector3 = s["inner"] + Vector3(0, 0.5, 0) + (s["n"] as Vector3) * 0.02
		var to: Vector3 = from + (s["n"] as Vector3) * 6.0
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var ex: Array[RID] = []
		if node is CollisionObject3D:
			ex.append((node as CollisionObject3D).get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		var free := 6.0 if hit.is_empty() else from.distance_to(hit["position"])
		worst = minf(worst, free)
		if free < PATH_MIN:
			narrow += 1
	return {"solids": solids.size(), "min": worst, "narrow": narrow}
