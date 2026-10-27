extends InventoryTooltipProperty
## Описание, бонусы и подсказки клавиш в тултипе. Цифры берёт у GameState, поэтому
## подпись предмета не может разойтись с тем, что реально считает броню и урон.

func _display(item_stack : ItemStack) -> void:
	var desc := item_stack.item_type.description
	if desc != "":
		add_bbcode("[color=#%s]" % tooltip.color_description.to_html())
		add_bbcode("[i]%s[/i]" % desc)

	var bonuses := GameState.item_bonuses_text(item_stack.extra_properties)
	if bonuses != "":
		if !is_label_empty():
			add_spacing(4.0, false)
		add_bbcode("[color=#%s]" % tooltip.color_bonus.to_html())
		add_bbcode(bonuses)

	if !is_label_empty():
		add_spacing(4.0, false)
	add_bbcode("[color=#%s]" % tooltip.color_neutral.to_html())
	add_bbcode("ЛКМ — взять · ПКМ — одну · 2×ЛКМ — собрать такие же")
