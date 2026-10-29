# Звук: источники и лицензии

Правило: **каждый звуковой файл игры имеет здесь строку** — источник и лицензию.
Новый звук без строки не коммитим. Проверка: `debug/audio_check.gd` ищет имя каждого
файла из `res://audio/` и `res://assets/audio/` в этом документе.

Подробности по моделям и текстурам — в `assets/CREDITS.md`.

## Атмосфера подземелья, этап 10 (`res://audio/`)

Генератор: `src/audio/build_ambience.py`. Синтез — свой код проекта (numpy), внешних
лицензий нет, коммерческое использование без ограничений. Шаги по камню и дереву —
CC0-пак Kenney «Impact Sounds» (<https://kenney.nl/assets/impact-sounds>, `License.txt`
в архиве `tools/cc0/impact`), прогнанный через ffmpeg loudnorm до −14 LUFS.

| Файл | Что это | Источник | Лицензия |
|---|---|---|---|
| `ambience/room_tone.wav` | тон помещения, луп 30 с (шина Ambience) | синтез, `build_room_tone` | своё |
| `ambience/torch_crackle.wav` | треск факела, луп 8 с | синтез, `build_torch_crackle` | своё |
| `ambience/drip_0.wav` | капля о лужу | синтез, `build_drip` | своё |
| `ambience/drip_1.wav` | капля о лужу | синтез, `build_drip` | своё |
| `ambience/drip_2.wav` | капля о лужу | синтез, `build_drip` | своё |
| `oneshots/rumble_distant_0.wav` | далёкий гул обвала | синтез, `build_rumble` | своё |
| `oneshots/rumble_distant_1.wav` | далёкий гул обвала | синтез, `build_rumble` | своё |
| `oneshots/chain_clink_0.wav` | звон звеньев цепи | синтез, `build_chain_clink` | своё |
| `oneshots/chain_clink_1.wav` | звон звеньев цепи | синтез, `build_chain_clink` | своё |
| `oneshots/rat_squeak_0.wav` | писк крысы и коготки | синтез, `build_rat_squeak` | своё |
| `oneshots/rat_squeak_1.wav` | писк крысы и коготки | синтез, `build_rat_squeak` | своё |
| `oneshots/stone_fall_0.wav` | камешек со свода, осыпь | синтез, `build_stone_fall` | своё |
| `oneshots/stone_fall_1.wav` | камешек со свода, осыпь | синтез, `build_stone_fall` | своё |
| `oneshots/drip_distant_0.wav` | далёкая капель | синтез, `build_drip_distant` | своё |
| `oneshots/drip_distant_1.wav` | далёкая капель | синтез, `build_drip_distant` | своё |
| `footsteps/step_water_0.wav` | шаг по луже | синтез, `build_step_water` | своё |
| `footsteps/step_water_1.wav` | шаг по луже | синтез, `build_step_water` | своё |
| `footsteps/step_water_2.wav` | шаг по луже | синтез, `build_step_water` | своё |
| `footsteps/step_water_3.wav` | шаг по луже | синтез, `build_step_water` | своё |
| `footsteps/step_stone_0.wav` | шаг по камню | Kenney Impact Sounds, `footstep_concrete_000.ogg` | CC0 |
| `footsteps/step_stone_1.wav` | шаг по камню | Kenney Impact Sounds, `footstep_concrete_001.ogg` | CC0 |
| `footsteps/step_stone_2.wav` | шаг по камню | Kenney Impact Sounds, `footstep_concrete_002.ogg` | CC0 |
| `footsteps/step_stone_3.wav` | шаг по камню | Kenney Impact Sounds, `footstep_concrete_003.ogg` | CC0 |
| `footsteps/step_stone_4.wav` | шаг по камню | Kenney Impact Sounds, `footstep_concrete_004.ogg` | CC0 |
| `footsteps/step_wood_0.wav` | шаг по дереву | Kenney Impact Sounds, `footstep_wood_000.ogg` | CC0 |
| `footsteps/step_wood_1.wav` | шаг по дереву | Kenney Impact Sounds, `footstep_wood_001.ogg` | CC0 |
| `footsteps/step_wood_2.wav` | шаг по дереву | Kenney Impact Sounds, `footstep_wood_002.ogg` | CC0 |
| `footsteps/step_wood_3.wav` | шаг по дереву | Kenney Impact Sounds, `footstep_wood_003.ogg` | CC0 |
| `footsteps/step_wood_4.wav` | шаг по дереву | Kenney Impact Sounds, `footstep_wood_004.ogg` | CC0 |

