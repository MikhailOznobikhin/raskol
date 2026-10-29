# Источники и лицензии ассетов

Правило проекта: **каждый внешний ассет (модель, текстура, звук, шрифт) обязан иметь
строку в этой таблице**. Если лицензия требует атрибуции (CC-BY, OFL, «non-commercial
with credit») — имя автора и ссылка идут в титры игры, а не только сюда.

## 3D-модели (`assets/*.glb`)

| Файл | Что это | Источник | Автор | Лицензия |
|---|---|---|---|---|
| `player.glb` | Герой: бородатый риг + 24 клипа (`Idle/Walk/Run/Sword_Slash/Roll/HitRecieve/Death`), кость `Wrist.R` | Poly Pizza, «Adventurer» — <https://poly.pizza/m/5EGWBMpuXq> | Quaternius | CC0 |
| `guard.glb` | Страж: скелет, риг + 5 клипов (`Skeleton_Idle/Attack/Death/Running/Spawn`) | Poly Pizza, «Skeleton» — <https://poly.pizza/m/wODZYCgX5Z> | Quaternius | CC0 |
| `monster.glb` | Босс «Пожиратель»: дракон, риг + 8 клипов (`Flying_Idle/Headbutt/Fast_Flying/Death`) | Poly Pizza, «Dragon Evolved» — <https://poly.pizza/m/LlwD0QNUPj> | Quaternius | CC0 |
| `weapon_hammer.glb` | Молот героя (статичный меш, узел `Hammer_Double`) | Poly Pizza, «Doublesided Hammer» — <https://poly.pizza/m/UIXvQ73DS1> | Quaternius | CC0 |
| `weapon_sword.glb` | Меч (статичный меш, в геймплее не используется — запас) | Poly Pizza, «Sword» — <https://poly.pizza/m/9lLmH8Et4K> | Quaternius | CC0 |
| `guard_zombie.glb` | **Запас**, в игре не используется: mixamo-риг, 13 клипов (`Walk/Attack/Die/Scream`) | Poly Pizza (страница не сохранилась) | уточнить | уточнить |

Все модели Quaternius — CC0: атрибуция не обязательна, но автора указываем в титрах
из уважения к труду. Коммерческое использование CC0 разрешает.

Готовой CC0-модели **гнома** с этим ригом нет (саб-агент проверял Quaternius, KayKit,
Mixamo и Sketchfab), поэтому шляпа Торвина собрана из примитивов кодом в
`scripts/gnome_kit.gd` и висит на кости `Head`. Внешних ассетов там нет — лицензия не нужна.

Проверка моделей перед сборкой: `.\build.ps1 -Models` (или входит в `-Test`).
Скрипт: `tools/check_models.py` — проверяет скин, клипы (`Idle/Walk/Run/Attack/Death`),
кость кисти для оружия и наличие записи в `ModelUtil.NATIVE_HEIGHT`.
Файлы из `RESERVE` в том же скрипте проверяются на читаемость, но не считаются ошибкой.

### Как добавить новую модель

1. Положить `.glb` в `assets/`, прогнать `--headless --path . --import`.
2. Измерить «натуральную» высоту: `--path . --resolution 512x512 --script tools/measure_models.gd`
   (печатает `native_h=…` по пикселям; внешний AABB у скиннованных мешей врёт).
3. Вписать высоту в `ModelUtil.NATIVE_HEIGHT` — иначе масштаб посчитается по AABB
   и персонаж окажется двухметровым или тридцатисантиметровым.
4. Проверить кадры: `--path . --resolution 640x640 --script tools/model_sheet.gd`
   (пишет `tools/sheet_<имя>.png`: вид спереди и сбоку рядом с эталоном 1.7 м).
5. Посмотреть новый ассет до установки: `--path . --resolution 700x700
   --script tools/model_preview.gd -- --model=res://assets/x.glb --tag=x --native=1.8`
   (три ракурса в `tools/x_0..2.png`).
6. Добавить строку в таблицу выше.

## Генерируемые ассеты

Текстуры (`assets/tex3d/*`), фон меню, кинематик-кадры и звук собираются кодом проекта:
`src/build_3d_textures.py`, `src/build_menu_bg.py`, `src/build_cinematic.py`,
`src/audio/build_audio.py` (запуск: `.\build.ps1 -Assets`). Внешних лицензий нет.

