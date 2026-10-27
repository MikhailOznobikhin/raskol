extends RefCounted
class_name Progression
## Каталог навыков развития и кривая опыта.
## Цифры живут в Balance, здесь — только состав навыков и их подача в UI.

const SKILLS: Dictionary = {
	"iron_arm": {
		"name": "Железная рука",
		"desc": "+10% урона в ближнем бою за ранг",
		"max_rank": 5,
		"level": 1,
		"kind": "passive",
	},
	"thick_skin": {
		"name": "Толстая кожа",
		"desc": "+20 к максимуму здоровья за ранг",
		"max_rank": 5,
		"level": 1,
		"kind": "passive",
	},
	"blood_well": {
		"name": "Кровавый колодец",
		"desc": "+20 к максимуму магии за ранг",
		"max_rank": 5,
		"level": 2,
		"kind": "passive",
	},
	"swift_step": {
		"name": "Скорый шаг",
		"desc": "−20% цены рывка за ранг",
		"max_rank": 3,
		"level": 2,
		"kind": "passive",
	},
	"spike_mastery": {
		"name": "Владение шипом",
		"desc": "+25% урона кровавого шипа за ранг",
		"max_rank": 4,
		"level": 3,
		"kind": "passive",
	},
	"blood_nova": {
		"name": "Кровавая нова",
		"desc": "R: кольцо крови вокруг героя, 30 магии",
		"max_rank": 1,
		"level": Balance.NOVA_LEVEL,
		"kind": "active",
	},
}


static func skill(id: String) -> Dictionary:
	var data = SKILLS.get(id, {})
	if data is Dictionary:
		return data
	return {}


static func ids() -> Array:
	return SKILLS.keys()


## Сколько опыта нужно, чтобы уйти с уровня `level` на следующий.
## 0 — уровень максимальный, дальше расти некуда.
static func xp_for_level(level: int) -> int:
	if level >= Balance.LEVEL_MAX:
		return 0
	var need: float = Balance.XP_LEVEL_BASE * pow(Balance.XP_LEVEL_GROWTH, float(level - 1))
	return int(round(need))