## Музыка и SFX до этапа 10 (`res://assets/audio/`)

Сначала всё синтезирует `src/audio/build_audio.py` (своё, без лицензий), затем
`src/audio/build_audio_samples.py` перезаписывает часть файлов слоями из паков.
Итоговый источник каждого файла — по таблице `MAPPING` в `build_audio_samples.py`.

| Файл | Источник | Лицензия |
|---|---|---|
| `amb_prison.wav` | синтез `build_audio.py` | своё |
| `music_menu.wav` | синтез `build_audio.py` | своё |
| `music_boss.wav` | синтез `build_audio.py` | своё |
| `sfx_step_1.wav` | Kenney Impact Sounds | CC0 |
| `sfx_step_2.wav` | Kenney Impact Sounds | CC0 |
| `sfx_step_3.wav` | Kenney Impact Sounds | CC0 |
| `sfx_hit.wav` | Kenney Impact Sounds | CC0 |
| `sfx_hit_heavy.wav` | Kenney Impact Sounds | CC0 |
| `sfx_cast.wav` | Kenney RPG Audio + Impact Sounds | CC0 |
| `sfx_absorb.wav` | Kenney RPG Audio + Impact Sounds | CC0 |
| `sfx_chain.wav` | Kenney Impact Sounds | CC0 |
| `sfx_door.wav` | Kenney RPG Audio + Impact Sounds | CC0 |
| `sfx_gate_open.wav` | Kenney RPG Audio + Impact Sounds | CC0 |
| `sfx_lowmagic.wav` | Kenney RPG Audio | CC0 |
| `sfx_trust.wav` | Kenney RPG Audio | CC0 |
| `sfx_win.wav` | Kenney Impact Sounds | CC0 |
| `sfx_click.wav` | Kenney RPG Audio | CC0 |
| `sfx_swing.wav` | OpenGameArt «Swishes» (artisticdude) | **не подтверждена** |
| `sfx_alert.wav` | OpenGameArt «Monster Sounds vol.2» (Ogrebane) | **не подтверждена** |
| `sfx_boss_roar.wav` | OpenGameArt «Monster Sounds vol.2» (Ogrebane) | **не подтверждена** |
| `sfx_death.wav` | OpenGameArt «Monster Sounds vol.2» (Ogrebane) | **не подтверждена** |
| `sfx_heartbeat.wav` | OpenGameArt «Heartbeat» (bart) | **не подтверждена** |

**Блокер релиза (из `assets/CREDITS.md`):** у четырёх паков OpenGameArt в архивах нет
`License.txt`. Пока лицензия не найдена, эти пять файлов не считаются разрешёнными к
коммерческому использованию — заменить на Kenney или найти страницы паков.

## Озвучка (`res://assets/audio/voice/`)

Синтез локальной TTS-моделью Chatterbox (ResembleAI, MIT) скриптом
`src/voice/build_voice.py`; тексты реплик — свои. Коммерческое использование разрешено.

| Файлы | Источник | Лицензия |
|---|---|---|
| m1_bark_001.ogg, m1_bark_002.ogg, m1_bark_003.ogg, m1_bark_004.ogg, m1_bark_005.ogg, m1_bark_006.ogg, m1_bark_007.ogg, m1_bark_008.ogg, m1_bark_009.ogg, m1_bark_010.ogg | Chatterbox TTS | MIT (модель), текст свой |
| m1_dlg_001.ogg, m1_dlg_002.ogg, m1_dlg_003.ogg, m1_dlg_004.ogg, m1_dlg_005.ogg, m1_dlg_006.ogg, m1_dlg_007.ogg, m1_dlg_008.ogg, m1_dlg_009.ogg, m1_dlg_010.ogg, m1_dlg_011.ogg, m1_dlg_012.ogg, m1_dlg_013.ogg, m1_dlg_014.ogg, m1_dlg_015.ogg, m1_dlg_016.ogg, m1_dlg_017.ogg, m1_dlg_018.ogg | Chatterbox TTS | MIT (модель), текст свой |
| m1_item_001.ogg, m1_item_002.ogg, m1_item_003.ogg, m1_item_004.ogg, m1_item_005.ogg, m1_item_006.ogg | Chatterbox TTS | MIT (модель), текст свой |
| m1_note_001.ogg, m1_note_002.ogg, m1_note_003.ogg, m1_note_004.ogg | Chatterbox TTS | MIT (модель), текст свой |
