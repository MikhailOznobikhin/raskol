"""Интерфейс, портреты, экранные эффекты и титульный арт."""
from __future__ import annotations

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image

from art import chars, env, palette as P, pixelkit
from art.pixelkit import Canvas, ellipse_gradient

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "ui")
FX = os.path.join(ROOT, "assets", "fx")
ART = os.path.join(ROOT, "assets", "art")


def hx(s):
    return P.hx(s)


# ---------------------------------------------------------------------------
# интерфейс
# ---------------------------------------------------------------------------

def panel(w=48, h=48, border=3):
    """Девятислайсовая панель: камень с металлической окантовкой."""
    c = Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, hx("#0d1119"))
    c.frame(0, 0, w - 1, h - 1, hx("#2a3140"))
    c.frame(1, 1, w - 2, h - 2, hx("#161c27"))
    c.frame(2, 2, w - 3, h - 3, hx("#0a0d13"))
    # заклёпки по углам
    for (x, y) in ((2, 2), (w - 4, 2), (2, h - 4), (w - 4, h - 4)):
        c.px(x, y, hx("#5b6a80"))
        c.px(x + 1, y + 1, hx("#1a212c"))
    return c


def bar(w=64, h=7, color="#a32247", dark="#2a0711", light="#e66a80"):
    c = Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, hx(dark))
    c.rect(0, 0, w - 1, h - 2, hx(color))
    c.hline(0, w - 1, 0, hx(light))
    c.hline(0, w - 1, h - 2, P.mix(hx(color), hx(dark), 0.5))
    for x in range(0, w, 8):
        c.px(x, 1, P.mix(hx(color), (255, 255, 255, 255), 0.18))
    return c


def bar_bg(w=64, h=7):
    c = Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, hx("#0a0d13"))
    c.frame(0, 0, w - 1, h - 1, hx("#2f3746"))
    c.hline(1, w - 2, 1, hx("#05070a"))
    return c


