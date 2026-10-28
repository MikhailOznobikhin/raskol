extends Control
## Экран инвентаря на Wyvernbox. Носителем данных остаётся GameState: при открытии
## сумка и экипировка перекладываются в ItemStack, а каждое изменение на экране
## сразу пишется обратно, чтобы подбор, бонусы и диалоги продолжали видеть то же самое.

signal closed

const FONT_PATH := "res://ui/fonts/Cinzel.ttf"

@onready var bag_view: InventoryView = %Bag
@onready var equip_view: InventoryView = %Equip
@onready var titles_root: Control = %Titles
@onready var stats_box: VBoxContainer = %Stats
@onready var action_button: Button = %BtnAction
@onready var sort_button: Button = %BtnSort
@onready var close_button: Button = %BtnClose

var _loading := false
var _active_view: ItemStackView
var _stat_labels := {}
var _leftovers: Array = []


func _ready() -> void:
	_use_font()
	_build_stats()
	_fill_slot_titles()
	_loading = true
	# Ячейки экипировки принимает только предмет с флагом своего слота: порядок
	# флагов задаёт GameState.EQUIP_SLOTS, а не список чисел в сцене.
	var equip_inv := equip_view.inventory as RestrictedInventory
	if equip_inv != null:
		equip_inv.restricted_to_types = ItemCatalog.equip_flags()
	bag_view.inventory.clear()
	equip_view.inventory.clear()
	_load_from_game_state()
	_loading = false
	for view in [bag_view, equip_view]:
		view.item_stack_added.connect(_on_stacks_changed)
		view.item_stack_removed.connect(_on_stacks_changed)
		view.item_stack_changed.connect(_on_stack_count_changed)
		view.item_stack_selected.connect(_on_item_selected)
		view.item_stack_deselected.connect(_on_item_deselected)
		if not view.item_stack_gui_input.is_connected(_on_item_gui_input):
			view.item_stack_gui_input.connect(_on_item_gui_input)
	action_button.pressed.connect(_on_action_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	close_button.pressed.connect(request_close)
	var held := GrabbedItemStackView.get_instance()
	if is_instance_valid(held):
		held.input_on_empty.connect(_on_input_on_empty)
	_flush()


func _fill_slot_titles() -> void:
	for slot in GameState.EQUIP_SLOTS:
		var title := titles_root.get_node_or_null(NodePath(slot)) as Label
		if title != null:
			title.text = String(GameState.SLOT_TITLES.get(slot, ""))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var closes := event.is_action_pressed("pause") \
		or (key != null and key.pressed and not key.echo \
			and key.physical_keycode == KEY_I)
	if closes:
		request_close()
		get_viewport().set_input_as_handled()


func request_close() -> void:
	_return_held()
	_flush()
	closed.emit()


func _use_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		theme.set_default_font(load(FONT_PATH))


func _build_stats() -> void:
	for key in ["dmg", "armor", "hp", "noise", "free"]:
		var line := Label.new()
		stats_box.add_child(line)
		_stat_labels[key] = line


func _load_from_game_state() -> void:
	_leftovers.clear()
	for entry in GameState.inventory:
		if entry is Dictionary:
			var stack := ItemCatalog.stack(String(entry.get("id", "")),
				int(entry.get("count", 1)))
			if stack != null:
				_put_in_bag(stack)
	for i in GameState.EQUIP_SLOTS.size():
		var worn = GameState.equipped.get(GameState.EQUIP_SLOTS[i])
		if worn is Dictionary and not worn.is_empty():
			var worn_stack := ItemCatalog.stack(String(worn.get("id", "")), 1)
			if worn_stack != null:
				equip_view.inventory.try_place_stack(worn_stack, i)


## Сумка и экипировка Wyvernbox -> словари GameState. Порядок обхода не важен:
## бонусы GameState считает одним обходом по всем надетым предметам.
func _flush() -> void:
	if _loading:
		return
	GameState.inventory.clear()
	for stack in bag_view.inventory.items:
		if stack != null:
			GameState.inventory.append(_entry(stack))
	for extra in _leftovers:
		GameState.inventory.append(extra)
	for i in GameState.EQUIP_SLOTS.size():
		var stack = equip_view.inventory.get_item_at_position(i)
		GameState.equipped[GameState.EQUIP_SLOTS[i]] = null if stack == null else _entry(stack)
	GameState.inventory_changed.emit()
	GameState.stats_changed.emit()
	_refresh_stats()
	_refresh_action()


func _entry(stack: ItemStack) -> Dictionary:
	var entry: Dictionary = ItemCatalog.source(String(stack.item_type.resource_name)) \
		.duplicate(true)
	entry["count"] = stack.count
	return entry


func _return_held() -> void:
	var grabbed := GrabbedItemStackView.get_instance()
	if not is_instance_valid(grabbed) or grabbed.stack == null:
		return
	var stack := grabbed.stack
	# Аддон при скрытии экрана и при клике мимо слотов роняет предмет на землю,
	# а GroundItemManager в игре нет — там assert. Возвращаем в сумку сами.
	grabbed.update_stack(null)
	_put_in_bag(stack)


## Стопка идёт в сумку; не влезшее остаётся в _leftovers и уходит в GameState
## вместе со следующим _flush — иначе пересборка сумки стёрла бы лишек.
func _put_in_bag(stack: ItemStack) -> void:
	var left := stack.count - bag_view.inventory.try_add_item(stack)
	if left > 0:
		var entry := _entry(stack)
		entry["count"] = left
		_leftovers.append(entry)


## Правый клик мимо слотов: одна вещь из руки возвращается, остальное держим.
func _return_one(grabbed: GrabbedItemStackView) -> void:
	var one := grabbed.stack.duplicate_with_count(1)
	grabbed.add_items_to_stack(-1)
	if grabbed.stack.count <= 0:
		grabbed.update_stack(null)
	_put_in_bag(one)


func _on_input_on_empty(event: InputEvent, _grabbed_item: ItemStack) -> void:
	var grabbed := GrabbedItemStackView.get_instance()
	if not is_instance_valid(grabbed) or grabbed.stack == null:
		return
	grabbed.item_input_cancelled = true
	if not (event is InputEventMouseButton) or event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_return_held()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_return_one(grabbed)


func _on_stacks_changed(_stack) -> void:
	_flush()


func _on_stack_count_changed(_stack, _delta) -> void:
	_flush()


func _on_item_selected(item_view: ItemStackView) -> void:
	_active_view = item_view
	_refresh_action()


func _on_item_deselected(item_view: ItemStackView) -> void:
	if _active_view == item_view:
		_active_view = null
		_refresh_action()


func _on_item_gui_input(event: InputEvent, item_view: ItemStackView) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.double_click:
		return
	var grabbed := GrabbedItemStackView.get_instance()
	if grabbed != null and grabbed.stack != null:
		return
	var stack := item_view.stack
	if stack == null:
		return
	var kind := String(stack.extra_properties.get("kind", ""))
	if kind == "use":
		var id := String(stack.item_type.resource_name)
		if GameState.use_item(id):
			_loading = true
			bag_view.inventory.clear()
			equip_view.inventory.clear()
			_leftovers.clear()
			_load_from_game_state()
			_loading = false
			_flush()
		_refresh_action()
		get_viewport().set_input_as_handled()
		return
	if kind == "equip":
		var source := item_view.get_parent()
		while source != null and not (source is InventoryView):
			source = source.get_parent()
		if source is InventoryView:
			source._quick_transfer_anywhere(item_view)
		_refresh_action()
		get_viewport().set_input_as_handled()
		return

func _active_stack() -> ItemStack:
	if _active_view == null or not is_instance_valid(_active_view):
		return null
	return _active_view.stack


func _refresh_action() -> void:
	var stack := _active_stack()
	if stack == null:
		action_button.text = "НЕТ ПРЕДМЕТА"
		action_button.disabled = true
		return
	var use := String(stack.extra_properties.get("kind", "")) == "use"
	action_button.text = "ИСПОЛЬЗОВАТЬ" if use else "НАДЕТЬ"
	action_button.disabled = false


func _on_action_pressed() -> void:
	var stack := _active_stack()
	# пока предмет в руке, перекладывать кнопкой нельзя: аддон отдаст его
	# тому, что под курсором, и предмет исчезнет между сумкой и рукой
	if stack == null or GrabbedItemStackView.grabbed_stack != null:
		return
	if String(stack.extra_properties.get("kind", "")) == "use":
		if GameState.use_item(String(stack.item_type.resource_name)):
			bag_view.inventory.add_items_to_stack(stack, -1)
		return
	var source := bag_view if stack.inventory == bag_view.inventory else equip_view
	source._quick_transfer_anywhere(_active_view)


func _on_sort_pressed() -> void:
	bag_view.sort_inventory()


func _refresh_stats() -> void:
	_stat_labels["dmg"].text = "Урон: +%d%%" % int(GameState.get_damage_bonus())
	_stat_labels["armor"].text = "Броня: +%d" % int(GameState.get_armor_bonus())
	_stat_labels["hp"].text = "Здоровье: +%d" % int(GameState.get_health_bonus())
	_stat_labels["noise"].text = "Шум: −%d%%" % int(GameState.get_noise_reduction() * 100.0)
	_stat_labels["free"].text = "Свободно ячеек: %d" \
		% bag_view.inventory.get_all_free_positions().size()