## Звуки из внешних сэмплов (`assets/audio/sfx_*.wav`)

Часть SFX собрана (`src/audio/build_audio_samples.py`) из готовых библиотек: берётся
слой, меняется громкость, `loudnorm` до −14 LUFS, на выходе 22050 Гц моно 16 bit.
Исходники лежат в `tools/cc0/` и в git не попадают — поэтому лицензия подтверждается
вот этой таблицей, а не файлом в репозитории.

| Пак | Автор / источник | Лицензия | Что из него звучит в игре |
|---|---|---|---|
| Impact Sounds 1.0 | Kenney (kenney.nl), `License.txt` в архиве | CC0 | удары, попадания, тяжёлый удар, цепь, ворота |
| RPG Audio | Kenney Vleugels (kenney.nl), `License.txt` в архиве | CC0 | шаги, поглощение плоти, магия, мало магии, UI |
| swishes | не подтверждён: в архиве нет `License.txt` и ссылки | **уточнить** | `sfx_swing` — взмах оружия, слышен постоянно |
| Monster Sounds Volume 2 | не подтверждён: в архиве нет `License.txt` и ссылки | **уточнить** | `sfx_alert`, `sfx_boss_roar`, `sfx_death` |
| heartbeat | не подтверждён: в архиве нет `License.txt` и ссылки | **уточнить** | `sfx_heartbeat` — пульс при низком здоровье |

**Блокер перед релизом:** три нижних строки идут под подписью «CC0» в комментарии к
скрипту, но подтверждения в архивах нет. Пока источник не найден, эти звуки нельзя
считать разрешёнными к коммерческому использованию — проще заменить на пакеты Kenney,
лицензия которых лежит рядом с файлами.

## AI-концепты (не в игре)

`assets/ai/` — 14 изображений, сгенерированных через Pollinations (Flux) по промптам
из `docs/prompts/`, с водяным знаком сервиса. В игру не подключены, используются как
референсы. Лицензия сервиса на генерации — свободное использование, водяной знак
удалять нельзя.

## Реквизит и декали этапа 8 (`assets/props3d/`, `textures/decals/`)

Скачаны 2026-10-29. Исходники — `tools/assets_incoming/stage8_cc0/` (вне git).
В репозитории лежат только glTF 1k с текстурами и собранные из них маски.

| Файл / что | Источник | Автор | Лицензия |
|---|---|---|---|
| `wine_barrel_01`, `wooden_barrels_01` (бочки и обломки бочек — «доски»), `wooden_crate_01/02`, `Shelf_01`, `wooden_bookshelf_worn`, `WoodenTable_01`, `round_wooden_table_01`, `wooden_stool_01/02`, `wooden_bucket_01/02`, `ceramic_pot`, `jug_01`, `wooden_bowl_01`, `carved_wooden_plate`, `wooden_candlestick`, `wooden_lantern_01`, `wooden_axe`, `ornate_medieval_mace`, `kite_shield`, `rock_07`, `rock_moss_set_01/02` | Poly Haven, <https://polyhaven.com/models> (страница модели = `https://polyhaven.com/a/<id>`) | авторы Poly Haven (указаны на странице модели) | CC0 |
| `Moss002` — цвет и нормаль мха (`moss_patch.png`, `moss_normal.png`) | ambientCG, <https://ambientcg.com/view?id=Moss002> | Lennart Demes | CC0 |
| `Leaking006` — маска мазка внутри копоти и потёков (`soot_streak.png`, `damp_streak.png`) | ambientCG, <https://ambientcg.com/view?id=Leaking006> | Lennart Demes | CC0 |
| `dirt_patch.png` | песок из пака подземелья (`assets/models/dungeon_kit/textures/sand_basecolor.jpg`) + маска кодом | — | как у пака |
| `crack_0..2.png` | сгенерированы кодом (`src/make_set_dressing.gd`) | — | внешней лицензии нет |

Скачано, но в игру не вошло: `Barrel_01` (современная бочка с маркировкой «взрывоопасно»),
`Leaking013A/016A` (капли на металле), `AsphaltDamage001` (заплатка асфальта).
