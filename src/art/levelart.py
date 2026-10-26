"""Живопись уровня: пол и стены рисуются целиком, без повторов тайлов.

Пол — брусчатка из неровных камней (диаграмма Вороного с дрожанием).
Стены — тёмная верхняя плоскость, светлая кромка и кирпичная лицевая часть
у пола, плюс мягкая тень на пол.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

from . import palette as P
from .pixelkit import Canvas

TILE = 32


def _hx(s):
    return np.array(P.hx(s)[:3], dtype=np.float32)


def _hash01(x, y, seed=0):
    v = np.sin(x * 12.9898 + y * 78.233 + seed * 37.719) * 43758.5453
    return v - np.floor(v)


def _box_blur(mask: np.ndarray, r: int) -> np.ndarray:
    a = mask.astype(np.float32)
    pad = np.pad(a, ((r + 1, r + 1), (r + 1, r + 1)), mode="edge")
    ii = pad.cumsum(0).cumsum(1)
    h, w = a.shape
    k = 2 * r + 1
    out = (ii[k - 1:k - 1 + h, k - 1:k - 1 + w]
           - ii[0:h, k - 1:k - 1 + w]
           - ii[k - 1:k - 1 + h, 0:w]
           + ii[0:h, 0:w])
    return out / (k * k)


# --- пол -------------------------------------------------------------------

FLOOR_TONES = [_hx(c) for c in ["#343e4d", "#3a4553", "#404b59", "#46525f",
                                "#4c5968", "#525f70"]]


def _voronoi_stones(w, h, cell=30, jitter=7, seed=3):
    """Вороной только по локальным окнам — быстро даже на 1920x1088."""
    gw, gh = w // cell + 3, h // cell + 3
    d1 = np.full((h, w), 1e9, dtype=np.float32)
    d2 = np.full((h, w), 1e9, dtype=np.float32)
    ids = np.zeros((h, w), dtype=np.int32)
    reach = cell * 2
    for gy in range(gh):
        for gx in range(gw):
            cx = (gx + 0.5) * cell + (_hash01(gx, gy, seed) - 0.5) * 2 * jitter
            cy = (gy + 0.5) * cell + (_hash01(gx, gy, seed + 77) - 0.5) * 2 * jitter
            x0, x1 = max(0, int(cx - reach)), min(w, int(cx + reach) + 1)
            y0, y1 = max(0, int(cy - reach)), min(h, int(cy + reach) + 1)
            if x0 >= x1 or y0 >= y1:
                continue
            ys = np.arange(y0, y1, dtype=np.float32)[:, None]
            xs = np.arange(x0, x1, dtype=np.float32)[None, :]
            d = np.sqrt(((xs - cx) / 1.15) ** 2 + ((ys - cy) / 0.9) ** 2)
            sub_d1 = d1[y0:y1, x0:x1]
            sub_d2 = d2[y0:y1, x0:x1]
            closer = d < sub_d1
            np.copyto(sub_d2, np.where(closer, sub_d1, np.minimum(sub_d2, d)))
            np.copyto(sub_d1, np.where(closer, d, sub_d1))
            ids[y0:y1, x0:x1] = np.where(closer, gy * gw + gx, ids[y0:y1, x0:x1])
    return ids, d1, d2


def paint_floor(w, h, seed=1, moss_amt=0.0):
    ids, d1, d2 = _voronoi_stones(w, h, seed=seed)
    edge = d2 - d1

    tone_idx = ((ids.astype(np.int64) * 2654435761) % 1000) / 1000.0
    base = np.zeros((h, w, 3), dtype=np.float32)
    n = len(FLOOR_TONES)
    for i in range(n):
        m = (tone_idx >= i / n) & (tone_idx < (i + 1) / n)
        base[m] = FLOOR_TONES[i]

    # мягкий объём камня: чуть светлее к центру камня
    centering = np.clip((edge - 1.0) / 7.0, 0, 1)[..., None]
    base = base * (0.90 + 0.22 * centering)

    # мелкая крапина
    rng = np.random.default_rng(seed * 17 + 5)
    spec = rng.random((h, w)).astype(np.float32)
    base = base * (1 + ((spec > 0.97).astype(np.float32) * 0.12)[..., None]
                   - ((spec < 0.015).astype(np.float32) * 0.12)[..., None])

    # раствор
    mot = _hx("#0b0e13")
    mixv = np.clip((2.8 - edge) / 2.8, 0, 1)[..., None] ** 0.6 * 0.95
    base = base * (1 - mixv) + mot * mixv

    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    # лужи влаги
    for i in range(5):
        cx = _hash01(i, 3, seed + 9) * w
        cy = _hash01(i, 7, seed + 4) * h
        rad = 50 + _hash01(i, 11, seed) * 110
        d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / rad
        m = np.clip(1 - d, 0, 1)[..., None] ** 2
        base = base * (1 - m * 0.25) + _hx("#1b242c") * (m * 0.25)
    if moss_amt > 0:
        moss = _hx(P.MOSS[2])
        for i in range(int(12 * moss_amt) + 1):
            cx = _hash01(i, 21, seed) * w
            cy = _hash01(i, 31, seed) * h
            rad = 14 + _hash01(i, 41, seed) * 34
            d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / rad
            m = np.clip(1 - d, 0, 1)[..., None] ** 2.5
            base = base * (1 - m * 0.55) + moss * (m * 0.55)
    return base


# --- стены -----------------------------------------------------------------

BRICK_TONES = [_hx(c) for c in ["#2a323e", "#333c4a", "#3c4655", "#465160",
                                "#505c6d", "#5c6a7d"]]


def paint_bricks(w, h, seed=2, row_h=8, brick_w=17):
    ys, xs = np.mgrid[0:h, 0:w]
    row = ys // row_h
    offset = (row % 2) * 8
    col = (xs + offset + (row * 5) % 7) // brick_w
    f = _hash01(col, row, seed)
    out = np.zeros((h, w, 3), dtype=np.float32)
    for i, c in enumerate(BRICK_TONES):
        out[(f >= i / len(BRICK_TONES)) & (f < (i + 1) / len(BRICK_TONES))] = c
    seam_y = (ys % row_h) == (row_h - 1)
    seam_x = ((xs + offset) % brick_w) == (brick_w - 1)
    out = np.where((seam_y | seam_x)[..., None], _hx("#0a0d12"), out)
    local_y = (ys % row_h) / row_h
    out = out * (1 + (0.22 - local_y * 0.34)[..., None])
    rng = np.random.default_rng(seed * 5 + 2)
    sp = rng.random((h, w)).astype(np.float32)
    out = out * (1 + ((sp > 0.96).astype(np.float32) * 0.16)[..., None]
                 - ((sp < 0.012).astype(np.float32) * 0.22)[..., None])
    return out


def render_level(lines, seed=1, floor_moss=0.0):
    gh, gw = len(lines), max(len(r) for r in lines)
    W, H = gw * TILE, gh * TILE
    wall_grid = np.zeros((gh, gw), dtype=bool)
    floor_grid = np.zeros((gh, gw), dtype=bool)
    for y, row in enumerate(lines):
        for x, ch in enumerate(row):
            if ch == "#":
                wall_grid[y, x] = True
            elif ch in ".+xXokc":
                floor_grid[y, x] = True
    wall_px = np.kron(wall_grid, np.ones((TILE, TILE), dtype=bool))
    floor_px = np.kron(floor_grid, np.ones((TILE, TILE), dtype=bool))

    img = paint_floor(W, H, seed=seed, moss_amt=floor_moss)

    # широкая мягкая тень стен на пол
    sh = np.clip(_box_blur(wall_px.astype(np.float32), 18) * 1.4, 0, 1)
    img = img * (1 - (np.roll(sh, 8, axis=0) ** 1.3)[..., None] * 0.6)

    ys, xs = np.mgrid[0:H, 0:W]
    in_cell_y = ys % TILE
    face = wall_px & np.roll(floor_px, TILE, axis=0) & (in_cell_y >= TILE - 13)
    top = wall_px & ~face

    bricks = paint_bricks(W, H, seed=seed + 3)
    img = np.where(face[..., None], bricks * 0.88, img)

    # верхняя плоскость стены: тёмный камень с крошкой
    top_col = _hx("#1e242e")
    rng = np.random.default_rng(seed * 3 + 7)
    gravel = rng.random((H, W)).astype(np.float32)
    top_img = top_col * (0.80 + gravel[..., None] * 0.30)
    top_img = top_img * 0.72 + bricks * 0.28
    img = np.where(top[..., None], top_img, img)

    # светлая кромка: первая строка стены сверху
    cap = wall_px & ~np.roll(wall_px, 1, axis=0)
    img = np.where(cap[..., None], np.clip(img * 1.45 + 6, 0, 255), img)
    # тень под кромкой
    cap2 = np.roll(cap, 1, axis=0) & wall_px
    img = np.where(cap2[..., None], img * 0.7, img)

    # стык стены и пола — тёмный контур + блик на полу
    edge_wall = wall_px & ~np.roll(wall_px, -1, axis=0)
    img = np.where(edge_wall[..., None], img * 0.4, img)
    floor_lip = floor_px & np.roll(wall_px, -TILE, axis=0)
    img = np.where(floor_lip[..., None], np.clip(img * 1.12 + 6, 0, 255), img)

    # светлая кромка по всем стыкам стены с полом
    adj = np.zeros_like(wall_px)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        adj |= np.roll(floor_px, (dy, dx), axis=(0, 1))
    rim = wall_px & adj & ~face
    img = np.where(rim[..., None], np.clip(img * 1.5 + 10, 0, 255), img)

    empty = ~(wall_px | floor_px)
    img = np.where(empty[..., None], _hx("#05070a"), img)

    return _canvas_from(img)


def _canvas_from(arr):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    c = Canvas(img.width, img.height)
    c.img = img
    from PIL import ImageDraw
    c.d = ImageDraw.Draw(c.img)
    return c
