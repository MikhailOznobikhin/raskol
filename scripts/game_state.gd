extends Node
## Глобальное состояние: здоровье, магия, Жажда, Доверие, флаги сюжета.
## Всё, что переживает смену сцен, живёт здесь.

signal stats_changed
signal trust_changed(old_value: int, new_value: int)
signal craving_changed(value: float)
signal inventory_changed
signal xp_changed
signal xp_gained(amount: int)
signal level_up(level: int)
signal skills_changed

const MAX_HEALTH := 100.0
const MAX_MAGIC := 100.0
const MAX_CRAVING := 100.0

var health := 100.0
var magic := 0.0
var craving := 0.0
var trust := -40

# прокачка: опыт, уровни, очки и изученные навыки
var level := 1
var xp := 0
var stat_points := 0
var skill_points := 0
var stats := {"strength": 0, "agility": 0, "vitality": 0}
var skills := {}            # id навыка -> ранг

# статистика прохождения (влияет на концовку)
var magic_used := 0.0
var flesh_eaten := 0
var guards_killed := 0
var guards_spared := 0
var selena := ""            # "" | "freed" | "devoured"
var boss_dead := false
var saw_prologue := false

# инвентарь и экипировка
## Порядок обхода слотов в интерфейсе: оружие и броня слева, мелочь справа.
const EQUIP_SLOTS := ["weapon", "helmet", "armor", "boots", "ring", "amulet"]
const SLOT_TITLES := {
	"weapon": "ОРУЖИЕ", "helmet": "ШЛЕМ", "armor": "БРОНЯ",
	"boots": "САПОГИ", "ring": "КОЛЬЦО", "amulet": "АМУЛЕТ",
}
var inventory: Array = []   # [{id, name, kind, slot, icon, count, ...}]
var equipped := {}          # slot -> предмет | null

# флаги уровня
var gates := {}             # id -> bool
var escaped := false
var playtime := 0.0


func reset_run() -> void:
	reset_progression()
	health = MAX_HEALTH
	magic = 15.0
	craving = 0.0
	trust = -40
	magic_used = 0.0
	flesh_eaten = 0
	guards_killed = 0
	guards_spared = 0
	selena = ""
	boss_dead = false
	gates = {}
	escaped = false
	playtime = 0.0
	inventory.clear()
	_reset_equipped()
	stats_changed.emit()
	inventory_changed.emit()


func _process(delta: float) -> void:
	playtime += delta


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	stats_changed.emit()


func heal(amount: float) -> void:
	health = minf(get_max_health(), health + amount)
	stats_changed.emit()


func _reset_equipped() -> void:
	equipped = {}
	for s in EQUIP_SLOTS:
		equipped[s] = null


## Предметы, надетые в слоты, — одним обходом: бонусы читают отсюда.
func _equipped_items() -> Array:
	var out := []
	for s in EQUIP_SLOTS:
		var it = equipped.get(s)
		if it is Dictionary:
			out.append(it)
	return out


func get_armor_bonus() -> float:
	var total := 0.0
	for it in _equipped_items():
		total += float(it.get("armor", 0.0))
	return total


func get_health_bonus() -> float:
	var total := 0.0
	for it in _equipped_items():
		total += float(it.get("hp", 0.0))
	return total


func get_damage_bonus() -> float:
	var total := 0.0
	for it in _equipped_items():
		total += float(it.get("dmg", 0.0))
	return total


## Насколько экипировка глушит звук: 0.25 — шаги на четверть тише.
func get_noise_reduction() -> float:
	var total := 0.0
	for it in _equipped_items():
		total += float(it.get("noise", 0.0))
	return clampf(total, 0.0, 0.6)


## Сколько урона снимает броня (доля от 0 до 0.5): 6 единиц брони = 10%.
func armor_reduction() -> float:
	return clampf(get_armor_bonus() * 0.02, 0.0, 0.5)


## Урон после брони. Всегда оставляет минимум 1: беззащитный герой не должен
## превращаться в неприкосновенного из-за пары амулетов.
func mitigate_damage(amount: float) -> float:
	if amount <= 0.0:
		return amount
	return maxf(1.0, amount * (1.0 - armor_reduction()))


## Человекочитаемое описание бонусов: «+10% урона · +5 к броне».
## Собирается из полей предмета, поэтому цифры в тексте не могут разойтись
## с тем, что реально считает mitigate_damage и melee_damage_mult.
func item_bonuses_text(item: Dictionary) -> String:
	var parts := []
	var dmg := int(item.get("dmg", 0))
	if dmg != 0:
		parts.append("%+d%% урона" % dmg)
	var arm := int(item.get("armor", 0))
	if arm != 0:
		parts.append("%+d к броне" % arm)
	var hp := int(item.get("hp", 0))
	if hp != 0:
		parts.append("%+d к здоровью" % hp)
	var noise := float(item.get("noise", 0.0))
	if noise > 0.0:
		parts.append("-%d%% шума" % int(noise * 100.0))
	var rh := int(item.get("restore_hp", 0))
	if rh != 0:
		parts.append("возвращает %d здоровья" % rh)
	var rm := int(item.get("restore_magic", 0))
	if rm != 0:
		parts.append("возвращает %d магии" % rm)
	return " · ".join(parts)


