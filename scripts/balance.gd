extends RefCounted
class_name Balance
## Баланс: единый источник цифр для героя и врагов 3D-RPG.

# --- Герой ---
const HERO_SPEED := 3.6
const HERO_RUN := 5.8
const HERO_ACCEL := 22.0
const HERO_DODGE_SPEED := 12.0
const HERO_DODGE_TIME := 0.22
const HERO_INVULN_DODGE := 0.3
const HERO_LIGHT_DMG := 12.0
const HERO_HEAVY_DMG := 26.0
const HERO_HEAVY_WINDUP := 0.42
const HERO_ATTACK_TIME := 0.42
const DODGE_COST := 15.0
const DODGE_CD := 0.6

# --- Кровавый шип (Q) ---
const SPIKE_COST := 10.0           # цена в магии
const SPIKE_DMG := 18.0
const SPIKE_RANGE := 11.0          # 220 px в 2D-версии
const SPIKE_SPEED := 22.0
const SPIKE_CD := 0.85
const NOISE_SPIKE := 4.5           # шум 60 px

# --- Скрытность героя ---
const HERO_CROUCH := 2.0            # скорость крадущегося шага
const NOISE_CROUCH := 3.0           # радиус шума, м
const NOISE_WALK := 6.5
const NOISE_RUN := 11.0
const NOISE_ABSORB := 4.0
const NOISE_CHAIN := 8.0
const NOISE_HIT := 6.0
const NOISE_THROW := 9.0
const DISTRACT_CD := 1.5

# --- Страж ---
const GUARD_HP := 60.0
const GUARD_SPEED := 2.6
const GUARD_CHASE := 3.4
const GUARD_DMG := 8.0
const GUARD_RANGE := 2.3
const GUARD_DETECT := 14.0
const GUARD_FOV := 60.0             # полный угол конуса зрения, градусы
const GUARD_DETECT_DARK := 7.5      # радиус зрения в темноте, м
const GUARD_DETECT_BRIGHT := 17.0   # радиус зрения на ярком свету, м
const GUARD_ALERT_MAX := 100.0      # накопитель внимания
const GUARD_SUSPICIOUS_TIME := 1.5  # «подозревает» — стоп, поворот, фраза
const GUARD_SEARCH_TIME := 6.0      # «поиск» — идёт к последней точке
const GUARD_LOSE_TIME := 4.0        # теряет цель после 4 с без видимости
const GUARD_CRAVING_MULT := 1.4     # Жажда 70+ расширяет зрение
const CRAVING_DETECT := 70.0

# --- Босс ---
const BOSS_HP := 280.0
const BOSS_SPEED := 2.2
const BOSS_CHASE := 2.9
const BOSS_DMG := 16.0
const BOSS_RANGE := 3.1
const BOSS_DETECT := 18.0

# --- Модели (высота в метрах) ---
const HERO_MODEL_HEIGHT := 1.42
const GUARD_MODEL_HEIGHT := 1.80
const BOSS_MODEL_HEIGHT := 2.30

# --- Прокачка: опыт и уровни ---
const XP_GUARD := 100            # опыт за убитого стражника
const XP_BOSS := 400             # опыт за босса
const XP_LEVEL_BASE := 100.0     # опыт на путь 1 → 2
const XP_LEVEL_GROWTH := 1.55    # во сколько раз дороже каждый следующий уровень
const LEVEL_MAX := 30
const POINTS_PER_LEVEL := 1      # очков характеристик и навыков за уровень
const LEVELUP_HP := 12.0         # автоприрост здоровья за уровень
const LEVELUP_MANA := 8.0        # автоприрост магии за уровень
const LEVELUP_DMG := 0.04        # автоприрост урона за уровень (+4%)
const LEVELUP_HEAL := 0.35       # доля максимального здоровья при лечении на уровне
const LEVELUP_MANA_HEAL := 0.25  # доля максимальной магии при лечении на уровне

# --- Характеристики (одно очко) ---
const STAT_MAX_RANK := 20
const STAT_STRENGTH_DMG := 0.08  # +8% урона за очко силы
const STAT_VITALITY_HP := 15.0   # +15 здоровья за очко живучести
const STAT_SPIRIT_MANA := 12.0   # +12 магии за очко духа

# --- Навыки развития ---
const IRON_ARM_DMG := 0.10       # железная рука: +10% ближнего урона за ранг
const THICK_SKIN_HP := 20.0      # толстая кожа: +20 здоровья за ранг
const BLOOD_WELL_MANA := 20.0    # кровавый колодец: +20 магии за ранг
const SWIFT_STEP_DODGE := 0.20   # скорый шаг: −20% цены рывка за ранг
const SPIKE_MASTERY_DMG := 0.25  # владение шипом: +25% урона шипа за ранг
const NOVA_LEVEL := 4            # с какого уровня открывается «Кровавая нова»
const NOVA_COST := 30.0
const NOVA_DMG := 34.0
const NOVA_RADIUS := 5.0
const NOVA_CD := 6.0
