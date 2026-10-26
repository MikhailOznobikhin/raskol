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

# --- Страж ---
const GUARD_HP := 60.0
const GUARD_SPEED := 2.6
const GUARD_CHASE := 3.4
const GUARD_DMG := 8.0
const GUARD_RANGE := 2.3
const GUARD_DETECT := 14.0

# --- Босс ---
const BOSS_HP := 280.0
const BOSS_SPEED := 2.2
const BOSS_CHASE := 2.9
const BOSS_DMG := 16.0
const BOSS_RANGE := 3.1
const BOSS_DETECT := 18.0
