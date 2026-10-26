"""pixelkit — минимальный, но удобный инструмент для процедурного пиксель-арта.

Работаем в 1x пикселях (без сглаживания), затем при необходимости
масштабируем NEAREST. Всё, что рисуется, сразу получает «пиксельный»
характер: никаких полупрозрачных градиентов, только рампы и дизеринг.
"""
from __future__ import annotations

import math
import random
from typing import Iterable, Sequence

from PIL import Image, ImageDraw

from . import palette as P


class Canvas:
    def __init__(self, w: int, h: int, fill=None):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), fill if fill else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # --- базовая запись ---------------------------------------------------
    def px(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h and color is not None:
            self.img.putpixel((int(x), int(y)), color)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.img.getpixel((int(x), int(y)))
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, color):
        self.d.rectangle([x0, y0, x1, y1], fill=color)

    def frame(self, x0, y0, x1, y1, color, t=1):
        for i in range(t):
            self.d.rectangle([x0 + i, y0 + i, x1 - i, y1 - i], outline=color)

    def hline(self, x0, x1, y, color):
        self.d.line([x0, y, x1, y], fill=color)

    def vline(self, x, y0, y1, color):
        self.d.line([x, y0, x, y1], fill=color)

    def line(self, pts: Sequence[tuple], color, width=1):
        self.d.line(list(pts), fill=color, width=width)

    def ellipse(self, x0, y0, x1, y1, color):
        self.d.ellipse([x0, y0, x1, y1], fill=color)

    def circle(self, cx, cy, r, color):
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)

    def poly(self, pts, color):
        self.d.polygon(pts, fill=color)

    # --- «умные» операции -------------------------------------------------
    def blit(self, other: "Canvas", ox=0, oy=0, mask_alpha=True):
        src = other.img
        if mask_alpha:
            self.img.alpha_composite(src, (int(ox), int(oy)))
        else:
            self.img.paste(src, (int(ox), int(oy)))

    def copy(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.img = self.img.copy()
        c.d = ImageDraw.Draw(c.img)
        return c

    def scale(self, k: int, resample=Image.NEAREST) -> "Canvas":
        c = Canvas(self.w * k, self.h * k)
        c.img = self.img.resize((self.w * k, self.h * k), resample)
        c.d = ImageDraw.Draw(c.img)
        return c

    def flip_h(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        c.img = self.img.transpose(Image.FLIP_LEFT_RIGHT)
        c.d = ImageDraw.Draw(c.img)
        return c

    def save(self, path):
        self.img.save(path)

    # --- тени, контур, дизеринг ------------------------------------------
    def outline(self, color=P.INK, diagonals=True, alpha_threshold=8):
        """Обвести непрозрачные пиксели (внешний контур)."""
        px = self.img.load()
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if px[x, y][3] > alpha_threshold:
                    continue
                neigh = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                if diagonals:
                    neigh += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
                for dx, dy in neigh:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and px[nx, ny][3] > alpha_threshold:
                        marks.append((x, y))
                        break
        for x, y in marks:
            px[x, y] = color

    def silhouette(self, color=P.INK) -> "Canvas":
        c = Canvas(self.w, self.h)
        src = self.img.load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] > 8:
                    c.img.putpixel((x, y), color)
        return c

    def dither_rect(self, x0, y0, x1, y1, a, b, density=0.5, seed=1):
        """Байеровский дизеринг между двумя цветами."""
        rnd = random.Random(seed)
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if not (0 <= x < self.w and 0 <= y < self.h):
                    continue
                t = bayer[y % 4][x % 4] / 16.0
                self.img.putpixel((x, y), a if t < 1 - density else b)
        _ = rnd

    def noise_alpha(self, color, x0, y0, x1, y1, density, seed=0):
        rnd = random.Random(seed)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if rnd.random() < density:
                    self.px(x, y, color)

    def speckle(self, region, colors: Sequence, density=0.15, seed=0):
        x0, y0, x1, y1 = region
        rnd = random.Random(seed)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.get(x, y)[3] > 0 and rnd.random() < density:
                    self.px(x, y, rnd.choice(colors))


def multiply(cv: Canvas, factor: float):
    """Умножить яркость всех пикселей (тень/свет по маске)."""
    px = cv.img.load()
    for y in range(cv.h):
        for x in range(cv.w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                max(0, min(255, int(r * factor))),
                max(0, min(255, int(g * factor))),
                max(0, min(255, int(b * factor))),
                a,
            )


def light_vertical(cv: Canvas, top=1.12, bottom=0.78, warm=(255, 214, 160, 255), cold=(10, 14, 26, 255)):
    """Верхний тёплый свет, нижняя холодная тень + лёгкий дизеринг.
    Применяется к отдельной детали до сборки — так объём читается."""
    px = cv.img.load()
    for y in range(cv.h):
        t = y / max(1, cv.h - 1)
        if t < 0.55:
            f = 1 + (top - 1) * (1 - t / 0.55)
            col = warm
            k = (top - 1) * (1 - t / 0.55)
        else:
            f = 1 + (bottom - 1) * ((t - 0.55) / 0.45)
            col = cold
            k = (1 - bottom) * ((t - 0.55) / 0.45)
        for x in range(cv.w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            nr, ng, nb = r * f, g * f, b * f
            # холодный/тёплый сдвиг
            if t < 0.55:
                nr += (col[0] - 128) * k * 0.5
                ng += (col[1] - 128) * k * 0.5
                nb += (col[2] - 128) * k * 0.5
            else:
                nr += (col[0] - 128) * k * 0.5
                ng += (col[1] - 128) * k * 0.5
                nb += (col[2] - 128) * k * 0.5
            px[x, y] = (max(0, min(255, int(nr))), max(0, min(255, int(ng))), max(0, min(255, int(nb))), a)


def light_horizontal(cv: Canvas, left=1.10, right=0.86):
    """Боковой объём: свет слева, тень справа."""
    px = cv.img.load()
    for x in range(cv.w):
        t = x / max(1, cv.w - 1)
        f = left + (right - left) * t
        for y in range(cv.h):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)


def directional_shade(cv: Canvas, lx=-0.75, ly=-0.85, amount=0.32, steps=4,
                      warm=(255, 226, 180, 255), cold=(12, 16, 28, 255)):
    """Объёмная подсветка детали: пиксели смещаются к тёплому свету сверху-слева
    и к холодной тени снизу-справа. Дискретные тона — без «мыла»."""
    xs, ys = [], []
    px = cv.img.load()
    for y in range(cv.h):
        for x in range(cv.w):
            if px[x, y][3]:
                xs.append(x)
                ys.append(y)
    if not xs:
        return
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    rx, ry = max(1, (max(xs) - min(xs)) / 2), max(1, (max(ys) - min(ys)) / 2)
    for y in range(cv.h):
        for x in range(cv.w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            t = ((x - cx) / rx) * lx + ((y - cy) / ry) * ly
            t = max(-1.0, min(1.0, t * 1.35))
            q = round(t * steps) / steps
            if q >= 0:
                k = q * amount
                col = warm
            else:
                k = -q * amount
                col = cold
            nr = r + (col[0] - r) * k * 1.15
            ng = g + (col[1] - g) * k * 1.15
            nb = b + (col[2] - b) * k * 1.15
            px[x, y] = (max(0, min(255, int(nr))), max(0, min(255, int(ng))), max(0, min(255, int(nb))), a)


def dither_shade(cv: Canvas, color, density=0.25, seed=3, region=None):
    """Крапинка/грязь поверх детали — «живая» поверхность."""
    x0, y0, x1, y1 = region if region else (0, 0, cv.w - 1, cv.h - 1)
    rnd = random.Random(seed)
    px = cv.img.load()
    for y in range(max(0, y0), min(cv.h, y1 + 1)):
        for x in range(max(0, x0), min(cv.w, x1 + 1)):
            if px[x, y][3] and rnd.random() < density:
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * 0.82 + color[0] * 0.18), int(g * 0.82 + color[1] * 0.18),
                            int(b * 0.82 + color[2] * 0.18), a)


