"""Персонажи: гномы, люди, эльфы.

Сборка из деталей: голова, борода, торс, руки, ноги, оружие. Каждая деталь
рисуется отдельно со своей подсветкой, затем собирается по «скелету» позы.
Так анимация остаётся управляемой, а рисунок — читаемым.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

from . import palette as P
from .pixelkit import Canvas, directional_shade, dither_shade

BASE_W, BASE_H = 48, 64


@dataclass
class Pose:
    bob: int = 0
    lean: int = 0
    crouch: float = 0.0
    leg_l: tuple = (0, 0)
    leg_r: tuple = (0, 0)
    arm_l: tuple = (0, 0)
    arm_r: tuple = (0, 0)
    head: tuple = (0, 0)
    beard: int = 0
    squash: int = 0
    weapon_angle: float | None = None   # угол оружия (град., 0 = вправо)
    extend: int = 0                     # вынос оружия от корпуса


@dataclass
class Look:
    cloth: str = "#25395e"
    cloth_dark: str = "#16233a"
    cloth_light: str = "#334d7a"
    pants: str = "#2c1f14"
    leather: str = "#3f2d1b"
    leather_light: str = "#573e25"
    skin: str = "#8f5c3e"
    hair: str = "#974a22"
    hair_gray: str = "#858a99"
    metal: str = "#4f5b70"
    metal_light: str = "#9aabc4"
    metal_dark: str = "#282e3a"
    eye: str = "#f5b23c"
    rim: str = "#f5b23c"
    accent: str = "#c9a548"


HERO = Look(
    cloth="#1a2a47", cloth_dark="#111d33", cloth_light="#27405f",
    pants="#2c1f14", leather="#3f2d1b", leather_light="#573e25",
    skin="#9a6a4a", hair="#6b3116", hair_gray="#8b8b93",
    metal="#4f5b70", metal_light="#9aabc4", metal_dark="#282e3a",
    eye="#f5b23c", rim="#f5b23c", accent="#c9a548",
)

GUARD = Look(
    cloth="#3d0b19", cloth_dark="#230610", cloth_light="#5c1026",
    pants="#1c2029", leather="#2c1f14", leather_light="#3f2d1b",
    skin="#70452f", hair="#2d130b", hair_gray="#40434e",
    metal="#4f5b70", metal_light="#9aabc4", metal_dark="#282e3a",
    eye="#e0334f", rim="#a32247", accent="#7d1734",
)

JAILER = Look(
    cloth="#2f3b2f", cloth_dark="#1b241b", cloth_light="#425239",
    pants="#1c2029", leather="#2c1f14", leather_light="#573e25",
    skin="#70452f", hair="#2d130b", hair_gray="#40434e",
    metal="#394252", metal_light="#6f7e98", metal_dark="#1c2029",
    eye="#f5b23c", rim="#d97a1c", accent="#755434",
)

GHARN = Look(
    cloth="#5c1026", cloth_dark="#230610", cloth_light="#7d1734",
    pants="#12151c", leather="#1b130d", leather_light="#3f2d1b",
    skin="#ad7855", hair="#1c1410", hair_gray="#6f7e98",
    metal="#394252", metal_light="#9aabc4", metal_dark="#12151c",
    eye="#ff5570", rim="#c93a5b", accent="#c9a548",
)

SELENA = Look(
    cloth="#25395e", cloth_dark="#111d33", cloth_light="#3d5b8c",
    pants="#1b130d", leather="#3f2d1b", leather_light="#755434",
    skin="#b98f6d", hair="#e2d3a8", hair_gray="#cfc49a",
    metal="#6f7e98", metal_light="#c9d8ea", metal_dark="#282e3a",
    eye="#8fe8dc", rim="#9db0c9", accent="#8fe8dc",
)


# ---------------------------------------------------------------------------
# детали: вид спереди
# ---------------------------------------------------------------------------

def _pants_color(look: Look):
    return P.hx(look.pants)


def leg_front(look: Look, w_boot=13):
    """Нога + тяжёлый ботинок, 13x16."""
    c = Canvas(13, 16)
    pants = _pants_color(look)
    pants_d = P.mix(pants, (0, 0, 0, 255), 0.4)
    leather = P.hx(look.leather)
    leather_l = P.hx(look.leather_light)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    metal_d = P.hx(look.metal_dark)

    # штанина
    c.rect(2, 0, 10, 8, pants)
    c.rect(2, 0, 5, 8, P.mix(pants, leather, 0.25))
    c.hline(2, 10, 6, pants_d)
    # обмотка голени
    c.rect(2, 7, 10, 11, leather)
    for y in (8, 10):
        c.hline(2, 10, y, leather_l)
    c.hline(3, 9, 11, P.mix(leather, (0, 0, 0, 255), 0.4))
    # ботинок
    c.d.rounded_rectangle([0, 10, 12, 15], radius=2, fill=P.mix(leather, (0, 0, 0, 255), 0.25))
    c.rect(0, 13, 12, 15, P.hx("#15100b"))
    c.hline(1, 11, 15, P.hx("#0a0806"))
    # железный носок
    c.d.rounded_rectangle([1, 11, 6, 14], radius=1, fill=metal)
    c.hline(1, 5, 11, metal_l)
    c.px(2, 12, metal_l)
    c.px(4, 13, metal_d)
    # заклёпки
    c.px(8, 12, metal_d)
    c.px(10, 12, P.hx(look.accent))
    directional_shade(c, amount=0.26)
    return c


def torso_front(look: Look, bulk=0, ragged=True):
    """Торс 28x26: рубаха, ремни, рваный подол, заплаты."""
    c = Canvas(28 + bulk * 2, 26)
    cloth = P.hx(look.cloth)
    cloth_d = P.hx(look.cloth_dark)
    cloth_l = P.hx(look.cloth_light)
    leather = P.hx(look.leather)
    leather_l = P.hx(look.leather_light)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    metal_d = P.hx(look.metal_dark)
    cx = (28 + bulk * 2) // 2

    # основной силуэт: плечи шире, к поясу уже
    rows = []
    for y in range(26):
        if y < 4:
            w = 13
        elif y < 15:
            w = 13 - int((y - 4) * 0.18)
        elif y < 20:
            w = 11
        else:
            w = 11 - (y - 20) // 2
        rows.append(w)
    for y, w in enumerate(rows):
        c.hline(cx - w, cx + w, y, cloth)
    # подол рваный
    if ragged:
        for i, x in enumerate(range(cx - 11, cx + 12, 3)):
            c.rect(x, 22, x + 2, 24 + (i % 2), cloth_d)
    # объём: левая сторона светлее
    for y in range(4, 22):
        w = rows[y]
        c.vline(cx - w + 1, y, y, cloth_l)
        c.hline(cx - w + 2, cx - w + 4, y, P.mix(cloth_l, cloth, 0.4))
        c.vline(cx + w, y, y, cloth_d)
    # складки
    for x in (cx - 7, cx - 2, cx + 4):
        for y in range(6, 20):
            if (y + x) % 5 < 3:
                c.px(x, y, cloth_d)
    # ворот
    c.rect(cx - 4, 0, cx + 4, 2, P.mix(cloth, (0, 0, 0, 255), 0.5))
    c.rect(cx - 3, 0, cx + 3, 1, P.hx(look.skin) if False else P.mix(cloth_d, (0, 0, 0, 255), 0.2))
    # заплата на груди
    c.rect(cx + 2, 6, cx + 7, 10, P.mix(cloth_d, leather, 0.35))
    for i in range(3):
        c.px(cx + 2, 6 + i * 2, P.mix(metal, cloth, 0.4))
        c.px(cx + 7, 7 + i * 2, P.mix(metal, cloth, 0.4))
    # грудные ремни (перевязь)
    c.line([(cx - 9, 2), (cx + 8, 12)], leather, 2)
    c.line([(cx - 8, 3), (cx + 9, 13)], leather_l, 1)
    c.px(cx + 3, 7, metal_l)
    # пояс-верёвка
    c.rect(cx - 11, 16, cx + 11, 19, leather)
    c.hline(cx - 11, cx + 11, 16, leather_l)
    c.hline(cx - 11, cx + 11, 19, P.mix(leather, (0, 0, 0, 255), 0.5))
    for x in range(cx - 10, cx + 11, 3):
        c.px(x, 17, P.mix(leather, leather_l, 0.5))
        c.px(x + 1, 18, P.mix(leather, (0, 0, 0, 255), 0.35))
    # пряжка-инструмент и кольцо сбоку
    c.rect(cx - 3, 16, cx + 2, 19, metal)
    c.px(cx - 2, 17, metal_l)
    c.px(cx + 1, 18, P.hx("#0a0c10"))
    # инженерный ремень: молоток и ключ
    c.vline(cx + 8, 14, 20, leather)
    c.rect(cx + 7, 13, cx + 7, 15, metal_d)
    c.px(cx + 7, 12, metal)
    c.rect(cx + 9, 19, cx + 10, 23, metal_d)
    c.px(cx + 10, 23, metal_l)
    # потёртости
    dither_shade(c, (110, 90, 70, 255), 0.06, seed=11)
    directional_shade(c, amount=0.22)
    return c


def arm_front(look: Look, is_left=True, sleeve=True):
    """Рука 8x17: рукав, наруч, кисть, кандальное кольцо."""
    c = Canvas(8, 17)
    cloth = P.hx(look.cloth_dark)
    cloth_l = P.hx(look.cloth)
    leather = P.hx(look.leather)
    leather_l = P.hx(look.leather_light)
    skin = P.hx(look.skin)
    skin_d = P.mix(skin, (0, 0, 0, 255), 0.45)
    skin_l = P.mix(skin, (255, 226, 190, 255), 0.3)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)

    c.rect(1, 0, 5, 6, cloth)
    c.vline(1, 0, 6, cloth_l)
    if sleeve:
        c.rect(0, 6, 6, 10, leather)
        c.hline(0, 6, 6, leather_l)
        c.hline(0, 6, 9, P.mix(leather, (0, 0, 0, 255), 0.5))
    # кисть
    c.d.rounded_rectangle([1, 10, 6, 14], radius=1, fill=skin)
    c.hline(1, 5, 11, skin_l)
    c.px(1, 13, skin_d)
    c.px(5, 13, skin_d)
    # кандальное кольцо
    c.hline(0, 6, 9, metal)
    c.px(6, 10, metal_l)
    c.px(0, 10, P.hx("#0a0c10"))
    directional_shade(c, amount=0.28)
    return c


def head_front(look: Look, gear: dict):
    """Голова 24x22: сильный контраст, глубокие глазницы, крупный нос."""
    c = Canvas(24, 22)
    skin = P.hx(look.skin)
    skin_d = P.mix(skin, (26, 10, 8, 255), 0.52)
    skin_m = P.mix(skin, (26, 10, 8, 255), 0.26)
    skin_l = P.mix(skin, (255, 228, 196, 255), 0.34)
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 5, 4, 255), 0.62)
    hair_l = P.mix(hair, (255, 210, 160, 255), 0.34)
    eye = P.hx(look.eye)

    # череп, челюсть, скулы
    c.ellipse(2, 1, 21, 18, skin)
    c.rect(7, 15, 16, 19, skin)
    c.rect(8, 18, 15, 19, skin)
    # правая сторона лица в тени
    for y in range(6, 19):
        c.px(20, y, skin_m)
        c.px(19, y, P.mix(skin, skin_m, 0.45))
    c.hline(5, 18, 17, skin_m)
    # виски/лоб
    c.hline(6, 17, 6, skin_l)
    c.hline(6, 17, 7, P.mix(skin_l, skin, 0.5))
    # уши
    c.rect(1, 10, 1, 13, skin)
    c.px(1, 11, skin_d)
    c.rect(22, 10, 22, 13, skin_d)
    # волосы: высокий лоб, космы на висках
    c.ellipse(1, 0, 22, 6, hair)
    c.ellipse(4, 0, 19, 3, hair_d)
    c.px(16, 1, P.mix(hair, hair_l, 0.35))
    c.px(17, 1, P.mix(hair, hair_l, 0.2))
    c.rect(0, 3, 2, 11, hair)
    c.rect(21, 3, 23, 11, hair_d)
    c.rect(0, 5, 1, 6, hair_l)
    c.hline(5, 18, 4, hair_d)            # кромка волос
    c.px(9, 4, hair)
    # надбровные дуги
    c.rect(4, 8, 9, 9, hair_d)
    c.rect(14, 8, 19, 9, hair_d)
    c.px(3, 7, hair)
    c.px(20, 7, hair_d)
    # глазницы
    c.rect(4, 10, 9, 11, P.mix(skin_d, (0, 0, 0, 255), 0.45))
    c.rect(14, 10, 19, 11, P.mix(skin_d, (0, 0, 0, 255), 0.45))
    c.rect(5, 10, 8, 11, P.mix(skin_d, (0, 0, 0, 255), 0.55))
    c.rect(15, 10, 18, 11, P.mix(skin_d, (0, 0, 0, 255), 0.55))
    c.rect(6, 10, 7, 11, eye)
    c.rect(16, 10, 17, 11, eye)
    c.px(6, 10, (255, 250, 232, 255))
    c.px(16, 10, (255, 250, 232, 255))
    c.px(7, 11, P.mix(eye, (0, 0, 0, 255), 0.75))
    c.px(17, 11, P.mix(eye, (0, 0, 0, 255), 0.75))
    c.hline(5, 8, 9, P.mix(hair_d, skin, 0.2))
    c.hline(15, 18, 9, P.mix(hair_d, skin, 0.2))
    # нос: переносица, спинка, крылья
    c.rect(11, 8, 13, 14, skin)
    c.vline(11, 9, 13, skin_l)
    c.vline(13, 10, 13, skin_m)
    c.rect(10, 14, 14, 15, skin_l)
    c.hline(10, 14, 15, skin_m)
    c.px(9, 15, skin_d)
    c.px(15, 15, skin_d)
    # щёки и морщины
    c.px(6, 13, P.mix(skin_l, skin, 0.4))
    c.px(17, 13, P.mix(skin, skin_m, 0.5))
    c.hline(6, 9, 16, skin_m)
    c.hline(15, 18, 16, skin_m)
    # шрам через левый глаз
    if gear.get("scar"):
        scar = P.mix(skin_l, (214, 116, 106, 255), 0.6)
        c.line([(3, 5), (4, 8), (6, 14)], scar)
        c.px(4, 9, P.mix(scar, (255, 240, 230, 255), 0.3))
        c.px(5, 12, P.mix(scar, skin, 0.35))
    directional_shade(c, lx=-0.55, ly=-0.9, amount=0.2)
    return c


def beard_front(look: Look, length=17, wide=13, style="full"):
    """Борода: массивный клин с усами, косами и кольцами. 28x(length)."""
    w = wide * 2 + 2
    c = Canvas(w, length)
    cx = w // 2
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 5, 4, 255), 0.6)
    hair_m = P.mix(hair, hair_d, 0.35)
    hair_l = P.mix(hair, (255, 214, 166, 255), 0.3)
    gray = P.hx(look.hair_gray)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)

    # основной клин: чем ниже, тем уже
    for y in range(length):
        t = y / max(1, length - 1)
        half = int(wide * (1 - t * 0.7))
        # волнистая кромка
        wob = 1 if (y * 5) % 7 == 0 else 0
        left = cx - half - wob
        right = cx + half
        c.hline(left, right, y, hair)
        # объём: слева свет, справа тень
        c.vline(left, y, y, hair_d)
        c.hline(left + 1, left + max(2, half // 2), y, hair_m)
        c.vline(right, y, y, hair_d)
        c.px(right - 1, y, hair_d)
        if y % 4 == 0:
            c.hline(left + 2, right - 3, y, P.mix(hair_m, hair_l, 0.45))
    # тень под подбородком (верх бороды), кромка скруглена у щёк
    for i in range(4):
        inset = 3 - i
        c.hline(cx - wide + inset, cx + wide - inset, i, P.mix(hair, hair_d, 0.35 + i * 0.1))
    c.hline(cx - 3, cx + 3, 0, hair_d)
    # центральная прядь
    c.vline(cx, 4, length - 2, hair_d)
    c.vline(cx + 1, 5, length - 3, hair_m)
    # усы: расходятся от носа вниз
    for i in range(9):
        x0 = cx - 9 + i
        c.px(x0, 2 + i // 4, hair)
        c.px(x0, 3 + i // 4, hair_d)
    for i in range(9):
        x0 = cx + 1 + i
        c.px(x0, 2 + i // 4, hair_m)
        c.px(x0, 3 + i // 4, hair_d)
    c.hline(cx - 3, cx + 2, 1, hair_d)
    # седина
    for i, x in enumerate((cx - 7, cx - 3, cx + 2, cx + 6)):
        y0 = 6 + (i * 3) % 7
        c.px(x, y0, gray)
        c.px(x, y0 + 1, P.mix(gray, hair_d, 0.5))
        c.px(x + 1, y0 + 2, P.mix(gray, hair_d, 0.65))
    # косы с кольцами
    for side in (-1, 1):
        bx = cx + side * (wide - 3)
        for y in range(8, length - 1, 3):
            c.px(bx, y, hair_m if side < 0 else hair_d)
        ring_y = length - 4
        c.hline(bx - 2, bx + 2, ring_y, metal)
        c.hline(bx - 2, bx + 2, ring_y + 1, P.mix(metal, (0, 0, 0, 255), 0.5))
        c.px(bx - 2, ring_y, metal_l)
        c.px(bx + 2, ring_y - 1, metal_l)
    # низ бороды — тёмный, рваный
    c.hline(cx - 2, cx + 2, length - 1, P.mix(hair_d, (0, 0, 0, 255), 0.35))
    dither_shade(c, (46, 30, 20, 255), 0.05, seed=9)
    return c


def head_back(look: Look):
    c = Canvas(24, 24)
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 6, 4, 255), 0.5)
    hair_l = P.mix(hair, (255, 210, 160, 255), 0.28)
    c.ellipse(2, 0, 21, 20, hair)
    c.ellipse(5, 3, 18, 16, hair_d)
    # косы
    for x in (8, 15):
        c.rect(x, 10, x + 1, 23, hair)
        c.vline(x + 1, 10, 23, hair_d)
    c.hline(6, 17, 2, hair_l)
    c.hline(9, 14, 5, hair_l)
    # ремень через затылок
    c.hline(3, 20, 14, P.hx(look.leather))
    c.px(4, 15, P.hx(look.metal_light))
    directional_shade(c, amount=0.22)
    return c


def torso_back(look: Look, bulk=0):
    c = torso_front(look, bulk=bulk)
    # перекрасить грудь в спину: убираем застёжку/заплату, добавляем шов
    cloth_d = P.hx(look.cloth_dark)
    cloth = P.hx(look.cloth)
    cx = c.w // 2
    c.vline(cx, 3, 15, P.mix(cloth_d, cloth, 0.4))
    c.vline(cx + 1, 4, 15, cloth_d)
    # лямки рюкзака
    c.line([(cx - 8, 1), (cx - 5, 16)], P.hx(look.leather), 2)
    c.line([(cx + 8, 1), (cx + 5, 16)], P.hx(look.leather), 2)
    # свёрток/инструменты за спиной
    c.d.rounded_rectangle([cx - 6, 2, cx + 6, 8], radius=2, fill=P.hx(look.leather))
    c.hline(cx - 6, cx + 6, 3, P.hx(look.leather_light))
    c.vline(cx - 6, 2, 8, P.hx(look.leather_light))
    return c


# ---------------------------------------------------------------------------
# детали: профиль (вправо)
# ---------------------------------------------------------------------------

def head_side(look: Look, gear: dict):
    """Профиль вправо, 26x24."""
    c = Canvas(26, 24)
    skin = P.hx(look.skin)
    skin_d = P.mix(skin, (30, 12, 8, 255), 0.42)
    skin_l = P.mix(skin, (255, 226, 190, 255), 0.32)
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (10, 6, 4, 255), 0.55)
    hair_l = P.mix(hair, (255, 210, 160, 255), 0.3)
    eye = P.hx(look.eye)

    # череп
    c.ellipse(4, 1, 22, 18, skin)
    c.rect(8, 14, 20, 20, skin)
    # затылок
    c.ellipse(3, 4, 12, 19, skin)
    # волосы (сзади и сверху)
    c.ellipse(2, 0, 20, 9, hair)
    c.ellipse(2, 2, 12, 18, hair)
    c.rect(3, 6, 6, 20, hair)
    c.rect(16, 1, 21, 4, P.mix(hair, hair_l, 0.4))
    # лоб
    c.ellipse(9, 3, 21, 9, skin)
    # надбровье
    c.rect(15, 7, 21, 8, hair_d)
    c.px(15, 6, hair)
    # глаз
    c.rect(16, 9, 19, 10, P.mix(skin_d, (0, 0, 0, 255), 0.3))
    c.px(17, 9, eye)
    c.px(18, 10, P.mix(eye, (0, 0, 0, 255), 0.4))
    # нос
    c.rect(20, 9, 23, 13, skin)
    c.px(23, 13, skin_d)
    c.hline(20, 23, 9, skin_l)
    c.px(21, 12, P.mix(skin, (0, 0, 0, 255), 0.3))
    # щека
    c.px(16, 12, skin_l)
    c.px(18, 14, skin_d)
    # ухо
    c.rect(10, 9, 12, 12, skin)
    c.px(11, 10, skin_d)
    # шрам
    if gear.get("scar"):
        scar = P.mix(skin_l, (220, 120, 110, 255), 0.5)
        c.line([(15, 5), (18, 12)], scar)
    directional_shade(c, amount=0.24)
    return c


def beard_side(look: Look, length=16):
    """Борода в профиль, растёт вперёд, 22x(length)."""
    c = Canvas(22, length)
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (12, 6, 4, 255), 0.55)
    hair_l = P.mix(hair, (255, 210, 160, 255), 0.3)
    gray = P.hx(look.hair_gray)
    for y in range(length):
        t = y / max(1, length - 1)
        x0 = int(2 + t * 4)
        x1 = int(19 - t * 9)
        c.hline(x0, x1, y, hair if t < 0.5 else P.mix(hair, hair_d, 0.4))
        c.px(x1, y, hair_d)
        if y % 3 == 0:
            c.hline(x0 + 1, x1 - 2, y, P.mix(hair, hair_l, 0.25))
    # усы
    c.rect(12, 0, 20, 2, hair)
    c.hline(12, 20, 2, hair_d)
    # седина
    for x, y in ((6, 4), (9, 7), (4, 9), (11, 11)):
        c.px(x, y, gray)
    # прядь
    c.vline(8, 2, length - 2, hair_d)
    directional_shade(c, amount=0.2)
    return c


def torso_side(look: Look):
    """Торс в профиль 20x26."""
    c = Canvas(20, 26)
    cloth = P.hx(look.cloth)
    cloth_d = P.hx(look.cloth_dark)
    cloth_l = P.hx(look.cloth_light)
    leather = P.hx(look.leather)
    metal = P.hx(look.metal)
    rows = []
    for y in range(26):
        if y < 3:
            w = 9
        elif y < 14:
            w = 9
        elif y < 20:
            w = 8
        else:
            w = 8 - (y - 20) // 3
        rows.append(w)
    for y, w in enumerate(rows):
        c.hline(9 - w, 9 + w, y, cloth)
    # живот и грудь
    c.ellipse(3, 4, 17, 16, cloth)
    c.ellipse(4, 5, 15, 15, P.mix(cloth, cloth_l, 0.35))
    # тень на спине
    c.vline(0, 3, 18, cloth_d)
    c.hline(0, 2, 19, cloth_d)
    # ремень
    c.rect(1, 16, 18, 19, leather)
    c.hline(1, 18, 16, P.hx(look.leather_light))
    c.rect(8, 16, 12, 19, metal)
    c.px(9, 17, P.hx(look.metal_light))
    # ворот и складки
    c.rect(11, 0, 17, 2, cloth_d)
    c.vline(5, 6, 15, cloth_d)
    c.vline(12, 8, 14, cloth_d)
    directional_shade(c, amount=0.22)
    return c


def leg_side(look: Look):
    """Нога в профиль 14x16 (ботинок вытянут вперёд)."""
    c = Canvas(14, 16)
    pants = _pants_color(look)
    leather = P.hx(look.leather)
    leather_l = P.hx(look.leather_light)
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    c.rect(3, 0, 10, 9, pants)
    c.rect(3, 7, 10, 11, leather)
    c.hline(3, 10, 8, leather_l)
    # ботинок
    c.d.rounded_rectangle([0, 10, 13, 15], radius=2, fill=P.mix(leather, (0, 0, 0, 255), 0.3))
    c.rect(0, 13, 13, 15, P.hx("#15100b"))
    c.hline(0, 12, 15, P.hx("#0a0806"))
    c.rect(2, 11, 8, 13, metal)
    c.hline(2, 7, 11, metal_l)
    c.px(10, 12, P.hx(look.accent))
    directional_shade(c, amount=0.24)
    return c


def arm_side(look: Look):
    c = arm_front(look)
    return c


# ---------------------------------------------------------------------------
# оружие и цепи
# ---------------------------------------------------------------------------

def weapon_chain(cv: Canvas, x0, y0, length=26, angle=0.0, look: Look = HERO, links=9):
    """Цепь/хлыст: звенья вдоль дуги. angle в градусах, 0 = вправо."""
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    metal_d = P.hx(look.metal_dark)
    a0 = math.radians(angle)
    sag = 0.25
    for i in range(links):
        t = i / max(1, links - 1)
        a = a0 + (t - 0.5) * 0.9
        dist = length * t
        x = x0 + math.cos(a) * dist
        y = y0 + math.sin(a) * dist + sag * dist * (t - 0.5) * 2
        if i % 2 == 0:
            cv.rect(int(x) - 1, int(y), int(x), int(y) + 1, metal)
            cv.px(int(x) - 1, int(y), metal_l)
        else:
            cv.px(int(x), int(y), metal_d)
            cv.px(int(x) + 1, int(y) + 1, metal)


def weapon_hammer(cv: Canvas, x, y, angle=0.0, look: Look = HERO, big=1.0):
    metal = P.hx(look.metal)
    metal_l = P.hx(look.metal_light)
    metal_d = P.hx(look.metal_dark)
    wood = P.hx(look.leather)
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    # рукоять
    for i in range(int(14 * big)):
        px_, py_ = int(x + dx * i), int(y + dy * i)
        cv.px(px_, py_, wood)
        cv.px(px_, py_ + 1, P.mix(wood, (0, 0, 0, 255), 0.4))
    # боёк
    hx_, hy_ = int(x + dx * 14 * big), int(y + dy * 14 * big)
    cv.rect(hx_ - 3, hy_ - 3, hx_ + 4, hy_ + 3, metal)
    cv.hline(hx_ - 2, hx_ + 3, hy_ - 3, metal_l)
    cv.hline(hx_ - 3, hx_ + 4, hy_ + 3, metal_d)
    cv.px(hx_ - 1, hy_, metal_l)


def weapon_club(cv: Canvas, x, y, angle=0.0, look: Look = JAILER):
    wood = P.hx(look.leather)
    wood_l = P.hx(look.leather_light)
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    for i in range(16):
        px_, py_ = int(x + dx * i), int(y + dy * i)
        r = 1 if i < 10 else 2 if i < 13 else 3
        cv.circle(px_, py_, r, wood)
    hx_, hy_ = int(x + dx * 15), int(y + dy * 15)
    cv.circle(hx_, hy_, 3, wood_l)
    cv.px(hx_ - 1, hy_ - 1, P.hx(look.metal_light))


def weapon_whip(cv: Canvas, x, y, angle=0.0, look: Look = GHARN):
    """Хлыст из сухожилий — кривая с утолщением."""
    flesh = P.hx("#8f2436")
    flesh_l = P.hx("#c93a5b")
    flesh_d = P.hx("#4a0d1d")
    a0 = math.radians(angle)
    for i in range(28):
        t = i / 27
        a = a0 + math.sin(t * 3.2) * 0.55
        dist = 34 * t
        x_, y_ = int(x + math.cos(a) * dist), int(y + math.sin(a) * dist + 4 * math.sin(t * 3))
        if t < 0.2:
            cv.px(x_, y_, flesh_d)
            cv.px(x_, y_ + 1, flesh_d)
        else:
            cv.px(x_, y_, flesh if i % 3 else flesh_l)
        if i == 27:
            cv.circle(x_, y_, 1, flesh_l)


# ---------------------------------------------------------------------------
# сборка
# ---------------------------------------------------------------------------

def draw_dwarf(pose: Pose, direction: str = "down", look: Look = HERO,
               gear: dict | None = None, helmet: bool = False,
               beard_len: int = 17, beard_wide: int = 13,
               weapon: str | None = None, bulk: int = 0,
               scale: int = 1) -> Canvas:
    """direction: down | up | left | right. Кадр 48x64, ступни на y=62."""
    gear = dict(gear or {})
    cv = Canvas(BASE_W, BASE_H)
    cr = int(pose.crouch * 6)
    if direction == "right":
        cv = _assemble_side(pose, look, gear, helmet, beard_len, bulk, cr, weapon)
    elif direction == "left":
        cv = _assemble_side(pose, look, gear, helmet, beard_len, bulk, cr, weapon).flip_h()
    elif direction == "up":
        cv = _assemble_back(pose, look, gear, helmet, beard_len, bulk, cr, weapon)
    else:
        cv = _assemble_front(pose, look, gear, helmet, beard_len, beard_wide, bulk, cr, weapon)

    cv.outline(P.hx(P.INK))
    # тёплый контровой свет по верхней кромке (факелы сверху)
    rim = P.hx(look.rim)
    for x in range(BASE_W):
        for y in range(BASE_H):
            c = cv.get(x, y)
            if c[3] and c[:3] != P.hx(P.INK)[:3]:
                cv.px(x, y, P.mix(c, rim, 0.16))
                break
    if scale > 1:
        return cv.scale(scale)
    return cv


def _long_hair(cv: Canvas, cx, head_top, look: Look):
    """Волосы, спадающие по спине и плечам."""
    hair = P.hx(look.hair)
    hair_d = P.mix(hair, (14, 10, 6, 255), 0.45)
    hair_l = P.mix(hair, (255, 236, 200, 255), 0.35)
    for y in range(head_top + 4, head_top + 34):
        t = (y - head_top - 4) / 30
        half = int(9 + 3 * t)
        cv.hline(cx - half, cx + half, y, hair)
        cv.px(cx - half, y, hair_d)
        cv.px(cx + half, y, hair_d)
        if y % 4 == 0:
            cv.hline(cx - half + 2, cx + half - 2, y, P.mix(hair, hair_l, 0.25))
    # пряди
    for off in (-6, -2, 3, 7):
        for y in range(head_top + 8, head_top + 32):
            if (y + off) % 3 == 0:
                cv.px(cx + off, y, hair_d)


def _assemble_front(pose, look, gear, helmet, beard_len, beard_wide, bulk, cr, weapon):
    cv = Canvas(BASE_W, BASE_H)
    cx = BASE_W // 2 + pose.lean
    ground = 62
    torso_top = ground - 39 - cr + pose.bob
    leg_y = torso_top + 23

    if gear.get("long_hair"):
        _long_hair(cv, cx, torso_top - 17, look)
    l_arm = arm_front(look, True)
    r_arm = arm_front(look, False)
    cv.blit(l_arm, cx - 18 + pose.arm_l[0], torso_top + 3 + pose.arm_l[1])
    cv.blit(leg_front(look), cx - 14 + pose.leg_l[0], leg_y + pose.leg_l[1])
    cv.blit(leg_front(look), cx + 2 + pose.leg_r[0], leg_y + pose.leg_r[1])
    cv.blit(torso_front(look, bulk), cx - 14 - bulk, torso_top)
    if beard_len > 0:
        cv.blit(beard_front(look, beard_len, beard_wide), cx - 14 + pose.beard, torso_top - 2)
    head = head_front(look, gear)
    if helmet:
        head = _helmet(head, look, gear)
    cv.blit(head, cx - 12 + pose.head[0], torso_top - 17 + pose.head[1])
    cv.blit(r_arm, cx + 10 + pose.arm_r[0], torso_top + 3 + pose.arm_r[1])

    # оружие в правой руке
    if weapon:
        hx_ = cx + 12 + pose.arm_r[0] + pose.extend
        hy_ = torso_top + 17 + pose.arm_r[1]
        ang = pose.weapon_angle if pose.weapon_angle is not None else 70
        if weapon == "chain":
            weapon_chain(cv, hx_, hy_ - 2, 22, ang - 60, look)
        elif weapon == "hammer":
            weapon_hammer(cv, hx_, hy_, ang, look)
        elif weapon == "club":
            weapon_club(cv, hx_, hy_, ang, look)
        elif weapon == "whip":
            weapon_whip(cv, hx_, hy_, ang, look)
        elif weapon == "pick":
            weapon_hammer(cv, hx_, hy_, ang, look, big=1.15)
    return cv


def _assemble_back(pose, look, gear, helmet, beard_len, bulk, cr, weapon):
    cv = Canvas(BASE_W, BASE_H)
    cx = BASE_W // 2 + pose.lean
    ground = 62
    torso_top = ground - 39 - cr + pose.bob
    leg_y = torso_top + 23

    cv.blit(arm_front(look, True), cx - 18 + pose.arm_l[0], torso_top + 3 + pose.arm_l[1])
    cv.blit(leg_front(look), cx - 14 + pose.leg_l[0], leg_y + pose.leg_l[1])
    cv.blit(leg_front(look), cx + 2 + pose.leg_r[0], leg_y + pose.leg_r[1])
    cv.blit(torso_back(look, bulk), cx - 14 - bulk, torso_top)
    head = head_back(look)
    if helmet:
        head = _helmet(head, look, gear, back=True)
    cv.blit(head, cx - 12 + pose.head[0], torso_top - 17 + pose.head[1])
    cv.blit(arm_front(look, False), cx + 10 + pose.arm_r[0], torso_top + 3 + pose.arm_r[1])
    if weapon:
        hx_ = cx - 16 + pose.arm_l[0] - pose.extend
        hy_ = torso_top + 17 + pose.arm_l[1]
        ang = pose.weapon_angle if pose.weapon_angle is not None else 110
        weapon_chain(cv, hx_, hy_, 18, ang, look)
    return cv


def _assemble_side(pose, look, gear, helmet, beard_len, bulk, cr, weapon):
    cv = Canvas(BASE_W, BASE_H)
    cx = BASE_W // 2 + pose.lean
    ground = 62
    torso_top = ground - 39 - cr + pose.bob
    leg_y = torso_top + 23

    # дальняя нога и рука (темнее)
    far_leg = leg_side(look)
    directional_shade(far_leg, amount=0.4)
    cv.blit(far_leg, cx - 10 + pose.leg_l[0], leg_y + pose.leg_l[1] + 1)
    cv.blit(leg_side(look), cx - 6 + pose.leg_r[0], leg_y + pose.leg_r[1])
    cv.blit(torso_side(look), cx - 9 - bulk, torso_top)
    if beard_len > 0:
        cv.blit(beard_side(look, beard_len), cx - 5 + pose.beard, torso_top - 2)
    head = head_side(look, gear)
    if helmet:
        head = _helmet(head, look, gear, side=True)
    cv.blit(head, cx - 12 + pose.head[0], torso_top - 17 + pose.head[1])
    arm = arm_side(look)
    cv.blit(arm, cx - 2 + pose.arm_r[0], torso_top + 3 + pose.arm_r[1])
    if weapon:
        hx_ = cx + 4 + pose.arm_r[0] + pose.extend
        hy_ = torso_top + 17 + pose.arm_r[1]
        ang = pose.weapon_angle if pose.weapon_angle is not None else 20
        if weapon == "chain":
            weapon_chain(cv, hx_, hy_, 20, ang, look)
        elif weapon == "hammer":
            weapon_hammer(cv, hx_, hy_, ang, look)
        elif weapon == "club":
            weapon_club(cv, hx_, hy_, ang, look)
        elif weapon == "whip":
            weapon_whip(cv, hx_, hy_, ang, look)
        elif weapon == "pick":
            weapon_hammer(cv, hx_, hy_, ang, look, big=1.15)
    return cv


def _helmet(head: Canvas, look: Look, gear: dict, back=False, side=False):
    """Шлем Пожирателей: тёмный купол, узкая прорезь с багровым свечением."""
    c = head.copy()
    metal = P.hx(look.metal)
    metal_l = P.mix(P.hx(look.metal_light), metal, 0.45)
    metal_d = P.hx(look.metal_dark)
    accent = P.hx(look.accent)
    w, h = c.w, c.h
    cx = w // 2

    # купол
    c.ellipse(1, -2, w - 2, 11, metal)
    c.ellipse(3, 0, w - 4, 7, P.mix(metal, metal_d, 0.35))
    # блик одной дугой
    for i in range(6):
        c.px(5 + i, 2 + (i // 3), metal_l)
    c.px(6, 1, P.mix(metal_l, (255, 255, 255, 255), 0.25))
    # нижняя кромка и назатыльник
    c.hline(1, w - 2, 8, metal_d)
    c.rect(1, 9, 3, 14, metal)
    c.rect(w - 4, 9, w - 2, 14, metal_d)
    # гребень цвета крови
    c.rect(cx - 1, -5, cx + 1, -2, accent)
    c.px(cx, -6, P.mix(accent, (255, 255, 255, 255), 0.3))
    c.hline(cx - 2, cx + 2, -2, P.mix(accent, (0, 0, 0, 255), 0.5))
    for x in (4, 8, 12, 16):
        c.px(x, 8, metal_l)
    if not back:
        # прорезь для глаз
        c.rect(4, 9, w - 5, 10, P.hx("#05060a"))
        if not side:
            c.rect(5, 9, 8, 9, P.hx(look.eye))
            c.rect(w - 9, 9, w - 6, 9, P.hx(look.eye))
            c.px(5, 9, (255, 220, 220, 255))
            c.px(w - 9, 9, (255, 220, 220, 255))
        else:
            c.rect(5, 9, 10, 9, P.hx(look.eye))
        # наносник
        c.rect(cx - 1, 10, cx + 1, 16, metal)
        c.vline(cx - 1, 10, 16, P.mix(metal, metal_l, 0.5))
        c.px(cx, 16, metal_d)
        # щёчная пластина
        c.rect(2, 12, 6, 17, metal_d)
        c.rect(w - 7, 12, w - 3, 17, metal_d)
        c.px(3, 15, metal)
        c.px(w - 4, 16, metal_d)
    directional_shade(c, lx=-0.5, ly=-0.95, amount=0.18)
    return c


# ---------------------------------------------------------------------------
# позы
# ---------------------------------------------------------------------------

def poses_idle() -> list[Pose]:
    return [Pose(bob=0), Pose(bob=1, arm_r=(0, 1), beard=1, head=(0, 1))]


def poses_walk() -> list[Pose]:
    return [
        Pose(bob=0, leg_l=(-3, -2), leg_r=(3, 0), arm_l=(2, -2), arm_r=(-1, 2), beard=-1),
        Pose(bob=-1, leg_l=(-2, -1), leg_r=(2, 0), arm_l=(1, -1), arm_r=(0, 1), beard=0, head=(0, -1)),
        Pose(bob=0, leg_l=(0, 0), leg_r=(0, -2), arm_l=(0, 0), arm_r=(1, 0), beard=1),
        Pose(bob=0, leg_l=(3, 0), leg_r=(-3, -2), arm_l=(-1, 2), arm_r=(2, -2), beard=1),
        Pose(bob=-1, leg_l=(2, 0), leg_r=(-2, -1), arm_l=(0, 1), arm_r=(1, -1), beard=0, head=(0, -1)),
        Pose(bob=0, leg_l=(0, -2), leg_r=(0, 0), arm_l=(1, 0), arm_r=(0, 0), beard=-1),
    ]


def poses_sneak() -> list[Pose]:
    return [
        Pose(bob=1, crouch=1.0, leg_l=(-2, 0), leg_r=(3, 0), arm_l=(1, 0), arm_r=(-1, 0), beard=1, head=(0, 1)),
        Pose(bob=2, crouch=1.0, leg_l=(-1, 0), leg_r=(2, 0), arm_l=(1, 0), arm_r=(0, 0), beard=0, head=(0, 2)),
        Pose(bob=1, crouch=1.0, leg_l=(3, 0), leg_r=(-2, 0), arm_l=(-1, 0), arm_r=(2, 0), beard=1, head=(0, 1)),
        Pose(bob=2, crouch=1.0, leg_l=(2, 0), leg_r=(-1, 0), arm_l=(0, 0), arm_r=(1, 0), beard=0, head=(0, 2)),
    ]


def poses_attack() -> list[Pose]:
    return [
        Pose(bob=0, lean=-1, arm_r=(-4, -3), beard=-1, head=(-1, 0), weapon_angle=110),
        Pose(bob=-1, lean=1, arm_r=(4, -4), beard=2, head=(1, 0), weapon_angle=40, extend=2),
        Pose(bob=1, lean=2, arm_r=(8, 0), beard=3, head=(2, 0), weapon_angle=-10, extend=4),
        Pose(bob=0, lean=1, arm_r=(3, 2), beard=1, head=(1, 1), weapon_angle=30),
    ]


def poses_heavy() -> list[Pose]:
    return [
        Pose(bob=0, lean=-2, arm_r=(-5, -7), beard=-2, head=(-1, 1), weapon_angle=150),
        Pose(bob=-1, lean=-1, arm_r=(-3, -9), beard=-1, head=(-1, 0), weapon_angle=165),
        Pose(bob=0, lean=1, arm_r=(3, -6), beard=1, head=(1, 0), weapon_angle=60),
        Pose(bob=1, lean=3, arm_r=(9, -1), beard=3, head=(2, 1), weapon_angle=-20, extend=4),
        Pose(bob=1, lean=1, arm_r=(4, 1), beard=1, head=(1, 1), weapon_angle=20),
    ]


def poses_cast() -> list[Pose]:
    return [
        Pose(bob=0, arm_l=(-2, -4), arm_r=(3, -3), beard=-1, head=(0, -1)),
        Pose(bob=-1, arm_l=(-1, -7), arm_r=(5, -7), beard=0, head=(0, -2)),
        Pose(bob=1, arm_l=(1, -2), arm_r=(7, -2), beard=1, head=(1, 0)),
        Pose(bob=0, arm_l=(0, 0), arm_r=(2, 0), beard=0, head=(0, 0)),
    ]


def poses_dash() -> list[Pose]:
    return [
        Pose(bob=-1, lean=2, crouch=0.4, leg_l=(-4, -1), leg_r=(3, 0), arm_l=(-3, -2), arm_r=(5, -2), beard=-2),
        Pose(bob=1, lean=1, crouch=0.3, leg_l=(-6, 0), leg_r=(1, -1), arm_l=(-4, 0), arm_r=(3, 0), beard=1),
    ]


def poses_hurt() -> list[Pose]:
    return [
        Pose(bob=-1, lean=-2, head=(-1, -1), arm_l=(-2, -3), arm_r=(-4, -2), beard=-2),
        Pose(bob=0, lean=-1, head=(-1, 0), arm_l=(-1, -1), arm_r=(-2, 0), beard=-1),
    ]


def poses_dead() -> list[Pose]:
    return [Pose(bob=6, lean=-1, crouch=1.0, leg_l=(5, 3), leg_r=(7, 4), head=(-5, 4), beard=-4)]


ANIMS = {
    "idle": (poses_idle, 3.0),
    "walk": (poses_walk, 9.0),
    "sneak": (poses_sneak, 6.0),
    "attack": (poses_attack, 14.0),
    "heavy": (poses_heavy, 10.0),
    "cast": (poses_cast, 10.0),
    "dash": (poses_dash, 10.0),
    "hurt": (poses_hurt, 8.0),
    "dead": (poses_dead, 4.0),
}
