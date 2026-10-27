#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Генератор озвучки реплик. Фаза 5.5 ROADMAP.

Читает assets/text/voice_manifest.json и синтезирует реплики локальной
TTS-моделью ChatterboxMultilingualTTS (MIT), затем нормализует и кладёт
ogg в assets/audio/voice/<id>.ogg.

На этой машине Windows не даёт держать в одном процессе T3 (2 ГБ) и S3Gen
(1 ГБ): CUDA-аллокации съедают host commit, и вторая модель уже не грузится.
Поэтому пайплайн разбит на две стадии, каждая в своём процессе:
  1) t3  — T3 на GPU: текст -> speech-токены (tools/cache/voice_tokens);
  2) voc — S3Gen на GPU (fallback CPU): токены -> wav 24 кГц -> ffmpeg -> ogg.

Кэш: <id>.tok.meta.json рядом с токенами и <id>.meta.json рядом с ogg.
Хэш токенов зависит от текста, спикера и exaggeration; хэш ogg — ещё и от
playback. Совпал хэш — шаг пропускается.

Питч персонажей делается пост-обработкой asetrate (временная мера до
подбора референс-голосов для клонирования).

Запуск:
  tools/tts_env/Scripts/python.exe src/voice/build_voice.py            # всё недостающее
  ... build_voice.py --only m1_dlg_001
  ... build_voice.py --speaker Торвин --force
  ... build_voice.py --list-missing
  ... build_voice.py --test                                            # 3 пробы, в tools/voice_preview/
  ... build_voice.py --stage t3 | --stage voc                          # по стадиям