def icon(kind: str, size=20):
    c = Canvas(size, size)
    cx = cy = size // 2
    pale = hx("#e8e2cf")
    gold = hx(P.GOLD[4])
    red = hx(P.BLOOD[4])
    dark = hx(P.BLOOD[2])
    if kind == "attack":          # кулак с цепью
        c.rect(5, 7, 13, 14, pale)
        c.rect(5, 7, 13, 8, gold)
        for y in (9, 11, 13):
            c.hline(6, 12, y, hx("#b9b3a0"))
        c.rect(3, 9, 5, 13, pale)
        c.px(15, 10, hx(P.IRON[5]))
        c.px(16, 11, hx(P.IRON[4]))
    elif kind == "dash":          # три шеврона
        for i, x in enumerate((3, 8, 13)):
            for y in range(6, 15):
                c.px(x + (y - 11) // 2 + i, y, gold if i else pale)
                c.px(x + (y - 11) // 2 + i + 1, y, P.mix(gold, (0, 0, 0, 255), 0.4))
    elif kind == "spike":         # кровавый шип
        for i in range(12):
            c.hline(cx - i // 3, cx + i // 3, 4 + i, red if i < 9 else pale)
        c.px(cx, 16, pale)
        c.hline(cx - 2, cx + 2, 15, dark)
    elif kind == "eat":           # кусок плоти
        c.d.ellipse([4, 6, 15, 15], fill=dark)
        c.d.ellipse([5, 7, 14, 13], fill=red)
        c.d.ellipse([7, 8, 11, 11], fill=hx(P.BLOOD[5]))
        c.hline(6, 13, 15, hx("#d8d3c3"))
        c.px(6, 15, hx("#d8d3c3"))
    elif kind == "sneak":         # шаг в тени
        c.d.ellipse([4, 8, 15, 16], fill=hx("#1a2130"))
        c.rect(3, 11, 8, 14, pale)
        c.rect(11, 9, 15, 12, pale)
        c.px(7, 8, hx(P.IRON[5]))
    elif kind == "eye":           # око Жажды
        c.d.ellipse([2, 7, 17, 14], fill=dark)
        c.d.ellipse([4, 8, 15, 13], fill=red)
        c.circle(9, 10, 2, hx("#0a0508"))
        c.px(9, 10, hx(P.BLOOD[5]))
    elif kind == "heart":
        c.rect(5, 5, 9, 9, red)
        c.rect(10, 5, 14, 9, red)
        c.rect(5, 14, 14, 15, dark)
        c.poly([(4, 7), (16, 7), (10, 15)], red)
        c.px(7, 6, hx(P.BLOOD[5]))
    elif kind == "key":
        c.circle(6, 7, 3, gold)
        c.circle(6, 7, 1, hx("#0a0d13"))
        c.vline(6, 10, 17, gold)
        c.hline(6, 10, 14, gold)
        c.hline(6, 9, 16, gold)
    elif kind == "trust":         # весы
        c.hline(4, 16, 5, gold)
        c.vline(10, 5, 16, gold)
        c.hline(6, 14, 16, gold)
        c.circle(5, 9, 2, hx(P.IRON[5]))
        c.circle(15, 9, 2, hx(P.BLOOD[4]))
    elif kind == "objective":
        c.frame(3, 3, 16, 16, gold)
        c.hline(6, 13, 7, pale)
        c.hline(6, 13, 10, pale)
        c.hline(6, 10, 13, pale)
    elif kind == "camp":          # лагерь / база
        c.poly([(4, 16), (10, 5), (16, 16)], hx(P.CLOTH[3]))
        c.poly([(7, 16), (10, 9), (13, 16)], hx(P.CLOTH[5]))
        c.rect(9, 12, 11, 16, hx("#0a0d13"))
    c.outline(hx(P.INK))
    return c


def portrait(char: str, look, kw, bg_color=None, tag=""):
    """Портрет 96x96: увеличенный бюст + свет + рамка."""
    c = Canvas(96, 96)
    # фон: радиальный градиент
    bg = ellipse_gradient(96, 96, hx(bg_color or "#2a1a20"), hx("#07080c"), power=1.2)
    c.blit(bg, 0, 0)
    # силуэт плеч
    c.d.ellipse([6, 62, 89, 120], fill=hx("#12161e"))
    sprite = chars.draw_dwarf(chars.Pose(), "down", look, **kw)
    big = sprite.scale(2)
    c.blit(big, 0, -6)
    # свет изнутри кадра
    arr = np.asarray(c.img.convert("RGBA")).astype(np.float32)
    yy, xx = np.mgrid[0:96, 0:96]
    d = np.sqrt(((xx - 48) / 48) ** 2 + ((yy - 40) / 52) ** 2)
    vig = np.clip(d / 1.35, 0, 1) ** 2
    arr[..., :3] *= (1 - vig[..., None] * 0.75)
    c.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    from PIL import ImageDraw
    c.d = ImageDraw.Draw(c.img)
    # рамка
    c.frame(0, 0, 95, 95, hx("#c9a548"))
    c.frame(1, 1, 94, 94, hx("#3a2c10"))
    c.frame(2, 2, 93, 93, hx("#0a0d13"))
    for (x, y) in ((1, 1), (93, 1), (1, 93), (93, 93)):
        c.px(x, y, hx("#e9cd7d"))
    _ = tag
    return c


# ---------------------------------------------------------------------------
# живопись: небо, горы, луна, туман
# ---------------------------------------------------------------------------

def sky(w, h, top="#0a0f1e", mid="#241b2e", bottom="#0b0a10", moon=None, stars=120, seed=1):
    c = Canvas(w, h)
    for y in range(h):
        t = y / (h - 1)
        if t < 0.55:
            col = P.mix(hx(top), hx(mid), t / 0.55)
        else:
            col = P.mix(hx(mid), hx(bottom), (t - 0.55) / 0.45)
        c.hline(0, w - 1, y, col)
    rnd = random.Random(seed)
    for _ in range(stars):
        x, y = rnd.randint(0, w - 1), rnd.randint(0, int(h * 0.6))
        b = rnd.randint(90, 220)
        c.px(x, y, (b, b, min(255, b + 20), 255))
    if moon:
        c.blit(_moon(*moon), moon[0] - moon[2], moon[1] - moon[2])
    return c


def _moon(cx, cy, r, color="#e8b9a0"):
    """Кровавая луна с кратерами и ореолом."""
    size = r * 4
    c = Canvas(size, size)
    ctr = size // 2
    halo = ellipse_gradient(size, size, (255, 140, 120, 90), (255, 120, 90, 0), power=1.6)
    c.blit(halo, 0, 0)
    base = hx(color)
    c.circle(ctr, ctr, r, base)
    c.circle(ctr, ctr, r - 1, P.mix(base, (255, 230, 220, 255), 0.25))
    rnd = random.Random(7)
    for _ in range(9):
        a = rnd.random() * math.tau
        d = rnd.random() * (r - 4)
        x = int(ctr + math.cos(a) * d)
        y = int(ctr + math.sin(a) * d)
        rr = rnd.randint(1, max(2, r // 7))
        c.circle(x, y, rr, P.mix(base, (120, 60, 60, 255), 0.45))
    # мягкий блик сверху-слева
    for i in range(r // 3):
        c.px(ctr - r + 4 + i, ctr - r + 5 + i, P.mix(base, (255, 245, 235, 255), 0.35))
        c.px(ctr - r + 5 + i, ctr - r + 5 + i, P.mix(base, (255, 245, 235, 255), 0.2))
    return c


def ridge(c, base_y, amp, color, seed, w, h, rough=0.5):
    """Силуэт горного хребта."""
    rnd = random.Random(seed)
    ys = [base_y]
    x = 0
    y = base_y
    while x < w:
        step = rnd.randint(8, 26)
        dy = rnd.randint(-amp, amp)
        y = max(h * 0.12, min(h - 4, y + dy))
        ys.append(y)
        x += step
    pts = [(0, h), (0, ys[0])]
    xx = 0
    for i, yy in enumerate(ys):
        xx = int(i * w / max(1, len(ys) - 1))
        pts.append((xx, yy))
    pts += [(w, h)]
    c.poly(pts, hx(color))
    # подножие светлее (воздушная перспектива)
    c.poly([p for p in pts[:-1]] + [(w, h - 1)], P.mix(hx(color), hx("#2a3040"), 0.25))


def fog_band(c, y0, y1, color="#7d8aa0", alpha=40, seed=3):
    """Полоса туманной дымки: мягкие радиальные пятна."""
    rnd = random.Random(seed)
    col = hx(color)
    for _ in range(26):
        x = rnd.randint(-60, c.w + 60)
        y = rnd.randint(y0, y1)
        size = rnd.randint(90, 260)
        puff = ellipse_gradient(size, size, (int(col[0]), int(col[1]), int(col[2]), alpha),
                                (int(col[0]), int(col[1]), int(col[2]), 0), power=1.3)
        c.img.alpha_composite(puff.img, (x - size // 2, y - size // 2))


def snow(c, count=220, seed=5, alpha=170):
    rnd = random.Random(seed)
    for _ in range(count):
        x, y = rnd.randint(0, c.w - 1), rnd.randint(0, c.h - 1)
        b = rnd.randint(150, 255)
        c.px(x, y, (b, b, min(255, b + 10), alpha))
        if rnd.random() < 0.25:
            c.px(x, y + 1, (b // 2, b // 2, b // 2, alpha // 2))


def title_art(w=960, h=540):
    """Титульный экран: кровавая луна, горы, врата тюрьмы, гном с факелом."""
    c = sky(w, h, moon=(int(w * 0.68), int(h * 0.26), 54))
    ridge(c, int(h * 0.46), 22, "#171d2a", 11, w, h)
    fog_band(c, int(h * 0.46), int(h * 0.58), "#5b6a86", 34, 4)
    ridge(c, int(h * 0.58), 30, "#10141d", 12, w, h)
    fog_band(c, int(h * 0.58), int(h * 0.70), "#4d5a74", 30, 5)
    # каменные врата: две башни и арка между ними
    gx, gy = int(w * 0.78), int(h * 0.52)
    stone_d = hx("#0c0f15")
    stone_l = hx("#171d27")
    # арка
    c.poly([(gx - 62, h), (gx - 62, gy + 10), (gx - 40, gy - 40), (gx + 40, gy - 40),
            (gx + 62, gy + 10), (gx + 62, h)], stone_d)
    c.d.ellipse([gx - 64, gy - 92, gx + 64, gy + 20], fill=stone_d)
    # проём
    c.poly([(gx - 44, h), (gx - 44, gy + 16), (gx - 28, gy - 22), (gx + 28, gy - 22),
            (gx + 44, gy + 16), (gx + 44, h)], hx("#05060a"))
    c.d.ellipse([gx - 46, gy - 62, gx + 46, gy + 22], fill=hx("#05060a"))
    # решётка в проёме
    for x in range(gx - 40, gx + 41, 9):
        c.vline(x, gy - 18, h, hx("#1b212b"))
        c.vline(x + 1, gy - 18, h, hx("#2c3542"))
    # башни
    for sx in (-1, 1):
        bx = gx + sx * 92
        c.rect(bx - 34, gy - 120, bx + 34, h, stone_d)
        c.hline(bx - 34, bx + 34, gy - 120, stone_l)
        c.vline(bx - 34 + (0 if sx > 0 else 68), gy - 120, h, stone_l)
        for wy in range(gy - 104, h, 26):
            for wx in range(bx - 24, bx + 25, 22):
                c.rect(wx, wy, wx + 7, wy + 12, hx("#05060a"))
        # зубцы
        for k in range(4):
            c.rect(bx - 34 + k * 18, gy - 132, bx - 24 + k * 18, gy - 118, stone_d)
    # факелы у врат
    # факелы у врат
    for x in (gx - 96, gx + 96):
        c.rect(x - 1, gy + 20, x + 1, gy + 54, hx("#2c1f14"))
        flame = Canvas(w, h)
        for i in range(10):
            yy = gy + 20 - i
            half = max(1, 4 - i // 3)
            flame.hline(x - half, x + half, yy, hx(P.FLAME[3 + min(2, i // 4)]))
        c.img.alpha_composite(flame.img)
    # уступ и фигура гнома
    c.poly([(0, h), (0, int(h * 0.86)), (int(w * 0.42), int(h * 0.86)), (int(w * 0.52), h)],
           hx("#0a0c11"))
    hero = chars.draw_dwarf(chars.Pose(), "right", chars.HERO, gear={"scar": True})
    hero_s = hero.scale(2)
    arr = np.asarray(hero_s.img.convert("RGBA")).astype(np.float32)
    arr[..., 0] *= 0.42
    arr[..., 1] *= 0.36
    arr[..., 2] *= 0.40
    dark = Canvas(hero_s.w, hero_s.h)
    dark.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    c.blit(dark, int(w * 0.16), int(h * 0.86) - 120)
    # факел героя
    c.circle(int(w * 0.16) + 100, int(h * 0.86) - 92, 5, hx(P.FLAME[5]))
    glow = ellipse_gradient(200, 200, (255, 170, 80, 150), (255, 120, 40, 0), power=1.4)
    c.img.alpha_composite(glow.img, (int(w * 0.16) + 0, int(h * 0.86) - 190))
    snow(c, 260, 9, 150)
    fog_band(c, int(h * 0.78), h, "#6b7891", 22, 6)
    # виньетка
    c.blit(env.vignette_texture(w, h, 2.0, 205), 0, 0)
    return c


def panel_golden(w=960, h=540):
    """Пролог, сцена 1: Золотой Мир — город на рассвете."""
    c = sky(w, h, "#141d30", "#7a4a3a", "#2a1a14", stars=40, seed=21)
    glow = ellipse_gradient(760, 760, (255, 200, 130, 120), (255, 150, 90, 0), power=1.5)
    c.img.alpha_composite(glow.img, (int(w * 0.5) - 380, int(h * 0.42) - 380))
    c.circle(int(w * 0.5), int(h * 0.44), 62, hx("#ffd9a0"))
    c.circle(int(w * 0.5), int(h * 0.44), 54, hx("#ffe9c2"))
    ridge(c, int(h * 0.60), 8, "#141a26", 31, w, h)
    # город: башни и крыши
    rnd = random.Random(4)
    for i in range(14):
        bx = rnd.randint(0, w - 40)
        bw = rnd.randint(18, 46)
        bh = rnd.randint(40, 150)
        by = int(h * 0.72) - bh
        c.rect(bx, by, bx + bw, int(h * 0.72), hx("#0e1219"))
        if rnd.random() < 0.5:
            c.poly([(bx - 4, by), (bx + bw // 2, by - 22), (bx + bw + 4, by)], hx("#0e1219"))
        for wy in range(by + 6, int(h * 0.72), 12):
            for wx in range(bx + 4, bx + bw - 3, 8):
                if rnd.random() < 0.6:
                    c.px(wx, wy, hx(P.FLAME[4]))
    fog_band(c, int(h * 0.62), int(h * 0.78), "#8a7a6a", 26, 8)
    # три фигуры на переднем плане
    trio = [("hero", chars.HERO, dict(gear={"scar": True})),
            ("elf", chars.SELENA, dict(beard_len=0, beard_wide=0, gear={"long_hair": True})),
            ("mage", chars.JAILER, dict(beard_len=4, beard_wide=6))]
    for i, (nm, look, kw) in enumerate(trio):
        base = chars.draw_dwarf(chars.Pose(), "right", look, **kw).scale(2)
        arr = np.asarray(base.img.convert("RGBA")).astype(np.float32)
        arr[..., 0] *= 0.55
        arr[..., 1] *= 0.46
        arr[..., 2] *= 0.44
        dim = Canvas(base.w, base.h)
        dim.img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
        c.blit(dim, int(w * 0.20) + i * 96, int(h * 0.80) - 20)
    c.blit(env.vignette_texture(w, h, 2.1, 190), 0, 0)
    return c


def panel_cave(w=960, h=540):
    """Пролог: пещера, костёр, двое у тела третьего."""
    c = Canvas(w, h, hx("#07070a"))
    # стены пещеры
    for y in range(h):
        t = y / h
        c.hline(0, w - 1, y, P.mix(hx("#0b0c10"), hx("#141218"), t))
    rnd = random.Random(33)
    for _ in range(40):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        r = rnd.randint(20, 90)
        c.circle(x, y, r, hx("#0e1014") if rnd.random() < 0.6 else hx("#151319"))
    # костёр
    fx, fy = int(w * 0.42), int(h * 0.62)
    for i in range(14, 0, -1):
        c.circle(fx, fy, i * 5, P.mix(hx("#2a1408"), hx("#0a0808"), i / 14))
    for i in range(18):
        half = max(1, 14 - i // 2)
        c.hline(fx - half, fx + half, fy - i, hx(P.FLAME[3 + min(2, i // 6)]))
    glow = ellipse_gradient(420, 420, (255, 160, 80, 120), (255, 90, 30, 0), power=1.5)
    c.img.alpha_composite(glow.img, (fx - 210, fy - 210))
    # лежащее тело
    body = chars.draw_dwarf(chars.poses_dead()[0], "right", chars.JAILER,
                            beard_len=4, beard_wide=6)
    c.blit(body.silhouette(hx("#0a0a0d")).scale(2), int(w * 0.62), int(h * 0.66))
    # два силуэта
    h1 = chars.draw_dwarf(chars.Pose(crouch=0.6), "right", chars.HERO, gear={"scar": True})
    h2 = chars.draw_dwarf(chars.Pose(crouch=0.4), "left", chars.SELENA,
                          beard_len=0, beard_wide=0, gear={"long_hair": True})
    c.blit(h1.silhouette(hx("#0a0a0e")).scale(2), int(w * 0.22), int(h * 0.58))
    c.blit(h2.silhouette(hx("#0a0a0e")).scale(2), int(w * 0.53), int(h * 0.55))
    snow(c, 40, 12, 60)
    c.blit(env.vignette_texture(w, h, 1.6, 230), 0, 0)
    return c


def panel_rise(w=960, h=540):
    """Пролог: восстание — толпа с факелами против строя стражи."""
    c = sky(w, h, "#140d12", "#3a1418", "#0a0809", moon=(int(w * 0.30), int(h * 0.20), 40,
                                                          "#d88a70"), stars=60, seed=44)
    ridge(c, int(h * 0.55), 14, "#151018", 51, w, h)
    # дым
    fog_band(c, int(h * 0.30), int(h * 0.55), "#3a2630", 40, 13)
    # толпа
    rnd = random.Random(77)
    for i in range(26):
        x = rnd.randint(0, w)
        y = int(h * 0.78) + rnd.randint(-14, 14)
        c.poly([(x - 8, y + 40), (x, y), (x + 8, y + 40)], hx("#08060a"))
        if rnd.random() < 0.7:
            c.vline(x + 2, y - 16, y, hx("#2c1f14"))
            c.circle(x + 2, y - 18, 3, hx(P.FLAME[4]))
    # строй стражи
    for i in range(9):
        x = int(w * 0.62) + i * 36
        y = int(h * 0.74)
        c.rect(x, y, x + 16, y + 52, hx("#161a22"))
        c.rect(x + 2, y - 12, x + 14, y, hx("#1d232e"))
        c.vline(x + 20, y - 40, y + 50, hx("#39424f"))
        c.px(x + 20, y - 42, hx("#8fa0b8"))
    snow(c, 120, 15, 90)
    c.blit(env.vignette_texture(w, h, 1.9, 210), 0, 0)
    return c


# ---------------------------------------------------------------------------
# эффекты
# ---------------------------------------------------------------------------

def fx_slash(frames=4, size=64):
    out = []
    for f in range(frames):
        c = Canvas(size, size)
        t = f / (frames - 1)
        for i in range(26):
            a = math.radians(-70 + i * 5.2 + t * 20)
            r = 14 + i * 0.7
            x = size / 2 + math.cos(a) * r + t * 6
            y = size / 2 + math.sin(a) * r
            col = P.mix(hx(P.BLOOD[5]), (255, 240, 240, 255), 1 - t)
            c.px(int(x), int(y), col)
            c.px(int(x), int(y) - 1, P.mix(col, hx(P.BLOOD[3]), 0.5))
            if i % 3 == 0:
                c.px(int(x) + 1, int(y) + 1, hx(P.BLOOD[4]))
        out.append(c)
    return out


def fx_impact(frames=4, size=32):
    out = []
    for f in range(frames):
        c = Canvas(size, size)
        t = f / (frames - 1)
        r = 3 + t * 12
        for i in range(int(r * 6)):
            a = i / max(1, r * 6) * math.tau
            x = size / 2 + math.cos(a) * r
            y = size / 2 + math.sin(a) * r * 0.7
            c.px(int(x), int(y), P.mix(hx(P.BLOOD[5]), hx(P.BLOOD[1]), t))
        if t < 0.5:
            c.circle(size // 2, size // 2, int(6 * (1 - t)), hx(P.BLOOD[5]))
        out.append(c)
    return out


def fx_spike():
    c = Canvas(26, 10)
    for i in range(20):
        x = 2 + i
        half = max(0, 3 - i // 6)
        c.hline(x, x, 5 - half, hx(P.BLOOD[4]))
        c.px(x, 5, hx(P.BLOOD[5]))
        c.px(x, 5 + half, hx(P.BLOOD[2]))
    c.px(22, 5, (255, 235, 235, 255))
    c.outline(hx(P.BLOOD[0]))
    return c


def fx_particles():
    dot = Canvas(3, 3)
    dot.px(1, 1, (255, 220, 180, 255))
    dot.px(0, 1, (255, 120, 60, 120))
    ember = Canvas(4, 4)
    ember.px(1, 1, (255, 200, 120, 255))
    ember.px(2, 1, (255, 150, 70, 200))
    ember.px(1, 2, (200, 80, 30, 160))
    blood = Canvas(4, 4)
    blood.px(1, 1, (201, 58, 91, 255))
    blood.px(2, 1, (163, 34, 71, 220))
    blood.px(1, 2, (125, 23, 52, 180))
    dust = Canvas(6, 6)
    for (x, y) in ((2, 2), (3, 2), (2, 3), (4, 3), (3, 4)):
        dust.px(x, y, (160, 160, 150, 90))
    smoke_puff = ellipse_gradient(64, 64, (90, 90, 100, 110), (70, 70, 80, 0), power=1.2)
    return {"dot": dot, "ember": ember, "blood": blood, "dust": dust, "smoke": smoke_puff}


def fog_texture(size=256):
    c = Canvas(size, size)
    rnd = random.Random(2)
    for _ in range(220):
        x, y = rnd.randint(0, size), rnd.randint(0, size)
        r = rnd.randint(10, 46)
        c.circle(x, y, r, (150, 160, 180, 4))
    # размытие через уменьшение/увеличение
    small = c.img.resize((size // 8, size // 8), Image.BILINEAR)
    c.img = small.resize((size, size), Image.BILINEAR)
    return c


def build():
    for d in (UI, FX, ART):
        os.makedirs(d, exist_ok=True)

    panel().save(os.path.join(UI, "panel.png"))
    bar_bg().save(os.path.join(UI, "bar_bg.png"))
    bar(color="#8f2436", dark="#2a0711", light="#e66a80").save(os.path.join(UI, "bar_health.png"))
    bar(color="#7d1734", dark="#230610", light="#c93a5b").save(os.path.join(UI, "bar_magic.png"))
    bar(color="#5c1026", dark="#120409", light="#b23a74").save(os.path.join(UI, "bar_craving.png"))
    bar(color="#2f6a8a", dark="#0d1a24", light="#6fb3d0").save(os.path.join(UI, "bar_trust.png"))

    for name in ("attack", "dash", "spike", "eat", "sneak", "eye", "heart", "key", "trust", "objective", "camp"):
        icon(name).save(os.path.join(UI, f"icon_{name}.png"))

    p = portrait("hero", chars.HERO, dict(gear={"scar": True}), "#2a1518")
    p.save(os.path.join(UI, "portrait_hero.png"))
    portrait("selena", chars.SELENA, dict(beard_len=0, beard_wide=0, gear={"long_hair": True}),
             "#1a2433").save(os.path.join(UI, "portrait_selena.png"))
    portrait("gharn", chars.GHARN, dict(helmet=True, beard_len=9, beard_wide=15, bulk=3),
             "#331018").save(os.path.join(UI, "portrait_gharn.png"))
    portrait("guard", chars.GUARD, dict(helmet=True, beard_len=8, beard_wide=10),
             "#241018").save(os.path.join(UI, "portrait_guard.png"))

    # арт
    title_art().save(os.path.join(ART, "title.png"))
    panel_golden().save(os.path.join(ART, "prologue_1_golden.png"))
    panel_cave().save(os.path.join(ART, "prologue_2_cave.png"))
    panel_rise().save(os.path.join(ART, "prologue_3_rise.png"))

    # эффекты
    for i, f in enumerate(fx_slash()):
        f.save(os.path.join(FX, f"slash_{i}.png"))
    for i, f in enumerate(fx_impact()):
        f.save(os.path.join(FX, f"impact_{i}.png"))
    fx_spike().save(os.path.join(FX, "spike.png"))
    parts = fx_particles()
    for k, v in parts.items():
        v.save(os.path.join(FX, f"p_{k}.png"))
    fog_texture().save(os.path.join(FX, "fog.png"))
    env.light_texture(256).save(os.path.join(FX, "light_warm.png"))
    env.light_texture(256, (255, 120, 120, 255), (255, 40, 60, 0), power=1.8).save(
        os.path.join(FX, "light_red.png"))
    env.light_texture(256, (150, 190, 255, 255), (60, 90, 200, 0), power=1.8).save(
        os.path.join(FX, "light_cold.png"))
    env.vignette_texture(640, 360, 2.2, 200).save(os.path.join(FX, "vignette.png"))
    print("ui/fx/art built")


if __name__ == "__main__":
    build()
