"""Сборка уровня: карта, фон, декор, список объектов."""
from __future__ import annotations

import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

from art import env, levelart, pixelkit

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "level")
PROP_OUT = os.path.join(ROOT, "assets", "props")
MW, MH = 60, 34
T = 32

# (x0, y0, x1, y1) — включительно, в тайлах
ROOMS = {
    "shaft": (25, 2, 33, 8),
    "shaft_corr": (27, 8, 31, 13),
    "forge": (12, 13, 33, 21),
    "forge_corr": (12, 21, 16, 25),
    "cells_corr": (3, 22, 31, 25),
    "start_cell": (4, 27, 9, 31),
    "cell_a": (12, 27, 17, 31),
    "cell_b": (20, 27, 25, 31),
    "cell_c": (27, 27, 30, 31),
    "to_kitchen": (31, 24, 35, 29),
    "kitchen": (35, 23, 56, 31),
    "to_barracks": (48, 20, 52, 23),
    "barracks": (38, 11, 56, 20),
    "forge_to_barracks": (33, 15, 38, 18),
    "to_shaft": (33, 9, 36, 15),
}

PILLARS = [(44, 14, 45, 15), (50, 14, 51, 15), (44, 17, 45, 18), (50, 17, 51, 18),
           (17, 15, 18, 16), (28, 15, 29, 16), (17, 19, 18, 20), (28, 19, 29, 20)]


def build_grid():
    floor = [[False] * MW for _ in range(MH)]
    for name, (x0, y0, x1, y1) in ROOMS.items():
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < MW and 0 <= y < MH:
                    floor[y][x] = True
    # дверные проёмы в стене камер
    for door_x in (6, 14, 22, 29):
        floor[26][door_x] = True
    # колонны внутри залов
    for (x0, y0, x1, y1) in PILLARS:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                floor[y][x] = False
    lines = []
    for y in range(MH):
        row = []
        for x in range(MW):
            if floor[y][x]:
                row.append(".")
            elif x == 0 or y == 0 or x == MW - 1 or y == MH - 1:
                row.append("#")
            else:
                row.append("#")
        lines.append("".join(row))
    return lines, floor


def tile_center_px(tx, ty):
    return tx * T + T // 2, ty * T + T // 2


def bake_decor(cv, floor, seed=4):
    """Пятна крови, кости, солома, решётки, лужи — впекаем в фон."""
    rnd = random.Random(seed)
    spots = {
        "blood": [(5, 24), (14, 27), (22, 24), (30, 28), (40, 26), (46, 24), (52, 27),
                  (44, 16), (48, 18), (20, 17), (30, 17), (26, 21), (9, 29), (33, 24)],
        "bones": [(7, 23), (16, 29), (24, 27), (39, 30), (54, 25), (45, 19), (22, 18)],
        "straw": [(4, 30), (13, 30), (21, 30), (29, 30), (37, 29), (50, 30)],
        "grate": [(28, 24), (42, 28), (18, 24), (35, 17)],
        "rubble": [(3, 22), (31, 22), (56, 22), (12, 21), (33, 13), (38, 11)],
    }
    for name, cells in spots.items():
        for (tx, ty) in cells:
            cv.blit(env.floor_decor(name, seed=tx * 31 + ty), tx * T, ty * T)
    for (tx, ty) in [(8, 26), (26, 28), (41, 22), (47, 15), (15, 18)]:
        cv.blit(env.puddle(tx * 7 + ty), tx * T + 2, ty * T + 6)


