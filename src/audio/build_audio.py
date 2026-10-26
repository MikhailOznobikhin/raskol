#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Процедурный генератор звуковых ассетов для игры
«Кровавая магия и Раскол».

Всё синтезируется детерминированно: numpy + только стандартная библиотека
(mainly wave/pathlib/math). Никаких сэмплов и скачиваний.

Запуск:
    python src/audio/build_audio.py

На выходе: assets/audio/*.wav, 22050 Гц, 16 бит, моно.
После генерации скрипт сам проверяет длительность, пик, формат и NaN.

Акустический почерк:
  * низкий каменный гул и железо;
  * мягкие атаки у «живых» звуков;
  * свёрточная реверберация с затухающим шумовым импульсом;
  * все одноразовые эффекты с фейдами по краям;
  * лупы склеены 0.5-секундным кроссфейдом с «запасным» продолжением.
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------------------
# Глобальные параметры
# ---------------------------------------------------------------------------

SR = 22_050                 # частота дискретизации
TWO_PI = 2.0 * math.pi
PEAK_TARGET = 0.84          # верхняя граница громкости большинства ассетов
PEAK_SAFE = 0.89            # жёсткий потолок из ТЗ
LOOP_XFADE = 0.5            # длина кроссфейда лупов, секунды

BASE_DIR = Path(__file__).resolve().parents[2]
OUT_DIR = BASE_DIR / "assets" / "audio"

# Фиксированные зёрна — от них зависит вся процедурная «случайность».
SEEDS = {
    "amb_prison": 1101,
    "music_menu": 2202,
    "music_boss": 3303,
    "step_1": 4101,
    "step_2": 4102,
    "step_3": 4103,
    "swing": 4201,
    "hit": 4301,
    "hit_heavy": 4302,
    "cast": 4401,
    "absorb": 4402,
    "alert": 4501,
    "chain": 4601,
    "door": 4602,
    "click": 4701,
    "heartbeat": 4801,
    "boss_roar": 4901,
    "death": 5001,
    "trust": 5101,
    "lowmagic": 5201,
    "win": 5301,
    "gate_open": 5401,
}


# ---------------------------------------------------------------------------
# Базовые утилиты
# ---------------------------------------------------------------------------

def nsamples(duration: float) -> int:
    """Перевод секунд в число отсчётов (округление, не меньше одного)."""
    return max(1, int(round(float(duration) * SR)))


def timeline(n: int) -> np.ndarray:
    """Временная ось в секундах для массива из n отсчётов."""
    return np.arange(n, dtype=np.float64) / SR


def rms(x: np.ndarray) -> float:
    """Корень из среднего квадрата — для аккуратного баланса слоёв."""
    if x.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(np.square(x, dtype=np.float64)) + 1e-20))


def sanitize(x: np.ndarray) -> np.ndarray:
    """Убираем NaN/Inf и приводим к float64 — страховка перед записью."""
    x = np.asarray(x, dtype=np.float64)
    if not np.isfinite(x).all():
        x = np.nan_to_num(x, nan=0.0, posinf=0.0, neginf=0.0)
    return x


def normalize_peak(x: np.ndarray, peak: float = PEAK_TARGET) -> np.ndarray:
    """Нормировка по пику. Значение peak всегда ниже 0.89."""
    x = sanitize(x)
    m = float(np.max(np.abs(x))) if x.size else 0.0
    if m < 1e-12:
        return x
    return x * (min(peak, PEAK_SAFE) / m)


def env(n: int, attack: float = 0.003, decay: float = 0.08,
        curve: float = 1.0) -> np.ndarray:
    """
    Простая одноразовая огибающая: короткая атака + экспоненциальный спад.
    Подходит для щелчков, капель, ударов и шумовых всплесков.
    """
    n = max(1, int(n))
    a = max(1, min(n, nsamples(max(0.0005, attack))))
    t = timeline(n)
    e = np.exp(-t / max(0.0005, decay))
    e[:a] *= np.linspace(0.0, 1.0, a, dtype=np.float64) ** max(0.1, curve)
    return e


def adsr(n: int, attack: float, decay: float, sustain: float,
         release: float, curve: float = 2.0) -> np.ndarray:
    """
    Классическая ADSR-огибающая. Если сумма времени больше длительности,
    все стадии пропорционально сжимаются — кликов на границах не возникает.
    """
    n = max(1, int(n))
    a = nsamples(attack)
    d = nsamples(decay)
    r = nsamples(release)
    total = a + d + r
    if total > n:
        k = n / float(total + 1)
        a = max(1, int(a * k))
        d = max(0, int(d * k))
        r = max(1, int(r * k))
        if a + d + r > n:
            a = max(1, n - d - r)
    sustain = float(np.clip(sustain, 0.0, 1.0))
    e = np.full(n, sustain, dtype=np.float64)

    if a > 0:
        e[:a] = np.linspace(0.0, 1.0, a, dtype=np.float64) ** max(0.1, curve)
    if d > 0:
        k = min(d, n - a)
        if k > 0:
            e[a:a + k] = 1.0 + (sustain - 1.0) * (
                np.linspace(0.0, 1.0, k, dtype=np.float64) ** 1.4
            )
    if r > 0:
        rr = min(r, n)
        e[n - rr:] *= (
            np.linspace(1.0, 0.0, rr, dtype=np.float64) ** max(0.1, curve)
        )
    return np.clip(e, 0.0, 1.0)


def noise(n: int, rng: np.random.Generator, color: str = "white") -> np.ndarray:
    """
    Генератор шума: white / pink / brown.
    Цветной шум делается умножением спектра на 1/f^slope (без scipy).
    """
    n = max(1, int(n))
    x = rng.standard_normal(n)
    if color == "white":
        return x
    slopes = {"pink": 0.5, "brown": 1.0}
    slope = slopes.get(color, 0.0)
    if slope <= 0.0:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1] if len(f) > 1 else 1.0
    spec /= np.power(f, slope)
    spec[0] = 0.0
    y = np.fft.irfft(spec, n)
    s = float(np.std(y))
    return y / (s + 1e-12) if s > 1e-12 else y


def _fft_filter(x: np.ndarray, magnitude) -> np.ndarray:
    """
    Нулевой фазы FFT-фильтр по заданной АЧХ.
    Небольшой reflect-padding убирает заворачивание краёв.
    """
    x = sanitize(x)
    n = x.size
    if n < 16:
        return x.copy()
    pad = min(4096, max(16, n // 8))
    xp = np.pad(x, (pad, pad), mode="reflect")
    spec = np.fft.rfft(xp)
    freqs = np.fft.rfftfreq(xp.size, 1.0 / SR)
    spec *= magnitude(freqs)
    y = np.fft.irfft(spec, xp.size)
    return y[pad:pad + n]


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    """Мягкий low-pass Баттерворта в частотной области (без scipy)."""
    fc = float(np.clip(cutoff, 20.0, SR * 0.49))

    def mag(f: np.ndarray) -> np.ndarray:
        return 1.0 / np.sqrt(1.0 + np.power(f / fc, 2 * max(1, order)))

    return _fft_filter(x, mag)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    """Симметричный high-pass, чтобы убрать DC и инфразвуковой мусор."""
    fc = float(np.clip(cutoff, 10.0, SR * 0.45))

    def mag(f: np.ndarray) -> np.ndarray:
        ff = np.maximum(f, 1e-6)
        return 1.0 / np.sqrt(1.0 + np.power(fc / ff, 2 * max(1, order)))

    return _fft_filter(x, mag)


def bandpass(x: np.ndarray, low: float, high: float,
             order: int = 2) -> np.ndarray:
    """Полосовой фильтр как произведение low-pass и high-pass АЧХ."""
    lo = float(np.clip(low, 15.0, SR * 0.48))
    hi = float(np.clip(max(high, lo * 1.05), lo * 1.05, SR * 0.49))

    def mag(f: np.ndarray) -> np.ndarray:
        ff = np.maximum(f, 1e-6)
        hp = 1.0 / np.sqrt(1.0 + np.power(lo / ff, 2 * max(1, order)))
        lp = 1.0 / np.sqrt(1.0 + np.power(f / hi, 2 * max(1, order)))
        return hp * lp

    return _fft_filter(x, mag)


def fft_convolve(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    """Быстрая свёртка через БПФ — для реверберации и длинных импульсов."""
    x = sanitize(x)
    h = sanitize(h)
    n = x.size + h.size - 1
    size = 1 << int(np.ceil(np.log2(max(2, n))))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)
    return y[:n]


def reverb(x: np.ndarray, seconds: float = 2.0, mix: float = 0.3,
           predelay: float = 0.025, damping: float = 0.55,
           seed: int = 0) -> np.ndarray:
    """
    Свёрточная реверберация с затухающим шумовым импульсом.
    В импульс добавлены ранние отражения; АЧХ хвоста приглушена.
    Возвращает сигнал той же длины, что и вход.
    """
    x = sanitize(x)
    n = x.size
    if seconds <= 0.01 or mix <= 0.0:
        return x.copy()

    rng = np.random.default_rng(int(seed) ^ 0x5EED)
    n_ir = nsamples(seconds)
    t = timeline(n_ir)
    ir = rng.standard_normal(n_ir) * np.exp(-6.9 * t / max(0.05, seconds))
    ir = lowpass(ir, 6200.0 - 4400.0 * float(np.clip(damping, 0.0, 1.0)),
                 order=2)

    # Несколько ранних отражений делают помещение «каменным», а не «облаком».
    early = [(0.009, 0.65), (0.017, -0.42), (0.028, 0.33),
             (0.041, 0.24), (0.063, -0.16), (0.089, 0.11)]
    for delay, gain in early:
        idx = int(delay * SR)
        if idx < n_ir:
            ir[idx] += gain * (0.5 + 0.5 * abs(rng.standard_normal()))

    ir -= float(np.mean(ir))
    ir /= math.sqrt(float(np.sum(ir * ir)) + 1e-18)

    pd = nsamples(max(0.0, predelay))
    if pd > 0:
        ir = np.concatenate((np.zeros(pd, dtype=np.float64), ir))

    wet = fft_convolve(x, ir)[:n]
    wet *= rms(x) / (rms(wet) + 1e-12)
    wet = highpass(wet, 35.0, order=2)
    mix = float(np.clip(mix, 0.0, 1.0))
    return (1.0 - mix) * x + mix * wet


def mix(*parts: np.ndarray) -> np.ndarray:
    """Сложение слоёв разной длины с выравниванием по самому длинному."""
    arrays = [np.asarray(p, dtype=np.float64) for p in parts if p is not None]
    if not arrays:
        return np.zeros(0, dtype=np.float64)
    n = max(a.size for a in arrays)
    out = np.zeros(n, dtype=np.float64)
    for p in arrays:
        out[:p.size] += p
    return out


def fade_edges(x: np.ndarray, fade_in: float = 0.008,
               fade_out: float = 0.012) -> np.ndarray:
    """Косинусные фейды 5–15 мс — против щелчков на краях файла."""
    x = sanitize(x).copy()
    n = x.size
    if n < 4:
        return x
    a = min(n, nsamples(max(0.0, fade_in)))
    b = min(n, nsamples(max(0.0, fade_out)))
    if a > 0:
        x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0.0, math.pi, a))
    if b > 0:
        x[n - b:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, math.pi, b))
    return x


def seamless_loop(signal: np.ndarray, target: float,
                  xfade: float = LOOP_XFADE) -> np.ndarray:
    """
    Бесшовная петля.

    В сигнале уже есть target + 0.5 с. Хвост-продолжение после точки петли
    плавно вводится в самое начало, а «стартовый» материал плавно уходит:
    на стыке конец файла и первый отсчёт являются соседними отсчётами
    одного и того же процесса, поэтому щелчка нет.

    Это и есть требуемый кроссфейд последних 0.5 с с началом.
    """
    n = nsamples(target)
    k = nsamples(xfade)
    if signal.size < n + k:
        raise ValueError("Для бесшовной петли нужен запас 0.5 с")
    out = sanitize(signal[:n]).copy()
    tail = sanitize(signal[n:n + k])
    if k > 1:
        # Equal-power: сумма квадратов весов постоянна.
        u = np.linspace(0.0, 0.5 * math.pi, k, dtype=np.float64)
        w_tail = np.cos(u) ** 2
        w_head = np.sin(u) ** 2
        out[:k] = tail * w_tail + out[:k] * w_head
    return out


def finalize(x: np.ndarray, peak: float = PEAK_TARGET,
             fade_in: float = 0.008, fade_out: float = 0.012,
             highpass_hz: float = 25.0) -> np.ndarray:
    """Финальная обработка одноразового SFX: DC, края, нормировка."""
    x = sanitize(x)
    if highpass_hz > 0:
        x = highpass(x, highpass_hz, order=2)
    x = x - float(np.mean(x))
    x = fade_edges(x, fade_in, fade_out)
    x = normalize_peak(x, peak)
    assert np.isfinite(x).all(), "NaN/Inf в готовом сигнале"
    return x


def finalize_loop(raw: np.ndarray, target: float, peak: float = 0.8,
                  xfade: float = LOOP_XFADE) -> np.ndarray:
    """Финальная обработка лупа: без краевых фейдов, только кроссфейд."""
    x = sanitize(raw).copy()
    x = x - float(np.mean(x))
    x = highpass(x, 20.0, order=2)
    x = seamless_loop(x, target, xfade)
    x = normalize_peak(x, peak)
    assert np.isfinite(x).all(), "NaN/Inf в готовом лупе"
    return x


def add_at(track: np.ndarray, sig: np.ndarray, start: float,
           gain: float = 1.0) -> None:
    """Добавление локального события в общий трек с обрезкой по длине."""
    i = int(round(start * SR))
    if i >= track.size or i < 0:
        return
    s = sanitize(sig) * float(gain)
    k = min(s.size, track.size - i)
    track[i:i + k] += s[:k]


def save_wav(path: Path, x: np.ndarray) -> None:
    """Запись моно WAV 22050 Гц / 16 бит без клиппинга."""
    x = sanitize(x)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.rint(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(data.tobytes())


# ---------------------------------------------------------------------------
# Простые «инструменты»
# ---------------------------------------------------------------------------

def pitch_sweep(n: int, f0: float, f1: float, tau: float = 0.03,
                phase0: float = 0.0) -> np.ndarray:
    """
    Синус с плавным экспоненциальным глиссандо f0 -> f1.
    Интегрируем частоту, поэтому фаза не «дёргается».
    """
    t = timeline(n)
    freq = f1 + (f0 - f1) * np.exp(-t / max(0.003, tau))
    phase = TWO_PI * np.cumsum(freq) / SR + phase0
    return np.sin(phase)


def saw_additive(freq: float, n: int, rng: np.random.Generator,
                 cutoff, amp: float = 1.0,
                 detunes=(-6.0, 0.0, 6.0),
                 max_harm: int = 24,
                 vib_hz: float = 0.13, vib_cents: float = 3.0) -> np.ndarray:
    """
    Пилообразный «струнный» голос из суммы гармоник.
    cutoff может быть числом или массивом — тогда тембр плавно раскрывается.

    Сумма 1/h с АЧХ low-pass даёт мягкий аналоговый саунд без алиасинга.
    """
    n = max(1, int(n))
    t = timeline(n)
    cutoff_arr = None if np.isscalar(cutoff) else np.asarray(cutoff, dtype=np.float64)
    cutoff_scalar = float(cutoff) if np.isscalar(cutoff) else 0.0

    out = np.zeros(n, dtype=np.float64)
    for det in detunes:
        f = float(freq) * (2.0 ** (float(det) / 1200.0))
        # Медленное вибрато + случайная начальная фаза для каждого голоса.
        fm = f * (1.0 + (vib_cents / 1200.0) *
                  np.sin(TWO_PI * vib_hz * t + rng.uniform(0, TWO_PI)))
        base = TWO_PI * np.cumsum(fm) / SR
        hmax = min(int(max_harm), int(SR * 0.45 / max(20.0, f)))
        for h in range(1, hmax + 1):
            fh = h * f
            if fh >= SR * 0.47:
                break
            if cutoff_arr is None:
                w = 1.0 / math.sqrt(1.0 + (fh / max(30.0, cutoff_scalar)) ** 4.0)
            else:
                w = 1.0 / np.sqrt(1.0 + (fh / np.maximum(30.0, cutoff_arr)) ** 4.0)
            ph = rng.uniform(0, TWO_PI)
            out += (amp / (h ** 1.05)) * w * np.sin(h * base + ph)
    return out


def metal_hit(dur: float, base: float, rng: np.random.Generator,
              amp: float = 1.0, bright: float = 1.0) -> np.ndarray:
    """
    Металлический удар: негармонические моды + короткий шумовой транзиент.
    """
    n = nsamples(dur)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)
    ratios = [1.0, 2.71, 4.05, 5.43, 7.12, 8.91]
    for i, ratio in enumerate(ratios):
        fr = base * ratio * (1.0 + rng.uniform(-0.012, 0.012))
        if fr > SR * 0.46:
            continue
        tau = max(0.012, dur * (0.42 - 0.05 * i))
        a = (0.9 / (1.0 + 0.55 * i)) * (bright ** (0.5 * i))
        out += a * np.sin(TWO_PI * fr * t + rng.uniform(0, TWO_PI)) * np.exp(-t / tau)

    nz = bandpass(noise(n, rng), 900.0, min(9000.0, SR * 0.47))
    nz *= env(n, attack=0.0012, decay=max(0.008, dur * 0.08), curve=1.6)
    out += 0.38 * nz
    out *= env(n, attack=0.001, decay=max(0.03, dur * 0.55), curve=1.0)
    return normalize_peak(out, 1.0) * amp


def thump(dur: float, f0: float, f1: float, rng: np.random.Generator,
          tau: float = 0.1, noise_amt: float = 0.35) -> np.ndarray:
    """Низкий «тук»: падающий синус + мягкий низкочастотный шум."""
    n = nsamples(dur)
    body = pitch_sweep(n, f0, f1, tau=max(0.012, tau * 0.45))
    body *= env(n, attack=0.0015, decay=tau, curve=1.2)
    nz = lowpass(noise(n, rng, "brown"), 420.0, order=2)
    nz *= env(n, attack=0.0015, decay=tau * 0.7, curve=1.2)
    return normalize_peak(body + noise_amt * nz, 1.0)


def water_drip(dur: float, freq: float, seed: int,
               distant: bool = False) -> np.ndarray:
    """
    Капля воды: короткий «плинк» с падающей частотой, каплей-резонансом
    и крошечным шумовым щелчком.
    """
    rng = np.random.default_rng(seed)
    n = nsamples(dur)
    t = timeline(n)
    f = freq * (1.0 + 0.55 * np.exp(-t / 0.011))
    body = np.sin(TWO_PI * np.cumsum(f) / SR + rng.uniform(0, 0.4))
    body *= env(n, attack=0.0015, decay=0.045, curve=1.2)

    # Вторая мода — «полость» под каплей.
    f2 = freq * 0.42
    body += 0.35 * np.sin(TWO_PI * f2 * t + 0.7) * env(
        n, attack=0.002, decay=0.075, curve=1.0)

    tick = bandpass(noise(n, rng), 1200.0, 7500.0)
    tick *= env(n, attack=0.0008, decay=0.007, curve=2.0)
    out = body + 0.30 * tick
    if distant:
        out = lowpass(out, 1900.0, order=2)
    return normalize_peak(out, 1.0)


# ---------------------------------------------------------------------------
# ЛУП 1: атмосфера подземной тюрьмы-шахты (45 с)
# ---------------------------------------------------------------------------

def build_amb_prison() -> np.ndarray:
    """45 с: гул 48–55 Гц, ветер, 4 капли, 2 далёких металла."""
    target = 45.0
    raw_n = nsamples(target + LOOP_XFADE)
    t = timeline(raw_n)
    rng = np.random.default_rng(SEEDS["amb_prison"])
    track = np.zeros(raw_n, dtype=np.float64)

    # --- Низкий каменный гул: близкие частоты дают медленное биение. ---
    beat_slow = 0.5 + 0.5 * np.sin(TWO_PI * 0.043 * t + 0.4)
    beat_slower = 0.5 + 0.5 * np.sin(TWO_PI * 0.027 * t + 2.1)
    rumble = (
        0.55 * np.sin(TWO_PI * 48.6 * t + 0.2) +
        0.43 * np.sin(TWO_PI * 49.15 * t + 2.0) +
        0.23 * np.sin(TWO_PI * 54.2 * t + 4.4) * beat_slow +
        0.16 * np.sin(TWO_PI * 97.3 * t + 1.2) * beat_slower
    )
    rumble *= 0.72 + 0.28 * (0.5 + 0.5 * np.sin(TWO_PI * 0.019 * t - 0.9))
    stone = lowpass(noise(raw_n, rng, "brown"), 105.0, order=3)
    stone *= 0.34 + 0.16 * (0.5 + 0.5 * np.sin(TWO_PI * 0.031 * t + 1.7))
    track += rumble + 0.9 * stone

    # --- Ветер в шахте: два слоя, очень медленная динамика. ---
    wind_raw = noise(raw_n, rng, "pink")
    wind_low = bandpass(wind_raw, 130.0, 900.0, order=2)
    wind_air = bandpass(noise(raw_n, rng, "white"), 900.0, 3600.0, order=2)
    gust = (0.5 + 0.5 * np.sin(TWO_PI * 0.031 * t + 1.2))
    gust *= (0.55 + 0.45 * (0.5 + 0.5 * np.sin(TWO_PI * 0.011 * t - 0.6)))
    tunnel = lowpass(noise(raw_n, rng, "brown"), 260.0, order=2)
    wind = 0.13 * wind_low * (0.35 + 0.65 * gust)
    wind += 0.055 * wind_air * (0.25 + 0.75 * gust ** 2)
    wind += 0.10 * tunnel * (0.3 + 0.7 * (0.5 + 0.5 * np.sin(TWO_PI * 0.017 * t + 2.4)))
    track += wind

    # --- Редкие капли с ревербом 1.2–1.4 с. ---
    drip_times = [6.2, 17.8, 28.9, 39.6]
    drip_freqs = [1180.0, 860.0, 1420.0, 980.0]
    for i, (st, fr) in enumerate(zip(drip_times, drip_freqs)):
        drop = water_drip(0.42, fr, SEEDS["amb_prison"] + 20 + i, distant=True)
        drop = reverb(drop, seconds=1.15 + 0.1 * (i % 2), mix=0.62,
                      predelay=0.018, damping=0.75,
                      seed=SEEDS["amb_prison"] + 30 + i)
        add_at(track, drop, st, gain=0.23 if i % 2 == 0 else 0.18)

    # --- Далёкий металл: скрип (1) и лязг (2), тихо. ---
    creak_t = 20.6
    n = nsamples(1.6)
    tt = timeline(n)
    creak_rng = np.random.default_rng(SEEDS["amb_prison"] + 40)
    f_creak = 105.0 + 28.0 * np.sin(TWO_PI * 0.7 * tt) + 8.0 * np.sin(TWO_PI * 1.9 * tt)
    creak = np.sin(TWO_PI * np.cumsum(f_creak) / SR)
    creak *= 0.55 + 0.45 * np.sin(TWO_PI * 8.0 * tt) ** 2
    creak += 0.4 * bandpass(noise(n, creak_rng), 280.0, 2400.0)
    creak *= adsr(n, 0.10, 0.35, 0.55, 0.65)
    creak = reverb(creak, seconds=1.6, mix=0.55, predelay=0.03,
                   damping=0.65, seed=SEEDS["amb_prison"] + 41)
    add_at(track, creak, creak_t, gain=0.12)

    clang = metal_hit(1.4, 155.0, rng, amp=1.0, bright=0.65)
    clang = reverb(clang, seconds=1.7, mix=0.55, predelay=0.035,
                   damping=0.7, seed=SEEDS["amb_prison"] + 42)
    add_at(track, clang, 35.1, gain=0.105)

    # Небольшая компрессия мягким tanh и финальная нормировка.
    track = np.tanh(track * 1.05) / np.tanh(1.05)
    track = reverb(track, seconds=0.65, mix=0.12, predelay=0.01,
                   damping=0.8, seed=SEEDS["amb_prison"] + 50)
    return finalize_loop(track, target, peak=0.60)


# ---------------------------------------------------------------------------
# ЛУП 2: мрачная тема меню (64 с)
# ---------------------------------------------------------------------------

def build_music_menu() -> np.ndarray:
    """64 с: Dm–Bb–F–C, низкие струнные пэды, виолончельный мотив и колокол."""
    target = 64.0
    raw_n = nsamples(target + LOOP_XFADE)
    rng = np.random.default_rng(SEEDS["music_menu"])
    track = np.zeros(raw_n, dtype=np.float64)
    chord_seconds = 8.0

    # Ноты в удобной для струнных тесситуре (частоты, Гц).
    chords = [
        [73.42, 110.00, 146.83, 174.61, 220.00],   # Dm
        [58.27, 87.31, 116.54, 146.83, 174.61],    # Bb
        [87.31, 130.81, 174.61, 220.00, 261.63],   # F
        [65.41, 98.00, 130.81, 164.81, 196.00],    # C
    ]
    roots = [73.42, 58.27, 87.31, 65.41]

    # 8 полных тактов + начало девятого: запас уходит в кроссфейд петли.
    for slot in range(9):
        start = slot * chord_seconds
        if start >= target + LOOP_XFADE - 0.02:
            break
        chord = chords[slot % 4]
        root = roots[slot % 4]
        local_len = min(10.6, target + LOOP_XFADE - start)
        if local_len < 0.05:
            continue
        n = nsamples(local_len)
        lrng = np.random.default_rng(SEEDS["music_menu"] + 100 + slot)

        # --- Низкая виолончельная «педаль» и основной тон. ---
        bass = 0.0
        bass += 0.50 * np.sin(TWO_PI * root * timeline(n) + 0.3)
        bass += 0.20 * np.sin(TWO_PI * (root * 0.5) * timeline(n) + 1.1)
        bass *= adsr(n, 1.4, 1.2, 0.72, 2.2, curve=2.0)
        add_at(track, bass, start, gain=0.42)

        # --- Пэды: 5 голосов, 3 расстроенных пилы, мягкая атака. ---
        for vi, fr in enumerate(chord):
            # Тембр чуть раскрывается к середине аккорда и снова темнеет.
            u = np.linspace(0.0, 1.0, n)
            cutoff = 520.0 + 430.0 * np.sin(np.pi * u) ** 1.5
            voice = saw_additive(
                fr, n, lrng, cutoff=cutoff, amp=0.22,
                detunes=(-5.0, 4.0), max_harm=20,
                vib_hz=0.09 + 0.02 * vi, vib_cents=2.4,
            )
            voice *= adsr(n, 1.35 + 0.12 * vi, 1.3, 0.68, 2.0, curve=2.2)
            add_at(track, voice, start, gain=0.34)

        # --- Очень тихий воздушный слой на октаву выше. ---
        air_fr = chord[-1] * 2.0
        air = saw_additive(air_fr, n, lrng, cutoff=1500.0, amp=0.10,
                           detunes=(-7.0, 7.0), max_harm=12,
                           vib_hz=0.13, vib_cents=4.0)
        air *= adsr(n, 2.2, 1.4, 0.52, 2.4, curve=2.0)
        add_at(track, air, start, gain=0.08)

    # --- Спарсенный мотив низкой виолончели. ---
    motif = [
        (2.6, 146.83, 2.8), (10.4, 174.61, 2.8),
        (18.3, 220.00, 2.6), (26.4, 196.00, 2.9),
        (34.6, 146.83, 2.8), (42.3, 174.61, 2.8),
        (50.2, 220.00, 2.6), (58.2, 196.00, 3.0),
    ]
    for i, (st, fr, dur) in enumerate(motif):
        n = nsamples(dur)
        mrng = np.random.default_rng(SEEDS["music_menu"] + 300 + i)
        cello = saw_additive(
            fr, n, mrng, cutoff=1150.0, amp=0.42,
            detunes=(-4.0, 5.0), max_harm=18,
            vib_hz=3.3, vib_cents=6.0,
        )
        cello *= adsr(n, 0.28, 0.5, 0.62, 1.45, curve=2.0)
        add_at(track, cello, st, gain=0.20)

    # --- Редкие колокольчики: 4 события за 64 с. ---
    bell_events = [
        (14.4, 587.33), (30.4, 698.46),
        (46.4, 880.00), (62.2, 1174.66),
    ]
    for i, (st, fr) in enumerate(bell_events):
        dur = 5.0
        n = nsamples(dur)
        brng = np.random.default_rng(SEEDS["music_menu"] + 500 + i)
        tbl = timeline(n)
        bell = np.zeros(n, dtype=np.float64)
        partials = [1.0, 2.01, 3.01, 4.17, 5.43, 7.03]
        base_decay = 1.5
        for j, p in enumerate(partials):
            f = fr * p
            if f >= SR * 0.45:
                continue
            a = 0.55 / (1.0 + 0.75 * j)
            tau = base_decay / (1.0 + 0.48 * j)
            bell += a * np.sin(TWO_PI * f * tbl + brng.uniform(0, TWO_PI)) * np.exp(
                -tbl / tau)
        bell *= env(n, attack=0.025, decay=2.4, curve=1.0)
        bell = reverb(bell, seconds=3.4, mix=0.48, predelay=0.04,
                      damping=0.45, seed=SEEDS["music_menu"] + 520 + i)
        add_at(track, bell, st, gain=0.085)

    # --- Глубокая каменная реверберация всей темы. ---
    track = reverb(track, seconds=3.8, mix=0.44, predelay=0.045,
                   damping=0.52, seed=SEEDS["music_menu"] + 900)
    # Лёгкая «аналоговая» компрессия, чтобы тема не была рыхлой.
    track = np.tanh(track * 1.15) / np.tanh(1.15)
    return finalize_loop(track, target, peak=0.76)


# ---------------------------------------------------------------------------
# ЛУП 3: боевая тема босса (48 с)
# ---------------------------------------------------------------------------

def boss_drum(dur: float, f0: float, f1: float, seed: int,
              heavy: bool = False) -> np.ndarray:
    """Боевой барабан: низкий удар + кожа/металлическая атака."""
    rng = np.random.default_rng(seed)
    n = nsamples(dur)
    t = timeline(n)
    body = pitch_sweep(n, f0, f1, tau=0.055)
    body *= env(n, attack=0.0012, decay=0.13 if heavy else 0.09, curve=1.0)
    head = lowpass(noise(n, rng), 1400.0 if heavy else 2200.0, order=2)
    head *= env(n, attack=0.0008, decay=0.018, curve=2.0)
    skin = np.sin(TWO_PI * (f1 * 1.55) * t) * env(n, attack=0.002, decay=0.075)
    out = body + (0.50 if heavy else 0.36) * head + 0.30 * skin
    return normalize_peak(out, 1.0)


def build_music_boss() -> np.ndarray:
    """48 с: 100 BPM, низкий дрон, тритоны, военные барабаны и металл."""
    target = 48.0
    raw_n = nsamples(target + LOOP_XFADE)
    t = timeline(raw_n)
    rng = np.random.default_rng(SEEDS["music_boss"])
    track = np.zeros(raw_n, dtype=np.float64)
    beat = 60.0 / 100.0          # 0.6 с
    bar = 4.0 * beat             # 2.4 с

    # --- Дрон D + A: низкий, с медленным биением. ---
    drone = np.zeros(raw_n, dtype=np.float64)
    drone += 0.55 * np.sin(TWO_PI * 36.71 * t + 0.1)
    drone += 0.32 * np.sin(TWO_PI * 36.93 * t + 2.3)
    drone += 0.24 * np.sin(TWO_PI * 55.00 * t + 1.2)
    drone += 0.20 * np.sin(TWO_PI * 73.42 * t + 4.0)
    drone *= 0.78 + 0.22 * (0.5 + 0.5 * np.sin(TWO_PI * 0.09 * t))
    drone += 0.16 * lowpass(noise(raw_n, rng, "brown"), 130.0, order=2)
    track += drone * 0.36

    # --- Диссонансная «тень»: малая секунда + тритон, растёт к финалу. ---
    tension_env = np.clip(t / target, 0.0, 1.0) ** 1.7
    tension = saw_additive(
        146.83, raw_n, rng, cutoff=420.0 + 260.0 * tension_env,
        amp=0.14, detunes=(-8.0, 8.0), max_harm=12,
        vib_hz=0.06, vib_cents=2.0,
    )
    tension += saw_additive(
        155.56, raw_n, rng, cutoff=380.0 + 220.0 * tension_env,
        amp=0.10, detunes=(-6.0, 5.0), max_harm=12,
        vib_hz=0.07, vib_cents=3.0,
    )
    tension += 0.07 * np.sin(TWO_PI * 103.83 * t) * (0.5 + 0.5 * np.sin(TWO_PI * 0.21 * t))
    tension *= 0.15 + 0.85 * tension_env
    track += tension * 0.25

    # --- Ритмическая сетка. ---
    drum_times = []
    for b in range(20):
        base = b * bar
        if b == 0:
            drum_times += [(base, 1.0)]
        elif b < 4:
            drum_times += [(base, 0.9), (base + 2 * beat, 0.55)]
        elif b < 8:
            drum_times += [
                (base, 1.0), (base + 1.5 * beat, 0.42),
                (base + 2 * beat, 0.8), (base + 3.5 * beat, 0.45),
            ]
        elif b < 12:
            drum_times += [
                (base, 1.0), (base + 0.75 * beat, 0.45),
                (base + 1.5 * beat, 0.68), (base + 2.0 * beat, 0.8),
                (base + 2.75 * beat, 0.48), (base + 3.25 * beat, 0.70),
            ]
        elif b < 16:
            for e in range(8):
                tt = base + e * beat * 0.5
                amp = 0.42 + 0.10 * (e % 2) + (0.18 if e in (0, 4) else 0.0)
                drum_times.append((tt, amp))
        else:
            for e in range(8):
                tt = base + e * beat * 0.5
                drum_times.append((tt, 0.48 + (0.22 if e in (0, 4) else 0.0)))
            for e in range(16):
                tt = base + e * beat * 0.25
                drum_times.append((tt, 0.22))
    for i, (st, amp) in enumerate(drum_times):
        if st >= target + LOOP_XFADE:
            continue
        heavy = (i % 5 == 0)
        d = boss_drum(0.42 if heavy else 0.30,
                      105.0 if heavy else 88.0,
                      42.0 if heavy else 50.0,
                      SEEDS["music_boss"] + 1000 + i,
                      heavy=heavy)
        d = reverb(d, seconds=0.7, mix=0.20, predelay=0.01,
                   damping=0.55, seed=SEEDS["music_boss"] + 1500 + i)
        add_at(track, d, st, gain=0.42 * amp)

    # --- Металлические удары: редкие, но с длинным хвостом. ---
    metal_beats = []
    for b in range(20):
        base = b * bar
        if b < 4:
            metal_beats.append((base + 2.0 * beat, 0.30))
        elif b < 8:
            metal_beats += [(base + 1.0 * beat, 0.34), (base + 3.0 * beat, 0.30)]
        elif b < 16:
            metal_beats += [(base, 0.36), (base + 2.0 * beat, 0.30)]
        else:
            metal_beats += [(base, 0.42), (base + 1.5 * beat, 0.30),
                            (base + 3.0 * beat, 0.38)]
    for i, (st, amp) in enumerate(metal_beats):
        if st >= target + LOOP_XFADE:
            continue
        base_f = [233.0, 311.0, 370.0, 466.0][i % 4]
        clang = metal_hit(0.95, base_f, rng, amp=1.0, bright=0.85)
        clang = reverb(clang, seconds=1.5, mix=0.34, predelay=0.02,
                       damping=0.50, seed=SEEDS["music_boss"] + 2000 + i)
        add_at(track, clang, st, gain=0.115 * amp)

    # --- Рифф: короткие жёсткие стабы, тритоны и малая секунда. ---
    riff = [(0.0, 73.42), (0.75, 73.42), (1.5, 77.78),
            (2.0, 73.42), (2.75, 103.83), (3.25, 110.00)]
    for b in range(8, 20):
        base = b * bar
        for j, (off, fr) in enumerate(riff):
            st = base + off
            if st >= target + LOOP_XFADE:
                continue
            n = nsamples(0.30)
            srng = np.random.default_rng(SEEDS["music_boss"] + 3000 + b * 10 + j)
            u = np.linspace(0.0, 1.0, n)
            cutoff = 1700.0 - 850.0 * u ** 0.7
            stab = saw_additive(fr, n, srng, cutoff=cutoff, amp=0.42,
                                detunes=(-8.0, 8.0), max_harm=18,
                                vib_hz=5.0, vib_cents=4.0)
            stab *= adsr(n, 0.008, 0.13, 0.38, 0.12, curve=2.2)
            stab = np.tanh(stab * 1.8) * 0.72
            add_at(track, stab, st, gain=0.25 if b < 16 else 0.27)

    # --- Подъём напряжения к точке петли: шумовой riser + синус. ---
    riser_start = 43.2
    n = nsamples(target - riser_start)
    rrng = np.random.default_rng(SEEDS["music_boss"] + 7000)
    ut = timeline(n)
    riser = bandpass(noise(n, rrng, "pink"), 300.0, 6500.0)
    riser *= (ut / max(0.001, ut[-1])) ** 2.1
    riser *= 0.7 + 0.3 * np.sin(TWO_PI * 9.0 * ut)
    riser += 0.25 * np.sin(TWO_PI * np.cumsum(70.0 + 130.0 * ut / ut[-1]) / SR)
    riser *= adsr(n, 0.3, 0.1, 0.9, 0.22)
    add_at(track, riser, riser_start, gain=0.15)

    # --- Мощный финальный удар ровно в точку петли (48.0 с). ---
    final_hit = boss_drum(0.65, 120.0, 38.0, SEEDS["music_boss"] + 8000, heavy=True)
    final_hit = mix(final_hit,
                    0.5 * metal_hit(0.8, 155.0, rng, amp=1.0, bright=0.7))
    final_hit = reverb(final_hit, seconds=1.6, mix=0.28, predelay=0.015,
                       damping=0.5, seed=SEEDS["music_boss"] + 8100)
    add_at(track, final_hit, target, gain=0.42)

    # --- Общая глубокая реверберация и мягкая сатурация. ---
    track = reverb(track, seconds=1.5, mix=0.28, predelay=0.025,
                   damping=0.58, seed=SEEDS["music_boss"] + 9000)
    track = np.tanh(track * 1.2) / np.tanh(1.2)
    return finalize_loop(track, target, peak=0.85)


# ---------------------------------------------------------------------------
# Шаги по камню
# ---------------------------------------------------------------------------

def build_step(variant: int) -> np.ndarray:
    """0.16 с, камень + гравий; три разных характера."""
    rng = np.random.default_rng(SEEDS[f"step_{variant}"])
    n = nsamples(0.16)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Приземление стопы: низкий короткий тук.
    f0 = [135.0, 110.0, 150.0][variant - 1]
    out += 0.50 * thump(0.16, f0, 52.0, rng, tau=0.035, noise_amt=0.25)

    # Гравий: несколько очень коротких шумовых «зёрен».
    for k in range(3 + variant):
        st = 0.001 + 0.007 * k + rng.uniform(0.0, 0.005)
        grain = bandpass(noise(n, rng), 850.0 + 500 * variant, 6200.0)
        grain *= env(n, attack=0.0006, decay=0.012 + 0.004 * (k % 3), curve=2.0)
        add_at(out, grain, st, gain=0.26 if k % 2 else 0.18)

    # Песок/пыль — мягкий шорох.
    dust = highpass(noise(n, rng), 2500.0, order=2)
    dust *= env(n, attack=0.002, decay=0.045, curve=1.2)
    out += 0.12 * dust

    out = reverb(out, seconds=0.16, mix=0.14, predelay=0.006,
                 damping=0.7, seed=SEEDS[f"step_{variant}"] + 20)
    return finalize(out, peak=[0.68, 0.62, 0.72][variant - 1],
                    fade_in=0.005, fade_out=0.012, highpass_hz=35.0)


# ---------------------------------------------------------------------------
# Боевые SFX
# ---------------------------------------------------------------------------

def build_swing() -> np.ndarray:
    """0.22 с: тяжёлый взмах с нисходящим полосовым шумом."""
    rng = np.random.default_rng(SEEDS["swing"])
    n = nsamples(0.22)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Три шумовых слоя с разными центрами; окна идут сверху вниз по спектру.
    layers = [
        (2200.0, 7600.0, 0.035, 0.060, 0.42),
        (850.0, 2400.0, 0.090, 0.080, 0.55),
        (220.0, 900.0, 0.155, 0.090, 0.65),
    ]
    for i, (lo, hi, center, width, gain) in enumerate(layers):
        nz = bandpass(noise(n, rng), lo, hi)
        e = np.exp(-((t - center) / width) ** 2)
        e *= env(n, attack=0.002, decay=0.2, curve=1.0)
        out += gain * nz * e

    # Лёгкий металлический призвук цепи.
    for i, (st, fr) in enumerate([(0.045, 1800.0), (0.12, 2600.0)]):
        ping = np.sin(TWO_PI * fr * t + rng.uniform(0, TWO_PI))
        ping += 0.5 * np.sin(TWO_PI * fr * 2.71 * t + rng.uniform(0, TWO_PI))
        ping *= env(n, attack=0.001, decay=0.025, curve=1.5)
        add_at(out, ping, st, gain=0.10)

    out += 0.20 * thump(0.22, 95.0, 45.0, rng, tau=0.04, noise_amt=0.15)
    out = reverb(out, seconds=0.22, mix=0.16, predelay=0.008,
                 damping=0.6, seed=SEEDS["swing"] + 20)
    return finalize(out, peak=0.78, fade_in=0.006, fade_out=0.012,
                    highpass_hz=45.0)


def build_hit() -> np.ndarray:
    """0.28 с: удар по телу/броне, низкий тук + металл."""
    rng = np.random.default_rng(SEEDS["hit"])
    n = nsamples(0.28)
    out = np.zeros(n, dtype=np.float64)

    out += 0.85 * thump(0.28, 132.0, 44.0, rng, tau=0.10, noise_amt=0.40)

    crunch = bandpass(noise(n, rng), 180.0, 2600.0)
    crunch *= env(n, attack=0.001, decay=0.045, curve=1.5)
    out += 0.44 * crunch

    clang = metal_hit(0.24, 410.0, rng, amp=0.55, bright=0.65)
    add_at(out, clang, 0.0, gain=0.42)

    out = reverb(out, seconds=0.34, mix=0.16, predelay=0.008,
                 damping=0.6, seed=SEEDS["hit"] + 20)
    return finalize(out, peak=0.84, fade_in=0.005, fade_out=0.012,
                    highpass_hz=30.0)


def build_hit_heavy() -> np.ndarray:
    """0.45 с: тяжёлый удар с металлом и низким гулом."""
    rng = np.random.default_rng(SEEDS["hit_heavy"])
    n = nsamples(0.45)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    out += 1.00 * thump(0.45, 108.0, 33.0, rng, tau=0.18, noise_amt=0.55)

    # Гулкий металлический корпус.
    clang = metal_hit(0.40, 235.0, rng, amp=0.62, bright=0.55)
    add_at(out, clang, 0.0, gain=0.65)

    # Низкий резонанс «в груди».
    hum = np.sin(TWO_PI * 47.0 * t + 0.4) * env(n, attack=0.005, decay=0.22)
    hum *= 0.78 + 0.22 * np.sin(TWO_PI * 5.5 * t)
    out += 0.30 * hum

    # Каменная крошка.
    debris = bandpass(noise(n, rng), 500.0, 4200.0)
    debris *= env(n, attack=0.002, decay=0.09, curve=1.4)
    out += 0.16 * debris

    out = reverb(out, seconds=0.72, mix=0.24, predelay=0.015,
                 damping=0.58, seed=SEEDS["hit_heavy"] + 20)
    return finalize(out, peak=0.86, fade_in=0.006, fade_out=0.015,
                    highpass_hz=28.0)


def build_cast() -> np.ndarray:
    """0.65 с: обратный вдох, влажный всплеск и низкий гул кровавой магии."""
    rng = np.random.default_rng(SEEDS["cast"])
    n = nsamples(0.65)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Обратный вдох: нарастающий шум, развёрнутый во времени.
    inh_n = nsamples(0.36)
    inh = noise(inh_n, rng, "pink")
    inh = lowpass(inh, 3200.0, order=2)
    inh *= env(inh_n, attack=0.02, decay=0.16, curve=0.7)[::-1]
    inh *= np.linspace(0.0, 1.0, inh_n) ** 0.4
    inh = fade_edges(inh, 0.005, 0.010)
    add_at(out, inh, 0.0, gain=0.35)

    # Влажный всплеск в точке «выдоха».
    splash_n = nsamples(0.32)
    srng = np.random.default_rng(SEEDS["cast"] + 30)
    splash = bandpass(noise(splash_n, srng), 180.0, 2300.0)
    splash *= env(splash_n, attack=0.002, decay=0.07, curve=1.1)
    splash += 0.45 * np.sin(TWO_PI * 92.0 * timeline(splash_n) + 0.5) * env(
        splash_n, attack=0.003, decay=0.09)
    splash = reverb(splash, seconds=0.55, mix=0.25, predelay=0.015,
                    damping=0.6, seed=SEEDS["cast"] + 31)
    add_at(out, splash, 0.285, gain=0.55)

    # Низкий гул, «кровь густеет».
    hum = pitch_sweep(n, 72.0, 48.0, tau=0.2)
    hum *= env(n, attack=0.05, decay=0.38, curve=1.1)
    hum *= 0.7 + 0.3 * np.sin(TWO_PI * 4.2 * t + 1.0)
    out += 0.35 * hum

    # Редкие мелкие капли.
    for i, st in enumerate([0.40, 0.49, 0.57]):
        add_at(out, water_drip(0.14, 1300.0 + 180 * i, SEEDS["cast"] + 50 + i),
               st, gain=0.11)

    out = reverb(out, seconds=1.25, mix=0.38, predelay=0.025,
                 damping=0.5, seed=SEEDS["cast"] + 60)
    return finalize(out, peak=0.80, fade_in=0.006, fade_out=0.015,
                    highpass_hz=28.0)


def build_absorb() -> np.ndarray:
    """1.4 с: несколько влажных чавков, насыщение и двойной удар сердца."""
    rng = np.random.default_rng(SEEDS["absorb"])
    n = nsamples(1.4)
    out = np.zeros(n, dtype=np.float64)

    # Четыре чавкающих «куска».
    chomp_times = [0.035, 0.235, 0.420, 0.585]
    for i, st in enumerate(chomp_times):
        dur = [0.18, 0.20, 0.17, 0.20][i]
        cn = nsamples(dur)
        crng = np.random.default_rng(SEEDS["absorb"] + 100 + i)
        ct = timeline(cn)
        wet = bandpass(noise(cn, crng), 170.0, 1350.0)
        wet *= env(cn, attack=0.003, decay=0.045 + 0.008 * i, curve=1.0)
        squelch = np.sin(TWO_PI * np.cumsum(
            95.0 - 38.0 * ct / max(0.001, ct[-1])) / SR + 0.8)
        squelch *= env(cn, attack=0.004, decay=0.055, curve=1.2)
        chomp = wet + 0.52 * squelch
        chomp = np.tanh(chomp * 1.4) * 0.7
        chomp = reverb(chomp, seconds=0.38, mix=0.20, predelay=0.008,
                       damping=0.65, seed=SEEDS["absorb"] + 120 + i)
        add_at(out, chomp, st, gain=0.55 - 0.04 * i)

    # Низкое насыщение: тёплый сатурированный гул.
    sat_start = 0.78
    sat_n = nsamples(1.4 - sat_start)
    stt = timeline(sat_n)
    sat = 0.5 * np.sin(TWO_PI * 46.0 * stt) + 0.32 * np.sin(TWO_PI * 69.0 * stt)
    sat += 0.14 * lowpass(noise(sat_n, rng, "brown"), 220.0)
    sat *= adsr(sat_n, 0.05, 0.15, 0.55, 0.30)
    sat = np.tanh(sat * 2.2) * 0.7
    add_at(out, sat, sat_start, gain=0.40)

    # Сердце: «луб-дуб» в самом конце.
    for i, (st, f0, gain) in enumerate([(0.91, 62.0, 0.70), (1.105, 52.0, 0.52)]):
        hb = thump(0.2, f0, 34.0, np.random.default_rng(SEEDS["absorb"] + 300 + i),
                   tau=0.07, noise_amt=0.30)
        hb = reverb(hb, seconds=0.35, mix=0.18, predelay=0.006,
                    damping=0.65, seed=SEEDS["absorb"] + 310 + i)
        add_at(out, hb, st, gain=gain)

    out = reverb(out, seconds=0.85, mix=0.24, predelay=0.012,
                 damping=0.62, seed=SEEDS["absorb"] + 400)
    return finalize(out, peak=0.82, fade_in=0.006, fade_out=0.015,
                    highpass_hz=28.0)


def build_alert() -> np.ndarray:
    """0.9 с: ржавый стражницкий горн/свисток с хрипом."""
    rng = np.random.default_rng(SEEDS["alert"])
    n = nsamples(0.9)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Две ноты тревоги: A -> C (малая терция), с «просадкой» строя.
    def horn_note(f0: float, f1: float, start: float, dur: float,
                  gain: float) -> None:
        hn = nsamples(dur)
        ht = timeline(hn)
        u = ht / max(0.001, ht[-1])
        f = f0 + (f1 - f0) * u + 0.9 * np.sin(TWO_PI * 5.5 * ht)
        base = TWO_PI * np.cumsum(f) / SR
        src = np.zeros(hn, dtype=np.float64)
        for h in range(1, 18):
            if h * np.max(f) >= SR * 0.45:
                break
            src += (1.0 / h) * np.sin(h * base + 0.11 * h)
        # Форманты ржавой трубы.
        src = 0.7 * bandpass(src, 280.0, 1200.0)
        src += 0.4 * bandpass(src, 900.0, 2600.0)
        src = np.tanh(src * 1.8) * 0.7
        breath = bandpass(noise(hn, rng), 700.0, 5200.0)
        breath *= 0.5 + 0.5 * np.sin(TWO_PI * 17.0 * ht) ** 2
        src += 0.20 * breath
        src *= adsr(hn, 0.035, 0.08, 0.78, 0.10)
        add_at(out, src, start, gain=gain)

    horn_note(220.0, 233.0, 0.00, 0.40, 0.55)
    horn_note(261.63, 246.94, 0.38, 0.45, 0.52)

    # Хрип/дыхание после сигнала.
    tail_n = nsamples(0.25)
    rasp = bandpass(noise(tail_n, rng), 500.0, 3000.0)
    rasp *= env(tail_n, attack=0.01, decay=0.08, curve=1.0)
    add_at(out, rasp, 0.62, gain=0.18)

    out = reverb(out, seconds=0.9, mix=0.28, predelay=0.02,
                 damping=0.55, seed=SEEDS["alert"] + 50)
    return finalize(out, peak=0.79, fade_in=0.008, fade_out=0.015,
                    highpass_hz=60.0)


# ---------------------------------------------------------------------------
# Железо, двери, интерфейс
# ---------------------------------------------------------------------------

def build_chain() -> np.ndarray:
    """1.0 с: серия металлических звяканий и финальный разрыв цепи."""
    rng = np.random.default_rng(SEEDS["chain"])
    n = nsamples(1.0)
    out = np.zeros(n, dtype=np.float64)

    clink_times = [0.015, 0.125, 0.250, 0.355, 0.455, 0.555]
    for i, st in enumerate(clink_times):
        base = [1350.0, 1720.0, 1120.0, 2050.0, 1510.0, 2380.0][i]
        clink = metal_hit(0.24, base, rng, amp=[0.42, 0.34, 0.38, 0.30, 0.32, 0.25][i],
                          bright=1.2)
        clink = reverb(clink, seconds=0.55, mix=0.20, predelay=0.008,
                       damping=0.45, seed=SEEDS["chain"] + 100 + i)
        add_at(out, clink, st, gain=0.7)

    # Разрыв: широкий шумовой треск + падающий металлический звон.
    tear_start = 0.67
    tn = nsamples(1.0 - tear_start)
    trng = np.random.default_rng(SEEDS["chain"] + 300)
    tear = highpass(noise(tn, trng), 500.0, order=2)
    tear *= env(tn, attack=0.001, decay=0.09, curve=0.8)
    tear += 0.55 * bandpass(noise(tn, trng), 120.0, 1600.0) * env(
        tn, attack=0.001, decay=0.13)
    add_at(out, tear, tear_start, gain=0.60)

    snap = metal_hit(0.48, 620.0, rng, amp=0.72, bright=1.3)
    snap = reverb(snap, seconds=0.7, mix=0.25, predelay=0.01,
                  damping=0.45, seed=SEEDS["chain"] + 310)
    add_at(out, snap, 0.70, gain=0.65)

    # Низкий рывок.
    yank = thump(0.38, 90.0, 38.0, rng, tau=0.09, noise_amt=0.45)
    add_at(out, yank, 0.68, gain=0.45)

    out = reverb(out, seconds=0.8, mix=0.24, predelay=0.012,
                 damping=0.52, seed=SEEDS["chain"] + 400)
    return finalize(out, peak=0.85, fade_in=0.005, fade_out=0.015,
                    highpass_hz=45.0)


def build_door() -> np.ndarray:
    """1.1 с: тяжёлая решётка — скрип, трение, глухой удар в конце."""
    rng = np.random.default_rng(SEEDS["door"])
    n = nsamples(1.1)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Скрип: пила с медленно гуляющей высотой и амплитудной «зазубренностью».
    f_creak = 78.0 + 24.0 * np.sin(TWO_PI * 0.9 * t) + 7.0 * np.sin(TWO_PI * 2.3 * t)
    creak = np.zeros(n, dtype=np.float64)
    base = TWO_PI * np.cumsum(f_creak) / SR
    for h in range(1, 20):
        creak += (1.0 / h) * np.sin(h * base + 0.2 * h)
    creak *= 0.35 + 0.65 * (0.5 + 0.5 * np.sin(TWO_PI * 11.0 * t + 0.6)) ** 2
    creak *= adsr(n, 0.05, 0.15, 0.65, 0.35)
    out += 0.34 * creak

    # Трение металла о камень.
    scrape = bandpass(noise(n, rng), 220.0, 2600.0)
    scrape *= 0.4 + 0.6 * (0.5 + 0.5 * np.sin(TWO_PI * 7.3 * t + 1.7)) ** 3
    scrape *= adsr(n, 0.04, 0.1, 0.6, 0.4)
    out += 0.22 * scrape

    # Тяжёлый глухой удар в конце.
    thud = thump(0.55, 82.0, 34.0, rng, tau=0.16, noise_amt=0.45)
    thud = reverb(thud, seconds=0.75, mix=0.3, predelay=0.015,
                  damping=0.65, seed=SEEDS["door"] + 100)
    add_at(out, thud, 0.70, gain=0.82)

    # Осыпающаяся каменная крошка.
    for i, st in enumerate([0.83, 0.89, 0.95]):
        grain = bandpass(noise(n, rng), 900.0, 5200.0)
        grain *= env(n, attack=0.002, decay=0.025, curve=1.6)
        add_at(out, grain, st, gain=0.12)

    out = reverb(out, seconds=1.0, mix=0.27, predelay=0.018,
                 damping=0.6, seed=SEEDS["door"] + 200)
    return finalize(out, peak=0.82, fade_in=0.007, fade_out=0.015,
                    highpass_hz=32.0)


def build_click() -> np.ndarray:
    """0.08 с: мягкий деревянно-металлический щелчок интерфейса."""
    rng = np.random.default_rng(SEEDS["click"])
    n = nsamples(0.08)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    tick = bandpass(noise(n, rng), 700.0, 5000.0)
    tick *= env(n, attack=0.0008, decay=0.006, curve=2.0)
    out += 0.55 * tick

    for i, (fr, amp, tau) in enumerate([(390.0, 0.55, 0.018),
                                        (1150.0, 0.25, 0.010),
                                        (1840.0, 0.12, 0.007)]):
        out += amp * np.sin(TWO_PI * fr * t + rng.uniform(0, TWO_PI)) * np.exp(-t / tau)

    # Мягкая атака, чтобы не было резкого «тика».
    out *= env(n, attack=0.002, decay=0.05, curve=0.7)
    return finalize(out, peak=0.52, fade_in=0.006, fade_out=0.012,
                    highpass_hz=80.0)


def build_heartbeat() -> np.ndarray:
    """0.9 с: глубокий двойной удар сердца (луб-дуб)."""
    rng = np.random.default_rng(SEEDS["heartbeat"])
    n = nsamples(0.9)
    out = np.zeros(n, dtype=np.float64)

    for i, (st, f0, f1, gain) in enumerate([(0.035, 66.0, 36.0, 0.95),
                                            (0.285, 55.0, 31.0, 0.68)]):
        hb = thump(0.42, f0, f1, np.random.default_rng(SEEDS["heartbeat"] + 20 + i),
                   tau=0.095, noise_amt=0.30)
        hb = reverb(hb, seconds=0.55, mix=0.18, predelay=0.008,
                    damping=0.7, seed=SEEDS["heartbeat"] + 30 + i)
        add_at(out, hb, st, gain=gain)

    # Очень тихий «клапанный» шорох.
    valve = lowpass(noise(n, rng), 900.0, order=2)
    valve *= env(n, attack=0.02, decay=0.20, curve=1.0)
    out += 0.035 * valve

    out = reverb(out, seconds=0.65, mix=0.15, predelay=0.01,
                 damping=0.7, seed=SEEDS["heartbeat"] + 50)
    return finalize(out, peak=0.80, fade_in=0.008, fade_out=0.015,
                    highpass_hz=25.0)


# ---------------------------------------------------------------------------
# Голос надзирателя, смерть, тёплые и финальные эффекты
# ---------------------------------------------------------------------------

def build_boss_roar() -> np.ndarray:
    """1.6 с: низкий расстроенный голос с формантами и рыком."""
    rng = np.random.default_rng(SEEDS["boss_roar"])
    n = nsamples(1.6)
    t = timeline(n)

    # Контур высоты: рёв поднимается и срывается вниз.
    u = t / t[-1]
    f0 = 64.0 + 13.0 * np.sin(np.pi * np.clip(u / 0.55, 0, 1)) - 14.0 * np.clip(
        (u - 0.62) / 0.38, 0, 1)
    fm = 1.0 + 0.012 * np.sin(TWO_PI * 5.2 * t + 0.7)
    f0 = f0 * fm

    def glottal(detune: float) -> np.ndarray:
        base = TWO_PI * np.cumsum(f0 * detune) / SR
        src = np.zeros(n, dtype=np.float64)
        for h in range(1, 36):
            if h * 95.0 >= SR * 0.45:
                break
            src += (1.0 / h) * np.sin(h * base + 0.05 * h)
        return src

    src = 0.62 * glottal(1.0) + 0.38 * glottal(0.978)
    # Грубая модуляция — «рык».
    growl = 0.5 + 0.5 * np.sin(TWO_PI * 29.0 * t + 0.2)
    src *= 0.45 + 0.55 * growl ** 2
    src = np.tanh(src * 2.8) * 0.55

    # Форманты: три полосы, близкие к низкому мужскому голосу.
    formants = (
        0.9 * bandpass(src, 300.0, 750.0) +
        0.65 * bandpass(src, 750.0, 1300.0) +
        0.28 * bandpass(src, 1900.0, 2900.0)
    )
    breath = bandpass(noise(n, rng), 350.0, 3200.0)
    breath *= 0.5 + 0.5 * np.sin(TWO_PI * 33.0 * t + 1.1) ** 2
    formants += 0.16 * breath
    formants *= adsr(n, 0.09, 0.22, 0.70, 0.30)
    formants = np.tanh(formants * 1.8) * 0.72

    out = reverb(formants, seconds=1.5, mix=0.34, predelay=0.025,
                 damping=0.45, seed=SEEDS["boss_roar"] + 50)
    # Низкий суб-слой для «живота» рёва.
    sub = np.sin(TWO_PI * 38.0 * t + 0.3) * env(n, attack=0.06, decay=0.8)
    sub *= 0.6 + 0.4 * growl
    out += 0.20 * sub
    return finalize(out, peak=0.86, fade_in=0.008, fade_out=0.015,
                    highpass_hz=28.0)


def build_death() -> np.ndarray:
    """1.2 с: хрип, падение тела, металл."""
    rng = np.random.default_rng(SEEDS["death"])
    n = nsamples(1.2)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Хрип: шум + слабый голосовой тон, быстро угасает.
    breath = bandpass(noise(n, rng), 300.0, 2800.0)
    breath *= env(n, attack=0.015, decay=0.20, curve=1.2)
    f_voice = 140.0 - 45.0 * np.clip(t / 0.55, 0, 1)
    voice = np.sin(TWO_PI * np.cumsum(f_voice) / SR) * 0.32
    voice *= env(n, attack=0.02, decay=0.16, curve=1.0)
    out += 0.38 * breath + 0.16 * voice

    # Падение тела: глухой удар.
    fall = thump(0.48, 86.0, 34.0, rng, tau=0.13, noise_amt=0.55)
    fall = reverb(fall, seconds=0.6, mix=0.22, predelay=0.012,
                  damping=0.65, seed=SEEDS["death"] + 30)
    add_at(out, fall, 0.51, gain=0.75)

    # Металл: оружие/доспех падает следом.
    for i, (st, base) in enumerate([(0.68, 740.0), (0.77, 1120.0), (0.86, 480.0)]):
        clink = metal_hit(0.33, base, rng,
                          amp=[0.55, 0.34, 0.28][i], bright=0.9)
        clink = reverb(clink, seconds=0.6, mix=0.22, predelay=0.008,
                       damping=0.5, seed=SEEDS["death"] + 40 + i)
        add_at(out, clink, st, gain=0.8)

    out = reverb(out, seconds=0.9, mix=0.24, predelay=0.012,
                 damping=0.6, seed=SEEDS["death"] + 60)
    return finalize(out, peak=0.82, fade_in=0.008, fade_out=0.015,
                    highpass_hz=30.0)


def build_trust() -> np.ndarray:
    """1.3 с: тёплый мажорный колокольчик/чакра с мягкой атакой."""
    rng = np.random.default_rng(SEEDS["trust"])
    n = nsamples(1.3)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # A-мажорный свет: A4, C#5, E5, A5.
    freqs = [440.0, 554.37, 659.25, 880.0]
    for i, fr in enumerate(freqs):
        partial_env = env(n, attack=0.05 + 0.01 * i, decay=0.85 - 0.1 * i, curve=0.8)
        tone = np.sin(TWO_PI * fr * t + rng.uniform(0, TWO_PI))
        tone += 0.26 * np.sin(TWO_PI * fr * 2.01 * t + rng.uniform(0, TWO_PI))
        out += (0.30 / (1.0 + 0.3 * i)) * tone * partial_env

    # Тёплая низкая подложка.
    warm = np.sin(TWO_PI * 220.0 * t) * 0.16 + np.sin(TWO_PI * 110.0 * t) * 0.10
    warm *= adsr(n, 0.12, 0.2, 0.5, 0.7)
    out += warm

    # Мягкий «воздух» и глубокая реверберация.
    air = highpass(noise(n, rng), 3000.0, order=2)
    air *= env(n, attack=0.08, decay=0.55, curve=1.0)
    out += 0.045 * air

    out = lowpass(out, 6200.0, order=2)
    out = reverb(out, seconds=1.9, mix=0.42, predelay=0.03,
                 damping=0.35, seed=SEEDS["trust"] + 50)
    return finalize(out, peak=0.64, fade_in=0.012, fade_out=0.015,
                    highpass_hz=45.0)


def build_lowmagic() -> np.ndarray:
    """0.5 с: глухой диссонансный удар — «нет магии»."""
    rng = np.random.default_rng(SEEDS["lowmagic"])
    n = nsamples(0.5)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    thud = thump(0.5, 78.0, 39.0, rng, tau=0.12, noise_amt=0.35)
    out += 0.90 * thud

    # Малая секунда + тритон, задавленные low-pass.
    cluster = (
        0.42 * np.sin(TWO_PI * 146.83 * t + 0.2) +
        0.38 * np.sin(TWO_PI * 155.56 * t + 1.4) +
        0.22 * np.sin(TWO_PI * 207.65 * t + 3.0)
    )
    cluster *= env(n, attack=0.003, decay=0.17, curve=1.1)
    out += 0.42 * lowpass(cluster, 620.0, order=2)

    out += 0.14 * lowpass(noise(n, rng), 500.0) * env(n, attack=0.002, decay=0.05)
    out = reverb(out, seconds=0.55, mix=0.20, predelay=0.012,
                 damping=0.7, seed=SEEDS["lowmagic"] + 20)
    return finalize(out, peak=0.73, fade_in=0.006, fade_out=0.015,
                    highpass_hz=30.0)


def build_win() -> np.ndarray:
    """4.0 с: финальный аккорд D-мажор с добавленной ноной — мрачно, но с надеждой."""
    rng = np.random.default_rng(SEEDS["win"])
    n = nsamples(4.0)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Пикардийская терция: D + F# + A + E. Тёмный тембр, светлый аккорд.
    notes = [73.42, 110.00, 146.83, 185.00, 220.00, 329.63, 369.99]
    for i, fr in enumerate(notes):
        cutoff = 650.0 + 850.0 * np.sin(np.pi * np.clip(t / 3.2, 0, 1)) ** 1.4
        voice = saw_additive(
            fr, n, rng, cutoff=cutoff, amp=0.20,
            detunes=(-5.0, 5.0), max_harm=20,
            vib_hz=0.10 + 0.01 * i, vib_cents=2.5,
        )
        voice *= adsr(n, 0.22 + 0.02 * i, 0.55, 0.64, 0.9, curve=2.0)
        add_at(out, voice, 0.0, gain=0.23)

    # Низкая педаль.
    pedal = 0.45 * np.sin(TWO_PI * 36.71 * t) + 0.40 * np.sin(TWO_PI * 73.42 * t)
    pedal *= adsr(n, 0.25, 0.5, 0.55, 1.0)
    out += 0.32 * pedal

    # Колокольчик-«луч надежды».
    for i, (fr, st, amp) in enumerate([(880.0, 0.55, 0.09), (1174.66, 0.95, 0.07)]):
        bn = nsamples(4.0 - st)
        bt = timeline(bn)
        bell = np.sin(TWO_PI * fr * bt) + 0.35 * np.sin(TWO_PI * fr * 2.01 * bt)
        bell *= env(bn, attack=0.06, decay=1.1, curve=0.9)
        add_at(out, bell, st, gain=amp)

    out = reverb(out, seconds=2.9, mix=0.40, predelay=0.035,
                 damping=0.45, seed=SEEDS["win"] + 50)
    out = lowpass(out, 7800.0, order=2)
    return finalize(out, peak=0.77, fade_in=0.015, fade_out=0.015,
                    highpass_hz=28.0)


def build_gate_open() -> np.ndarray:
    """1.5 с: каменные ворота / подъём решётки с низким гулом."""
    rng = np.random.default_rng(SEEDS["gate_open"])
    n = nsamples(1.5)
    t = timeline(n)
    out = np.zeros(n, dtype=np.float64)

    # Гул механизма: низкий сау и суб-синус, слегка поднимается.
    nz = lowpass(noise(n, rng, "brown"), 110.0, order=3)
    grind = 0.45 * np.sin(TWO_PI * 39.0 * t + 0.6)
    grind += 0.25 * np.sin(TWO_PI * 58.5 * t + 2.1)
    grind *= 0.6 + 0.4 * np.sin(TWO_PI * 3.1 * t) ** 2
    out += 0.42 * grind * adsr(n, 0.08, 0.2, 0.7, 0.5)

    # Каменное трение.
    scrape = bandpass(noise(n, rng), 120.0, 1900.0)
    scrape *= 0.45 + 0.55 * (0.5 + 0.5 * np.sin(TWO_PI * 6.2 * t + 1.2)) ** 2
    scrape *= adsr(n, 0.05, 0.25, 0.65, 0.45)
    out += 0.28 * scrape + 0.18 * nz

    # Цепной механизм.
    for i, st in enumerate([0.11, 0.23, 0.34, 0.46, 0.58]):
        clink = metal_hit(0.25, 900.0 + 240 * i, rng, amp=0.3, bright=1.0)
        clink = reverb(clink, seconds=0.45, mix=0.2, predelay=0.006,
                       damping=0.5, seed=SEEDS["gate_open"] + 30 + i)
        add_at(out, clink, st, gain=0.28)

    # Подъём: шумовой слоу-свелл и финальный тяжёлый стоп.
    rise_start = 0.35
    rn = nsamples(1.5 - rise_start)
    rt = timeline(rn)
    rise = bandpass(noise(rn, rng), 350.0, 5200.0)
    rise *= (rt / max(0.001, rt[-1])) ** 1.4
    rise *= env(rn, attack=0.1, decay=0.7, curve=1.0)
    add_at(out, rise, rise_start, gain=0.12)

    stop = thump(0.55, 78.0, 32.0, rng, tau=0.16, noise_amt=0.6)
    stop = mix(stop, 0.35 * metal_hit(0.45, 330.0, rng, amp=0.5, bright=0.7))
    stop = reverb(stop, seconds=1.0, mix=0.28, predelay=0.012,
                  damping=0.6, seed=SEEDS["gate_open"] + 100)
    add_at(out, stop, 0.98, gain=0.75)

    out = reverb(out, seconds=1.25, mix=0.30, predelay=0.02,
                 damping=0.55, seed=SEEDS["gate_open"] + 200)
    return finalize(out, peak=0.84, fade_in=0.008, fade_out=0.015,
                    highpass_hz=28.0)


# ---------------------------------------------------------------------------
# Сборка и проверка
# ---------------------------------------------------------------------------

BUILDERS = {
    "amb_prison.wav": (build_amb_prison, 45.0),
    "music_menu.wav": (build_music_menu, 64.0),
    "music_boss.wav": (build_music_boss, 48.0),
    "sfx_step_1.wav": (lambda: build_step(1), 0.16),
    "sfx_step_2.wav": (lambda: build_step(2), 0.16),
    "sfx_step_3.wav": (lambda: build_step(3), 0.16),
    "sfx_swing.wav": (build_swing, 0.22),
    "sfx_hit.wav": (build_hit, 0.28),
    "sfx_hit_heavy.wav": (build_hit_heavy, 0.45),
    "sfx_cast.wav": (build_cast, 0.65),
    "sfx_absorb.wav": (build_absorb, 1.4),
    "sfx_alert.wav": (build_alert, 0.9),
    "sfx_chain.wav": (build_chain, 1.0),
    "sfx_door.wav": (build_door, 1.1),
    "sfx_click.wav": (build_click, 0.08),
    "sfx_heartbeat.wav": (build_heartbeat, 0.9),
    "sfx_boss_roar.wav": (build_boss_roar, 1.6),
    "sfx_death.wav": (build_death, 1.2),
    "sfx_trust.wav": (build_trust, 1.3),
    "sfx_lowmagic.wav": (build_lowmagic, 0.5),
    "sfx_win.wav": (build_win, 4.0),
    "sfx_gate_open.wav": (build_gate_open, 1.5),
}

LOOPS = {"amb_prison.wav", "music_menu.wav", "music_boss.wav"}


def read_wav_info(path: Path):
    """Чтение параметров и отсчётов WAV для проверки."""
    with wave.open(str(path), "rb") as wf:
        channels = wf.getnchannels()
        width = wf.getsampwidth()
        rate = wf.getframerate()
        frames = wf.readframes(wf.getnframes())
        n = wf.getnframes()
    y = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32767.0
    return channels, width, rate, n, y


def validate_assets() -> bool:
    """Проверка: файл есть, формат, ±10 % длительности, пик 0.05–0.89, NaN."""
    print("\n=== ПРОВЕРКА АССЕТОВ ===")
    print(f"{'файл':<24} {'длит., с':>9} {'пик':>7}  статус")
    ok_all = True
    for name, (_, expected) in BUILDERS.items():
        path = OUT_DIR / name
        if not path.exists():
            print(f"{name:<24} {'—':>9} {'—':>7}  НЕТ ФАЙЛА")
            ok_all = False
            continue
        ch, width, rate, n, y = read_wav_info(path)
        dur = n / rate
        peak = float(np.max(np.abs(y))) if y.size else 0.0
        finite = bool(np.isfinite(y).all())
        duration_ok = abs(dur - expected) <= expected * 0.10 + 0.002
        peak_ok = 0.05 <= peak <= 0.89
        format_ok = (ch == 1 and width == 2 and rate == SR)
        if name in LOOPS:
            # Для лупов важна непрерывность на стыке, а не нули на краях.
            edge_jump = abs(float(y[0] - y[-1])) if y.size > 1 else 0.0
            edge_txt = f"стык {edge_jump:.4f}"
        else:
            edge_jump = max(abs(float(y[0])), abs(float(y[-1])))
            edge_txt = f"края {edge_jump:.4f}"
        good = finite and duration_ok and peak_ok and format_ok
        ok_all &= good
        status = "OK" if good else "ОШИБКА"
        print(f"{name:<24} {dur:9.3f} {peak:7.3f}  {status}  {edge_txt}")
        if not good:
            print(f"    формат={ch}ch/{width*8}bit/{rate}Гц, "
                  f"finite={finite}, duration_ok={duration_ok}, peak_ok={peak_ok}")
    return ok_all


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Генерация в {OUT_DIR}")
    for i, (name, (builder, expected)) in enumerate(BUILDERS.items(), 1):
        print(f"[{i:02d}/{len(BUILDERS)}] {name} ...", flush=True)
        x = sanitize(builder())
        expected_n = nsamples(expected)
        if x.size != expected_n:
            raise RuntimeError(
                f"{name}: длина {x.size} отсчётов, ожидалось {expected_n}")
        if float(np.max(np.abs(x))) > PEAK_SAFE:
            raise RuntimeError(f"{name}: пик превышает {PEAK_SAFE}")
        save_wav(OUT_DIR / name, x)

    ok = validate_assets()
    if not ok:
        raise SystemExit(1)
    print("\nГотово: все ассеты собраны и проверены.")


if __name__ == "__main__":
    main()
