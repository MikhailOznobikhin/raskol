extends Control
## Фон сетки сумки: ячейки рисуются одним StyleBoxFlat поверх каменной панели,
## вместо TextureRect на каждую клетку.

@export var slot_style : StyleBox

var _grid := Vector2i.ONE
var _cell := Vector2(56, 56)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var view := get_parent() as InventoryView
	if view == null or view.inventory == null:
		return
	_cell = view.cell_size
	_grid = Vector2i(view.inventory.width, 1)
	var grid := view.inventory as GridInventory
	if grid != null:
		_grid.y = grid.height
	queue_redraw()


func _draw() -> void:
	if slot_style == null:
		return
	for y in _grid.y:
		for x in _grid.x:
			var cell_rect := Rect2(Vector2(x, y) * _cell, _cell).grow(-1.0)
			draw_style_box(slot_style, cell_rect)