def build_props():
    """Возвращает список объектов {type, x, y} в пикселях (низ-центр)."""
    props = []

    def add(kind, tx, ty, **extra):
        d = {"type": kind, "x": tx * T + T // 2, "y": ty * T + T}
        d.update(extra)
        props.append(d)

    # факелы на стенах (y — тайл стены)
    for tx, ty in [(6, 21), (9, 21), (12, 21), (19, 21), (26, 21), (31, 21),
                   (36, 10), (42, 10), (48, 10), (54, 10),
                   (34, 22), (40, 22), (46, 22), (52, 22),
                   (11, 12), (20, 12), (29, 12), (32, 12),
                   (24, 1), (28, 1), (32, 1)]:
        add("torch", tx, ty)

    # жаровни
    for tx, ty in [(45, 13), (52, 19), (16, 14), (30, 20), (44, 23)]:
        add("brazier", tx, ty)

    # камеры и двери
    add("cell_door", 6, 26, id="door_start", cell="start")
    add("cell_door", 14, 26, id="door_a", cell="a")
    add("cell_door", 22, 26, id="door_b", cell="b")
    add("cell_door", 29, 26, id="door_c", cell="c")
    add("bars", 3, 26, tiles=2)
    add("bars", 9, 26, tiles=2)
    add("bars", 25, 26, tiles=4)

    # стартовая камера: отбросы, солома, ведро
    add("refuse", 7, 29, amount=30)
    add("straw_bed", 4, 30)
    add("bucket", 9, 30)
    add("chain", 10, 27)

    # коридор камер
    add("banner", 10, 22)
    add("banner", 27, 22)
    add("barrel", 17, 24)
    add("crate", 18, 24)
    add("chain", 24, 22)
    add("chain", 30, 22)
    add("bones", 20, 25)

    # кухня отбросов
    add("cauldron", 38, 25)
    add("refuse", 40, 27, amount=45)
    add("refuse", 43, 26, amount=35)
    add("refuse", 45, 28, amount=50)
    add("table", 50, 25)
    add("barrel", 53, 28)
    add("barrel", 54, 29)
    add("crate", 52, 26)
    add("bucket", 36, 30)
    add("refuse", 55, 30, amount=40)

    # ворота из кухни в казарму + рычаг
    add("gate", 50, 22, id="gate_barracks")
    add("lever", 47, 23, id="lever_gate")

    # казарма
    add("table", 41, 13)
    add("table", 53, 13)
    add("ore_cart", 46, 16)
    add("crate", 39, 19)
    add("crate", 40, 19)
    add("barrel", 55, 18)
    add("chain", 43, 11)
    add("chain", 49, 11)
    add("straw_bed", 55, 20)
    add("banner", 45, 10)
    add("banner", 51, 10)

    # кузня оков
    add("anvil", 14, 16)
    add("forge_fire", 12, 14)
    add("winch", 31, 14)
    add("ore_cart", 22, 20)
    add("barrel", 13, 20)
    add("chain", 19, 13)
    add("chain", 25, 13)
    add("gate", 14, 22, id="gate_forge")
    add("lever", 17, 22, id="lever_forge")

    # шахта
    add("winch", 26, 3)
    add("crate", 32, 7)
    add("barrel", 33, 7)
    add("stairs", 29, 2, id="exit")
    add("chain", 31, 2)

    return props


def build():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PROP_OUT, exist_ok=True)
    lines, floor = build_grid()

    bg = levelart.render_level(lines, seed=7, floor_moss=0.6)
    bake_decor(bg, floor, seed=12)
    bg.save(os.path.join(OUT, "m1_bg.png"))

    with open(os.path.join(OUT, "m1.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    props = build_props()
    with open(os.path.join(OUT, "m1_props.json"), "w", encoding="utf-8") as f:
        json.dump({"tile": T, "props": props}, f, ensure_ascii=False, indent=1)

    # спрайты объектов
    def save(name, canvas_list):
        for i, c in enumerate(canvas_list):
            suffix = "" if len(canvas_list) == 1 else f"_{i}"
            c.save(os.path.join(PROP_OUT, f"{name}{suffix}.png"))

    save("torch", env.torch_frames(3))
    save("brazier", env.brazier_frames(5))
    save("cell_door", [env.cell_door(False), env.cell_door(True)])
    save("gate", [env.gate(False), env.gate(True)])
    save("lever", [env.lever(False), env.lever(True)])
    save("refuse", [env.refuse_pile(9, 0), env.refuse_pile(9, 1)])
    save("chain", [env.chain_hanging(7, 34)])
    save("barrel", [env.barrel(11)])
    save("crate", [env.crate(12)])
    save("straw_bed", [env.straw_bed(13)])
    save("cauldron", [env.cauldron(14)])
    save("ore_cart", [env.ore_cart(15)])
    save("winch", [env.winch(16)])
    save("banner", [env.banner(17)])
    save("bars", [env.bars_row(4, 18)])
    save("stairs", [env.stairs(19, True)])
    save("bones", [env.floor_decor("bones", 20)])
    save("anvil", [env.anvil(22)])
    save("table", [env.table(23)])
    save("forge_fire", env.forge_fire(24))
    save("bucket", [env.bucket(21)])
    print("level:", len(lines), "x", len(lines[0]), "props:", len(props))


if __name__ == "__main__":
    build()
