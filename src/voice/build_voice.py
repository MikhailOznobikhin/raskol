#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Генератор озвучки реплик. Фаза 5.5 ROADMAP.

Читает assets/text/voice_manifest.json, синтезирует каждую реплику локальной
TTS-моделью (Chatterbox / ChatterboxMultilingualTTS, MIT), нормализует и
сохраняет в assets/audio/voice/<id>.ogg через ffmpeg.

Кэш: рядом с wav лежится <id>.meta.json {hash}; если хэш совпал — реплика
пропускается. Хэш зависит от текста, спикера и параметров генерации.

Питч персонажей делается пост-обработкой resample (asetrate) — временная
 мера до подбора референс-голосов для клонирования.

Запуск:
  tools\tts_env\Scripts\python.exe src\voice\build_voice.py            # всё недостающее
  ... build_voice.py --only m1_dlg_001                                 # одну реплику
  ... build_voice.py --list-missing
  ... build_voice.py --test                                            # 3 пробы, в tools\\voice_preview\\
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
MANIFEST = BASE / "assets" / "text" / "voice_manifest.json"
OUT_DIR = BASE / "assets" / "audio" / "voice"
PREVIEW_DIR = BASE / "tools" / "voice_preview"
FFMPEG = BASE / "tools" / "ffmpeg" / "ffmpeg-9.0.2-essentials_build" / "bin" / "ffmpeg.exe"

DEVICE = "cuda" if _cuda_ok() else "cpu"


def _cuda_ok() -> bool:
    try:
        import torch
        return torch.cuda.is_available()
    except Exception:
        return False


# Характеристики персонажей: пост-обработка pitch/speed через resample.
# playback=0.8 → голос ниже и медленнее; 1.1 → выше и быстрее.
VOICE_PROFILES = {
    "Торвин": {"playback": 0.94, "exaggeration": 0.5},
    "Селена Вейн": {"playback": 1.08, "exaggeration": 0.45},
    "Стражник": {"playback": 1.00, "exaggeration": 0.35},
    "Гхарн": {"playback": 0.80, "exaggeration": 0.9},
    "Рассказчик": {"playback": 0.97, "exaggeration": 0.25},
}

TEST_IDS = ["m1_dlg_001", "m1_dlg_004", "m1_bark_001"]


def line_hash(text: str, speaker: str, prof: dict) -> str:
    key = f"{speaker}|{text}|{prof}"
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:16]


def run_ffmpeg(args: list[str]) -> None:
    res = subprocess.run([str(FFMPEG), "-y", "-loglevel", "error"] + args,
                         capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg: {res.stderr.strip()}")


def postprocess(wav: Path, ogg_out: Path, playback: float) -> None:
    """wav → ogg: питч/скорость asetrate (resample вместе с темпом)."""
    filter_complex = (
        f"asetrate=24000*{playback:.6f},"
        f"aresample=22050,"
        f"loudnorm=I=-16:TP=-1.5:LRA=9"
    )
    run_ffmpeg(["-i", str(wav), "-af", filter_complex,
                "-ar", "22050", "-c:a", "libvorbis", "-q:a", "4",
                str(ogg_out)])


def synth(line: dict, model) -> dict:
    from pathlib import Path as _P
    id_ = line["id"]
    speaker = line["speaker"]
    prof = VOICE_PROFILES.get(speaker, VOICE_PROFILES["Торвин"])
    hsh = line_hash(line["text"], speaker, prof)
    wav = OUT_DIR / f"{id_}.wav"
    ogg = OUT_DIR / f"{id_}.ogg"
    meta = OUT_DIR / f"{id_}.meta.json"
    if meta.exists() and ogg.exists():
        if json.loads(meta.read_text(encoding="utf-8")).get("hash") == hsh:
            return {"id": id_, "status": "cached"}
    wav.parent.mkdir(parents=True, exist_ok=True)
    wav.unlink(missing_ok=True)
    try:
        get_res = model.generate(line["text"],
                                 language_id="ru",
                                 exaggeration=float(prof["exaggeration"]))
    except TypeError:
        # одноязычная (английская) версия API без language_id
        get_res = model.generate(line["text"],
                                 exaggeration=float(prof["exaggeration"]))
    import torchaudio
    torchaudio.save(str(wav), get_res.cpu(), getattr(model, "sr", 24000))
    postprocess(wav, ogg, float(prof["playback"]))
    meta.write_text(json.dumps({"hash": hsh, "speaker": speaker,
                                "text": line["text"]}, ensure_ascii=False),
                    encoding="utf-8")
    # Держим wav только в кэше инструментов, к билду идёт ogg.
    wav.replace(BASE / "tools" / "voice_wav" / f"{id_}.wav")
    return {"id": id_, "status": "generated"}


def load_model():
    try:
        from chatterbox.tts import ChatterboxMultilingualTTS as M
        return M.from_pretrained(device=DEVICE)
    except ImportError:
        from chatterbox.tts import ChatterboxTts as M
        return M.from_pretrained(device=DEVICE)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="генерить только одну реплику по id")
    ap.add_argument("--speaker", help="только один спикер")
    ap.add_argument("--force", action="store_true", help="без кэша")
    ap.add_argument("--list-missing", action="store_true")
    ap.add_argument("--test", action="store_true", help="3 пробы в tools\\voice_preview")
    args = ap.parse_args()

    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    lines = data["lines"]
    if args.only:
        lines = [l for l in lines if l["id"] == args.only]
        if not lines:
            print(f"id '{args.only}' не найден"); return 2
    if args.speaker:
        lines = [l for l in lines if l["speaker"] == args.speaker]
    if args.test:
        lines = [l for l in lines if l["id"] in TEST_IDS]
        if not lines:
            print("test ids не найдены в манифесте"); return 2

    (BASE / "tools" / "voice_wav").mkdir(parents=True, exist_ok=True)
    if args.test:
        OUT_DIR2 = PREVIEW_DIR
        global OUT_DIR; OUT_DIR = OUT_DIR2
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    missing = [l["id"] for l in lines
               if not (OUT_DIR / f"{l['id']}.ogg").exists()]
    if args.list_missing:
        for mid in missing:
            print("MISSING", mid)
        print(f"итого missing: {len(missing)} / {len(lines)}")
        return 0

    print(f"Загрузка модели ({DEVICE})... первый запуск качает веса с HF")
    model = load_model()
    ok = failed = cached = 0
    for i, ln in enumerate(lines, 1):
        try:
            if args.force:
                (OUT_DIR / f"{ln['id']}.meta.json").unlink(missing_ok=True)
            r = synth(ln, model)
            if r["status"] == "cached":
                cached += 1
            else:
                ok += 1
                print(f"[{i}/{len(lines)}] {ln['id']} готов")
        except Exception as e:  # noqa: BLE001 — отчёт нужен, не падать на середине
            failed += 1
            print(f"[{i}/{len(lines)}] {ln['id']} ОШИБКА: {e}")
    print(f"Итог: generated={ok} cached={cached} failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
