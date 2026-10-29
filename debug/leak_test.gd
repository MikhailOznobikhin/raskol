extends Node3D
## Автопроверка утечек/дыр по ТЗ STAGE 1
## Запускать в сцене уровня (или как @tool). Требует, чтобы герой был в дереве.

const GRID := 0.5
const RAY_DOWN := 3.0
const RAY_UP := 1.0
const STEP_H := 0.6
const MAX_PER_FRAME := 500

var dungeon: Node3D
var player: Node3D
var space: PhysicsDirectSpaceState3D
var visited := {}
var queue := []
var holes := []
var leaks := []
var intended_aabb: AABB
var floor_y_cache := {}
var running := false
var frame_count := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	setup()

func setup() -> void:
	dungeon = get_parent()
	space = get_world_3d().direct_space_state
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# compute intended bounds from floor meshes
	intended_aabb = AABB()
	var floors := []
	_collect_meshes(dungeon, floors)
	for m in floors:
		if m is MeshInstance3D and m.mesh:
			var aabb = m.get_aabb()
			var gaabb = m.global_transform * aabb
			if intended_aabb.size == Vector3.ZERO:
				intended_aabb = gaabb
			else:
				intended_aabb = intended_aabb.merge(gaabb)
	if intended_aabb.size == Vector3.ZERO:
		# fallback
		intended_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 50, 200))
	else:
		intended_aabb = intended_aabb.grow(1.0)
	start()

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func start() -> void:
	if not player or not space:
		return
	var p := player.global_position
	var start_cell = Vector2(round(p.x / GRID) * GRID, round(p.z / GRID) * GRID)
	visited = {}
	queue = []
	holes = []
	leaks = []
	_enqueue(start_cell)
	running = true

func _enqueue(cell: Vector2) -> void:
	var key = str(cell)
	if visited.has(key):
		return
	visited[key] = true
	queue.append(cell)

func _process(_delta: float) -> void:
	if not running or queue.is_empty():
		if running and queue.is_empty():
			_finish()
			running = false
		return
	var processed := 0
	while processed < MAX_PER_FRAME and not queue.is_empty():
		var cell = queue.pop_front()
		_explore(cell)
		processed += 1

func _explore(cell: Vector2) -> void:
	var neighbors = [
		Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1),
		Vector2(1,1), Vector2(1,-1), Vector2(-1,1), Vector2(-1,-1)
	]
	for n in neighbors:
		var nc = cell + n * GRID
		_check_cell(nc)

func _check_cell(cell: Vector2) -> void:
	var key = str(cell)
	if visited.has(key):
		return
	var from = Vector3(cell.x, 1.0, cell.y)
	var to = Vector3(cell.x, -3.0, cell.y)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1  # world_static
	var res = space.intersect_ray(q)
	if res.is_empty():
		# hole - no floor
		var c3 = Vector3(cell.x, 0, cell.y)
		if _inside_level(c3):
			holes.append(c3)
		return
	var hit_pos = res.position
	# check height difference from visited context rough check - skip if too high
	# capsule overlap test for player
	var shape = CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.5
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 1
	var trans = Transform3D(Basis.IDENTITY, hit_pos + Vector3(0, shape.height * 0.5 + 0.01, 0))
	params.transform = trans
	var overlaps = space.intersect_shape(params)
	if overlaps.size() > 0:
		return
	# check if outside intended bounds
	if not intended_aabb.has_point(Vector3(cell.x, hit_pos.y, cell.y)):
		leaks.append(Vector3(cell.x, hit_pos.y, cell.y))
		return
	_enqueue(cell)

func _inside_level(p: Vector3) -> bool:
	# basic bounds check against dungeon size
	return true

func _finish() -> void:
	var report = []
	report.append("LEAK_TEST_REPORT")
	report.append("reachable_cells=" + str(visited.size()))
	report.append("HOLES=" + str(holes.size()))
	for h in holes:
		report.append("HOLE " + str(h))
	report.append("LEAKS=" + str(leaks.size()))
	for l in leaks:
		report.append("LEAK " + str(l))
	var out = "\n".join(report) + "\n"
	var dir = "res://_docs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fpath = dir + "leak_report.txt"
	var fa = FileAccess.open(fpath, FileAccess.WRITE)
	if fa:
		fa.store_string(out)
		fa.close()
	print("[LEAK_TEST] " + out)
