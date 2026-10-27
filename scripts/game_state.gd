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
var stats := {"strength": 0, "vitality": 0, "spirit": 0}
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
var inventory: Array = []
var equipped := {
	"helmet": null,
	"armor": null,
	"boots": null,
	"weapon": null,
}

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
	equipped = {"helmet": null, "armor": null, "boots": null, "weapon": null}
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


func get_armor_bonus() -> float:
	var total := 0.0
	for slot in equipped.keys():
		var it = equipped[slot]
		if it is Dictionary:
			total += float(it.get("armor", 0.0))
	return total


func get_health_bonus() -> float:
	var total := 0.0
	for slot in equipped.keys():
		var it = equipped[slot]
		if it is Dictionary:
			total += float(it.get("hp", 0.0))
	return total


func get_damage_bonus() -> float:
	var total := 0.0
	for slot in equipped.keys():
		var it = equipped[slot]
		if it is Dictionary:
			total += float(it.get("dmg", 0.0))
	return total


func equip_item(item: Dictionary) -> void:
	if not (item is Dictionary):
		return
	var slot: String = item.get("slot", "")
	if slot == "":
		return
	equipped[slot] = item.duplicate()
	if not inventory.has(item) and not inventory.has(item.get("id")):
		# если пришёл новый предмет - добавить в инвентарь при первом надевании не обязательно
		pass
	inventory_changed.emit()
	stats_changed.emit()


func unequip(slot: String) -> void:
	if equipped.has(slot):
		equipped[slot] = null
		inventory_changed.emit()
		stats_changed.emit()


func add_item(item: Dictionary) -> void:
	if item is Dictionary:
		inventory.append(item.duplicate())
		inventory_changed.emit()


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


## Во сколько раз враги слышат героя: при высокой Жажде — сердцебиение.
func noise_mult() -> float:
	if craving > 70.0:
		return 1.4
	if craving > 40.0:
		return 1.15
	return 1.0


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
	bonus += float(stats["spirit"]) * Balance.STAT_SPIRIT_MANA
	bonus += float(skill_rank("blood_well")) * Balance.BLOOD_WELL_MANA
	return MAX_MAGIC + bonus


## Множитель ближнего урона: уровни + сила + «Железная рука».
func melee_damage_mult() -> float:
	var m := 1.0 + float(level - 1) * Balance.LEVELUP_DMG
	m += float(stats["strength"]) * Balance.STAT_STRENGTH_DMG
	m += float(skill_rank("iron_arm")) * Balance.IRON_ARM_DMG
	return m


## Множитель урона заклинаний (шип, нова).
func spell_damage_mult() -> float:
	var m := 1.0 + float(level - 1) * Balance.LEVELUP_DMG
	m += float(skill_rank("spike_mastery")) * Balance.SPIKE_MASTERY_DMG
	return m


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
		stat_points += Balance.POINTS_PER_LEVEL
		skill_points += Balance.POINTS_PER_LEVEL
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
	elif stat == "spirit":
		magic = minf(get_max_magic(), magic + Balance.STAT_SPIRIT_MANA)
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
	stats = {"strength": 0, "vitality": 0, "spirit": 0}
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
	stats = {"strength": 0, "vitality": 0, "spirit": 0}
	var saved_stats = data.get("stats", {})
	if saved_stats is Dictionary:
		for key in stats.keys():
			stats[key] = maxi(0, int(saved_stats.get(key, 0)))
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
