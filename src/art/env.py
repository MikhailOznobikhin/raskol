"""Окружение: тайлы подземной тюрьмы, детали, источники света.

Тайл 32x32, вид сверху. Холодный камень, тёплые факелы, ржавчина и кровь.
Все тайлы собираются в атлас 8x6, детали — отдельными спрайтами.
"""
from __future__ import annotations

import math
import random

from . import palette as P
from .pixelkit import Canvas, directional_shade, dither_shade, ellipse_gradient

T = 32

STONE_FLOOR = ["#191e27", "#222833", "#2c3441", "#37404f", "#455062", "#556277"]
STONE_WALL = ["#12161d", "#1a1f28", "#232a35", "#2e3745", "#3d4757", "#556176"]
MORTAR = "#0b0e13"


def _noise(c: Canvas, seed, amount=0.08, colors=None, region=None):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = region or (0, 0, c.w - 1, c.h - 1)
    px = c.img.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not px[x, y][3]:
                continue
            if rnd.random() < amount:
                r, g, b, a = px[x, y]
                k = rnd.choice([0.85, 0.92, 1.06, 1.12])
                px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)


def _mortar_grid(c: Canvas, x_lines, y_lines, color=MORTAR, alpha=255, jitter=0):
    rnd = random.Random(len(x_lines) * 7 + len(y_lines))
    for x in x_lines:
        for y in range(c.h):
            xx = x + (rnd.randint(-jitter, jitter) if jitter else 0)
            c.px(xx, y, P.hx(color))
    for y in y_lines:
        for x in range(c.w):
            yy = y + (rnd.randint(-jitter, jitter) if jitter else 0)
            c.px(x, yy, P.hx(color))


# ---------------------------------------------------------------------------
# ПОЛ
# ---------------------------------------------------------------------------