func item_by_id(id: String) -> Dictionary:
	for it in inventory:
		if it is Dictionary and String(it.get("id", "")) == id:
			return it
	return {}


## Снимает один предмет из сумки, не испуская сигнал: пакетные операции сами
## решают, когда перерисовывать интерфейс.
func _take_one(id: String) -> Dictionary:
	var item := item_by_id(id)
	if item.is_empty():
		return {}
	if int(item.get("count", 1)) > 1:
		item["count"] = int(item.get("count", 1)) - 1
		item = item.duplicate(true)
	else:
		inventory.erase(item)
	return item


func _put_one(item: Dictionary) -> void:
	var have := item_by_id(String(item.get("id", "")))
	if not have.is_empty() and String(have.get("kind", "")) == "use":
		have["count"] = int(have.get("count", 1)) + 1
		return
	inventory.append(item.duplicate(true))


## Кладёт предмет в сумку. Расходники складываются в стопку, снаряжение — нет.
func add_item(item: Dictionary) -> void:
	if not (item is Dictionary) or String(item.get("id", "")) == "":
		return
	var have := item_by_id(String(item.get("id", "")))
	if not have.is_empty():
		if String(have.get("kind", "")) == "use":
			have["count"] = int(have.get("count", 1)) + 1
			inventory_changed.emit()
		return
	_put_one(item)
	inventory_changed.emit()


## Надевает предмет из сумки; то, что было в слоте, возвращается в сумку.
func equip_item(id: String) -> bool:
	var item := item_by_id(id)
	if item.is_empty() or String(item.get("kind", "")) != "equip":
		return false
	var slot := String(item.get("slot", ""))
	if slot == "":
		return false
	if not equipped.has(slot):
		equipped[slot] = null
	var taken := _take_one(id)
	if taken.is_empty():
		return false
	var old = equipped[slot]
	equipped[slot] = taken
	if old is Dictionary:
		_put_one(old)
	inventory_changed.emit()
	stats_changed.emit()
	return true


func unequip(slot: String) -> void:
	var old = equipped.get(slot)
	if not (old is Dictionary):
		return
	equipped[slot] = null
	_put_one(old)
	inventory_changed.emit()
	stats_changed.emit()


## Расходник по двойному клику: выпить зелье, сжечь свиток.
func use_item(id: String) -> bool:
	var item := item_by_id(id)
	if item.is_empty() or String(item.get("kind", "")) != "use":
		return false
	var hp := float(item.get("restore_hp", 0.0))
	var mg := float(item.get("restore_magic", 0.0))
	if hp <= 0.0 and mg <= 0.0:
		return false
	if hp > 0.0:
		heal(hp)
	if mg > 0.0:
		add_magic(mg)
	_take_one(id)
	inventory_changed.emit()
	stats_changed.emit()
	return true


func add_magic(amount: float) -> void:
	magic = clampf(magic + amount, 0.0, get_max_magic())
	stats_changed.emit()


func spend_magic(amount: float) -> bool:
	if magic + 0.001 < amount:
		return false
	magic -= amount
	magic_used += amount
	stats_changed.emit()
	return true


func add_craving(amount: float) -> void:
	craving = clamp(craving + amount, 0.0, MAX_CRAVING)
	craving_changed.emit(craving)
	stats_changed.emit()


## Множитель урона от Жажды: >40 — +10%, >70 — +25%.
func craving_damage_mult() -> float:
	if craving > 70.0:
		return 1.25
	if craving > 40.0:
		return 1.10
	return 1.0


## Во сколько раз враги слышат героя: при высокой Жажде — сердцебиение,
## плащ и подобные вещи шум глушат.
func noise_mult() -> float:
	var k := 1.0
	if craving > 70.0:
		k = 1.4
	elif craving > 40.0:
		k = 1.15
	return k * (1.0 - get_noise_reduction())


func add_trust(delta_value: int) -> void:
	var old := trust
	trust = clampi(trust + delta_value, -100, 100)
	trust_changed.emit(old, trust)
	stats_changed.emit()


# --- Прокачка: производные максимумы, множители, очки и навыки ---

## Максимум здоровья: база + экипировка + уровни + живучесть + навыки.
func get_max_health() -> float:
	var bonus: float = get_health_bonus()
	bonus += float(level - 1) * Balance.LEVELUP_HP
	bonus += float(stats["vitality"]) * Balance.STAT_VITALITY_HP
	bonus += float(skill_rank("thick_skin")) * Balance.THICK_SKIN_HP
	return MAX_HEALTH + bonus


func get_max_magic() -> float:
	var bonus: float = float(level - 1) * Balance.LEVELUP_MANA
	bonus += float(skill_rank("blood_well")) * Balance.BLOOD_WELL_MANA
	return MAX_MAGIC + bonus


## Множитель ближнего урона: уровни + сила + «Железная рука» + снаряжение.
func melee_damage_mult() -> float:
	var m := 1.0 + float(level - 1) * Balance.LEVELUP_DMG
	m += float(stats["strength"]) * Balance.STAT_STRENGTH_DMG
	m += float(skill_rank("iron_arm")) * Balance.IRON_ARM_DMG
	return m + get_damage_bonus() / 100.0


