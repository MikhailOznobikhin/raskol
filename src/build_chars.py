"""Сборка персонажей в готовые спрайт-листы + манифест анимаций."""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from art import chars, pixelkit

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")

DIRS = ["down", "left", "right", "up"]

# name: (look, kwargs, anims)
CAST = {
    "hero": (chars.HERO, dict(gear={"scar": True}, beard_len=16, beard_wide=12), 
             ["idle", "walk", "sneak", "attack", "heavy", "cast", "dash", "hurt", "dead"]),
    "guard": (chars.GUARD, dict(helmet=True, beard_len=8, beard_wide=10, weapon="club"),
              ["idle", "walk", "attack", "hurt", "dead"]),
    "jailer": (chars.JAILER, dict(helmet=False, beard_len=10, beard_wide=10, weapon="club"),
               ["idle", "walk", "attack", "hurt", "dead"]),
    "gharn": (chars.GHARN, dict(helmet=True, beard_len=9, beard_wide=15, bulk=3, weapon="whip"),
              ["idle", "walk", "attack", "heavy", "hurt", "dead"]),
    "selena": (chars.SELENA, dict(beard_len=0, beard_wide=0, gear={"long_hair": True}),
               ["idle", "hurt"]),
}


def build():
    os.makedirs(OUT, exist_ok=True)
    manifest = {"frame": [chars.BASE_W, chars.BASE_H], "characters": {}}
    for name, (look, kw, anims) in CAST.items():
        char_dir = os.path.join(OUT, name)
        os.makedirs(char_dir, exist_ok=True)
        entry = {"dirs": {}}
        for d in DIRS:
            dir_entry = {}
            for anim in anims:
                pose_fn, fps = chars.ANIMS[anim]
                poses = pose_fn()
                if name == "selena" and anim == "walk":
                    poses = chars.poses_idle()
                frames = [chars.draw_dwarf(p, d, look, **kw) for p in poses]
                sheet = pixelkit.sheet(frames, cols=len(frames), pad=0)
                fname = f"{d}_{anim}.png"
                sheet.save(os.path.join(char_dir, fname))
                dir_entry[anim] = {"sheet": f"res://assets/sprites/{name}/{fname}",
                                   "frames": len(frames), "fps": fps}
            entry["dirs"][d] = dir_entry
        manifest["characters"][name] = entry
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("characters:", ", ".join(CAST))
    return manifest


if __name__ == "__main__":
    build()
