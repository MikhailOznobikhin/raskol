extends Node
## Глобальное состояние: здоровье, магия, Жажда, Доверие, флаги сюжета.
## Всё, что переживает смену сцен, живёт здесь.

signal stats_changed
signal trust_changed(old_value: int, new_value: int)
signal craving_changed(value: float)

const MAX_HEALTH := 100.0
const MAX_MAGIC := 100.0
const MAX_CRAVING := 100.0

var health := 100.0
var magic := 0.0
var craving := 0.0
var trust := -40

# статистика прохождения (влияет на концовку)
var magic_used := 0.0
var flesh_eaten := 0
var guards_killed := 0
var guards_spared := 0
var selena := ""            # "" | "freed" | "devoured"
var boss_dead := false
var saw_prologue := false

# флаги уровня
var gates := {}             # id -> bool
var escaped := false
var playtime := 0.0


func reset_run() -> void:
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
	stats_changed.emit()


func _process(delta: float) -> void:
	playtime += delta


func damage(amount: float) -> void:
	health = max(0.0, health - amount)
	stats_changed.emit()


func heal(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)
	stats_changed.emit()


func add_magic(amount: float) -> void:
	magic = clamp(magic + amount, 0.0, MAX_MAGIC)
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


func ending() -> String:
	# В: «Множественный выбор» — если магии/мяса было много
	if magic_used > 260.0 or flesh_eaten >= 7:
		return "C"
	if trust >= 25 and selena == "freed":
		return "A"
	return "B"
