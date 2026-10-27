extends InventoryTooltip
## Аддон считает позицию подсказки в экранных пикселях (get_global_transform_with_canvas),
## а пишет её в координатах канваса: в полноэкранном окне с растянутыми canvas_items
## тултип уезжал в правый нижний угол. Считаем так же, но без экранного масштаба.

func _update_rect(mouseover_node : Control) -> void:
	size.y = 0
	if !is_instance_valid(mouseover_node):
		return

	if !_first_displayed:
		_first_displayed = true
		await get_tree().process_frame

	if !is_instance_valid(mouseover_node):
		return

	# get_global_transform() отдаёт координаты канваса, а position пишется в
	# локальных координатах родителя: экран инвентаря стоит с масштабом 0.5,
	# поэтому без пересчёта тултип вставал ровно посередине между слотом и
	# его настоящим местом.
	var node_pos := mouseover_node.get_global_transform().origin
	var host := get_parent() as Control
	if host != null:
		node_pos = host.get_global_transform().affine_inverse() * node_pos
	var left_half := node_pos.x + mouseover_node.size.x * 0.5 < get_viewport_rect().size.x * 0.5
	var minsize := get_combined_minimum_size()
	position = node_pos + Vector2(
		mouseover_node.size.x if left_half else -size.x,
		(mouseover_node.size.y - minsize.y) * 0.5
	)
	position.y = clampf(position.y, 0.0, get_viewport_rect().size.y - minsize.y)
	size.y = 0
