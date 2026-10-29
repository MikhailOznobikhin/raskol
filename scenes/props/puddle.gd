extends Decal
## Лужа: проецирующая декаль, лежащая В полу, а не плоскость над ним.
##
## Декаль проецирует альбедо и ORM вниз, поэтому пятно повторяет рельеф
## коббла, а низкая шероховатость из ORM даёт отражения факелов (SSR) и
## блик от ближнего света. Форму задаёт альфа альбедо-маски: край рваный,
## а не круглый, и он же служит маской для ORM — глянец только внутри
## пятна. Лужа ставится генератором подземелья (scripts/dungeon.gd,
## _add_puddle()), если её положить в сцену вручную — она тоже работает.
## Под декалью — Area3D в группе "water_zone": шаг в ней даёт брызги.

const MASKS: Array[Texture2D] = [
	preload("res://textures/decals/puddle_mask_0.png"),
	preload("res://textures/decals/puddle_mask_1.png"),
	preload("res://textures/decals/puddle_mask_2.png"),
	preload("res://textures/decals/puddle_mask_3.png"),
]

## Множитель размера: лужа в кластере крупнее одиночной, цистерна — ещё крупнее.
@export var base_scale := 1.0
## 0–3 — конкретная маска; при randomize_on_ready берётся случайная.
@export_range(0, 3) var variant := 0
## Случайные маска, поворот и размер: иначе все лужи уровня — одно пятно.
@export var randomize_on_ready := true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var v := variant
	var k := base_scale
	if randomize_on_ready:
		v = randi() % MASKS.size()
		k *= randf_range(0.7, 1.5)
		rotation.y = randf() * TAU
	texture_albedo = MASKS[clampi(v, 0, MASKS.size() - 1)]
	# Y не масштабируем: глубина проекции (size.y) должна остаться маленькой,
	# иначе декаль достаёт до свода и красит стены.
	scale = Vector3(k, 1.0, k)
	_add_water_zone(k)


## Зона воды для шагов (этап 9): по ней FootstepFx отличает лужу от камня.
## Цилиндр меньше квадрата декали — рваное пятно маски не доходит до углов.
## top_level: масштаб декали (k, 1, k) неравномерный, а физика такого не любит.
func _add_water_zone(k: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = size.x * 0.5 * k * 0.7
	shape.height = 0.6
	var col := CollisionShape3D.new()
	col.shape = shape
	var area := Area3D.new()
	area.name = "WaterZone"
	area.add_to_group("water_zone")
	area.collision_layer = FootstepFx.WATER_MASK
	area.collision_mask = 0
	area.monitoring = false
	area.top_level = true
	area.add_child(col)
	add_child(area)
	area.global_position = global_position