## Множитель скорости передвижения от ловкости (шаг, бег, крадущийся шаг).
func move_speed_mult() -> float:
	return 1.0 + float(stats["agility"]) * Balance.STAT_AGILITY_SPEED


## Множитель урона заклинаний (шип, нова).
func spell_damage_mult() -> float:
	var m := 1.0 + float(level - 1) * Balance.LEVELUP_DMG
	m += float(skill_rank("spike_mastery")) * Balance.SPIKE_MASTERY_DMG
	return m + get_damage_bonus() / 100.0


## Цена рывка с учётом «Скорого шага».
func dodge_cost() -> float:
	var k: float = clampf(1.0 - float(skill_rank("swift_step")) * Balance.SWIFT_STEP_DODGE, 0.0, 1.0)
	return Balance.DODGE_COST * k


func xp_need() -> int:
	return Progression.xp_for_level(level)


## Начисляет опыт. Уровни могут идти пачкой: за босса иногда сразу два.
func add_xp(amount: int) -> void:
	if amount <= 0 or level >= Balance.LEVEL_MAX:
		return
	xp += amount
	xp_gained.emit(amount)
	var leveled := false
	while level < Balance.LEVEL_MAX:
		var need: int = Progression.xp_for_level(level)
		if need <= 0 or xp < need:
			break
		xp -= need
		level += 1
		stat_points += Balance.STAT_POINTS_PER_LEVEL
		skill_points += Balance.SKILL_POINTS_PER_LEVEL
		health = minf(get_max_health(), health + get_max_health() * Balance.LEVELUP_HEAL)
		magic = minf(get_max_magic(), magic + get_max_magic() * Balance.LEVELUP_MANA_HEAL)
		leveled = true
		level_up.emit(level)
	if level >= Balance.LEVEL_MAX:
		xp = 0
	if leveled:
		stats_changed.emit()
	xp_changed.emit()


## Тратит очко характеристик. false — очков нет или ранг уже максимальный.
func add_stat(stat: String) -> bool:
	if stat_points <= 0 or not stats.has(stat):
		return false
	if int(stats[stat]) >= Balance.STAT_MAX_RANK:
		return false
	stats[stat] = int(stats[stat]) + 1
	stat_points -= 1
	if stat == "vitality":
		health = minf(get_max_health(), health + Balance.STAT_VITALITY_HP)
	stats_changed.emit()
	xp_changed.emit()
	return true


func skill_rank(id: String) -> int:
	return int(skills.get(id, 0))


## Можно ли изучить или поднять навык прямо сейчас.
func can_unlock_skill(id: String) -> bool:
	var data := Progression.skill(id)
	if data.is_empty():
		return false
	if level < int(data.get("level", 1)):
		return false
	return skill_rank(id) < int(data.get("max_rank", 1)) and skill_points > 0


func unlock_skill(id: String) -> bool:
	if not can_unlock_skill(id):
		return false
	skills[id] = skill_rank(id) + 1
	skill_points -= 1
	skills_changed.emit()
	stats_changed.emit()
	xp_changed.emit()
	return true


func reset_progression() -> void:
	level = 1
	xp = 0
	stat_points = 0
	skill_points = 0
	stats = {"strength": 0, "agility": 0, "vitality": 0}
	skills = {}
	xp_changed.emit()
	skills_changed.emit()
	stats_changed.emit()


func progression_data() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"stat_points": stat_points,
		"skill_points": skill_points,
		"stats": stats.duplicate(),
		"skills": skills.duplicate(),
	}


## Восстановление прокачки из чекпоинта.
func apply_progression(data: Dictionary) -> void:
	if data.is_empty():
		return
	level = clampi(int(data.get("level", 1)), 1, Balance.LEVEL_MAX)
	xp = maxi(0, int(data.get("xp", 0)))
	stat_points = maxi(0, int(data.get("stat_points", 0)))
	skill_points = maxi(0, int(data.get("skill_points", 0)))
	skills = {}
	var saved_skills = data.get("skills", {})
	if saved_skills is Dictionary:
		for key in saved_skills.keys():
			skills[String(key)] = maxi(0, int(saved_skills[key]))
	stats = {"strength": 0, "agility": 0, "vitality": 0}
	var saved_stats = data.get("stats", {})
	if saved_stats is Dictionary:
		for key in stats.keys():
			stats[key] = maxi(0, int(saved_stats.get(key, 0)))
		# «Духа» больше нет: вложенные в него очки возвращаем в пул,
		# чтобы старый чекпоинт не съел накопленную прокачку.
		stat_points += maxi(0, int(saved_stats.get("spirit", 0)))
	xp_changed.emit()
	skills_changed.emit()
	stats_changed.emit()


func ending() -> String:
	# В: «Множественный выбор» — если магии/мяса было много
	if magic_used > 260.0 or flesh_eaten >= 7:
		return "C"
	if trust >= 25 and selena == "freed":
		return "A"
	return "B"
