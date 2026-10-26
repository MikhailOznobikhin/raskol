# AGENTS.md — правила работы ИИ-агентов в этом репозитории

Читай этот файл перед любой правкой. Полная справка: `ROADMAP.md` (сборка,
грабли, дорожная карта) и `TASKS_AI.md` (формат карточек задач).

## Проект

3D-RPG от третьего лица на **Godot 4.4.1** (Forward+). Главная сцена:
`main3d.tscn` → `scripts/main3d.gd`. Герой/враги — риги из примитивов в коде,
уровень собирается из карты `assets/level/m1.txt` в `scripts/dungeon.gd`.
Баланс — только через `scripts/balance.gd`, сохранения — `scripts/save_system.gd`.

## Среда (Windows)

- Godot: `tools\godot\Godot_v4.4.1-stable_win64_console.exe`
- Python: `%USERPROFILE%\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe`
- Пересборка/тесты: `build.ps1` в корне (не набирай команды вручную).
- Перед запуском Godot в песочнице обязательно:
  `$env:APPDATA = "<проект>\tools\appdata"; $env:LOCALAPPDATA = "<проект>\tools\localappdata"` —
  без этого Godot не может создать пользовательские каталоги.

## Обязательная pipeline проверки

```powershell
.\build.ps1 -Import          1) регистрация class_name после добавления файлов
.\build.ps1 -Test            2) автотест: обязательно "TEST DONE escaped=true"
.\build.ps1 -Shots           3) скриншоты в tools\shot_3d_*.png (визуальные задачи)
```

Любая строка `SCRIPT ERROR` — блокер; закоммитить можно только при зелёном `[OK] TEST`.

## Жёсткие правила GDScript

1. Строгая типизация: нельзя `var x := load(...).new()` и `var r := clamp(...)` —
   пиши `var m: Node = ...`, `var r: float = clampf(...)`.
2. Не присваивай несуществующие свойства (у `MeshInstance3D` нет `billboard` —
   это `BaseMaterial3D.billboard_mode`).
3. НЕ подключать `SCREEN_TEXTURE` и `blend_mode=MUL`: в этом проекте это
   приводило к чёрному миру под HUD (см. `ROADMAP.md` §3.2).
4. HUD нарисован под 640×360 и масштабируется ×2 через `CanvasLayer.transform`;
   не меняй масштаб вьюпорта — 3D станет мыльным.
5. Тени: максимум 3–5 источников с `shadow_enabled`, иначе свет «исчезает».
6. Спавн не ближе ~5 м к стене — `SpringArm3D` камеры прилипает.

## Рабочий процесс

- Одна задача = правки только в перечисленных файлах (карточки в `TASKS_AI.md`).
- Один зелёный прогон `-Test` = один атомарный коммит
  (`T4: комбо из трёх ударов` — id карточки + суть).
- Комментарии в коде — по-русски, стиль как в соседних файлах.
- Скриншотами для проверки картинки верить только внутренним (`--shots`),
  не внешнему захвату экрана.
- PowerShell: инлайн-скрипты с кавычками ломаются — пиши временный `.py`/`.ps1`.
- L-задачи режь на 2–3 карточки M с проверкой между ними.