"""

from __future__ import annotations

import argparse
import gc
import hashlib
import json
import os
import struct
import subprocess
import sys
import time
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
MANIFEST = BASE / "assets" / "text" / "voice_manifest.json"
TOKENS_DIR = BASE / "tools" / "cache" / "voice_tokens"
WAV_DIR = BASE / "tools" / "voice_wav"
OUT_DIR = BASE / "assets" / "audio" / "voice"
PREVIEW_DIR = BASE / "tools" / "voice_preview"
FFMPEG = BASE / "tools" / "ffmpeg" / "ffmpeg-9.0.2-essentials_build" / "bin" / "ffmpeg.exe"
HF_CACHE = BASE / "tools" / "cache" / "hf" / "hub"
REPO_ID = "ResembleAI/chatterbox"
CKPT_FILES = [
    "ve.pt",
    "t3_mtl23ls_v2.safetensors",
    "s3gen.pt",
    "grapheme_mtl_merged_expanded_v1.json",
    "conds.pt",
    "Cangjie5_TC.json",
]

# --- Кэш-обход (Windows): глобальная TORCHINDUCTOR_CACHE_DIR пользователя
# может указывать на недоступный ~/.unsloth, а ~/.cache/huggingface у Python
# без прав на запись — перенаправляем оба в tools/cache. ДО import torch!
os.environ["TORCHINDUCTOR_CACHE_DIR"] = str(BASE / "tools" / "cache" / "torchinductor")
os.environ["HF_HOME"] = str(BASE / "tools" / "cache" / "hf")
os.environ.setdefault("PKUSEG_HOME", str(BASE / "tools" / "cache" / "pkuseg"))
for _p in (os.environ["TORCHINDUCTOR_CACHE_DIR"], os.environ["HF_HOME"],
           os.environ["PKUSEG_HOME"]):
    try:
        Path(_p).mkdir(parents=True, exist_ok=True)
    except OSError as _e:
        print(f"[warn] не создался кэш {_p}: {_e}")

TEST_IDS = ["m1_dlg_001", "m1_dlg_004", "m1_bark_001"]

# Характеристики персонажей: пост-обработка pitch/speed через resample.
# playback=0.8 → голос ниже и медленнее; 1.1 → выше и быстрее.
VOICE_PROFILES = {
    "Торвин": {"playback": 0.94, "exaggeration": 0.5},
    "Селена Вейн": {"playback": 1.08, "exaggeration": 0.45},
    "Стражник": {"playback": 1.00, "exaggeration": 0.35},
    "Гхарн": {"playback": 0.80, "exaggeration": 0.9},
    "Рассказчик": {"playback": 0.97, "exaggeration": 0.25},
}

_DTYPES = {
    "F32": "float32", "F16": "float16", "BF16": "bfloat16", "F64": "float64",
    "I64": "int64", "I32": "int32", "I16": "int16", "I8": "int8",
    "U8": "uint8", "BOOL": "bool",
}


def _setup_stdio() -> None:
    # В Git Bash stdout по умолчанию cp1251 — русские логи превращаются в мусор.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass


def _digest(*parts: object) -> str:
    return hashlib.sha1("|".join(str(p) for p in parts).encode("utf-8")).hexdigest()[:16]


def token_hash(text: str, speaker: str, kind: str, exag: float) -> str:
    return _digest("t3", speaker, kind, text, f"{exag:.3f}")


def ogg_hash(tok_hash: str, playback: float) -> str:
    return _digest("ogg", tok_hash, f"{playback:.4f}")


def profile(line: dict) -> dict:
    return VOICE_PROFILES.get(line["speaker"], VOICE_PROFILES["Торвин"])


def paths(test: bool) -> tuple[Path, Path, Path]:
    if test:
        return PREVIEW_DIR, PREVIEW_DIR, PREVIEW_DIR
    return TOKENS_DIR, WAV_DIR, OUT_DIR


def ckpt_dir() -> Path:
    """Локальный snapshot модели; если его нет — качаем."""
    hits = sorted(
        (HF_CACHE / "models--ResembleAI--chatterbox" / "snapshots").glob(
            "*/t3_mtl23ls_v2.safetensors")
    )
    if hits:
        # Оффлайн, чтобы китайский Cangjie-конвертер не ходил в сеть
        # (для русского он не нужен).
        os.environ["HF_HUB_OFFLINE"] = "1"
        return hits[-1].parent
    os.environ.pop("HF_HUB_OFFLINE", None)
    try:
        import huggingface_hub.constants as hf_const
        hf_const.HF_HUB_OFFLINE = False
    except Exception:  # noqa: BLE001
        pass
    from huggingface_hub import snapshot_download
    print("Весов нет в кэше — качаю с HF (~3 ГБ)...")
    return Path(snapshot_download(REPO_ID, allow_patterns=CKPT_FILES))


def stub_pkuseg() -> None:
    """pkuseg тянет модель в ~/.pkuseg и в сеть; для русского не нужен."""
    try:
        import spacy_pkuseg
    except ImportError:
        return

    class _Stub:
        def cut(self, text: str) -> list[str]:
            return [text]

    spacy_pkuseg.pkuseg = _Stub


def stream_into(model: "torch.nn.Module", path: Path, chunk_mb: int = 8) -> None:
    """Заливает safetensors в уже созданные параметры in-place.

    Обычный load_file строит вторую копию в RAM (её не хватает), поэтому
    читаем по чанкам и копируем прямо в параметры.
    """
    import torch

    target = model.state_dict()
    chunk_bytes = chunk_mb * 1024 * 1024
    with open(path, "rb") as f:
        n = struct.unpack("<Q", f.read(8))[0]
        header = json.loads(f.read(n))
        base = 8 + n
        keys = {k for k in header if k != "__metadata__"}
        missing = set(target) - keys
        extra = keys - set(target)
        if missing or extra:
            raise RuntimeError(
                f"keys mismatch: missing={len(missing)} extra={len(extra)}"
            )
        for name, info in header.items():
            if name == "__metadata__":
                continue
            t = target[name]
            dt = getattr(torch, _DTYPES[info["dtype"]])
            if t.dtype != dt:
                raise RuntimeError(f"{name}: model {t.dtype} vs file {dt}")
            start, _end = info["data_offsets"]
            f.seek(base + start)
            flat = t.view(-1)
            got = 0
            while got < flat.numel():
                nbytes = min(chunk_bytes, (flat.numel() - got) * t.element_size())
                raw = f.read(nbytes)
                if len(raw) != nbytes:
                    raise EOFError(f"{name}: короткое чтение")
                buf = torch.frombuffer(bytearray(raw), dtype=dt)
                flat[got:got + buf.numel()].copy_(buf)
                got += buf.numel()


def run_ffmpeg(args: list[str]) -> None:
    res = subprocess.run([str(FFMPEG), "-y", "-loglevel", "error"] + args,
                         capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg: {res.stderr.strip()}")


def trim_silence(wav, sr: int, aggressive: bool):
    """Срезает тишину по краям; для барков — ещё и болтовню после первой паузы."""
    import numpy as np

    frame = max(1, int(sr * 0.02))
    n = len(wav) // frame
    if n < 10:
        return wav
    rms = np.sqrt((wav[:n * frame].reshape(n, frame) ** 2).mean(axis=1))
    voiced = rms > 0.012

    start = 0
    while start < n and not voiced[start]:
        start += 1
    start = max(0, start - 2)              # 40 мс до начала
    end = n
    while end > start and not voiced[end - 1]:
        end -= 1
    end = min(n, end + 5)                  # 100 мс после конца

    if aggressive:
        gap = int(0.40 / 0.02)
        i = start
        while i < end:
            if not voiced[i]:
                j = i
                while j < end and not voiced[j]:
                    j += 1
                if j - i >= gap:           # первая пауза длиннее 0.4 с
                    end = min(end, i + 6)  # оставляем 120 мс хвоста
                    break
                i = j
            else:
                i += 1

    if end - start < 5:
        return wav
    return wav[start * frame:min(len(wav), end * frame)]


def _loudnorm_json(wav: Path, playback: float) -> dict | None:
    """Первый проход loudnorm: измеряем громкость уже после сдвига питча."""
    chain = (
        f"asetrate=24000*{playback:.6f},aresample=22050,"
        f"loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json"
    )
    res = subprocess.run([str(FFMPEG), "-hide_banner", "-nostats",
                          "-i", str(wav), "-af", chain, "-f", "null", "-"],
                         capture_output=True, text=True)
    text = res.stderr
    start, end = text.rfind("{"), text.rfind("}")
    if res.returncode != 0 or start < 0 or end < start:
        return None
    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None


def postprocess(wav: Path, ogg_out: Path, playback: float) -> None:
    """wav → ogg: питч asetrate, выравнивание громкости, vorbis 22 кГц.

    loudnorm в один проход врёт на коротких клипах, а линейный режим не может
    поднять громкость у клипов с пиком под 0 dBFS. Поэтому измеряем EBU R128
    и применяем точный gain; если пик не даёт — дожимаем alimiter без makeup.
    """
    base = f"asetrate=24000*{playback:.6f},aresample=22050"
    m = _loudnorm_json(wav, playback)
    chain = f"{base},loudnorm=I=-16:TP=-1.5:LRA=9"
    if m:
        try:
            lufs = float(m["input_i"])
        except (KeyError, TypeError, ValueError):
            lufs = float("-inf")
        if lufs > -70.0:
            gain = -16.0 - lufs
            # Safety-лимитер нужен всегда: Vorbis добавляет межсэмпловые
            # выбросы до ~+1.5 дБ, поэтому потолок -3 dBFS.
            chain = (f"{base},volume={gain:.2f}dB,"
                     f"alimiter=limit=0.708:level=0:attack=5:release=50")
    run_ffmpeg(["-i", str(wav), "-af", chain,
                "-ar", "22050", "-c:a", "libvorbis", "-q:a", "4",
                str(ogg_out)])


def select_lines(args: argparse.Namespace) -> list[dict]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    lines = data["lines"]
    if args.only:
        lines = [l for l in lines if l["id"] == args.only]
        if not lines:
            raise SystemExit(f"id '{args.only}' не найден")
    if args.speaker:
        lines = [l for l in lines if l["speaker"] == args.speaker]
    if args.test:
        lines = [l for l in lines if l["id"] in TEST_IDS]
        if not lines:
            raise SystemExit("test ids не найдены в манифесте")
    return lines


def stage_t3(lines: list[dict], test: bool, force: bool) -> int:
    tok_dir, _wav_dir, _out_dir = paths(test)
    tok_dir.mkdir(parents=True, exist_ok=True)

    work = []
    for ln in lines:
        prof = profile(ln)
        h = token_hash(ln["text"], ln["speaker"], ln["kind"],
                       float(prof["exaggeration"]))
        tok_file = tok_dir / f"{ln['id']}.tokens.pt"
        meta = tok_dir / f"{ln['id']}.tok.meta.json"
        if not force and tok_file.exists() and meta.exists():
            try:
                if json.loads(meta.read_text(encoding="utf-8"))["hash"] == h:
                    continue
            except (json.JSONDecodeError, KeyError, OSError):
                pass
        work.append((ln, prof, h, tok_file, meta))

    if not work:
        print("T3: все токены в кэше")
        return 0

    import torch
    from chatterbox.models.t3 import T3
    from chatterbox.models.t3.modules.t3_config import T3Config
    from chatterbox.models.t3.modules.cond_enc import T3Cond
    from chatterbox.models.tokenizers import MTLTokenizer
    from chatterbox.mtl_tts import Conditionals, punc_norm

    stub_pkuseg()
    ckpt = ckpt_dir()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    if device == "cpu":
        print("[warn] CUDA нет — T3 на CPU будет очень медленным")

    t0 = time.time()
    tokenizer = MTLTokenizer(str(ckpt / "grapheme_mtl_merged_expanded_v1.json"))
    conds = Conditionals.load(ckpt / "conds.pt", map_location="cpu")
    print(f"T3 ({device}): строю модель...")
    with torch.device(device):
        t3 = T3(T3Config.multilingual())
    stream_into(t3, ckpt / "t3_mtl23ls_v2.safetensors")
    t3.eval()
    conds.t3 = conds.t3.to(device=device)
    if device == "cuda":
        torch.cuda.synchronize()
    print(f"T3 готов за {time.time() - t0:.1f} c")

    failed = 0
    for i, (ln, prof, h, tok_file, meta) in enumerate(work, 1):
        try:
            text = punc_norm(ln["text"])
            tok = tokenizer.text_to_tokens(text, language_id="ru").to(t3.device)
            tok = torch.cat([tok, tok], dim=0)  # CFG: cond + uncond
            tok = torch.nn.functional.pad(tok, (1, 0), value=t3.hp.start_text_token)
            tok = torch.nn.functional.pad(tok, (0, 1), value=t3.hp.stop_text_token)
            exag = float(prof["exaggeration"])
            t3_cond = T3Cond(
                speaker_emb=conds.t3.speaker_emb,
                cond_prompt_speech_tokens=conds.t3.cond_prompt_speech_tokens,
                emotion_adv=exag * torch.ones(1, 1, 1, device=t3.device),
            )
            t1 = time.time()
            speech = None
            # Барки короткие: без лимита модель «договаривает» до 6-7 секунд.
            max_new = 96 if ln["kind"] == "bark" else 600
            for attempt in (1, 2):
                try:
                    with torch.inference_mode():
                        speech = t3.inference(
                            t3_cond=t3_cond, text_tokens=tok, max_new_tokens=max_new,
                            temperature=0.8, cfg_weight=0.5, repetition_penalty=2.0,
                            min_p=0.05, top_p=1.0,
                        )
                    break
                except torch.OutOfMemoryError:
                    if attempt == 2 or device != "cuda":
                        raise
                    gc.collect()
                    torch.cuda.empty_cache()
                    time.sleep(2)
            speech = speech[0].cpu()
            if speech.numel() == 0:
                raise RuntimeError("пустой результат T3")
            torch.save(speech, tok_file)
            meta.write_text(
                json.dumps({"hash": h, "speaker": ln["speaker"], "text": ln["text"]},
                           ensure_ascii=False),
                encoding="utf-8")
            print(f"[{i}/{len(work)}] {ln['id']}: {speech.numel()} токенов "
                  f"за {time.time() - t1:.1f} c")
        except Exception as e:  # noqa: BLE001 — не валим весь прогон
            failed += 1
            print(f"[{i}/{len(work)}] {ln['id']} ОШИБКА: {e}")
    print(f"T3: готово={len(work) - failed} ошибок={failed}")
    return 1 if failed else 0


def _is_oom(e: Exception) -> bool:
    return "out of memory" in str(e).lower()


def stage_voc(lines: list[dict], test: bool, force: bool) -> int:
    tok_dir, wav_dir, out_dir = paths(test)
    for d in (tok_dir, wav_dir, out_dir):
        d.mkdir(parents=True, exist_ok=True)

    work = []
    for ln in lines:
        prof = profile(ln)
        th = token_hash(ln["text"], ln["speaker"], ln["kind"],
                        float(prof["exaggeration"]))
        oh = ogg_hash(th, float(prof["playback"]))
        tok_file = tok_dir / f"{ln['id']}.tokens.pt"
        tok_meta = tok_dir / f"{ln['id']}.tok.meta.json"
        ogg = out_dir / f"{ln['id']}.ogg"
        meta = out_dir / f"{ln['id']}.meta.json"
        if not force and ogg.exists() and meta.exists():
            try:
                if json.loads(meta.read_text(encoding="utf-8"))["hash"] == oh:
                    continue
            except (json.JSONDecodeError, KeyError, OSError):
                pass
        if not tok_file.exists():
            print(f"[skip] {ln['id']}: нет токенов — сначала --stage t3")
            continue
        try:
            if json.loads(tok_meta.read_text(encoding="utf-8"))["hash"] != th:
                print(f"[skip] {ln['id']}: токены устарели — сначала --stage t3")
                continue
        except (json.JSONDecodeError, KeyError, OSError):
            print(f"[skip] {ln['id']}: нет меты токенов — сначала --stage t3")
            continue
        work.append((ln, prof, oh, tok_file, ogg, meta))

    if not work:
        print("S3Gen: всё в кэше")
        return 0

    import torch
    from chatterbox.models.s3gen import S3Gen, S3GEN_SR
    from chatterbox.models.s3tokenizer import drop_invalid_tokens
    from chatterbox.mtl_tts import Conditionals
    import soundfile as sf

    ckpt = ckpt_dir()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    t0 = time.time()
    try:
        with torch.device(device):
            s3gen = S3Gen()
        state = torch.load(ckpt / "s3gen.pt", map_location="cpu",
                           weights_only=True, mmap=True)
        s3gen.load_state_dict(state)
        del state
        s3gen.to(device).eval()
        conds = Conditionals.load(ckpt / "conds.pt", map_location="cpu").to(device)
        print(f"S3Gen: готов за {time.time() - t0:.1f} c ({device})")
    except (torch.OutOfMemoryError, RuntimeError) as e:
        if not _is_oom(e) or device == "cpu":
            raise
        print(f"[warn] S3Gen не влез на GPU ({e}) — перехожу на CPU")
        gc.collect()
        torch.cuda.empty_cache()
        device = "cpu"
        s3gen = S3Gen()
        state = torch.load(ckpt / "s3gen.pt", map_location="cpu",
                           weights_only=True, mmap=True)
        s3gen.load_state_dict(state)
        del state
        s3gen.eval()
        conds = Conditionals.load(ckpt / "conds.pt", map_location="cpu").to(device)
        print(f"S3Gen: готов за {time.time() - t0:.1f} c (cpu)")

    failed = 0
    for i, (ln, prof, oh, tok_file, ogg, meta) in enumerate(work, 1):
        try:
            speech = torch.load(tok_file, weights_only=True)
            speech = drop_invalid_tokens(speech)
            t1 = time.time()
            wav = None
            for attempt in (1, 2):
                try:
                    with torch.inference_mode():
                        wav, _ = s3gen.inference(
                            speech_tokens=speech.to(device), ref_dict=conds.gen)
                    break
                except (torch.OutOfMemoryError, RuntimeError) as e:
                    if attempt == 2 or device != "cuda" or not _is_oom(e):
                        raise
                    gc.collect()
                    torch.cuda.empty_cache()
                    time.sleep(2)
            wav = wav.squeeze(0).float().cpu()
            samples = trim_silence(wav.numpy(), S3GEN_SR,
                                   aggressive=(ln["kind"] == "bark"))
            wav_file = wav_dir / f"{ln['id']}.wav"
            sf.write(str(wav_file), samples, S3GEN_SR)
            postprocess(wav_file, ogg, float(prof["playback"]))
            meta.write_text(
                json.dumps({"hash": oh, "speaker": ln["speaker"], "text": ln["text"]},
                           ensure_ascii=False),
                encoding="utf-8")
            print(f"[{i}/{len(work)}] {ln['id']}: {len(samples) / S3GEN_SR:.1f} c "
                  f"за {time.time() - t1:.1f} c")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"[{i}/{len(work)}] {ln['id']} ОШИБКА: {e}")
    print(f"S3Gen: готово={len(work) - failed} ошибок={failed}")
    return 1 if failed else 0


def main() -> int:
    _setup_stdio()
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="генерить только одну реплику по id")
    ap.add_argument("--speaker", help="только один спикер")
    ap.add_argument("--force", action="store_true", help="без кэша")
    ap.add_argument("--list-missing", action="store_true")
    ap.add_argument("--test", action="store_true", help="3 пробы в tools\\voice_preview")
    ap.add_argument("--stage", choices=("t3", "voc"), help="внутреннее: одна стадия")
    args = ap.parse_args()

    lines = select_lines(args)
    test = args.test
    _tok_dir, _wav_dir, out_dir = paths(test)

    if args.list_missing:
        missing = [ln["id"] for ln in lines
                   if not (out_dir / f"{ln['id']}.ogg").exists()]
        for mid in missing:
            print("MISSING", mid)
        print(f"итого missing: {len(missing)} / {len(lines)}")
        return 0

    if args.stage == "t3":
        return stage_t3(lines, test, args.force)
    if args.stage == "voc":
        return stage_voc(lines, test, args.force)

    # Две стадии — двумя процессами: так GPU-память и host commit
    # освобождаются между T3 и S3Gen полностью.
    child = [sys.executable, str(Path(__file__).resolve())]
    if args.only:
        child += ["--only", args.only]
    if args.speaker:
        child += ["--speaker", args.speaker]
    if args.force:
        child.append("--force")
    if test:
        child.append("--test")
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    for stage in ("t3", "voc"):
        print(f"=== стадия {stage} ===")
        rc = subprocess.call(child + ["--stage", stage], env=env)
        if rc != 0:
            return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
