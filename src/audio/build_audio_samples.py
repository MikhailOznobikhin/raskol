#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Сборка SFX из CC0-сэмплов (Kenney / OpenGameArt) + локальная ppусурия.

Правило: исходники лежат в tools\\cc0\\ (в git не попадают, CC0 лицензия),
обработанные файлы перезаписываются в assets\\audio\\ под ТЕМИ ЖЕ именами,
которые уже использует игра (sfx_*.wav), так что код менять не нужно.

Обработка каждого таргета:
  слои -> volume -> amix -> loudnorm(-14 LUFS) -> 22050 mono 16bit WAV.

Маппинг — единственное, что правится вручную (переставляй варианты на слух).

Запуск:
  python src\\audio\\build_audio_samples.py            # собрать всё
  python src\\audio\\build_audio_samples.py --list     # показать маппинг
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
CC0 = BASE / "tools" / "cc0"
OUT = BASE / "assets" / "audio"
FFMPEG = BASE / "tools" / "ffmpeg" / "ffmpeg-9.0.2-essentials_build" / "bin" / "ffmpeg.exe"

IMP = CC0 / "impact" / "Audio"
RPG = CC0 / "rpg" / "Audio"
SWI = CC0 / "swishes" / "swishes"
MON = CC0 / "monster" / "Monster-Sounds-Volume-2"
HB = CC0 / "heartbeat"

# target -> [(источник, громкость, effect)], effect: None | 'rev' | 'slow'
MAPPING = {
    # --- движение ---
    "sfx_step_1":    [(IMP / "footstep_concrete_000.ogg", 1.0, None)],
    "sfx_step_2":    [(IMP / "footstep_concrete_002.ogg", 1.0, None)],
    "sfx_step_3":    [(IMP / "footstep_concrete_004.ogg", 1.0, None)],
    # --- бой ---
    "sfx_swing":     [(SWI / "swish-4.wav", 1.0, None)],
    "sfx_hit":       [(IMP / "impactPunch_medium_002.ogg", 1.0, None),
                      (IMP / "impactMetal_light_001.ogg", 0.35, None)],
    "sfx_hit_heavy": [(IMP / "impactPunch_heavy_001.ogg", 1.0, None),
                      (IMP / "impactWood_heavy_002.ogg", 0.8, None),
                      (IMP / "impactMining_002.ogg", 0.4, None)],
    # --- магия/жажда ---
    "sfx_cast":      [(RPG / "chop.ogg", 0.9, "rev"),
                      (IMP / "impactSoft_heavy_004.ogg", 0.5, None)],
    "sfx_absorb":    [(RPG / "chop.ogg", 1.0, None),
                      (RPG / "knifeSlice.ogg", 0.5, None),
                      (IMP / "impactSoft_medium_001.ogg", 0.6, None)],
    # --- мир/враги ---
    "sfx_alert":     [(MON / "Monster-2.wav", 1.0, None)],
    "sfx_chain":     [(IMP / "impactMetal_heavy_001.ogg", 1.0, None),
                      (IMP / "impactMetal_light_004.ogg", 0.5, None)],
    "sfx_door":      [(RPG / "doorClose_2.ogg", 1.0, None),
                      (IMP / "impactMining_003.ogg", 0.4, None)],
    "sfx_boss_roar": [(MON / "Monster-7.wav", 1.0, None),
                      (MON / "Monster-15.wav", 0.4, None)],
    "sfx_death":     [(MON / "Monster-13.wav", 1.0, None)],
    "sfx_lowmagic":  [(RPG / "metalClick.ogg", 1.2, "slow")],
    "sfx_trust":     [(RPG / "handleCoins.ogg", 1.0, None)],
    "sfx_win":       [(IMP / "impactBell_heavy_002.ogg", 1.0, None)],
    "sfx_gate_open": [(RPG / "doorOpen_1.ogg", 1.0, None),
                      (RPG / "metalLatch.ogg", 0.5, None),
                      (IMP / "impactMining_004.ogg", 0.3, None)],
    # --- интерфейс/прочее ---
    "sfx_click":     [(RPG / "metalClick.ogg", 1.0, None)],
    "sfx_heartbeat": [(HB / "heartbeat_slow_0.wav", 1.0, None)],
}

EFFECT_FILTER = {
    None: "",
    "rev": "areverse,",       # задом-наперёд (заклинание «вдыхает»)
    "slow": "asetrate=26000,aresample=22050,atempo=0.9,",
}


def convert(target: str, sources: list[dict]) -> None:
    """Слои -> amix (если >1) -> loudnorm -> WAV 22050 mono."""
    args = [str(FFMPEG), "-y", "-loglevel", "error"]
    for s in sources:
        args += ["-i", str(s["path"])]
    chains = []
    for i, s in enumerate(sources):
        eff = EFFECT_FILTER.get(s["effect"], "")
        chains.append(f"[{i}:a]aresample=48000,{eff}"
                      f"volume={s['gain']:g},aformat=channel_layouts=mono[s{i}];")
    ln = "loudnorm=I=-14:TP=-1.0:LRA=11"
    if len(sources) == 1:
        full = "".join(chains) + f"[s0]{ln}[aout]"
    else:
        labels = "".join(f"[s{i}]" for i in range(len(sources)))
        full = "".join(chains) + f"{labels}amix=inputs={len(sources)}:duration=longest[mix];[mix]{ln}[aout]"
    args += ["-filter_complex", full, "-map", "[aout]",
             "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le",
             str(OUT / (target + ".wav"))]
    res = subprocess.run(args, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"{target}: {res.stderr.strip()[:400]}")


def collect_sources() -> dict[str, list[dict]]:
    out = {}
    for tgt, items in MAPPING.items():
        entries = []
        for path, gain, eff in items:
            p = Path(path)
            if not p.exists():
                raise FileNotFoundError(f"{tgt}: нет файла {p}")
            entries.append({"path": p, "gain": gain, "effect": eff})
        out[tgt] = entries
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("targets", nargs="*", help="только эти (по имени без .wav)")
    args = ap.parse_args()

    srcs = collect_sources()
    if args.list:
        for tgt, items in srcs.items():
            parts = " + ".join(
                f"{i['path'].relative_to(CC0)} x{round(i['gain'],2)}"
                f"{ '[' + i['effect'] + ']' if i['effect'] else ''}"
                for i in items)
            print(f"{tgt} = {parts}")
        return 0

    pick = args.targets or list(srcs)
    fail = 0
    for tgt in pick:
        try:
            convert(tgt, srcs[tgt])
            print("[OK]", tgt)
        except Exception as e:  # noqa: BLE001
            fail += 1
            print("[FAIL]", tgt, e)
    print(f"готово: {len(pick) - fail}/{len(pick)}")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
