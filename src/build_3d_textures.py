"""PBR-текстуры для 3D-версии: камень, кирпич, железо, дерево.

Всё бесшовное (периодический шум), 512x512: albedo + normal + roughness.
Нормали считаются из карты высот, чтобы факельный свет «лепил» поверхность.
"""
from __future__ import annotations

import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "tex3d")
S = 512


def periodic_noise(size: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells)).astype(np.float32)
    # периодическая билинейная интерполяция
    xs = np.linspace(0, cells, size, endpoint=False, dtype=np.float32)
    ys = np.linspace(0, cells, size, endpoint=False, dtype=np.float32)
    x0 = np.floor(xs).astype(int) % cells
    y0 = np.floor(ys).astype(int) % cells
    x1 = (x0 + 1) % cells
    y1 = (y0 + 1) % cells
    fx = (xs - np.floor(xs))[:, None]
    fy = (ys - np.floor(ys))[:, None]
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    top = a * (1 - fx) + b * fx
    bot = c * (1 - fx) + d * fx
    return top * (1 - fy) + bot * fy


def fbm(size: int, base_cells: int, octaves: int, seed: int) -> np.ndarray:
    out = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    total = 0.0
    cells = base_cells
    for o in range(octaves):
        out += periodic_noise(size, cells, seed + o * 17) * amp
        total += amp
        amp *= 0.5
        cells *= 2
    return out / total


def normal_from_height(h: np.ndarray, strength: float = 2.0) -> np.ndarray:
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nz = -dx / l, -dy / l, nz / l
    img = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    return img


def save(name: str, rgb: np.ndarray, normal: np.ndarray | None = None,
         rough: np.ndarray | None = None) -> None:
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + "_albedo.png"))
    if normal is not None:
        Image.fromarray(np.clip(normal * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + "_normal.png"))
    if rough is not None:
        g = np.clip(rough * 255, 0, 255).astype(np.uint8)
        Image.fromarray(g).save(os.path.join(OUT, name + "_rough.png"))
    print("tex", name)


def stone_floor() -> None:
    n = fbm(S, 8, 5, 11)
    # плиты: периодическая сетка с дрожанием
    cells = 4
    step = S // cells
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
    jitter = (periodic_noise(S, cells * 2, 3) - 0.5) * 0.06
    gx = xs / S * cells + jitter
    gy = ys / S * cells + jitter * 0.7
    fx = np.abs(gx - np.round(gx))
    fy = np.abs(gy - np.round(gy))
    edge = np.minimum(fx, fy) * step
    mortar = np.clip(1.0 - edge / 4.0, 0, 1)

    base = np.array([0.30, 0.33, 0.38], dtype=np.float32)
    tile = (0.85 + 0.30 * periodic_noise(S, cells * 2, 7))[..., None]
    col = base * tile + (n[..., None] - 0.5) * 0.10
    col = col * (1 - mortar[..., None] * 0.75) + np.array([0.07, 0.07, 0.08]) * mortar[..., None] * 0.75

    # трещины
    cracks = (fbm(S, 16, 4, 21) > 0.72) & (n < 0.45)
    col[cracks] *= 0.55

    height = 0.55 + n * 0.25 - mortar * 0.55
    save("stone_floor", col, normal_from_height(height, 3.0),
         0.75 + 0.2 * n)


def stone_wall() -> None:
    n = fbm(S, 8, 6, 31)
    rows = 8
    brick_h = S // rows
    cols = 4
    brick_w = S // cols
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
    row = np.floor(ys / brick_h)
    off = (row % 2) * (brick_w // 2)
    bx = (xs + off) % S
    seam_y = np.abs((ys % brick_h) - 0) < 3.0
    seam_x = np.abs(((bx) % brick_w) - 0) < 3.0
    seam = (seam_y | seam_x).astype(np.float32)

    tone = (0.8 + 0.4 * periodic_noise(S, 16, 41))[..., None]
    base = np.array([0.28, 0.31, 0.36], dtype=np.float32)
    col = base * tone + (n[..., None] - 0.5) * 0.12
    col = col * (1 - seam[..., None] * 0.7) + np.array([0.05, 0.05, 0.06]) * seam[..., None] * 0.7
    # потёки
    drip = np.clip(periodic_noise(S, 24, 51) - 0.55, 0, 1)[..., None] * 0.35
    col *= (1 - drip)

    height = 0.6 + (1 - seam) * 0.2 + n * 0.2
    save("stone_wall", col, normal_from_height(height, 3.4), 0.8 + 0.15 * n)


def metal() -> None:
    n = fbm(S, 16, 5, 61)
    streak = periodic_noise(S, 64, 71)
    base = np.array([0.36, 0.38, 0.43], dtype=np.float32)
    col = base * (0.85 + 0.3 * streak[..., None]) + (n[..., None] - 0.5) * 0.12
    rust = np.clip(fbm(S, 10, 4, 81) - 0.55, 0, 1)[..., None] * 1.6
    col = col * (1 - rust) + np.array([0.32, 0.16, 0.08]) * rust
    save("metal", col, normal_from_height(0.5 + n * 0.3, 1.6), 0.35 + 0.4 * n)


def wood() -> None:
    n = fbm(S, 8, 4, 91)
    grain = np.sin(((np.mgrid[0:S, 0:S][0] / S) * 38.0 + n * 6.0)) * 0.06
    base = np.array([0.26, 0.18, 0.11], dtype=np.float32)
    col = base * (0.8 + 0.4 * n[..., None]) + grain[..., None]
    save("wood", col, normal_from_height(0.5 + n * 0.35, 2.0), 0.8 + 0.1 * n)


if __name__ == "__main__":
    stone_floor()
    stone_wall()
    metal()
    wood()
