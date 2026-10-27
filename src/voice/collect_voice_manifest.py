#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Собирает реестр реплик для озвучки: assets/text/voice_manifest.json.

Источники:
  * scripts/mission3d.gd — все вызовы hud.say([...{"name","text"}...])
  * assets/text/lore.json — barks / notes / items (голос рассказчика)

Манифест: {"version", "speakers": {...описание голосов...},
           "lines": [{id, speaker, text, source, priority}]}
id стабильные: m1_dlg_001..., m1_bark_01..., m1_note_01..., m1_item_01...
Кэш генератора звука опирается на id, поэтому порядок важен и_locked: новые
реплики добавляются в конец своей группы, существующие id не меняются.

Запуск:
    python src/voice/collect_voice_manifest.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]
MISSION = BASE / "scripts" / "mission3d.gd"
LORE = BASE / "assets" / "text" / "lore.json"
OUT = BASE / "assets" / "text" / "voice_manifest.json"

SPEAKERS = {
    "Торвин": {"sex": "male", "note": "низкий мужской, гном, живой"},
    "Селена Вейн": {"sex": "female", "note": "женский, усталая горечь"},
    "Гхарн": {"sex": "male", "note": "рычащий низкий босс"},
    "Стражник": {"sex": "male", "note": "армейские реплики, мрачный"},
    "Рассказчик": {"sex": "male", "note": "за кадром, записки/предметы/барки"},
}

# Нормализация спикеров из кода.
ALIASES = {
    "Селена Вейн": "Селена Вейн",
    "Гхарн": "Гхарн",
    "Стражник": "Стражник",
    "Стража": "Стражник",
    "Торвин": "Торвин",
}

PAREN_RE = re.compile(r"hud\.say\(")