def sheet(frames: Iterable[Canvas], cols=None, pad=0) -> Canvas:
    frames = list(frames)
    if not frames:
        raise ValueError("empty sheet")
    cols = cols or len(frames)
    rows = math.ceil(len(frames) / cols)
    w = max(f.w for f in frames)
    h = max(f.h for f in frames)
    out = Canvas(cols * w + pad * (cols - 1), rows * h + pad * (rows - 1))
    for i, f in enumerate(frames):
        cx = (i % cols) * (w + pad)
        cy = (i // cols) * (h + pad)
        out.blit(f, cx + (w - f.w) // 2, cy + (h - f.h) // 2)
    return out


def glow(canvas: Canvas, cx, cy, radius, color, strength=0.5, steps=4):
    """Мягкое свечение дискретными кольцами с убывающей прозрачностью.
    Работает поверх уже нарисованного (alpha_composite)."""
    r, g, b, _ = color if isinstance(color, tuple) else P.hx(color)
    for i in range(steps, 0, -1):
        rr = radius * i / steps
        a = int(255 * strength * (1 - i / (steps + 1)) ** 1.5)
        if a <= 0:
            continue
        layer = Canvas(canvas.w, canvas.h)
        layer.circle(int(cx), int(cy), int(rr), (r, g, b, a))
        canvas.img.alpha_composite(layer.img)


def radial_gradient(w, h, inner, outer, power=2.0) -> Canvas:
    """Радиальный градиент (для света, виньеток, тумана) — рисуем в RGBA."""
    c = Canvas(w, h)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    maxd = math.hypot(cx, cy)
    ir, ig, ib, ia = inner if isinstance(inner, tuple) else P.hx(inner)
    orr, og, ob, oa = outer if isinstance(outer, tuple) else P.hx(outer)
    px = c.img.load()
    for y in range(h):
        for x in range(w):
            t = (math.hypot(x - cx, y - cy) / maxd) ** power
            px[x, y] = (
                int(ir + (orr - ir) * t),
                int(ig + (og - ig) * t),
                int(ib + (ob - ib) * t),
                int(ia + (oa - ia) * t),
            )
    return c


def ellipse_gradient(w, h, inner, outer, power=1.6) -> Canvas:
    """Радиальный градиент, вписанный в прямоугольник (для пятен света)."""
    c = Canvas(w, h)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    ir, ig, ib, ia = inner if isinstance(inner, tuple) else P.hx(inner)
    orr, og, ob, oa = outer if isinstance(outer, tuple) else P.hx(outer)
    px = c.img.load()
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / max(cx, 1)
            dy = (y - cy) / max(cy, 1)
            t = min(1.0, (dx * dx + dy * dy) ** (power / 2))
            px[x, y] = (
                int(ir + (orr - ir) * t),
                int(ig + (og - ig) * t),
                int(ib + (ob - ib) * t),
                int(ia + (oa - ia) * t),
            )
    return c


def grid_preview(canvas: Canvas, k=4, bg=(24, 27, 34, 255)) -> Canvas:
    """Увеличить для просмотра на нейтральном фоне."""
    base = Canvas(canvas.w, canvas.h, bg)
    base.img.alpha_composite(canvas.img)
    return base.scale(k)
