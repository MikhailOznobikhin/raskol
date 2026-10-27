"""Панель инвентаря: тёмная каменная кладка из PBR-текстур dungeon_kit.

Рисуется под NinePatchRect с отступом MARGIN, а центр в NinePatch не тайлится, а
РАСТЯГИВАЕТСЯ: 176 px середины ложатся на 920×420 экрана. Поэтому в центре —
только однородный тёмный камень без швов (любая геометрия превратилась бы в
мазок). Кладка живёт в рамке: углы тянутся 1:1 и несут камни 2×2, а кромки
растягиваются вдоль одной оси — на них швы идут только параллельно этой оси.
Сверху — ржавый металлический ободок с заклёпками.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "models", "dungeon_kit", "textures")
OUT = os.path.join(ROOT, "assets", "ui", "inventory")

# палитра интерфейса «Раскола» (совпадает с scripts/inventory_screen.gd)
BRONZE = (140, 115, 51)        # 0.55, 0.45, 0.20 — рамка слотов и заклёпки
GOLD = (224, 204, 158)         # 0.88, 0.80, 0.62 — светлая кромка металла
MORTAR = (16, 16, 20)          # шов между камнями
SEAM = 3                       # толщина шва вокруг камня

SIZE = 256
MARGIN = 40                    # NinePatchRect patch_margin
BLOCKS = 2                     # камней по стороне в углу (угол тянется 1:1)
CROP = 420                     # фрагмент кладки, из которого режется камень
LIGHT = np.array([-0.45, -0.55, 0.70])   # свет факела сверху-слева


def _relief(color: Image.Image, normal: Image.Image) -> Image.Image:
    """Ламбертово затенение по карте нормалей: рельеф кладки читается и в UI."""
    n = np.asarray(normal, dtype=np.float32) / 127.5 - 1.0
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-4)
    # Y в тангентных нормал-мапах перевёрнут относительно экранных координат
    lambert = (n * np.array([1.0, -1.0, 1.0]) * LIGHT).sum(axis=2)
    shade = 0.78 + 0.22 * lambert
    lit = np.asarray(color, dtype=np.float32) * shade[:, :, None]
    return Image.fromarray(np.clip(lit, 0, 255).astype(np.uint8))


def stone_block(size: int, seed: int, crop: int = CROP) -> Image.Image:
    """Один камень: средний план кладки, уведенный в тёмный холодный камень.

    Берётся крупный фрагмент и размывается до низких частот: на масштабе
    интерфейса мелкая зернистость PBR-карты читается как телевизионный шум.
    Разные seed дают разные камни, чтобы тайлинг не бросался в глаза.
    """
    src = os.path.join(TEX, "brickwalls_basecolor.jpg")
    nrm = os.path.join(TEX, "brickwalls_normal.jpg")
    w, h = Image.open(src).size
    x0 = (w - crop) // 2 + (seed % 2) * crop // 2 - crop // 4
    y0 = (h - crop) // 2 + (seed // 2) * crop // 2 - crop // 4
    box = (x0, y0, x0 + crop, y0 + crop)
    color = Image.open(src).convert("RGB").crop(box)
    normal = Image.open(nrm).convert("RGB").crop(box)
    stone = _relief(color.resize((size, size), Image.LANCZOS),
                    normal.resize((size, size), Image.LANCZOS))
    stone = stone.filter(ImageFilter.GaussianBlur(size / 22.0))

    gray = ImageOps.grayscale(stone).convert("RGB")
    stone = Image.blend(stone, gray, 0.62)                       # почти бесцветный камень
    stone = ImageOps.autocontrast(stone, cutoff=2)
    # пятна кладки приглушаем и сильно затемняем: панель — фон, а не второй объект
    stone = ImageEnhance.Contrast(stone).enhance(0.80)
    stone = stone.point(lambda v: int(v * 0.50))                # темнее слотов — иначе рамка тонет
    r, g, b = stone.split()                                       # холод подземелья
    stone = Image.merge("RGB", (
        r.point(lambda v: int(v * 0.92)),
        g.point(lambda v: int(v * 0.98)),
        b.point(lambda v: min(255, int(v * 1.14))),
    )).convert("RGBA")

    d = ImageDraw.Draw(stone)
    # скол по периметру: светлая грань сверху-слева, тень снизу-справа, вокруг — шов
    seam = 2 if size < 40 else SEAM
    d.rectangle((0, 0, size - 1, size - 1), outline=MORTAR + (255,), width=seam)
    d.rectangle((seam, seam, size - seam - 1, size - seam - 1), outline=GOLD + (40,), width=1)
    d.line((seam, seam, size - seam, seam), fill=GOLD + (54,), width=1)
    d.line((seam, seam, seam, size - seam), fill=GOLD + (40,), width=1)
    d.line((seam, size - seam - 1, size - seam, size - seam - 1), fill=(0, 0, 0, 150), width=1)
    d.line((size - seam - 1, seam, size - seam - 1, size - seam), fill=(0, 0, 0, 150), width=1)
    return stone


def _metal_rim(d: ImageDraw.ImageDraw) -> None:
    """Ободок по внешнему краю плитки: тёмный шов, бронза, светлая фаска."""
    d.rectangle((0, 0, SIZE - 1, SIZE - 1), outline=(6, 6, 8, 255), width=3)
    d.rectangle((3, 3, SIZE - 4, SIZE - 4), outline=BRONZE + (220,), width=2)
    d.line((4, 4, SIZE - 5, 4), fill=GOLD + (170,), width=1)
    d.line((4, 4, 4, SIZE - 5), fill=GOLD + (120,), width=1)
    d.line((4, SIZE - 5, SIZE - 5, SIZE - 5), fill=(4, 4, 5, 230), width=2)
    d.line((SIZE - 5, 4, SIZE - 5, SIZE - 5), fill=(4, 4, 5, 230), width=2)


def _rivets(d: ImageDraw.ImageDraw) -> None:
    for cx, cy in ((12, 12), (SIZE - 17, 12), (12, SIZE - 17), (SIZE - 17, SIZE - 17)):
        d.ellipse((cx, cy, cx + 5, cy + 5), fill=BRONZE + (255,), outline=(5, 4, 5, 255))
        d.point((cx + 1, cy + 1), fill=GOLD + (210,))


def _slab(size: int, gain: float = 0.20) -> Image.Image:
    """Однородный тёмный камень без единого шва.

    NinePatchRect растягивает центр, а не тайлит его, поэтому здесь допустимы
    только низкие частоты: беру крупный фрагмент кладки, режу его до 1/8 и
    размываю — остаются мягкие пятна, которые тянутся без узнаваемых линий.
    """
    src = os.path.join(TEX, "brickwalls_basecolor.jpg")
    w, h = Image.open(src).size
    box = ((w - CROP) // 2, (h - CROP) // 2, (w - CROP) // 2 + CROP, (h - CROP) // 2 + CROP)
    stone = Image.open(src).convert("RGB").crop(box)
    stone = stone.resize((max(size // 8, 8), max(size // 8, 8)), Image.LANCZOS)
    stone = stone.resize((size, size), Image.LANCZOS)
    stone = stone.filter(ImageFilter.GaussianBlur(size / 26.0))
    stone = ImageOps.grayscale(stone).convert("RGB")
    stone = ImageEnhance.Contrast(stone).enhance(0.45)
    stone = stone.point(lambda v: int(v * gain) + 7)          # темнее слотов на порядок
    r, g, b = stone.split()
    return Image.merge("RGB", (
        r.point(lambda v: int(v * 0.94)),
        g.point(lambda v: int(v * 0.99)),
        b.point(lambda v: min(255, int(v * 1.16))),
    )).convert("RGBA")


def _courses(d: ImageDraw.ImageDraw) -> None:
    """Швы рамки. Кромка тянется только вдоль своей оси, поэтому на верхней и
    нижней допустимы горизонтальные линии, на боковых — вертикальные; ставим
    их в размер камня угла, чтобы кладка сходилась с углами встык. Свет факела
    сверху-слева, поэтому блик ложится под шов и правее него."""
    for off in (MARGIN // 2, MARGIN - SEAM):
        d.line((MARGIN, off, SIZE - MARGIN, off), fill=MORTAR + (255,), width=2)
        d.line((MARGIN, off + 2, SIZE - MARGIN, off + 2), fill=(214, 208, 190, 16))
        d.line((MARGIN, SIZE - off, SIZE - MARGIN, SIZE - off), fill=MORTAR + (255,), width=2)
        d.line((MARGIN, SIZE - off + 2, SIZE - MARGIN, SIZE - off + 2),
               fill=(214, 208, 190, 16))
        d.line((off, MARGIN, off, SIZE - MARGIN), fill=MORTAR + (255,), width=2)
        d.line((off + 2, MARGIN, off + 2, SIZE - MARGIN), fill=(214, 208, 190, 16))
        d.line((SIZE - off, MARGIN, SIZE - off, SIZE - MARGIN), fill=MORTAR + (255,), width=2)
        d.line((SIZE - off + 2, MARGIN, SIZE - off + 2, SIZE - MARGIN),
               fill=(214, 208, 190, 16))


def _corner_bricks(img: Image.Image, x0: int, y0: int) -> None:
    """Кладка в угол: он единственный тянется 1:1, поэтому швы тут не плывут."""
    block = MARGIN // BLOCKS
    for seed in range(BLOCKS * BLOCKS):
        bx, by = seed % BLOCKS, seed // BLOCKS
        stone = stone_block(block, seed, crop=block * 5)
        img.paste(stone, (x0 + bx * block, y0 + by * block))


def _band_stone() -> Image.Image:
    """Камень кромки: полоса, вытянутая из ОДНОГО столбца кладки.

    Кромка NinePatch растягивается вдоль своей оси, поэтому любая вертикальная
    деталь исходника размазалась бы в полосу. Столбец шириной в пиксель даёт
    честный рисунок камня по высоте и идеально тянется вширь.
    """
    src = os.path.join(TEX, "brickwalls_basecolor.jpg")
    w, h = Image.open(src).size
    x0 = (w - CROP) // 2 + CROP // 3
    strip = Image.open(src).convert("RGB").crop(
        (x0, (h - CROP) // 2, x0 + 2, (h - CROP) // 2 + CROP))
    band = strip.resize((SIZE, MARGIN), Image.LANCZOS)
    band = band.filter(ImageFilter.GaussianBlur(1.2))
    band = ImageOps.grayscale(band).convert("RGB")
    band = ImageEnhance.Contrast(band).enhance(0.72)
    band = band.point(lambda v: int(v * 0.42) + 9)
    r, g, b = band.split()
    return Image.merge("RGB", (
        r.point(lambda v: int(v * 0.94)),
        g.point(lambda v: int(v * 0.99)),
        b.point(lambda v: min(255, int(v * 1.16))),
    ))


def build_panel() -> str:
    os.makedirs(OUT, exist_ok=True)
    band = _band_stone()                                    # SIZE × MARGIN, курсы горизонтально
    img = Image.new("RGBA", (SIZE, SIZE))
    side = band.transpose(Image.ROTATE_90)                  # MARGIN × SIZE, курсы вертикально
    img.paste(side, (0, 0))
    img.paste(side.transpose(Image.FLIP_LEFT_RIGHT), (SIZE - MARGIN, 0))
    img.paste(band, (0, 0))
    img.paste(band.transpose(Image.FLIP_TOP_BOTTOM), (0, SIZE - MARGIN))
    img.paste(_slab(SIZE - 2 * MARGIN, 0.16), (MARGIN, MARGIN))   # середина почти чёрная
    _corner_bricks(img, 0, 0)
    _corner_bricks(img, SIZE - MARGIN, 0)
    _corner_bricks(img, 0, SIZE - MARGIN)
    _corner_bricks(img, SIZE - MARGIN, SIZE - MARGIN)
    d = ImageDraw.Draw(img)
    _courses(d)
    # рамка поверх камня: кромки между углами растягиваются по одной оси,
    # поэтому там только ровные линии ободка и заклёпки по углам
    _metal_rim(d)
    _rivets(d)

    out = os.path.join(OUT, "panel_brick.png")
    img.save(out)
    print(f"[OK] {out} {img.size} patch_margin={MARGIN}")
    return out


if __name__ == "__main__":
    build_panel()