def floor_tile(seed=0, variant=0, moss=False):
    c = Canvas(T, T)
    rnd = random.Random(seed)
    base = P.hx(STONE_FLOOR[2 + (variant % 2)])
    c.rect(0, 0, T - 1, T - 1, base)
    # плиты 2x2 со смещением
    splits_x = [0, 16, 31] if variant % 2 == 0 else [0, 11, 22]
    splits_y = [0, 15, 31]
    for i in range(len(splits_x) - 1):
        for j in range(len(splits_y) - 1):
            x0, x1 = splits_x[i], splits_x[i + 1]
            y0, y1 = splits_y[j], splits_y[j + 1]
            tint = P.hx(STONE_FLOOR[1 + (i + j + variant) % 3])
            c.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, tint)
            # верхний левый блик, нижняя тень
            c.hline(x0 + 1, x1 - 2, y0 + 1, P.mix(tint, P.hx(STONE_FLOOR[4]), 0.35))
            c.hline(x0 + 1, x1 - 2, y1 - 1, P.mix(tint, (0, 0, 0, 255), 0.45))
            c.vline(x0 + 1, y0 + 2, y1 - 2, P.mix(tint, P.hx(STONE_FLOOR[4]), 0.2))
    # раствор
    _mortar_grid(c, splits_x[1:-1], splits_y[1:-1], MORTAR, jitter=0)
    # сколы и трещины
    for _ in range(2 + variant):
        x = rnd.randint(3, T - 4)
        y = rnd.randint(3, T - 4)
        c.px(x, y, P.hx(STONE_FLOOR[5]))
        c.px(x + 1, y, P.hx(STONE_FLOOR[1]))
    if variant == 2:
        # трещина
        x, y = 6, 22
        for i in range(14):
            c.px(x + i // 2, y - i // 3, P.hx(STONE_FLOOR[0]))
            if i % 3 == 0:
                c.px(x + i // 2 + 1, y - i // 3, P.hx(STONE_FLOOR[4]))
    if moss:
        for _ in range(18):
            x, y = rnd.randint(1, 30), rnd.randint(1, 30)
            c.px(x, y, P.hx(P.MOSS[1 + rnd.randint(0, 2)]))
            if rnd.random() < 0.4:
                c.px(x + 1, y, P.hx(P.MOSS[2]))
    _noise(c, seed + 1, 0.1)
    return c


def floor_decor(kind: str, seed=0):
    c = floor_tile(seed, 1)
    rnd = random.Random(seed)
    if kind == "blood":
        for _ in range(3):
            cx, cy = rnd.randint(8, 24), rnd.randint(8, 24)
            r = rnd.randint(3, 6)
            for y in range(-r, r + 1):
                for x in range(-r, r + 1):
                    if x * x + y * y <= r * r and rnd.random() < 0.85:
                        c.px(cx + x, cy + y, P.hx(P.BLOOD[1 + rnd.randint(0, 2)]))
        for _ in range(10):
            c.px(rnd.randint(2, 29), rnd.randint(2, 29), P.hx(P.BLOOD[2]))
    elif kind == "bones":
        for _ in range(4):
            cx, cy = rnd.randint(6, 26), rnd.randint(6, 26)
            c.hline(cx, cx + 5, cy, P.hx(P.BONE[3]))
            c.px(cx - 1, cy - 1, P.hx(P.BONE[4]))
            c.px(cx + 6, cy + 1, P.hx(P.BONE[2]))
        c.ellipse(12, 20, 20, 26, P.hx(P.BONE[2]))
        c.ellipse(14, 21, 18, 25, P.hx(P.BONE[3]))
        c.px(15, 23, P.hx("#0b0e13"))
        c.px(17, 23, P.hx("#0b0e13"))
    elif kind == "straw":
        c = floor_tile(seed, 0)
        for _ in range(60):
            x, y = rnd.randint(1, 30), rnd.randint(1, 30)
            ln = rnd.randint(2, 5)
            col = P.hx(P.BLOND[2 + rnd.randint(0, 2)])
            for i in range(ln):
                c.px(x + i, y + (i % 2), col)
    elif kind == "grate":
        c.rect(4, 4, 27, 27, P.hx("#05070a"))
        for x in range(4, 27, 3):
            c.vline(x, 4, 27, P.hx(STONE_FLOOR[1]))
            c.px(x, 4, P.hx(STONE_FLOOR[4]))
        for y in (4, 27):
            c.hline(4, 27, y, P.hx(STONE_FLOOR[3]))
        for _ in range(12):
            c.px(rnd.randint(5, 26), rnd.randint(5, 26), P.hx(P.BLOOD[1]))
    elif kind == "rubble":
        for _ in range(14):
            x, y = rnd.randint(2, 26), rnd.randint(2, 26)
            w, h = rnd.randint(2, 4), rnd.randint(2, 3)
            col = P.hx(STONE_FLOOR[3 + rnd.randint(0, 2)])
            c.rect(x, y, x + w, y + h, col)
            c.hline(x, x + w, y, P.mix(col, (255, 240, 210, 255), 0.18))
            c.hline(x, x + w, y + h, P.mix(col, (0, 0, 0, 255), 0.45))
    return c


# ---------------------------------------------------------------------------
# СТЕНЫ
# ---------------------------------------------------------------------------

def wall_tile(seed=0, variant=0, torch=False, moss=False):
    c = Canvas(T, T)
    rnd = random.Random(seed + 11)
    base = P.hx(STONE_WALL[2])
    c.rect(0, 0, T - 1, T - 1, base)
    # кирпичная кладка: 2 ряда по 3 кирпича, со смещением
    rows = [(0, 9, 3), (10, 20, 4), (21, 31, 3)]
    for ri, (y0, y1, n) in enumerate(rows):
        off = 0 if ri % 2 == 0 else 5
        brick_w = (T + off) // n
        for bi in range(n + 1):
            x0 = bi * brick_w - off
            x1 = x0 + brick_w - 2
            if x1 < 0 or x0 > T - 1:
                continue
            xa, xb = max(0, x0), min(T - 1, x1)
            col = P.hx(STONE_WALL[1 + (ri + bi) % 3])
            c.rect(xa, y0, xb, y1, col)
            c.hline(xa, xb, y0, P.mix(col, P.hx(STONE_WALL[5]), 0.45))
            c.hline(xa, xb, y0 + 1, P.mix(col, P.hx(STONE_WALL[4]), 0.25))
            c.hline(xa, xb, y1, P.mix(col, (0, 0, 0, 255), 0.55))
            c.vline(xb, y0 + 1, y1, P.mix(col, (0, 0, 0, 255), 0.4))
            # сколы
            if rnd.random() < 0.5:
                px_, py_ = rnd.randint(xa + 1, max(xa + 1, xb - 1)), rnd.randint(y0 + 3, y1 - 2)
                c.px(px_, py_, P.mix(col, P.hx(STONE_WALL[5]), 0.4))
                c.px(px_ + 1, py_, P.mix(col, (0, 0, 0, 255), 0.5))
    # тёмный низ и светлый верх
    c.hline(0, T - 1, 0, P.mix(base, P.hx(STONE_WALL[5]), 0.3))
    c.hline(0, T - 1, T - 1, P.hx("#05070a"))
    c.rect(0, T - 3, T - 1, T - 2, P.mix(base, (0, 0, 0, 255), 0.45))
    # потёки
    for _ in range(3):
        x = rnd.randint(2, 29)
        ln = rnd.randint(4, 12)
        for i in range(ln):
            c.px(x, 3 + i, P.mix(base, P.hx(STONE_WALL[0]), 0.6))
    if moss:
        for _ in range(14):
            x, y = rnd.randint(0, 31), rnd.randint(2, 31)
            c.px(x, y, P.hx(P.MOSS[1 + rnd.randint(0, 2)]))
    if torch:
        # подтёк копоти над факелом
        for y in range(0, 12):
            for x in range(12, 21):
                if (x - 16) ** 2 + (y - 0) ** 2 < 60:
                    c.px(x, y, P.mix(base, (0, 0, 0, 255), 0.55))
    _noise(c, seed + 2, 0.1)
    return c


def wall_top(seed=0):
    """Верхняя кромка стены — «гребень» для читаемого объёма."""
    c = wall_tile(seed, 1)
    cap = P.hx(STONE_WALL[4])
    c.rect(0, 0, T - 1, 5, cap)
    c.hline(0, T - 1, 0, P.mix(cap, (255, 240, 210, 255), 0.35))
    c.hline(0, T - 1, 1, P.mix(cap, (255, 240, 210, 255), 0.2))
    c.hline(0, T - 1, 6, P.hx("#05070a"))
    for x in range(0, T, 6):
        c.px(x, 3, P.hx(STONE_WALL[1]))
        c.px(x + 1, 3, P.hx(STONE_WALL[2]))
    return c


def wall_corner(seed=0, flip=False):
    c = wall_tile(seed)
    if flip:
        c = c.flip_h()
        c.outline(P.hx(P.INK))
    # тёмный стык
    for y in range(T):
        c.px(0 if not flip else T - 1, y, P.hx("#05070a"))
    return c


def bars_tile(seed=0, variant=0):
    """Тюремная решётка (стоит на полу, вертикальные прутья)."""
    c = Canvas(T, T)
    px = 3 if variant == 0 else 4
    for x in range(2, T, 8):
        c.vline(x, 0, T - 1, P.hx(P.IRON[2]))
        c.vline(x + 1, 0, T - 1, P.hx(P.IRON[4]))
        c.vline(x + 2, 0, T - 1, P.hx(P.IRON[1]))
        c.px(x + 1, 0, P.hx(P.IRON[6]))
        c.px(x + 1, T - 1, P.hx(P.IRON[0]))
    # горизонтальные перекладины
    for y in (3, 27):
        c.hline(0, T - 1, y, P.hx(P.IRON[2]))
        c.hline(0, T - 1, y + 1, P.hx(P.IRON[4]))
        c.hline(0, T - 1, y + 2, P.hx(P.IRON[1]))
    _noise(c, seed, 0.08)
    return c


# ---------------------------------------------------------------------------
# ДЕТАЛИ-СПРАЙТЫ
# ---------------------------------------------------------------------------

def torch_frames(seed=0):
    """Факел на стене, 4 кадра, 16x32."""
    out = []
    for f in range(4):
        c = Canvas(16, 32)
        rnd = random.Random(seed * 31 + f)
        # держатель
        c.rect(6, 14, 9, 26, P.hx(P.IRON[2]))
        c.vline(6, 14, 26, P.hx(P.IRON[4]))
        c.vline(9, 14, 26, P.hx(P.IRON[1]))
        c.rect(4, 24, 11, 26, P.hx(P.IRON[3]))
        # чаша
        c.rect(4, 12, 11, 15, P.hx(P.IRON[3]))
        c.hline(4, 11, 12, P.hx(P.IRON[5]))
        c.hline(4, 11, 15, P.hx(P.IRON[1]))
        # пламя
        h = [7, 9, 8, 6][f]
        for y in range(12 - h, 12):
            t = (12 - y) / h
            half = max(1, int(3 * (1 - t) + 1))
            base = P.hx(P.FLAME[3 + int(t * 2)])
            c.hline(8 - half, 7 + half, y, base)
            c.px(8 - half, y, P.hx(P.FLAME[2]))
            c.px(7 + half, y, P.hx(P.FLAME[2]))
            if t < 0.5:
                c.hline(8 - half + 1, 7 + half - 1, y, P.hx(P.FLAME[5]))
            if t < 0.25:
                c.hline(8, 7, y, (255, 255, 235, 255))
        # искры
        for _ in range(2):
            c.px(rnd.randint(5, 10), rnd.randint(0, 8), P.hx(P.FLAME[5]))
        out.append(c)
    return out


def brazier_frames(seed=0):
    """Жаровня 24x24, 4 кадра."""
    out = []
    for f in range(4):
        c = Canvas(24, 24)
        rnd = random.Random(seed * 13 + f)
        # ножки
        c.vline(7, 16, 22, P.hx(P.IRON[2]))
        c.vline(16, 16, 22, P.hx(P.IRON[2]))
        c.vline(8, 16, 22, P.hx(P.IRON[3]))
        c.vline(17, 16, 22, P.hx(P.IRON[3]))
        c.hline(5, 18, 14, P.hx(P.IRON[4]))
        # чаша
        c.d.ellipse([4, 9, 19, 16], fill=P.hx(P.IRON[2]))
        c.d.ellipse([5, 10, 18, 14], fill=P.hx(P.IRON[4]))
        c.d.ellipse([6, 11, 17, 13], fill=P.hx(P.FLAME[1]))
        # угли и пламя
        for _ in range(10):
            x, y = rnd.randint(7, 16), rnd.randint(10, 13)
            c.px(x, y, P.hx(P.FLAME[3 + rnd.randint(0, 2)]))
        h = [5, 7, 6, 4][f]
        for y in range(10 - h, 11):
            t = (10 - y) / max(1, h)
            half = max(1, int(4 * (1 - t) + 1))
            c.hline(12 - half, 11 + half, y, P.hx(P.FLAME[3 + int(t * 2)]))
            if t < 0.4:
                c.hline(12 - half + 1, 11 + half - 1, y, P.hx(P.FLAME[5]))
        out.append(c)
    return out


def cell_door(open_=False, seed=0):
    """Дверь камеры 32x40: рама, прутья, замок."""
    c = Canvas(32, 40)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    iron_d = P.hx(P.IRON[1])
    c.rect(0, 0, 31, 39, iron_d)
    if not open_:
        for x in range(3, 30, 5):
            c.vline(x, 2, 37, iron)
            c.vline(x + 1, 2, 37, iron_l)
            c.vline(x + 2, 2, 37, iron_d)
        for y in (4, 20, 36):
            c.hline(2, 29, y, iron)
            c.hline(2, 29, y + 1, iron_l)
        # замок
        c.rect(12, 22, 20, 29, P.hx(P.IRON[3]))
        c.hline(12, 20, 22, iron_l)
        c.px(16, 25, P.hx("#0a0c10"))
        c.px(16, 26, P.hx("#0a0c10"))
    else:
        # открытая: створка ушла в сторону, видны петли
        for y in (3, 19, 35):
            c.rect(0, y, 5, y + 2, iron)
            c.hline(0, 5, y, iron_l)
        c.rect(0, 0, 2, 39, P.hx("#05070a"))
    c.outline(P.hx(P.INK))
    return c


def chain_hanging(seed=0, length=26):
    c = Canvas(12, length + 6)
    iron = P.hx(P.IRON[3])
    iron_l = P.hx(P.IRON[4])
    iron_d = P.hx(P.IRON[1])
    c.rect(4, 0, 7, 3, iron_d)
    c.hline(4, 7, 0, iron_l)
    for i in range(length // 2):
        y = 4 + i * 2
        if i % 2 == 0:
            c.hline(5, 6, y, iron)
            c.hline(5, 6, y + 1, iron_l)
        else:
            c.vline(5, y, y + 1, iron)
            c.vline(6, y, y + 1, iron_d)
    # крюк или кандалы
    c.ellipse(2, length, 9, length + 5, iron)
    c.ellipse(3, length + 1, 8, length + 4, (0, 0, 0, 0))
    c.px(2, length + 2, iron_l)
    c.outline(P.hx(P.INK))
    return c


def barrel(seed=0):
    c = Canvas(20, 24)
    wood = P.hx(P.LEATHER[2])
    wood_d = P.hx(P.LEATHER[1])
    wood_l = P.hx(P.LEATHER[4])
    iron = P.hx(P.IRON[2])
    c.d.rounded_rectangle([1, 2, 18, 22], radius=3, fill=wood)
    c.vline(2, 4, 20, wood_l)
    c.vline(17, 4, 20, wood_d)
    for x in (6, 10, 14):
        c.vline(x, 3, 21, P.mix(wood, wood_d, 0.5))
    for y in (6, 12, 18):
        c.hline(1, 18, y, iron)
        c.hline(1, 18, y + 1, P.hx(P.IRON[1]))
    c.ellipse(2, 0, 17, 5, P.mix(wood, wood_l, 0.4))
    c.ellipse(4, 1, 15, 4, P.mix(wood, (0, 0, 0, 255), 0.45))
    directional_shade(c, amount=0.22)
    c.outline(P.hx(P.INK))
    return c


def crate(seed=0):
    c = Canvas(20, 18)
    wood = P.hx(P.LEATHER[2])
    wood_l = P.hx(P.LEATHER[4])
    wood_d = P.hx(P.LEATHER[1])
    c.rect(1, 3, 18, 17, wood)
    c.hline(1, 18, 3, wood_l)
    c.line([(1, 3), (18, 17)], wood_d)
    c.line([(1, 17), (18, 3)], P.mix(wood, wood_l, 0.3))
    c.rect(1, 3, 18, 4, wood_l)
    c.left = 0
    for x in (1, 9, 18):
        c.vline(x, 3, 17, wood_d)
    directional_shade(c, amount=0.2)
    c.outline(P.hx(P.INK))
    return c


def straw_bed(seed=0):
    c = Canvas(30, 18)
    straw_d = P.hx(P.BLOND[1])
    straw = P.hx(P.BLOND[3])
    straw_l = P.hx(P.BLOND[4])
    c.d.ellipse([0, 4, 29, 17], fill=straw_d)
    c.d.ellipse([1, 5, 28, 15], fill=straw)
    rnd = random.Random(seed)
    for _ in range(70):
        x, y = rnd.randint(1, 28), rnd.randint(6, 15)
        ln = rnd.randint(2, 4)
        for i in range(ln):
            c.px(x + i, y + (i % 2), rnd.choice([straw_l, straw, straw_d]))
    # грязное пятно
    for _ in range(12):
        c.px(rnd.randint(4, 25), rnd.randint(8, 15), P.hx(P.BLOOD[1]))
    directional_shade(c, amount=0.18)
    c.outline(P.hx(P.INK))
    return c


def refuse_pile(seed=0, frame=0):
    """Куча отбросов — источник «гнилой плоти»."""
    c = Canvas(30, 20)
    rnd = random.Random(seed + frame)
    flesh = P.hx(P.BLOOD[2])
    flesh_d = P.hx(P.BLOOD[1])
    bone = P.hx(P.BONE[3])
    c.d.ellipse([0, 6, 29, 19], fill=P.hx(P.BLOOD[0]))
    for i in range(26):
        x = rnd.randint(2, 26)
        y = rnd.randint(6, 16)
        r = rnd.randint(2, 4)
        c.d.ellipse([x, y, x + r, y + r - 1], fill=rnd.choice([flesh, flesh_d, P.hx(P.BLOOD[3])]))
    for _ in range(4):
        x, y = rnd.randint(3, 24), rnd.randint(8, 16)
        c.hline(x, x + 4, y, bone)
        c.px(x - 1, y, P.hx(P.BONE[4]))
    # мухи/пар
    for _ in range(6):
        c.px(rnd.randint(2, 27), rnd.randint(2, 7) - frame, P.mix(P.hx(P.MOSS[4]), (0, 0, 0, 0), 0.2))
    directional_shade(c, amount=0.25)
    c.outline(P.hx(P.INK))
    return c


def cauldron(seed=0):
    c = Canvas(26, 24)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    c.d.ellipse([0, 5, 25, 23], fill=iron)
    c.d.ellipse([2, 7, 23, 21], fill=P.hx(P.IRON[3]))
    c.hline(4, 21, 8, iron_l)
    c.d.ellipse([3, 2, 22, 9], fill=P.hx(P.IRON[1]))
    c.d.ellipse([4, 3, 21, 8], fill=P.hx(P.BLOOD[1]))
    c.d.ellipse([6, 4, 19, 7], fill=P.hx(P.BLOOD[2]))
    # огонь под котлом
    for x in range(5, 21, 3):
        c.vline(x, 20, 23, P.hx(P.FLAME[2]))
        c.px(x, 21, P.hx(P.FLAME[4]))
    directional_shade(c, amount=0.24)
    c.outline(P.hx(P.INK))
    return c


def lever(seed=0, pulled=False):
    c = Canvas(16, 26)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    c.rect(4, 16, 11, 24, iron)
    c.rect(4, 16, 11, 17, iron_l)
    c.rect(5, 18, 10, 23, P.hx(P.IRON[1]))
    if not pulled:
        c.vline(7, 2, 17, iron)
        c.vline(8, 2, 17, iron_l)
        c.circle(7, 2, 2, P.hx(P.BLOOD[3]))
        c.px(7, 1, P.hx(P.BLOOD[4]))
    else:
        c.line([(7, 16), (12, 3)], iron, 2)
        c.circle(12, 2, 2, P.hx(P.BLOOD[3]))
    directional_shade(c, amount=0.22)
    c.outline(P.hx(P.INK))
    return c


def gate(seed=0, open_=False):
    """Ворота 64x48: тяжёлая решётка."""
    c = Canvas(64, 48)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    iron_d = P.hx(P.IRON[1])
    c.rect(0, 0, 63, 47, P.hx("#05070a"))
    if not open_:
        for x in range(2, 62, 6):
            c.vline(x, 1, 46, iron)
            c.vline(x + 1, 1, 46, iron_l)
            c.vline(x + 2, 1, 46, iron_d)
        for y in (1, 16, 31, 46):
            c.hline(1, 62, y, iron)
            c.hline(1, 62, y + 1, iron_l)
        # клёпки
        for x in range(4, 62, 12):
            for y in (3, 18, 33):
                c.px(x, y, P.hx(P.IRON[5]))
        # замок
        c.rect(26, 20, 38, 30, P.hx(P.IRON[3]))
        c.hline(26, 38, 20, iron_l)
        c.px(31, 24, P.hx("#0a0c10"))
    else:
        c.rect(0, 0, 7, 47, iron)
        c.vline(1, 0, 47, iron_l)
    c.outline(P.hx(P.INK))
    return c


def winch(seed=0):
    c = Canvas(28, 28)
    wood = P.hx(P.LEATHER[2])
    wood_l = P.hx(P.LEATHER[4])
    iron = P.hx(P.IRON[3])
    c.rect(2, 20, 26, 26, wood)
    c.hline(2, 26, 20, wood_l)
    c.rect(4, 6, 8, 22, wood)
    c.rect(20, 6, 24, 22, wood)
    c.hline(4, 8, 6, wood_l)
    c.hline(20, 24, 6, wood_l)
    c.rect(6, 10, 22, 16, P.hx(P.IRON[2]))
    c.hline(6, 22, 10, P.hx(P.IRON[4]))
    for x in range(7, 22, 3):
        c.vline(x, 11, 15, P.hx(P.IRON[1]))
    # ворот
    c.vline(13, 15, 20, P.hx(P.IRON[4]))
    c.hline(13, 13, 20, P.hx(P.IRON[5]))
    directional_shade(c, amount=0.22)
    c.outline(P.hx(P.INK))
    return c


def ore_cart(seed=0):
    c = Canvas(34, 26)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    c.poly([(2, 6), (31, 6), (27, 21), (6, 21)], P.hx(P.IRON[3]))
    c.poly([(4, 8), (29, 8), (26, 19), (7, 19)], P.hx(P.IRON[1]))
    for x in range(6, 30, 4):
        c.vline(x, 7, 20, iron)
    c.hline(2, 31, 6, iron_l)
    # руда
    for _ in range(12):
        x = random.Random(seed + _).randint(6, 28)
        y = random.Random(seed + _ * 3).randint(9, 12)
        c.rect(x, y, x + 2, y + 1, P.hx(P.STONE[4] if _ % 2 else P.GOLD[2]))
    # колёса
    c.circle(9, 22, 4, P.hx(P.IRON[1]))
    c.circle(9, 22, 2, P.hx(P.IRON[3]))
    c.circle(25, 22, 4, P.hx(P.IRON[1]))
    c.circle(25, 22, 2, P.hx(P.IRON[3]))
    directional_shade(c, amount=0.2)
    c.outline(P.hx(P.INK))
    return c


def banner(seed=0, color=None):
    """Знамя клана Пожирателей."""
    c = Canvas(20, 40)
    cloth = P.hx(color or P.BLOOD[2])
    cloth_l = P.hx(P.BLOOD[3])
    cloth_d = P.hx(P.BLOOD[0])
    c.rect(2, 4, 17, 36, cloth)
    c.vline(2, 4, 36, cloth_l)
    c.vline(17, 4, 36, cloth_d)
    # рваный низ
    for x in range(2, 18, 3):
        c.px(x, 36, (0, 0, 0, 0))
        c.px(x + 1, 37, (0, 0, 0, 0))
    # древко
    c.rect(0, 0, 2, 39, P.hx(P.LEATHER[2]))
    c.vline(0, 0, 39, P.hx(P.LEATHER[4]))
    # символ: череп с рогами
    c.ellipse(6, 12, 14, 20, P.hx(P.BONE[3]))
    c.ellipse(7, 13, 13, 17, P.hx(P.BONE[4]))
    c.px(8, 16, P.hx("#0b0e13"))
    c.px(12, 16, P.hx("#0b0e13"))
    c.hline(8, 12, 19, P.hx(P.BONE[2]))
    c.line([(6, 12), (3, 8)], P.hx(P.BONE[3]))
    c.line([(14, 12), (17, 8)], P.hx(P.BONE[3]))
    directional_shade(c, amount=0.2)
    c.outline(P.hx(P.INK))
    return c


def stairs(seed=0, up=True):
    c = Canvas(32, 32)
    stone = P.hx(STONE_WALL[3])
    stone_l = P.hx(STONE_WALL[5])
    for i in range(4):
        y0 = i * 8
        col = P.mix(stone, (0, 0, 0, 255), 0.35 - i * 0.08) if up else P.mix(stone, (0, 0, 0, 255), 0.1 + i * 0.07)
        c.rect(0, y0, 31, y0 + 7, col)
        c.hline(0, 31, y0, P.mix(col, stone_l, 0.4) if up else P.mix(col, (0, 0, 0, 255), 0.3))
        c.hline(0, 31, y0 + 7, P.mix(col, (0, 0, 0, 255), 0.5))
    _noise(c, seed, 0.08)
    return c


def puddle(seed=0):
    c = Canvas(30, 18)
    for _ in range(3):
        c.d.ellipse([random.Random(seed + _).randint(0, 6), random.Random(seed + _ * 2).randint(1, 5),
                     random.Random(seed + _ * 3).randint(20, 29), random.Random(seed + _ * 4).randint(11, 17)],
                    fill=P.hx("#101820"))
    c.d.ellipse([3, 3, 26, 15], fill=P.hx("#0c1219"))
    c.hline(6, 20, 5, P.hx("#1b2a38"))
    c.px(8, 6, P.hx("#2b4356"))
    c.px(9, 6, P.hx("#2b4356"))
    return c




def anvil(seed=0):
    """Наковальня 26x20."""
    c = Canvas(26, 20)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    iron_d = P.hx(P.IRON[1])
    c.rect(11, 12, 14, 19, P.hx(P.LEATHER[1]))
    c.poly([(2, 6), (23, 6), (20, 10), (5, 10)], iron)
    c.poly([(3, 7), (22, 7), (19, 9), (6, 9)], iron_l)
    c.rect(5, 10, 20, 12, iron_d)
    c.hline(3, 22, 6, P.mix(iron_l, (255, 255, 255, 255), 0.18))
    c.hline(6, 19, 9, iron_d)
    c.px(8, 8, P.hx(P.BLOOD[2]))
    c.px(9, 8, P.hx(P.BLOOD[1]))
    directional_shade(c, amount=0.24)
    c.outline(P.hx(P.INK))
    return c


def table(seed=0):
    """Стол 30x22 с хламом."""
    c = Canvas(30, 22)
    wood = P.hx(P.LEATHER[2])
    wood_l = P.hx(P.LEATHER[3])
    wood_d = P.hx(P.LEATHER[0])
    c.rect(1, 4, 28, 13, wood)
    c.hline(1, 28, 4, wood_l)
    c.hline(2, 27, 5, P.mix(wood, wood_l, 0.4))
    c.hline(1, 28, 13, wood_d)
    for x in (2, 27):
        c.vline(x, 13, 21, wood_d)
        c.vline(x + 1, 13, 21, P.mix(wood_d, (0, 0, 0, 255), 0.3))
    # хлам на столе: миска, кости, нож
    c.d.ellipse([5, 5, 12, 11], fill=P.hx(P.IRON[2]))
    c.d.ellipse([6, 6, 11, 10], fill=P.hx(P.BLOOD[1]))
    c.hline(15, 20, 8, P.hx(P.BONE[3]))
    c.px(14, 8, P.hx(P.BONE[4]))
    c.line([(22, 6), (26, 11)], P.hx(P.IRON[4]))
    directional_shade(c, amount=0.2)
    c.outline(P.hx(P.INK))
    return c


def bucket(seed=0):
    c = Canvas(14, 16)
    wood = P.hx(P.LEATHER[2])
    wood_l = P.hx(P.LEATHER[4])
    iron = P.hx(P.IRON[2])
    c.poly([(2, 4), (11, 4), (9, 15), (4, 15)], wood)
    c.poly([(3, 5), (6, 5), (5, 14), (4, 14)], wood_l)
    c.hline(2, 11, 4, iron)
    c.hline(4, 9, 9, iron)
    c.hline(4, 9, 14, iron)
    c.d.ellipse([2, 2, 11, 6], fill=P.hx(P.IRON[1]))
    directional_shade(c, amount=0.2)
    c.outline(P.hx(P.INK))
    return c


def forge_fire(seed=0):
    """Кузнечный горн: 4 кадра, 32x32."""
    out = []
    for f in range(4):
        c = Canvas(32, 32)
        rnd = random.Random(seed * 7 + f)
        stone = P.hx(STONE_WALL[2])
        c.rect(0, 14, 31, 31, stone)
        for i in range(4):
            c.hline(0, 31, 14 + i * 4, P.mix(stone, (0, 0, 0, 255), 0.35))
        c.rect(2, 16, 29, 29, P.hx("#120a08"))
        # угли
        for _ in range(26):
            x, y = rnd.randint(4, 27), rnd.randint(18, 28)
            c.px(x, y, P.hx(P.FLAME[3 + rnd.randint(0, 2)]))
        # пламя
        h = [9, 12, 10, 7][f]
        for y in range(18 - h, 19):
            t = (18 - y) / max(1, h)
            half = max(2, int(9 * (1 - t) + 2))
            c.hline(16 - half, 15 + half, y, P.hx(P.FLAME[3 + int(t * 2)]))
            if t < 0.45:
                c.hline(16 - half + 2, 15 + half - 2, y, P.hx(P.FLAME[5]))
        for _ in range(4):
            c.px(rnd.randint(6, 26), rnd.randint(4, 16), P.hx(P.FLAME[5]))
        c.outline(P.hx(P.INK))
        out.append(c)
    return out


def bars_row(tiles=4, seed=0):
    """Полоса решётки шириной tiles*32."""
    c = Canvas(32 * tiles, 34)
    iron = P.hx(P.IRON[2])
    iron_l = P.hx(P.IRON[4])
    iron_d = P.hx(P.IRON[1])
    for x in range(3, c.w, 9):
        c.vline(x, 0, 33, iron)
        c.vline(x + 1, 0, 33, iron_l)
        c.vline(x + 2, 0, 33, iron_d)
    for y in (2, 31):
        c.hline(0, c.w - 1, y, iron)
        c.hline(0, c.w - 1, y + 1, iron_l)
    _noise(c, seed, 0.08)
    c.outline(P.hx(P.INK))
    return c


# ---------------------------------------------------------------------------
# АТЛАС И СВЕТ
# ---------------------------------------------------------------------------

TILE_INDEX = {}


def build_tile_atlas():
    """8x6 тайлов 32x32 = 256x192. Возвращает (canvas, index name->(x,y))."""
    tiles = {}
    tiles["floor_0"] = floor_tile(1, 0)
    tiles["floor_1"] = floor_tile(2, 1)
    tiles["floor_2"] = floor_tile(3, 2)
    tiles["floor_moss"] = floor_tile(4, 0, moss=True)
    tiles["floor_blood"] = floor_decor("blood", 5)
    tiles["floor_bones"] = floor_decor("bones", 6)
    tiles["floor_straw"] = floor_decor("straw", 7)
    tiles["floor_grate"] = floor_decor("grate", 8)
    tiles["floor_rubble"] = floor_decor("rubble", 9)
    tiles["wall_0"] = wall_tile(10, 0)
    tiles["wall_1"] = wall_tile(11, 1)
    tiles["wall_2"] = wall_tile(12, 2)
    tiles["wall_top"] = wall_top(13)
    tiles["wall_corner_l"] = wall_corner(14, False)
    tiles["wall_corner_r"] = wall_corner(15, True)
    tiles["wall_moss"] = wall_tile(16, 0, moss=True)
    tiles["bars"] = bars_tile(17, 0)
    tiles["bars2"] = bars_tile(18, 1)
    tiles["stairs_up"] = stairs(19, True)
    tiles["stairs_down"] = stairs(20, False)
    tiles["void"] = Canvas(T, T, P.hx("#05070a"))
    order = list(tiles.items())
    atlas = Canvas(T * 8, T * 6)
    idx = {}
    for i, (name, tile) in enumerate(order):
        gx, gy = i % 8, i // 8
        atlas.blit(tile, gx * T, gy * T)
        idx[name] = [gx, gy]
    return atlas, idx


def light_texture(size=256, inner=(255, 214, 150, 255), outer=(255, 150, 60, 0), power=2.0):
    return ellipse_gradient(size, size, inner, outer, power=power)


def vignette_texture(w=640, h=360, power=2.4, strength=190):
    """Виньетка для CanvasLayer/спрайта поверх сцены."""
    c = Canvas(w, h)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    maxd = math.hypot(cx, cy)
    px = c.img.load()
    for y in range(h):
        for x in range(w):
            t = (math.hypot(x - cx, y - cy) / maxd) ** power
            px[x, y] = (6, 8, 14, int(strength * t))
    return c
