@tool
extends Node3D
## Корень сцены реквизита этапа 8 (res://scenes/props/*.tscn).
##
## Сцены собирает src/make_set_dressing.gd: модель внутри уже сдвинута так,
## что низ её AABB лежит на y = 0, а центр — на оси Y. Поэтому предмет,
## поставленный на пол (y = 0), стоит на нём без зазора.
## Скрипт лишь раздаёт мелочи настройки дальности и теней — в самих
## импортированных glTF их не задать.

enum SizeClass { LARGE, MEDIUM, SMALL, DEBRIS }

## Дальность, после которой мелочь исчезает (этап 8, шаг 5).
const SMALL_RANGE := 25.0
const SMALL_MARGIN := 3.0

@export var size_class: SizeClass = SizeClass.LARGE
## Габарит модели после нормализации (x — вдоль стены, z — от стены).
@export var footprint := Vector3.ONE


## Визуальный слой реквизита (SetDressing.PROP_LAYER): декали копоти, мха и
## грязи (cull_mask = 1) не ложатся на предметы у стены.
const PROP_LAYER := 3


func _ready() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).layers = 1 << (PROP_LAYER - 1)
	if size_class == SizeClass.LARGE or size_class == SizeClass.MEDIUM:
		return
	for n in find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		g.visibility_range_end = SMALL_RANGE
		g.visibility_range_end_margin = SMALL_MARGIN
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if size_class == SizeClass.DEBRIS:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
