#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Звук этапа 10 «Атмосфера»: room tone, треск факела, капель, случайные
далёкие звуки и шаги по поверхностям.

Почти всё синтезируется кодом (хелперы из build_audio.py) — внешних
лицензий нет. Шаги по камню и дереву берутся из CC0-пака Kenney
«Impact Sounds» (tools/cc0/impact, в git не попадает) и проходят через
ffmpeg так же, как в build_audio_samples.py.

Запуск:
    python src/audio/build_ambience.py
    python src/audio/build_ambience.py --tools <каталог tools основного дерева>

На выходе: audio/{ambience,oneshots,footsteps}/*.wav, 22050 Гц, 16 бит, моно.
Каждый файл обязан иметь строку в _docs/licenses.md.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

from build_audio import (
    SR, TWO_PI, add_at, bandpass, env, finalize, finalize_loop, highpass,
    lowpass, metal_hit, noise, nsamples, reverb,
    sanitize, save_wav, thump, timeline, water_drip,
)

BASE = Path(__file__).resolve().parents[2]
OUT = BASE / "audio"


# ---------------------------------------------------------------------------
# Лупы
# ---------------------------------------------------------------------------

def build_room_tone() -> np.ndarray:
    """Тон помещения: низкий гул камня, медленно дышащий воздух. 30 с."""
    target = 30.0
    rng = np.random.default_rng(10_001)
    n = nsamples(target + 0.5)
    t = timeline(n)
    rumble = lowpass(noise(n, rng, "brown"), 140.0, order=3)
    rumble *= 0.75 + 0.25 * np.sin(TWO_PI * t / 15.25 + 0.4)
    hum = (0.5 * np.sin(TWO_PI * 46.0 * t) + 0.3 * np.sin(TWO_PI * 61.5 * t + 1.1))
    hum *= 0.6 + 0.4 * np.sin(TWO_PI * t / 10.17)
    air = bandpass(noise(n, rng, "pink"), 350.0, 1400.0)
    air *= 0.5 + 0.5 * np.sin(TWO_PI * t / 7.63 + 2.0) ** 2
    raw = 1.0 * rumble / (np.std(rumble) + 1e-9) \
        + 0.18 * hum \
        + 0.12 * air / (np.std(air) + 1e-9)
    return finalize_loop(raw, target, peak=0.7)


def build_torch_crackle() -> np.ndarray:
    """Факел: мягкий гул пламени и щелчки углей. 8 с."""
    target = 8.0
    rng = np.random.default_rng(10_101)
    n = nsamples(target + 0.5)
    t = timeline(n)
    roar = lowpass(noise(n, rng, "pink"), 380.0, order=2)
    roar *= 0.7 + 0.3 * np.sin(TWO_PI * 0.6 * t) * np.sin(TWO_PI * 0.23 * t + 1.0)
    track = 0.35 * roar / (np.std(roar) + 1e-9)
    # Пуассоновский поток щелчков: плотность ~14 в секунду, громкость разная.
    clicks = rng.poisson(14.0 * (target + 0.5))
    for _ in range(clicks):
        dur = rng.uniform(0.004, 0.03)
        m = nsamples(dur)
        lo = rng.uniform(900.0, 2500.0)
        c = bandpass(noise(m, rng), lo, lo * rng.uniform(2.0, 4.0))
        c *= env(m, attack=0.0004, decay=dur * 0.3, curve=1.5)
        gain = rng.uniform(0.15, 1.0) ** 2 * 1.6
        add_at(track, c / (np.max(np.abs(c)) + 1e-9), rng.uniform(0.0, target + 0.45), gain)
    # Редкие «стреляющие» угольки.
    for _ in range(5):
        m = nsamples(0.06)
        pop = highpass(noise(m, rng), 1500.0) * env(m, 0.0005, 0.012, 1.5)
        add_at(track, pop / (np.max(np.abs(pop)) + 1e-9), rng.uniform(0.0, target), 1.8)
    return finalize_loop(track, target, peak=0.75)


# ---------------------------------------------------------------------------
# Капель и одноразовые звуки
# ---------------------------------------------------------------------------

def build_drip(variant: int) -> np.ndarray:
    freq = [1650.0, 1980.0, 1420.0][variant]
    x = np.zeros(nsamples(0.9))
    add_at(x, water_drip(0.4, freq, 10_200 + variant), 0.0)
    return finalize(reverb(x, seconds=0.8, mix=0.3, seed=variant))


def build_drip_distant(variant: int) -> np.ndarray:
    x = np.zeros(nsamples(2.2))
    add_at(x, water_drip(0.4, [1300.0, 1750.0][variant], 10_300 + variant, distant=True), 0.0)
    add_at(x, water_drip(0.4, [1450.0, 1550.0][variant], 10_310 + variant, distant=True),
           [0.55, 0.8][variant], 0.6)
    return finalize(reverb(x, seconds=2.0, mix=0.55, damping=0.7, seed=30 + variant))


def build_rumble(variant: int) -> np.ndarray:
    """Далёкий обвал: низкий нарастающий гул, без атаки."""
    rng = np.random.default_rng(10_400 + variant)
    dur = [4.0, 3.2][variant]
    n = nsamples(dur)
    body = lowpass(noise(n, rng, "brown"), [110.0, 150.0][variant], order=3)
    body *= env(n, attack=dur * 0.3, decay=dur * 0.35, curve=1.6)
    grit = bandpass(noise(n, rng), 200.0, 700.0) * env(n, dur * 0.25, dur * 0.2, 1.4)
    x = body / (np.std(body) + 1e-9) + 0.08 * grit / (np.std(grit) + 1e-9)
    return finalize(reverb(x, seconds=2.5, mix=0.4, damping=0.8, seed=40 + variant),
                    fade_in=0.2, fade_out=0.4)


def build_chain_clink(variant: int) -> np.ndarray:
    """Звенья цепи качнулись: 3–5 лёгких звонов подряд."""
    rng = np.random.default_rng(10_500 + variant)
    x = np.zeros(nsamples(1.6))
    at = 0.0
    for i in range([4, 3][variant]):
        clink = metal_hit(0.35, rng.uniform(820.0, 1250.0), rng, bright=0.8)
        add_at(x, clink, at, rng.uniform(0.4, 1.0) * (0.85 ** i))
        at += rng.uniform(0.09, 0.22)
    x = lowpass(x, 5200.0)
    return finalize(reverb(x, seconds=1.4, mix=0.35, seed=50 + variant))


def build_rat_squeak(variant: int) -> np.ndarray:
    """Крыса: 2–3 писка с быстрым вибрато и шорох коготков."""
    rng = np.random.default_rng(10_600 + variant)
    x = np.zeros(nsamples(1.3))
    at = 0.05
    for _ in range([3, 2][variant]):
        dur = rng.uniform(0.07, 0.14)
        m = nsamples(dur)
        tt = timeline(m)
        f0 = rng.uniform(3200.0, 4200.0)
        freq = f0 * (1.0 + 0.12 * np.sin(TWO_PI * 38.0 * tt)) * (1.0 + 0.25 * tt / dur)
        s = np.sin(TWO_PI * np.cumsum(freq) / SR) + 0.25 * np.sin(2 * TWO_PI * np.cumsum(freq) / SR)
        s *= np.sin(np.pi * tt / dur) ** 1.5
        add_at(x, s, at, rng.uniform(0.6, 1.0))
        at += dur + rng.uniform(0.04, 0.12)
    scratch_n = nsamples(0.4)
    scratch = bandpass(noise(scratch_n, rng), 2500.0, 8000.0)
    taps = np.zeros(scratch_n)
    for k in range(9):
        i = nsamples(k * 0.04 + rng.uniform(0.0, 0.01))
        if i < scratch_n:
            taps[i:i + nsamples(0.006)] = 1.0
    add_at(x, scratch * lowpass(taps, 300.0) * 0.6, at + 0.05)
    return finalize(reverb(x, seconds=0.9, mix=0.3, seed=60 + variant))


def build_stone_fall(variant: int) -> np.ndarray:
    """Камешек сорвался со свода: удар, отскоки, осыпь гравия."""
    rng = np.random.default_rng(10_700 + variant)
    x = np.zeros(nsamples(2.0))
    at = 0.0
    gain = 1.0
    for _ in range([4, 5][variant]):
        hit = thump(0.18, rng.uniform(240.0, 380.0), 90.0, rng, tau=0.05, noise_amt=0.6)
        click_n = nsamples(0.03)
        click = bandpass(noise(click_n, rng), 1500.0, 6000.0) * env(click_n, 0.0005, 0.006)
        add_at(x, hit, at, gain)
        add_at(x, click / (np.max(np.abs(click)) + 1e-9), at, gain * 0.5)
        at += rng.uniform(0.12, 0.3) * gain + 0.05
        gain *= rng.uniform(0.45, 0.7)
    gravel_n = nsamples(0.8)
    gravel = bandpass(noise(gravel_n, rng), 1800.0, 7000.0)
    gravel *= (rng.random(gravel_n) < 0.004) * env(gravel_n, 0.01, 0.25)
    add_at(x, lowpass(gravel, 6000.0), 0.08, 0.7)
    return finalize(reverb(x, seconds=1.8, mix=0.4, seed=70 + variant))


def build_step_water(variant: int) -> np.ndarray:
    """Шаг по луже: глухой тык подошвы, всплеск и пара капель."""
    rng = np.random.default_rng(10_800 + variant)
    x = np.zeros(nsamples(0.45))
    add_at(x, thump(0.12, 160.0, 70.0, rng, tau=0.035, noise_amt=0.5), 0.0, 0.5)
    m = nsamples(0.22)
    splash = bandpass(noise(m, rng), 700.0, 5500.0)
    splash *= env(m, attack=0.004, decay=0.06, curve=1.3)
    # Амплитудная «рябь» превращает шум в плеск, а не в шипение.
    splash *= 0.6 + 0.4 * np.abs(np.sin(TWO_PI * rng.uniform(25.0, 40.0) * timeline(m)))
    add_at(x, splash / (np.max(np.abs(splash)) + 1e-9), 0.01, 0.9)
    for k in range(2):
        add_at(x, water_drip(0.2, rng.uniform(1400.0, 2400.0), 10_820 + variant * 4 + k),
               rng.uniform(0.07, 0.2), 0.25)
    return finalize(x)


# ---------------------------------------------------------------------------
# Шаги из CC0-пака Kenney
# ---------------------------------------------------------------------------

KENNEY_STEPS = {
    # (поверхность, файл пака) — всё из Kenney «Impact Sounds», CC0
    "stone": [f"footstep_concrete_{i:03d}.ogg" for i in range(5)],
    "wood": [f"footstep_wood_{i:03d}.ogg" for i in range(5)],
}


def convert_kenney(ffmpeg: Path, src: Path, dst: Path) -> None:
    """Как в build_audio_samples.py: loudnorm до −14 LUFS, 22050 моно 16 бит."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    args = [str(ffmpeg), "-y", "-loglevel", "error", "-i", str(src),
            "-af", "aresample=48000,aformat=channel_layouts=mono,loudnorm=I=-14:TP=-1.0:LRA=11",
            "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le", str(dst)]
    res = subprocess.run(args, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"{src.name}: {res.stderr.strip()[:400]}")


# ---------------------------------------------------------------------------

SYNTH = {
    "ambience/room_tone.wav": build_room_tone,
    "ambience/torch_crackle.wav": build_torch_crackle,
    **{f"ambience/drip_{i}.wav": (lambda i=i: build_drip(i)) for i in range(3)},
    **{f"oneshots/rumble_distant_{i}.wav": (lambda i=i: build_rumble(i)) for i in range(2)},
    **{f"oneshots/chain_clink_{i}.wav": (lambda i=i: build_chain_clink(i)) for i in range(2)},
    **{f"oneshots/rat_squeak_{i}.wav": (lambda i=i: build_rat_squeak(i)) for i in range(2)},
    **{f"oneshots/stone_fall_{i}.wav": (lambda i=i: build_stone_fall(i)) for i in range(2)},
    **{f"oneshots/drip_distant_{i}.wav": (lambda i=i: build_drip_distant(i)) for i in range(2)},
    **{f"footsteps/step_water_{i}.wav": (lambda i=i: build_step_water(i)) for i in range(4)},
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tools", type=Path, default=BASE / "tools",
                    help="каталог tools с cc0/ и ffmpeg/ (в git их нет)")
    args = ap.parse_args()

    for rel, builder in SYNTH.items():
        x = sanitize(builder())
        if float(np.max(np.abs(x))) > 0.89 or x.size == 0:
            raise RuntimeError(f"{rel}: пустой сигнал или пик выше 0.89")
        save_wav(OUT / rel, x)
        print(f"[synth] {rel}  {x.size / SR:.2f} с")

    ffmpeg = args.tools / "ffmpeg" / "ffmpeg-9.0.2-essentials_build" / "bin" / "ffmpeg.exe"
    impact = args.tools / "cc0" / "impact" / "Audio"
    if not ffmpeg.exists() or not impact.exists():
        print(f"[kenney] нет {ffmpeg} или {impact}: шаги stone/wood не пересобраны",
              file=sys.stderr)
        return 1
    for surface, files in KENNEY_STEPS.items():
        for i, name in enumerate(files):
            rel = f"footsteps/step_{surface}_{i}.wav"
            convert_kenney(ffmpeg, impact / name, OUT / rel)
            print(f"[kenney] {rel} <- {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