def load_existing_ids() -> dict[tuple[str, str, str], str]:
    """Ключ (kind, speaker, text) → id из прошлого манифеста.

    Реплика с тем же текстом сохраняет id, поэтому кэш озвучки не
    инвалидируется, когда меняются соседние строки.
    """
    if not OUT.exists():
        return {}
    try:
        data = json.loads(OUT.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    out: dict[tuple[str, str, str], str] = {}
    for ln in data.get("lines", []) if isinstance(data, dict) else []:
        if not isinstance(ln, dict):
            continue
        text = str(ln.get("text", ""))
        id_ = str(ln.get("id", ""))
        if text and id_:
            key = (str(ln.get("kind", "")), str(ln.get("speaker", "")), text)
            out.setdefault(key, id_)
    return out


def assign_id(prefix: str, used: set[str]) -> str:
    n = 1
    while f"{prefix}_{n:03d}" in used:
        n += 1
    return f"{prefix}_{n:03d}"


def balanced_block(text: str, start: int) -> str:
    """Возвращает содержимое скобок вызова, начиная со '[' или '{'."""
    i = start + len("hud.say(")
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    if i >= len(text) or text[i] not in "[{":
        return ""
    open_ch = text[i]
    close_ch = {"[": "]", "{": "}"}[open_ch]
    depth = 0
    j = i
    while j < len(text):
        c = text[j]
        if c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
            if depth == 0 and c == close_ch:
                return text[i + 1:j]
        j += 1
    return ""


DICT_RE = re.compile(r"\{[^{}]*\}")


def extract_name_text(block: str) -> list[tuple[str, str]]:
    """Вытаскивает пары (name, text) из словарей внутри блока."""
    out = []
    for d in DICT_RE.findall(block):
        nm = re.search(r'"name"\s*:\s*"([^"]*)"', d)
        tx = re.search(r'"text"\s*:\s*"((?:[^"\\]|\\.)*)"', d)
        if tx:
            name = nm.group(1) if nm else "Торвин"
            # Тело строки — это JSON-строка: json.loads корректно снимает
            # \" и \n и сохраняет кириллицу (unicode_escape её ломал).
            raw = tx.group(1)
            try:
                text = json.loads(f'"{raw}"')
            except json.JSONDecodeError:
                text = raw.replace('\\"', '"')
            out.append((name, text.strip()))
    return out


def collect_dialog_lines() -> list[tuple[str, str]]:
    src = MISSION.read_text(encoding="utf-8")
    pairs = []
    for m in PAREN_RE.finditer(src):
        block = balanced_block(src, m.start())
        pairs.extend(extract_name_text(block))
    return pairs


def collect_lore_lines(data: dict) -> dict[str, list[dict]]:
    res: dict[str, list[dict]] = {}
    barks = data.get("barks") or []
    if isinstance(barks, dict):
        barks = [b for _, b in sorted(barks.items())]
    res["bark"] = [b if isinstance(b, dict) else {"text": str(b)} for b in barks]
    res["note"] = [n for n in (data.get("notes") or []) if isinstance(n, dict)]
    res["item"] = [i for i in (data.get("items") or []) if isinstance(i, dict)]
    return res


def text_of(entry: dict, *keys: str) -> str:
    for k in keys:
        v = entry.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def main() -> None:
    lines: list[dict] = []

    for name, text in collect_dialog_lines():
        speaker = ALIASES.get(name, "Рассказчик")
        lines.append({"speaker": speaker, "text": text,
                      "source": "mission3d.gd", "kind": "dlg"})

    lore = json.loads(LORE.read_text(encoding="utf-8"))
    groups = collect_lore_lines(lore)
    for entry in groups.get("bark", []):
        text = text_of(entry, "text", "text_en", "phrase")
        if not text:
            continue
        speaker = ALIASES.get(str(entry.get("who", "")), "Стражник")
        lines.append({"speaker": speaker, "text": text,
                      "source": "lore.json#barks", "kind": "bark"})
    for entry in groups.get("note", []):
        text = text_of(entry, "text")
        if not text:
            continue
        lines.append({"speaker": "Рассказчик", "text": text,
                      "source": "lore.json#notes", "kind": "note"})
    for entry in groups.get("item", []):
        text = text_of(entry, "desc")
        if not text:
            continue
        # Текст ДОЛЖЕН совпадать с тем, что миссия передаёт в hud.say
        # (описание без префикса), иначе матчинг озвучки не сработает.
        lines.append({"speaker": "Рассказчик", "text": text,
                      "source": "lore.json#items", "kind": "item"})

    counters: dict[str, int] = {}
    existing = load_existing_ids()
    # Сначала резервируем id, которые переиспользуются: иначе новая строка
    # может занять номер, который через пару строк достанется старой.
    used: set[str] = {id_ for ln in lines
                      if (id_ := existing.get((ln["kind"], ln["speaker"], ln["text"]), ""))}
    assigned: set[str] = set()
    for ln in lines:
        prefix = {"dlg": "m1_dlg", "bark": "m1_bark",
                  "note": "m1_note", "item": "m1_item"}[ln["kind"]]
        id_ = existing.get((ln["kind"], ln["speaker"], ln["text"]), "")
        if not id_ or id_ in assigned:
            id_ = assign_id(prefix, used)
        counters[prefix] = counters.get(prefix, 0) + 1
        ln["id"] = id_
        assigned.add(id_)
        used.add(id_)
        ln["priority"] = 1 if ln["kind"] == "dlg" else 3

    manifest = {
        "version": 1,
        "note": "Генерится src/voice/collect_voice_manifest.py; id стабильные, "
                "не перенумеровывать — на них завязан кэш озвучки.",
        "speakers": SPEAKERS,
        "lines": lines,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")

    by_sp: dict[str, int] = {}
    for ln in lines:
        by_sp[ln["speaker"]] = by_sp.get(ln["speaker"], 0) + 1
    chars = sum(len(ln["text"]) for ln in lines)
    print(f"Всего реплик: {len(lines)}  (~{chars} символов)")
    for sp, n in sorted(by_sp.items(), key=lambda kv: -kv[1]):
        print(f"  {sp}: {n}")
    print(f"Записан: {OUT.relative_to(BASE)}")


if __name__ == "__main__":
    main()
