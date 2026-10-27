class_name ItemCatalog
extends RefCounted
## КаталогItemType для Wyvernbox: шаблоны предметов собираются из lore.json,
## чтобы описание и иконка не разъезжались с тем, что носит GameState.

## Ищу иконку сначала в новой папке, потом в старых asset'ах HUD.
const ICON_PATHS := ["res://assets/ui/icons/", "res://assets/ui/"]

## Слот GameState -> флаг ячейки экипировки, которую предмет туда пустят.
const SLOT_FLAGS := {
	"weapon": ItemType.SlotFlags.E_MAINHAND,
	"offhand": ItemType.SlotFlags.E_OFFHAND,
	"helmet": ItemType.SlotFlags.E_HEAD,
	"armor": ItemType.SlotFlags.E_CHEST,
	"belt": ItemType.SlotFlags.E_BELT,
	"hands": ItemType.SlotFlags.E_HANDS,
	"boots": ItemType.SlotFlags.E_FEET,
	"ring": ItemType.SlotFlags.E_RING,
	"ring2": ItemType.SlotFlags.E_RING,
	"amulet": ItemType.SlotFlags.E_NECK,
}

const BONUS_KEYS := ["dmg", "armor", "hp", "noise", "restore_hp", "restore_magic"]

static var _types := {}
static var _sources := {}


## Шаблоны по id предмета. Строит один раз за запуск: предметы добавляет только миссия.
static func types() -> Dictionary:
	if _types.is_empty():
		_build()
	return _types


## Исходная запись предмета из lore.json — по ней мост восстанавливает словарь GameState.
static func source(id: String) -> Dictionary:
	if _sources.is_empty():
		_build()
	return _sources.get(id, {})


static func stack(id: String, count: int = 1) -> ItemStack:
	var type: ItemType = types().get(id)
	if type == null:
		return null
	return ItemStack.new(type, count)


static func equip_flags() -> Array[ItemType.SlotFlags]:
	var out: Array[ItemType.SlotFlags] = []
	for slot in GameState.EQUIP_SLOTS:
		out.append(SLOT_FLAGS.get(slot, ItemType.SlotFlags.EQUIPMENT))
	return out


static func _build() -> void:
	var txt := FileAccess.get_file_as_string("res://assets/text/lore.json")
	if txt.is_empty():
		push_error("Не найден lore.json — каталог предметов пуст")
		return
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("lore.json повреждён — каталог предметов пуст")
		return
	for entry in parsed.get("items", []):
		if not (entry is Dictionary):
			continue
		var id := String(entry.get("id", ""))
		if id == "":
			continue
		var type := _make_type(entry)
		_types[id] = type
		_sources[id] = entry.duplicate(true)


static func _make_type(entry: Dictionary) -> ItemType:
	var type := ItemType.new()
	type.name = String(entry.get("name", id_of(entry)))
	type.description = String(entry.get("desc", ""))
	type.texture = _icon(entry)
	type.resource_name = id_of(entry)
	var usable := String(entry.get("kind", "")) == "use"
	type.max_stack_count = 99 if usable else 1
	# Расходным хватает метки «зелье»: их принимает любая ячейка сумки.
	# Снаряжение же ячейки экипировки фильтруют по флагу именно своего слота.
	if usable:
		type.slot_flags = ItemType.SlotFlags.POTION
	else:
		type.slot_flags = SLOT_FLAGS.get(String(entry.get("slot", "")),
			ItemType.SlotFlags.EQUIPMENT)
	var props := {}
	for key in BONUS_KEYS:
		if entry.has(key):
			props[key] = entry[key]
	props["id"] = id_of(entry)
	props["kind"] = String(entry.get("kind", ""))
	type.default_properties = props
	return type


static func id_of(entry: Dictionary) -> String:
	return String(entry.get("id", ""))


static func _icon(entry: Dictionary) -> Texture2D:
	for name in [id_of(entry), String(entry.get("icon", ""))]:
		if name == "":
			continue
		for base: String in ICON_PATHS:
			# Иконки HUD исторически с префиксом «icon_», новые кладут по имени предмета.
			for prefix: String in ["", "icon_"]:
				var path: String = base + prefix + name + ".png"
				if ResourceLoader.exists(path):
					return load(path) as Texture2D
	return null
