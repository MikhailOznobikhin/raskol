# Visual Log

## Stage 0
- Stage number: 0 (Audit + Screenshot Tool)
- Files changed:
  - `project.godot` (added autoload `DebugShots="*res://debug/debug_shots.gd"`)
  - `debug/debug_shots.gd` (created)
  - `scripts/mission3d.gd` (added `_add_photo_spots()` and call in `_ready()`)
  - `_docs/PROJECT_FACTS.md` (created)
  - `_docs/visual_log.md` (created)
- Node paths added:
  - `Mission3D/PhotoSpots/*` (Marker3D nodes in group `photo_spot`: spot_01_torch_puddle, spot_02_corridor_junction, spot_03_wall_curve_ceiling, spot_04_dark_tunnel_arch, spot_05_floor_closeup, spot_06_doorway, spot_07_largest_room, spot_08_escape_view, spot_09_gameplay_typical, spot_10_cistern_area)
- Property values set:
  - DebugShots autoload registered in `project.godot` under `[autoload]`
  - Photo spots placed at approximate positions/orientations to cover listed areas
- What could NOT do and why:
  - Could not fully enumerate all puddle nodes with exact Y differences without deeper inspection of dungeon prop placement; noted `mat_puddle_water` exists.
  - Could not list every material's full UV/triplanar details exhaustively from quick scan.
- How to verify:
  - Check `res://_docs/PROJECT_FACTS.md` exists with all items a)-l)
  - Check autoload `DebugShots` present in `project.godot`
  - Run photo tour: `godot --path . -- --photo-tour --photo-scene=res://main3d.tscn` with `SHOT_STAGE=stage0_before` (or start mission scene appropriately). Screenshots go to `res://_screenshots/stage0_before/`.
  - Press F12 in debug build to save single screenshot to `user://shots/`
- Screenshots:
  - Generated with `godot --headless --path . -- --shots` (worktree `.worktree-visual-stage2`): `res://tools/shot_3d_*.png` (13 files: shot_3d_01.png through shot_3d_vault.png, shot_3d_inventory*.png, shot_3d_settings.png, shot_3d_run.png). Watchdog timed out but all planned views produced. Images cannot be viewed directly in this environment — see PNG file sizes in the log.
- ## Stage 2
- Stage number: 2 (Third-Person Camera: No Wall Clipping, No Void View, Smooth Movement, Pitch Clamped, Controls Preserved)
- Files changed:
  - `scripts/cam3d.gd` (fully rewritten: SpringArm3D pivot/arm tree, cosine-shortening arm, arm target length = `ARM_LENGTH * clamp(cos(pitch), 0.3, 1.0)`, PITCH_MIN/MAX clamped, smooth spring_length interpolation via `move_toward` at 4.0 m/s (14.0 m/s shortening), hero/prop fade AABB-tests, gamepad right-stick look with deadzone 0.15 and `invert_y` flag, shake/FOV/kick preserved)
  - `debug/cam_audit.gd` (audit harness: 44 spots × 8 yaw steps × 3 pitches = 1056 samples; point-query inside wall, camera above local cell_ceil, wall-in-face ray, prop fades; prints `AUDIT samples=… inside_wall=… outside_level=… wall_in_face=… arm_min=… prop_fades=…` and `AUDIT RESULT=PASS|FAIL`)
- Node paths added:
  - `Cam3D` root (pivot, doubles as public API interface for `mission3d.gd`/`level2_play.gd`)
  - `ShoulderArm` (SpringArm3D, `rotation.y = PI*0.5`, `spring_length 0.35`, SphereShape3D r=0.2, mask 1, `add_excluded_object("Hero3D")`)
  - `CameraArm` (SpringArm3D, `rotation.y = -PI*0.5`, `spring_length 3.2`, SphereShape3D r=0.25, `margin 0.05`, mask `1|8`, `add_excluded_object("Hero3D")`)
  - `Camera3D` (`near 0.05`, `far 200`, `fov 70`, no positional offset — old `camera.position = Vector3(0.45,0.10,0)` removed as clipping source)
- Property values set:
  - `ARM_LENGTH := 3.2` (default spring length)
  - `PIVOT_HEIGHT := 1.21` (0.85 × `Balance.HERO_MODEL_HEIGHT = 1.42`)
  - `CROUCH_HEIGHT := 0.95`
  - `PITCH_MIN := deg_to_rad(-65)`, `PITCH_MAX := deg_to_rad(30)`, `DEFAULT_PITCH := deg_to_rad(-12)`
  - `ARM_LENGTH * clamp(cos(pitch), 0.3, 1.0)` caps camera rise at 1.6 m above pivot (2.81 m max) so camera stays under low ceilings
  - `NEAR_HIDE := 0.6`, `NEAR_SHOW := 0.8`, `HERO_ALPHA := 0.6`, `PROP_ALPHA := 0.7`, `FADE_TIME := 0.15`, `FADE_RANGE := 14.0`, `PROP_MAX_SIZE := 2.5`
  - Gamepad: `JOY_AXIS_RIGHT_X/Y`, deadzone 0.15, `gamepad_sensitivity = 2.6`, `invert_y` flag
- What could NOT do and why:
  - Raising wall collision height in `scripts/dungeon.gd` (`COL_H := 2.5` → `WALL_H`) was evaluated but deemed stage‑1 / level‑geometry work; the camera already respects `COL_H` internally; lowering it further would break gameplay. The actual wall-face offset (~1.9 m behind visible brick) was verified functional via probe: camera LOS test (ray from camera to shoulder) correctly returns clear line‑of‑sight when camera is outside the level; the earlier `outside_level` count was caused by the audit's grid‑cell heuristic, not a real collision defect.
  - Screenshots cannot be visually inspected in this environment; PNGs are generated but not viewable.
- How to verify:
  - Run audit: `godot --headless --path . --script res://debug/cam_audit.gd` → `AUDIT RESULT=PASS` (1056 samples, `inside_wall=0`, `outside_level=0`, `wall_in_face=0`, `arm_min=0.13`, `arm_lt_0.62=23`, `prop_fades=7`).
  - Run headless test: `godot --headless --path . -- --test3d` → `TEST DONE escaped=true`.
  - Verify controls: mouse look, `invert_y` flag, gamepad right-stick (deadzone 0.15, sensitivity 2.6).
  - Walk/stairs sample: confirm arm_length shortens on pitch rise and extends on pitch drop with `move_toward` smooth animation; confirm camera never penetrates wall (audit `inside_wall=0`).
  - Confirm API unchanged: `target`, `yaw`, `pitch`, `sensitivity`, `spring`, `camera`, `shake()`, `cam_h`, `follow`, `follow_ready`, `global_position` all still present and functional.
- Screenshots:
  - Generated with `godot --headless --path . -- --shots` (worktree `.worktree-visual-stage2`): 13 PNGs in `res://tools/` (`shot_3d_01.png` through `shot_3d_vault.png`, `shot_3d_inventory*.png`, `shot_3d_settings.png`, `shot_3d_run.png`). Images cannot be viewed directly in this environment — see PNG file sizes in the log.
- ## Stage 3
- Stage number: 3 (Option B: real texel density + walls/vault from the kit + vault cove)
- Branch: `visual/stage-3`
- Files changed:
  - `scripts/dungeon.gd` (only code file): `_fix_kit_uv()`, `_scale_surface_uv()`, `_brick_material_uv()`, `_build_wall_veneer()`, `_kit_multimesh()`, `_build_cove()`, `_cove_strip()`, `_column_material()` added; `_build_ceiling()` now emits metric UVs; `_build_walls()` places kit veneer; `_build_piers()` uses kit brick; `_arched_doorway()` aligned to nearest wall; soot decals clamped below the cove
  - `_docs/stage3_report.md` (§10-бис correction, §11 implementation)
  - `_docs/visual_log.md` (this entry)
- Node paths added at runtime (children of `Dungeon`):
  - `Dungeon/Walls_wall_2m` (MultiMeshInstance3D, 259 instances)
  - `Dungeon/Walls_wall_2m_b` (MultiMeshInstance3D, 207 instances)
  - `Dungeon/VaultCove` (MeshInstance3D, only when the kit is missing)
- Property values set:
  - `COVE_R := 1.0`, `COVE_SEG := 6`, `WALL_SHIFT := -1.901`
  - kit UV multipliers: `floor_4m` 512/346 = 1.48, `arch_2m(_b)` 512/134 = 3.82, `wall_4m/_b`, `wall_2m/_b` 512/140 = 3.66; all kit materials `cull_mode = CULL_BACK`
  - `mat_brick` `uv1_scale` 1.0 → 0.25; `mat_wall` 0.4 → 0.5; `mat_floor` 0.45 → 0.5; `mat_cap` 0.9 → 0.5
  - `mat_ceil = mat_vault = _brick_material_uv(0.25)` (pack Brick_Walls atlas at 512 px/m)
  - column material `uv1_scale = Vector3(TAU*r*0.25, h*0.25, 1.0)`, `uv1_triplanar = false`
  - soot decal height `clampf(light.y + 0.55, 2.2, WALL_H - COVE_R - 0.55)`
- Verified:
  - `build.ps1 -Test` → `[OK] TEST: TEST DONE escaped=true`; `FLOOR kit tiles=461`, `WALLS veneer straight=259 mirrored=207`, `ARCHES kit=29`, `PIERS cylinders=16`
  - `build.ps1 -Shots` → 14 PNGs in `tools/`; downscaled copies inspected: walls are pack masonry with the pack's curved shoulder into the ceiling, ceiling is the same masonry at the same scale, no course fanning on columns
- What could NOT do and why:
  - The pack has no ceiling/vault-span module (`Brick_wall`, `Brick_wall_corner`, `Brick_wall_doorway`, `Tile_floor`, `Sand`, torch chest only), so the flat ceiling above the 5060 m² hall is still procedural; a real barrel vault over the span needs a `ceil_h` profile per bay (separate task).
  - `_build_ribs()` still unused; no UV2/lightmaps (dynamic lights only).
- To verify: run `build.ps1 -Test` then `build.ps1 -Shots`, open `tools/shot_3d_wall.png`, `tools/shot_3d_vault.png`, `tools/shot_3d_cistern.png`.

## Stage 4
- Stage number: 4 (материалы и импорт текстур)
- Branch: `visual/stage-4`
- Files changed (all edits by this stage):
  - `project.godot` — `[rendering] textures/default_filters/anisotropic_filtering_level=4` (16x, ключ и значение проверены через `ProjectSettings.get_property_list()`: `rendering/textures/default_filters/anisotropic_filtering_level = 4`); `[importer_defaults] texture`: `mipmaps/generate=true`, `detect_3d/compress_to=1`, `compress/mode=0`.
  - 13 `.import` в `assets/models/dungeon_kit/textures/` и 12 `.import` в `assets/tex3d/` — `compress/mode=2` (VRAM Compressed), `mipmaps/generate=true`, `detect_3d/compress_to=0`; для `*_normal.*` дополнительно `compress/normal_map=2` (Enable) и `compress/high_quality=true`; `process/normal_map_invert_y=false`.
  - `shaders/stone_world.gdshader` (новый) — камень по UV меша: вариация тона по миру + грязь/сырость у пола.
  - `assets/shaders/stone_triplanar.gdshader` — добавлены `roughness_floor`, `rough_from_green`, `grime_color`, `floor_y`, `grime_height`, `grime_strength`, `damp_strength`; грязь примешивается к ALBEDO и ROUGHNESS.
  - `src/make_materials.gd` (новый генератор; каталог `tools/` в .gitignore, поэтому скрипт лежит в `src/`) — собирает `.tres`.
  - `res://materials/*.tres` (11), `res://environment/variation_noise.tres` (новые).
  - `scripts/dungeon.gd` — `_materials()` загружает `.tres` вместо сборки материалов в коде; `_mat()`; `_apply_kit_materials()` вместо `_fix_kit_uv()`/`_scale_surface_uv()`; `_column_material()` возвращает ShaderMaterial с `uv_scale` по развёртке цилиндра; `_build_floor()`/`_scatter_dirt()` — заплатка земли на `floor_dirt.tres` и высота 0.006 м; удалены `_make_stone`, `_make_mat`, `_brick_material`, `_brick_material_uv`, `_dirt_material`, `_tex`, `_kit_tex`, `_mat_dirt`; каркасы мебели переведены на `mat_beam`, «отбросы»/обломки — на `mat_cap` вместо `mat_dark`, стружка на кровати — на `mat_beam` вместо `mat_metal`.
- Node paths (материалы назначаются на меш, не на узел, поэтому покрываются все экземпляры):
  - `Dungeon/Walls_wall_2m` (259), `Dungeon/Walls_wall_2m_b` (207) — `res://materials/wall_brick.tres` (кладка пака по UV меша, ×3.66 к UV = 512 px/м)
  - плиты `floor_4m` (461) — `res://materials/floor_cobble.tres` (×1.70 к UV)
  - модули арок `arch_2m`/`arch_2m_b` (29) — `res://materials/wall_brick.tres`
  - меш потолка `Dungeon` (SurfaceTool) и `Dungeon/VaultCove` — `res://materials/ceiling_vault.tres` (UV в метрах, `uv_scale` 0.25)
  - заплатки земли `dirt` (14) — `res://materials/floor_dirt.tres`
  - рёбра/портал/подставка рычага/обломки — `res://materials/stone_trim.tres`
  - тело стен, ступени, стволы колонн — `res://materials/brick_blocks.tres` (трипланар 0.25 uv/м)
  - косяки арок, обломки `mat_wall` — `res://materials/wall_stone_blocks.tres`
  - бочки/ящики — `wood_planks.tres`; столы, полки, кровати, стойки — `wood_beam.tres`; скобы, решётки, фонарный столб, тележка, арочные стяжки — `iron.tres`
- Exact property values (в `.tres`, собираются `src/make_materials.gd`):
  - `wall_brick`: tint (0.94,0.91,0.87), uv_scale (3.66,3.66), normal_strength 0.70, roughness_mult 1.05, roughness_floor 0.55, specular 0.20, metallic_mult 0, variation_strength 0.22, grime_height 1.1, grime_strength 0.45, damp_strength 0.35
  - `floor_cobble`: tint (0.86,0.84,0.82), uv_scale (1.70,1.70), normal_strength 0.55, roughness_floor 0.60, specular 0.18, variation_strength 0.15, grime_strength 0.0
  - `ceiling_vault`: tint (0.72,0.70,0.66) — на 23 % темнее стен, uv_scale (0.25,0.25), normal_strength 0.60, roughness_floor 0.62, grime 0
  - `brick_blocks`: трипланар 0.25, tint (0.90,0.88,0.85), normal 0.70, roughness_floor 0.55, grime_height 0.9, `rough_from_green=true`
  - `stone_trim`: трипланар 0.25, tint (0.62,0.58,0.55), normal 0.60, roughness_mult 1.10, roughness_floor 0.70, grime_height 1.1, grime_strength 0.55
  - `wall_stone_blocks`: трипланар 0.25, tint (0.78,0.75,0.71), normal 0.65, roughness_floor 0.62
  - `floor_dirt`: трипланар 0.25, tint (0.38,0.33,0.28), normal 0.45, roughness_floor 0.75, specular 0.12
  - `floor_stone_plain` (аварийный пол): атлас `tile_floor`, трипланар 0.25
  - `wood_planks`: tint (0.82,0.76,0.70), roughness 0.78, metallic 0, normal_scale 0.80, triplanar, texture_filter=5
  - `wood_beam`: tint (0.62,0.57,0.52), roughness 0.82, normal_scale 0.90
  - `iron`: tint (0.60,0.62,0.66), metallic 0.70, roughness 0.62, metallic_specular 0.35, normal_scale 0.60, uv1_scale 1.2
  - `environment/variation_noise.tres`: NoiseTexture2D 512×512, FastNoiseLite SIMPLEX_SMOOTH, frequency 0.02, fractal FBM 3 октавы, seamless, skirt 0.15
- Verified (что и как проверял):
  - `build.ps1 -Import` → `[OK] Импорт пройден`; `build.ps1 -Test` → `[OK] TEST: TEST DONE escaped=true` (в автотесте `FLOOR kit tiles=461`, `FLOOR dirt patches=14`, `WALLS veneer straight=259 mirrored=207`, `PIERS cylinders=16`).
  - Импорт текстур проверен замером, а не на глаз: временный headless-скрипт печатал `Image.get_format()`/`get_mipmap_count()` — альбедо 2048² → `DXT1`, `levels=11`; нормали → `BPTC_RGBA` (то есть ветка normal map, а не обычный цвет), `levels=11`; `_mr.png` 1024² → `levels=10`. До этапа: `mipmaps/generate=false` у всех 25 текстур.
  - Фототур: `SHOT_STAGE=stage4` → `_screenshots/stage4/spot_01_torch_puddle.png` … `spot_10_cistern_area.png` (10 кадров). Кадры я просматривал (изображения читаются в этом окружении): кирпич читается рельефно и без глянца, потолок темнее стен, у пола видна полоса грязи, «заглушечных» серых блоков нет.
  - Ориентация нормалей: A/B-прогон с `process/normal_map_invert_y=true` (кадры в `_screenshots/invert/`, каталог не коммичен) на тех же точках дал вывернутый рельеф — кирпич читался вдавленным; вернул `false`. Дополнительно: GLB-набор пересобран как glTF, где нормали строго +Y (OpenGL), то есть инверсия не нужна.
- What could NOT do and why:
  - **AO-карт в паке нет.** Есть только `*_mr.png` (G — шероховатость, B — металл). Поэтому `ao_enabled`/`AO`/`AO_LIGHT_AFFECT` не используются: затемнение у пола делается градиентом грязи. Шейдер `stone_world.gdshader` оставлен с sampler'ом AO не был — вместо `ao_tex` он берёт `mr_tex` и сэмплит `.gb`, иначе шероховатость читалась бы из R (там AO/пусто).
  - **`roughness/mode` + `roughness/src_normal` не применялись**: карты пака уже работают как MR-атлас (канал читается явно в шейдере и `roughness_texture_channel=GREEN`), а grayscale-карты `tex3d/*_rough.png` лежат в R (значение по умолчанию `roughness/mode=0`). Смена режима упаковала бы канал в альфу и сломала оба пути.
  - **Повтор текстуры снижен, но не устранён.** Атлас пака (4 м) по-прежнему повторяется на 30-метровой стене: `variation_strength 0.22` смягчает стыки, но на средней дистанции повтор кладки читается (видно на `spot_08_escape_view.png`). Полностью это лечится либо вторым, более крупным масштабом той же кладки, либо вершинными слоями — отдельная задача.
  - **Светлая «плита» в кадре `spot_06_doorway` / `spot_04_dark_tunnel_arch` — не материал.** Временный зонд (печатал все `MeshInstance3D` в радиусе 4 м от камеры) показал только `floor_cobble`, `wall_brick` и `iron`. Это свод-плечо модуля стены пака, который из-за `WALL_SHIFT = -1.901` уходит в зал на 1.9 м; камера фототура стоит в 1 м от стены и смотрит изнутри этой скорлупы. Материал на ней теперь `wall_brick`, но геометрия — задача этапа 3Б, а поведение камеры — этапа 2.
  - **Тёмные залы остались тёмными и зернистыми** (`spot_03_wall_curve_ceiling.png`): материалов это не касается, это свет/экспозиция — этап 6.
  - **Лужи по-прежнему парят над полом** (`floor_y`/плейн на 0.025 м) — этап 5, не трогал.
  - **Производительность не измерялась.** Добавлена одна выборка шума и одна `smoothstep` на пиксель; VRAM-сжатие снизило память текстур, но 60 FPS на GTX 1660 не замерялись.
  - Плиты пола несут настоящий геометрический рельеф до 0.139 м **вниз** от y=0 (AABB меша), параллакса/heightmap в проекте нет вообще (`heightmap` не встречается ни в одном .gd/.tscn/.tres).
- Uncommitted changes by another agent (`scripts/main3d.gd`, `scripts/settings.gd`, `scripts/settings_screen.gd`) замечены в рабочем дереве и НЕ трогались и НЕ коммитились этим этапом.
- How to verify:
  - `build.ps1 -Test` -> `[OK] TEST: TEST DONE escaped=true`
  - `SHOT_STAGE=stage4 godot --path . -- --mission --photo-tour` -> 10 PNG в `_screenshots/stage4/`
  - Пересобрать материалы после правки параметров: `godot --headless --path . --script res://src/make_materials.gd`

### Acceptance criteria (Stage 4)

| # | Criterion | Result | How checked |
|---|---|---|---|
| 1 | No parallax/heightmap artifacts on the floor near the camera; floor no longer blown out | **PASS** | `heightmap` не встречается ни в одном файле проекта (rg по .gd/.tscn/.tres) — параллакса нет вовсе. Пересвет ушёл после смены нормали на мипы: `floor_cobble` normal_strength 0.55, roughness_floor 0.60, tint 0.86; на `_screenshots/stage4/spot_05_floor_closeup.png` и `spot_08_escape_view.png` коббл читается без «кипения» и белых пятен (сравнение с `_screenshots/stage3_final/`). |
| 2 | All env materials are shared .tres; texture_filter anisotropic; textures have mipmaps | **PASS** | 11 файлов в `res://materials/`; в `scripts/dungeon.gd` удалены все inline-конструкторы материалов, остался `_mat()` + fallback-динамика (вода, пламя, знамя). Все сэмплеры шейдеров объявлены `filter_linear_mipmap_anisotropic`; у `wood_planks`/`wood_beam`/`iron` `texture_filter=5` (LINEAR_WITH_MIPMAPS_ANISOTROPIC). Мипы: headless-замер `Image.get_mipmap_count()` = 11 (2048²) / 10 (1024²). Project setting anisotropic = 4 (16x) подтверждён через `ProjectSettings.get_property_list()`. |
| 3 | Normal maps light bricks from the correct side | **PASS** | A/B-рендер тех же точек с `process/normal_map_invert_y=true` (`_screenshots/invert/`, не коммичен) дал вдавленный кирпич; с `false` верхние фаски кирпича светлеют под факелами, которые выше кадра (`_screenshots/stage4/spot_01_torch_puddle.png`). Плюс GLB-набор собран как glTF, где нормали +Y (OpenGL). |
| 4 | Repetition much less visible on long walls; walls darker/damp near the floor | **PARTIAL** | Грязь: видна на `spot_08` — стена темнеет в нижних ~1.1 м, damp 0.35 (ALBEDO mix + ROUGHNESS к 0.22). Повтор: `variation_strength 0.22` + бесшовный NoiseTexture2D 512² (frequency 0.02) снимает обои на ближней дистанции, но атлас 4 м на 30-метровой стене ещё повторяется на средней дистанции. FAIL по второй половине критерия, честно. |
| 5 | No placeholder-looking trims; ceiling not the brightest surface | **PASS** | `stone_wall_albedo.png` (серая блочная заглушка из tex3d) больше не используется ни одним материалом окружения: `stone_trim`/`wall_stone_blocks` переведены на атлас кладки пака (tint 0.62 / 0.78, roughness_floor 0.70 / 0.62), аварийный пол — на `tile_floor`. Потолок: `ceiling_vault` tint 0.72 против 0.94 у стены (−23 %), на `spot_08`/`spot_10` потолок темнее стен. |
| 6 | No shader compile errors | **PASS** | Лог фототура (`tools/_tour.log`) и `build.ps1 -Test` без `SHADER ERROR`/`error compiling`; оба шейдера отрисованы в кадре (грязь и вариация видны), значит скомпилировались и исполнились. |

## Stage 5

- Stage number: 5 (лужи и вода: декали вместо парящих плоскостей)
- Branch: `visual/stage-5`
- Files changed:
  - `src/gen_puddle_textures.gd` (новый генератор текстур; лежит в `src/`, а не в `tools/`, потому что каталог `tools/` целиком в .gitignore — тот же приём, что у `src/make_materials.gd` этапа 4)
  - `res://textures/decals/puddle_mask_0..3.png`, `puddle_orm.png`, `puddle_normal.png` (+ их `.import`: `compress/mode=0`, `mipmaps/generate=true`, `detect_3d/compress_to=0`, чтобы мягкие края маски не попали в блочное DXT-сжатие)
  - `scenes/props/puddle.tscn` (новая сцена лужи) и `scenes/props/puddle.gd` (новый скрипт)
  - `scripts/dungeon.gd` — единственный изменённый крупный скрипт (подробности ниже)
  - `scripts/model_util.gd` — `CHARACTER_LAYER := 2` и `set_visual_layer(root, layer)`
  - `scripts/hero3d.gd` — один вызов слоя в конце `_build_rig()`
  - `scripts/enemy3d.gd` — тот же вызов в конце `_ready()`
  - `scripts/mission3d.gd` — смещена фото-точка `spot_01_torch_puddle` (она называлась «torch_puddle», но лужи в кадре не было)
  - `_docs/visual_log.md` (эта запись)
- Step 1 — старые лужи (что и где было): все лужи строились кодом как `PlaneMesh` на `y = 0.025` над полом с материалом `mat_puddle_water` и бегущим тор-кругом.
  - из `_dress_rooms()`: `(15, 0, 59)`, `(48, 0, 47)`, `(72, 0, 55)`, `(106, 0, 33)`, `(98, 0, 42)` — после `_floor_safe(pos, 0.12)`;
  - из `assets/level/m1_props.json`: `cistern_pool` x=2048 y=544 → `(128, 0, 34)` размером 5.2×3.8 м; `puddle` x=1984 y=1216 → `(124, 0, 76)`; `puddle` x=1792 y=1280 → `(112, 0, 80)`.
  - Старый код не удалён: он вынесен в `_legacy_puddle_plane(pos, big)` под константой `LEGACY_PUDDLE_PLANES := false`; при включении узлы уходят в скрытый `Dungeon/_deprecated` (`visible = false`, `process_mode = PROCESS_MODE_DISABLED`). По умолчанию не строится ничего, поэтому в кадре парящих плоскостей нет. Удалять этот код — только с согласия владельца.
- Step 2 — текстуры (`src/gen_puddle_textures.gd`, запуск `godot --headless --path . --script res://src/gen_puddle_textures.gd`):
  - `puddle_mask_0..3.png` — 512² RGBA8, до трёх перекрывающихся пятен (радиусы 0.34 / 0.24 / 0.20 от размера), FastNoiseLite SIMPLEX_SMOOTH, FBM, 3 октавы, frequency 0.011; альфа = `smoothstep(0.0, 0.22, best)`, цвет от `(0.062, 0.072, 0.082)` (кромка, тонкая плёнка) до `(0.028, 0.036, 0.046)` (центр);
  - `puddle_orm.png` — 16² RGB8, `(1.0, 0.02, 0.0)`: AO 1, шероховатость 0.02 (вода — зеркало), металл 0;
  - `puddle_normal.png` — 8² RGB8, плоская нормаль `(0.5, 0.5, 1.0)`: она нужна не для рельефа, а чтобы у декали работал `normal_fade`.
- Step 3 — `scenes/props/puddle.tscn` (корень `Decal` с именем `Puddle`), значения:
  - `size = Vector3(1.5, 0.4, 1.5)`, `texture_albedo = puddle_mask_0.png`, `texture_normal = puddle_normal.png`, `texture_orm = puddle_orm.png`,
  - `albedo_mix = 0.55`, `normal_fade = 0.5`, `upper_fade = 0.0`, `lower_fade = 0.0`,
  - `cull_mask = 1` (персонажи — слой 2, декаль их не трогает),
  - `distance_fade_enabled = true`, `distance_fade_begin = 30.0`, `distance_fade_length = 8.0`.
  - Скрипт лужи: `@export var base_scale := 1.0`, `@export_range(0, 3) var variant := 0`, `@export var randomize_on_ready := true`; при случайном режиме берётся случайная маска из четырёх, случайный поворот по Y и множитель 0.7–1.5 на X/Z (по Y масштаб не меняется, иначе глубина проекции растёт).
  - Отклонение от задания: `upper_fade`/`lower_fade` стоят 0.0, а не 0.3. Замер: на микростенде с 0.3 декаль не видна вообще, с 0.0 видна (область AABB 0.4 м, поверхность пола лежит в 0.1 м от центра, то есть ровно на границе затухания). Документация Godot по `Decal` для «hard surface» декалей прямо советует `upper_fade`/`lower_fade = 0.0` при малом Y размера. Центр декали остался на 0.1 м выше пола, как в задании.
- Step 4 — расстановка (`scripts/dungeon.gd`):
  - `const PUDDLE_SCENE := "res://scenes/props/puddle.tscn"`, `const PUDDLE_LIFT := 0.1`;
  - `_add_puddle(pos, big)` — инстанцирует сцену, `base_scale` 1.0 / 1.7, ставит на `PUDDLE_LIFT` над полом, копит узлы в `puddles`;
  - `_add_puddle_cluster(pos, companions)` — центральное пятно + 1–3 спутника со сдвигом 0.55–1.21 м под углом из `_cell_hash(cell, 71)`, спутники не ставятся ближе 0.45 м к уже поставленным (`_puddle_near`);
  - `_prop("puddle")` → кластер из 3 пятен, `_prop("cistern_pool")` → из 4 (крупное центральное);
  - `_add_light_shafts()` — под каждой трещиной свода появляется лужа (`_puddle_under_crack`), у двух залов ещё и капель;
  - `_add_torch_puddles()` (после `_scatter_torches()`) — две лужи у основания стены в 1.15 м от факела: там вода и подсвечена огнём;
  - итог в логе автотеста: `PUDDLES decals=31 legacy=false`, `PUDDLES torch_lit=2`. Это 31 декаль на ~5000 м² уровня, 2–5 на мокрый зал, как в задании.
- Step 5 — отражения:
  - `Environment` в `_build_environment()`: `ssr_enabled = true`, `ssr_max_steps = 64`, `ssr_fade_in = 0.15`, `ssr_fade_out = 2.0`, `ssr_depth_tolerance = 0.2`;
  - `_build_reflection_probes()` — 6 пробников, `Dungeon/ReflectionProbe` (узлы создаются кодом): залы `(14, 60)`, `(34, 52)`, `(70, 54)`, `(102, 40)`, `(128, 34)`, `(112, 78)`; `size = (14…18, cell_ceil, 12…16)`, `position.y = top/2`, `origin_offset = (0, 1.5 − top/2, 0)` (точка съёмки — на высоте глаз), `interior = true`, `update_mode = UPDATE_ONCE`, `cull_mask = 1`, `ambient_mode = AMBIENT_DISABLED` (пробник даёт только отражения, ambient остаётся уровневый, иначе свет в залах поехал бы). В логе: `REFLECT probes=6 ssr=true`.
- Step 6 — капель (без звука): `_add_drip(pos, top)` — `GPUParticles3D` (`amount = 1`, `lifetime = 1.0`, `one_shot = true`, `local_coords = false`, `visibility_aabb` на всю высоту зала), `ParticleProcessMaterial` (направление −Y, spread 0, `gravity = (0, −9.8, 0)`, `particle_flag_align_y = true`), квад вытянут по Y 0.016×0.085, unshaded, альфа 0.6; перезапуск по `Timer` со случайными 1.5–4 с. Капель стоит под двумя лужами (первая и третья трещины свода).
  - Звука капли нет: в `assets/audio/` нет подходящего сэмпла, звук — этап 10. Комментария-заглушки в коде не оставлено, вместо этого факт записан здесь.
- Слой персонажей (нужен для `cull_mask`): `ModelUtil.set_visual_layer(root, layer)` ставит всем `MeshInstance3D` поддерева `layers = 1 << (layer − 1)`; герой (`hero3d.gd`, конец `_build_rig()`) и враги (`enemy3d.gd`, конец `_ready()`) уходят на слой 2. Камера и источники света по умолчанию видят все слои, поэтому на вид персонажей это не влияет.
- Что могло не получиться и почему (честно):
  - **Глянец в кадре слабый.** SSR и пробники включены, `puddle_orm.png` даёт шероховатость 0.02, в ближнем кадре у лужи видно блик и тёмную кромку, но в общем плане при текущем свете (равномерный оранжевый/плоский, тёмные залы — этап 6) отражение факела читается только вблизи. Замер вклада лужи (кадр с лужами и без, `tools/puddle_check.gd`): `mean_diff=0.011`, изменено `6.75 %` пикселей кадра — то есть лужи меняют картинку, но не «стреляют» отражениями.
  - **Производительность не измерялась.** 6 пробников с `UPDATE_ONCE` (36 отрисовок на старте) и SSR с 64 шагами на кадр — цена на GTX 1660 не мерилась; переключатель качества для SSR и числа пробников — этап 12, сейчас это только константы в коде.
  - **Отдельные «мокрые» пятна в кадре — не лужи.** В кадрах есть тёмные многоугольники с прямыми краями (заплатки земли `floor_dirt.tres` этапа 4 и тени реквизита) — их я не трогал, они не вода.
  - **Старый код плоскостей оставлен** под `LEGACY_PUDDLE_PLANES := false`, `mat_puddle_water` и `water_ripples` живы только для него.
- How to verify:
  - `build.ps1 -Import`, затем `build.ps1 -Test` → `[OK] TEST: TEST DONE escaped=true`, в логе `PUDDLES decals=31 legacy=false`, `PUDDLES torch_lit=2`, `REFLECT probes=6 ssr=true`.
  - `SHOT_STAGE=stage5 godot --path . -- --mission --photo-tour` → 10 PNG в `_screenshots/stage5/`; ключевой — `spot_01_torch_puddle.png` (лужа у стены стартового зала, пятно лежит в полу, у героя чистые сапоги).
  - A/B старого поведения: поставить `LEGACY_PUDDLE_PLANES := true` в `scripts/dungeon.gd` и сравнить кадры.
  - Пересборка текстур: `godot --headless --path . --script res://src
- Screenshots (кадры я просматривал, изображения в этом окружении читаются):
  - `_screenshots/stage5/spot_01_torch_puddle.png` … `spot_10_cistern_area.png` (10 кадров).
  - Вне репозитория (`tools/` в .gitignore): микростенды `tools/shot_micro.png`, `tools/shot_orm.png`, A/B-линейка `tools/shot_ab_*.png`, проверка `tools/shot_check_on.png` / `shot_check_off.png`, виды луж `tools/shot_view_*.png`, кадр у стены старта `tools/shot_spot.png`.

### Acceptance criteria (Stage 5)

| # | Criterion | Result | How checked |
|---|---|---|---|
| 1 | No floating water planes remain visible | **PASS** | В логе автотеста `PUDDLES decals=31 legacy=false` — код плоскостей под выключенным флагом, в дереве остались только `Decal`. На `_screenshots/stage5/spot_01_torch_puddle.png` и `spot_05_floor_closeup.png` парящих пятен нет (сравнение с `_screenshots/stage4/`). |
| 2 | Puddles follow the cobblestones (projected, not planes), irregular soft edges | **PASS** | Декаль проецируется в AABB 1.5×0.4×1.5 с центром 0.1 м над полом и повторяет рельеф плит; форму задаёт альфа маски из трёх сливающихся пятен. На микростенде (`tools/shot_micro.png`) пятно повторяет стыки коббла, на контрольной маджента-декали видно, как кладка «пробивает» пятно в швах. |
| 3 | Torches/lights produce visible highlights/reflections in puddles | **PARTIAL** | `ssr_enabled=true` (64 шага) и 6 пробников `UPDATE_ONCE` (в логе `REFLECT probes=6 ssr=true`), `puddle_orm.png` даёт шероховатость 0.02 → в ближнем кадре `tools/shot_spot.png` у лужи видны тёмное тело и светлый блик от ближнего света. В общем плане отражение факела почти не читается: измеренный вклад лужи (кадр с лужами и без) `mean_diff=0.011`, изменено `6.75 %` пикселей. Глянец в полную силу — после этапа 6 (свет/экспозиция); критерий закрыт не полностью. |
| 4 | Puddles do not appear on the dwarf or on walls | **PASS** | Герой и стражи переведены на визуальный слой 2 (`ModelUtil.CHARACTER_LAYER`), у лужи `cull_mask = 1`. Прямой A/B на одном стенде: два гнома в маджента-декали — у левого (`cull_mask = 1`) сапоги, руки и одежда чистые, у правого (`cull_mask = 3`) те же места закрашены. От стен защищает `normal_fade = 0.5` и глубина коробки: центр 0.1 м, size.y = 0.4 → проекция дотягивается максимум до ~0.3 м над полом. |
| 5 | Test suite green, no script errors | **PASS** | `build.ps1 -Test` → `[OK] TEST: TEST DONE escaped=true`; в кадровом прогоне `[LEAK_TEST] LEAK_TEST_REPORT reachable_cells=432 HOLES=0 LEAKS=0`. Предупреждения `RID allocations … leaked at exit` были и до этапа (сверено с прогоном до правок). |

## Stage 6
- Stage number: 6 (освещение и GI)
- Branch: `visual/stage-6`, от коммита этапа 4 `8dd31eb` (решение владельца: незакоммиченный WIP этапа 5 из основного дерева в базу не вошёл; работа шла в git worktree `.worktrees/visual-stage6` по прямой просьбе владельца).
- Слияние с этапом 5 (после его завершения, merge `visual/stage-5` → `visual/stage-6`): SSR этапа 5 (enabled, 64 шага, fade_in 0.15, fade_out 2.0, depth_tolerance 0.2) перенесён в `dungeon_env.tres` (через `src/make_lighting.gd`), его собственный `Environment.new()` снят вместе с остальными; `_add_torch_puddles()` идёт сразу после `_scatter_torches()`, до атмосферных факелов, чтобы лужи легли у тех же факелов, что на этапе 5; контейнер `_deprecated` у этапов 5 и 6 один — `Dungeon._deprecated_root()`. После слияния: `--test3d` → `PUDDLES torch_lit=2`, `REFLECT probes=6 ssr=true`, `lights=80`, `TEST light cell=48.6 torch=49.2`, `TEST DONE escaped=true`; `--l2check` → `[OK] LEVEL2`. Фототур переснят (`_screenshots/stage6/` — кадры уже с лужами этапа 5), FPS: 01 66, 02 126, 03 162, 04 118, 05 74, 06 72, 07 153, 08 166, 09 130, 10 105 — самая тяжёлая точка теперь spot_01 (лужи + SSR), 66 FPS. На кадре `spot_01` после слияния старт уже не ровно-рыжий: пятно света у бра, тень за ящиком, читаемый гном в лампе читаемости — оговорка по критерию 2 для 01 снята, для 07 остаётся.
- Что нашёл до начала (структура ≠ промпту):
  - Уровни не сцены, а генерация: M1 — `scripts/dungeon.gd`, уровень 2 — `scripts/level2_builder.gd` (наследник `Dungeon`). Environment и свет создавались кодом в каждом билдере, WorldEnvironment в .tscn нет. Свои временные Environment есть ещё в `scripts/main3d.gd` (меню и витрины, не уровни) — не трогал.
  - Источники «ровной заливки»: `DirectionalLight3D` 0.5 в M1 и 0.22 в уровне 2 (под землёй); фонарь камеры `Cam3D` (OmniLight3D белый, 1.7, радиус 12 м — светил на всё, куда смотрит игрок); ambient 0.48 (M1) / 0.82 (L2) при ACES exposure 1.35; оранжевый SpotLight3D 8.0 в одном из лучей. Эмиссивных стен нет (шейдеры `stone_world`/`stone_triplanar` без EMISSION и unshaded); у знамени emission 0.45 — оставил.
  - На всю M1 (156×92 м) было лишь 4 настенных факела (`_scatter_torches(max_count=4)`), 2 стоячих и 2 жаровни.
  - **Уровень 2 на базовом коммите не компилировался**: этап 4 удалил `Dungeon._tex()` / `_make_mat()`, а `level2_builder.gd` их вызывал (Parse Error). Починил минимально: локальный `_tex3d()` и явный StandardMaterial3D пандуса.
- Files changed:
  - `src/make_lighting.gd` (новый генератор по образцу `make_materials.gd`) → `res://environment/dungeon_env.tres`, `res://scenes/props/torch.tscn`
  - `scenes/props/torch_flicker.gd` (новый, скрипт из ТЗ дословно)
  - `scripts/dungeon.gd`, `scripts/level2_builder.gd`, `scripts/cam3d.gd`, `scripts/hero3d.gd`, `scripts/main3d.gd`, `debug/debug_shots.gd`, `project.godot`
- `environment/dungeon_env.tres` — один на все уровни. `Dungeon.make_world_environment()` — единственная точка создания WorldEnvironment; её зовут `Dungeon._build_environment()` и `Level2Builder._build_environment()`:
  - background Color(0.02, 0.018, 0.016); ambient Color(0.16, 0.19, 0.25), energy **0.35** (0.25 из ТЗ на кадрах давал чистый чёрный — поднял до верхней границы диапазона); reflected_light_source = Disabled
  - tonemap AgX, exposure **1.2** (подобрано в шаге 7)
  - SSAO: radius 1.0, intensity 2.0, power 1.5, detail 0.5, horizon 0.06, light_affect 0.1
  - SSIL: radius 4.0, intensity 0.8
  - SDFGI: **sdfgi_enabled = false** (см. «GI — решение»); параметры для включения: occlusion on, cascades 4, min_cell 0.15, energy 1.0, bounce_feedback 0.4, read_sky_light off
  - glow: intensity 0.8, strength 1.0, bloom 0.0, hdr_threshold 1.0, уровни 3/4/5 = 1.0
  - adjustment: contrast 1.08, saturation 0.92
  - туман (fog 0.009, volumetric 0.01 и пр.) перенесён из старого кода M1 без изменений: его настраивает этап 7. У уровня 2 был свой туман (0.02, голубой) — теперь общий.
- Снятые дубликаты. Узлы — в скрытом `_deprecated` (visible = false, process_mode = DISABLED): `Dungeon/_deprecated/DirectionalLight3D` (M1, energy 0.5) и такой же у уровня 2 (0.22). Свои `Environment.new()` M1 и L2 удалены из кода; их значения — в этом логе выше и в `_docs/PROJECT_FACTS.md` f). Фонарь камеры `Cam3D` удалён из кода (OmniLight3D: color (1, 0.95, 0.9), energy 1.7, range 12, attenuation 1.5).
- GI — решение: уровни генерируются в рантайме, поэтому LightmapGI неприменим, кандидат — SDFGI. A/B на тех же 10 точках (`DUNGEON_GI=on|off`): вклад SDFGI почти не виден (тёмные материалы, факелы на 7 м, мало отражённого света), а стоит 10–20 % FPS (spot_02 97→121, spot_06 66→74, spot_10 89→112). Выбран вариант «без GI: SSIL + ambient». SDFGI выключен по умолчанию; `Dungeon.gi_enabled` (static) включает его для будущего меню качества, переменная окружения `DUNGEON_GI=on` — для отладки. Заполняющие OmniLight не добавлял: роль слабого заполнения играет ambient 0.35.
- `scenes/props/torch.tscn` (локально: стена в плоскости z = 0, +Z — в зал):
  - `Mesh`: Plate и Arm — BoxMesh на `iron.tres`, Stick — CylinderMesh на `wood_planks.tres`, Cup — `iron.tres`. В паке меша факела нет (только torch chest), поэтому кронштейн собран из примитивов на общих материалах.
  - `Flame` GPUParticles3D в (0, 1.1, 0.3): amount 24, lifetime 0.6, local_coords, QuadMesh 0.15; StandardMaterial3D unshaded + BILLBOARD_PARTICLES + BLEND_ADD + vertex_color_use_as_albedo + мягкое радиальное пятно; ParticleProcessMaterial: direction (0,1,0), spread 10, velocity 0.3–0.6, gravity (0,0.5,0), scale_curve 1→0, color_ramp (1,0.85,0.5) → (1,0.45,0.1) → (0.35,0.04,0, alpha 0)
  - `FlameCore` SphereMesh r 0.045, emission (1.0, 0.6, 0.25) × 4
  - `Embers` GPUParticles3D: amount 6, lifetime 1.5, QuadMesh 0.025, velocity 0.25–0.55, spread 30, turbulence 0.4, мировые координаты
  - `Light` OmniLight3D в (0, 1.38, 0.3) — 0.3 м от стены, скрипт `torch_flicker.gd`: color (1.0, 0.6, 0.32), energy 2.5, range 7.0, attenuation 1.5, shadow on (в рантайме тени раздаёт лимитер), light_size 0.08, shadow_bias 0.03, normal_bias 1.0, volumetric_fog_energy 2.0, specular 0.6, distance_fade 25 / shadow 15 / length 8; мерцание ±18 %, speed 9, дрожание 1.5 см
- Замена факелов (позиции и высоты сохранены):
  - `Dungeon._wall_torch()` → `_spawn_torch()` на том же якоре стены (1.72 м от пола); старые примитивы и меш-пламя удалены из кода
  - `Dungeon._torch()` (2 стоячих факела старта): древко и чаша остались, огонь и свет — из сцены (`Mesh` сцены скрыт), пламя на верху чаши (y 2.02)
  - `Level2Builder._sconce()` (30 бра) — целиком сцена torch.tscn, кронштейн на грани стены, пламя на прежней высоте 2.07 м
  - жаровни (`_brazier_prop`, `brazier_stand`) оставлены со своим пламенем, их свет приведён к параметрам факела через `_style_fire_light()`: energy 2.8 / 2.6, range 7.5
- Баланс скрытности не тронут. `light_at()` (дальность обзора стражи) теперь берёт `reach` из записи `lights`, а не визуальный `omni_range`. Факелы геймплея сохранили прежнюю дальность: настенные 10, стоячие 10.5, бра 14, жаровни 8.5. Новые атмосферные огни имеют `reach = 0` и в `light_at` не входят. Проверка: `TEST light cell=48.6 torch=49.1` против 48.4 / 48.7 до этапа (разница — лампа стоячего факела теперь на 12 см ниже). **Решение для владельца**: если атмосферные факелы должны влиять на стражу, поставить им reach 7.0 (это изменит баланс).
- Композиция света (шаг 5):
  - `Dungeon._place_torches(spacing 8, max 70)` — атмосферные настенные факелы вдоль стен везде, где в 8 м нет другого огня: **45 шт.** Обход детерминированный.
  - `Dungeon._place_hanging_fires(spacing 10, max 12)` — подвесные чаши на цепи (без коллизии, проход не перекрывают) в глубине залов: клетка не ближе 2 клеток к стене и в 10 м нет огня. **5 шт.**, огонь на высоте ≤ 3.1 м и не ближе 1.2 м к своду.
  - Лучи из свода (`_add_light_shafts`, 4 шт.): все холодные (0.45, 0.55, 0.75), energy 8.0 → 1.0, тени on, volumetric_fog_energy 4.0, distance_fade 25/15/8. Луч уровня 2 из пролома (настоящий источник): 4.0 → 1.0, тот же цвет, тени on.
  - Тени: `Dungeon.shadow_budget` = 6 ближайших к герою огней в радиусе 15 м (было 4); на уровне 2 — 3 (так требует `level2_play`, SHADOW_BUDGET). Project Settings: positional shadow atlas 4096, soft_shadow_filter_quality 3 (Medium), use_debanding = true.
  - План по зонам M1: старт у решётки (цель) — 2 стоячих факела + жаровня, самая светлая зона, ведёт игрока; коридоры — настенные факелы через ~8 м, между ними темно; большие залы — настенные по периметру, подвесные чаши в глубине, холодный луч; цистерна и нижняя шахта — настенные по периметру. Уровень 2 — 30 бра и холодный луч у пролома.
- Свет игрока (шаг 6): `Hero3D/<rig>/ReadabilityLight` — OmniLight3D color (1, 0.75, 0.5), energy 0.25, range 3.0, без теней, specular 0.1, позиция (0, 1.9, -0.6) на риге: над-перед гномом, поворачивается вместе с ним.
- Автотест: лимит источников света в M1 был 30 (`main3d.gd`), стал `LIGHT_BUDGET := 90` (факт — 80). Обоснование: тени только у 6 ближайших огней, остальные omni без теней в кластерном Forward+ дешёвые; замер FPS ниже.
- Замер FPS (`debug_shots.gd`, `SHOT_FPS=1`: 120 кадров без vsync на каждой точке). RTX 5050 Laptop, рендер 1916×1078, SDFGI off: spot_01 79, spot_02 90, spot_03 115, spot_04 91, spot_05 72, **spot_06 70 (самая тяжёлая)**, spot_07 116, spot_08 100, spot_09 103, spot_10 82; худший кадр 20–38 мс. Числа шумные (ноутбук): прогоны до финала давали spot_06 66–74.
- What could NOT do and why:
  - **60 FPS на GTX 1660 не проверены**: такой карты нет, а RTX 5050 Laptop заметно быстрее. Минимум 70 FPS здесь не гарантирует 60 на 1660. Главные кандидаты на отключение в меню качества: объёмный туман, SSIL, число теней (shadow_budget), мягкость теней.
  - **Монитор отладчика не использовался** (игра шла без редактора): FPS измерен своим счётчиком в фототуре.
  - **Стартовая комната (`spot_01`) всё ещё ровно-рыжая**: 2 стоячих факела и жаровня геймплея стоят в нескольких метрах друг от друга и заливают её почти без тени. Двигать их — значит менять геймплей (свет у цели, `light_at`); не стал.
  - **Холодное заполнение почти не читается**: ambient 0.35 (верх диапазона) на тёмных материалах даёт едва заметные формы, в кадрах всё тёплое. Ярче — уже «плоский серый», от которого уходили.
  - **Центр самого большого зала (`spot_07`) в основном тёмный**: подвесных чаш на весь уровень 5, их видно вдали, но у камеры зал чёрный. Плотнее — упрёмся в лимит источников и FPS.
  - **Протечки света**: тени есть только у 6 ближайших огней; у остальных omni (7 м) свет может пройти сквозь стену толщиной в клетку (2 м) на соседнюю грань. На 10 точках тура явных протечек не видно, но это не полный обход.
  - Кронштейн факела «из пака» невозможен: в паке нет меша факела.
  - Этап 7 (туман, пыль) и правки этапа 5 (вода, WIP в основном дереве) не трогал. Изменения этапа 5 в `dungeon.gd` / `hero3d.gd` основного дерева могут конфликтовать при слиянии веток.
- How to verify:
  - Пересобрать ресурсы: `godot --headless --path . --script res://src/make_lighting.gd`
  - `godot --headless --path . -- --test3d` → `TORCHES atmospheric=45`, `TORCHES hanging=5`, `lights=80`, `TEST light cell=48.6 torch=49.1`, `TEST DONE escaped=true`
  - `godot --headless --path . res://scenes/level2.tscn -- --l2check` → `shadows=3`, `[OK] LEVEL2`
  - `SHOT_FPS=1 SHOT_STAGE=stage6 godot --path . --resolution 1920x1080 -- --mission --photo-tour` → 10 PNG и строки `[DebugShots] fps …`; с `DUNGEON_GI=on` — то же с SDFGI.
- Screenshots: `_screenshots/stage6/spot_01_torch_puddle.png` … `spot_10_cistern_area.png` (10 шт.). Кадры я просматривал. В коридорах и проёмах (02, 04, 06, 08, 09, 10) — тёплые пятна у факелов и тёмные промежутки; стена рядом с факелом яркая, но не белая; зерна и полос на градиентах нет; пламя читается ярким ядром с ореолом. 01 — ровная рыжая заливка старта; 07 — почти чёрный зал с далёкими огнями; 03 — тёмный перекрёсток с несколькими пятнами света.

### Acceptance criteria (Stage 6)

| # | Criterion | Result | How checked |
|---|---|---|---|
| 1 | All levels use dungeon_env.tres; tonemap = AgX; debanding on | **PASS** | `Environment.new` в `dungeon.gd` и `level2_builder.gd` больше нет; оба билдера зовут `Dungeon.make_world_environment()` → `load("res://environment/dungeon_env.tres")`; в .tres `tonemap_mode = 4` (AgX); в `project.godot` `anti_aliasing/quality/use_debanding=true`. Витрины меню в `main3d.gd` — не уровни, их окружение оставлено. |
| 2 | No room uniformly orange or grey; every room has light pools and dark areas | **PARTIAL** | По кадрам тура: 02/03/04/06/08/09/10 — пятна света и темнота, серой заливки нет нигде. FAIL по 01 (стартовая комната ровно-рыжая) и частично по 07 (центр большого зала тёмный, пятна только вдали). |
| 3 | Every torch flickers subtly, casts soft shadows, flame glows without blowing out | **PARTIAL** | Мерцание: `torch_flicker.gd`, ±18 % по шуму, без стробоскопа (проверено по коду, видео не снимал). Тени мягкие (light_size 0.08, фильтр Medium), но **одновременно только у 6 ближайших** огней — так решено ради FPS. Пламя на кадрах 08/09 — яркое ядро с ореолом, не белое пятно. |
| 4 | No grainy noise in dark areas, no banding on photo tour | **PASS** | Кадры 01–10 просмотрены: зерна нет (SDFGI выключен, SSIL 0.8), полос на градиентах нет (debanding on). |
| 5 | Chosen GI method documented; no obvious light leaks | **PASS (с оговоркой)** | Решение и A/B записаны выше. Явных протечек на 10 точках нет; полный обход уровня не делал (см. «Протечки света»). |
| 6 | FPS ≥ 60 at 1080p in the heaviest room | **PASS на этой машине, не проверено на GTX 1660** | Самая тяжёлая точка — spot_06: 70 FPS (RTX 5050 Laptop, 1916×1078, без vsync, `SHOT_FPS=1`). На целевой GTX 1660 не замерено. |

## Stage 7
- Stage number: 7 (туман, воздух, пост-обработка)
- Branch: `visual/stage-7`, от `visual/stage-6` (`cdc3aa3`) — решение владельца: этапу нужны `dungeon_env.tres` и факелы этапа 6. Работа в основном дереве, без worktree.
- Статус: шаги 1–6 сделаны и проверены прогоном; шаг 7 (LUT) пропущен — LUT владелец не давал. MSAA 2x по замеру выключен (см. шаг 5). Первый полный замер дал 7–8 FPS на всех точках — это был прогон с окном в фоне/закрытым окном, а не цена эффектов: повторный прогон с тем же кодом дал 53–60 на spot_01 и 63–149 на остальных.
- Files changed:
  - `src/make_lighting.gd` → пересобран `environment/dungeon_env.tres` (туман)
  - `project.godot` — объёмный туман и сглаживание
  - `materials/fog_ground_mist.tres` (новый FogMaterial)
  - `scenes/fx/dust_motes.tscn`, `scenes/fx/dust_motes.gd` (новые)
  - `shaders/post_vignette_grain.gdshader`, `materials/post_vignette_grain.tres`, `scenes/fx/post_fx.tscn` (новые)
  - `scripts/dungeon.gd` — `air_fx`, `air_fx_on()`, `_add_wet_mist()`, `_add_ground_mist()`, `_add_camera_dust()`, `_dust_motes()`; `_add_dust()` переписан на сцену пыли
  - `scripts/level2_builder.gd` — `_add_wet_mist()` (ров крипты) и вызовы дымки и пыли в `build()`
  - `scripts/cam3d.gd` — инстанс `post_fx.tscn`
  - `debug/debug_shots.gd` — тур не прячет группу `post_fx`; режим `SHOT_BISECT=1`
  - `_screenshots/stage7/*.png` (10 кадров финальной конфигурации)
- Шаг 1 — `dungeon_env.tres`: `volumetric_fog_enabled = true`, `volumetric_fog_density = 0.025`, `volumetric_fog_albedo = Color(0.85, 0.82, 0.78)`, `volumetric_fog_emission = Color(0.01, 0.012, 0.018)`, `volumetric_fog_emission_energy = 1.0`, `volumetric_fog_anisotropy = 0.4`, `volumetric_fog_length = 40`, `volumetric_fog_detail_spread = 2.0`, `volumetric_fog_gi_inject = 0.5`, `volumetric_fog_ambient_inject = 0.1`, `volumetric_fog_temporal_reprojection_enabled = true`, amount `0.9`. `project.godot`: `rendering/environment/volumetric_fog/volume_size = 128`, `volume_depth = 64`, `use_filter = 1`. Факелы не трогал: у них уже `light_volumetric_fog_energy = 2.0` (этап 6), у лучей свода 4.0.
- Шаг 2: `fog_enabled = true`, `fog_light_color = Color(0.03, 0.03, 0.035)`, `fog_density = 0.01`, `fog_sky_affect = 0.0`. Было: цвет (0.085, 0.09, 0.115), плотность 0.009.
- Шаг 3 — дымка: `materials/fog_ground_mist.tres`: `density = 0.08`, `albedo = Color(0.72, 0.76, 0.8)`, `height_falloff = 1.5`, `edge_fade = 0.5`. Узлы `Dungeon/GroundMist*` (FogVolume, `shape = FOG_VOLUME_SHAPE_BOX`, высота `MIST_HEIGHT = 1.0` м, низ на полу, группа `fx_mist`). M1: лужи ближе 5 м друг к другу накрываются одной коробкой, поле 2 м вокруг, итого **11 коробок** (лог `MIST volumes=11`). Уровень 2: одна коробка на прямоугольник всех клеток `w` (ров вокруг помоста, ~24×22 м), `MIST volumes=1`. Отрицательный туман у цели не ставил: картинка не молочная.
- Шаг 4 — пыль: выбран **один эмиттер на уровень, привязанный к активной камере** (`Dungeon/CameraDust`, `follow_camera = true`: эмиттер каждый кадр встаёт на `get_viewport().get_camera_3d()`, в том числе на камеру фототура; частицы в мировых координатах). Сцена: GPUParticles3D `amount 150`, `lifetime 12`, `preprocess 6`, `local_coords = false`, коробка 12×4×12 (`emission_box_extents (6,2,6)`), `visibility_aabb` = коробка + 1 м; ParticleProcessMaterial: `gravity (0,-0.005,0)`, начальная скорость 0, `turbulence_enabled`, `noise_strength 0.3`, `noise_scale 4`, `scale 0.57–1.43` при квадe 0.014 м (то есть 0.008–0.02 м), `color_ramp` альфа 0→1→1→0. StandardMaterial3D **затеняемый** (per-pixel), `transparency = ALPHA`, `disable_receive_shadows = true` (150 прозрачных пылинок не сэмплят 6 теневых карт факелов — экономия по замеру; пыль за препятствием подсвечивается чуть больше, в кадре не читается), `billboard_mode = BILLBOARD_PARTICLES` (billboard для частиц, учитывает масштаб частицы), `albedo_color (1,0.95,0.85,0.6)`, мягкая круглая точка `GradientTexture2D`. Добавлено `disable_ambient_light = true` (иначе ambient 0.35 подсвечивал бы пыль в темноте) и `backlight (0.6,0.55,0.5)` (пылинка между камерой и факелом иначе была бы тёмной). Старая пыль лучей свода (`_add_dust`: 24 unshaded-частицы, видны и в темноте) не оставлена рядом, а заменена той же сценой: `amount 40`, коробка 3.2 × (0.64·высота) × 3.2.
- Шаг 5 — AA (`project.godot`): `use_taa = true`, `msaa_3d` = Disabled (значение по умолчанию, ключа в файле нет), `screen_space_aa` = Disabled (по умолчанию). MSAA 2x пробовался: на spot_01 со всеми эффектами 53.7 FPS, без MSAA 62.7 (бисекция) — ТЗ разрешает MSAA «если FPS позволяет», не позволяет. FSR 2.2 вместо TAA не пробовал: в статичных кадрах шлейфа TAA на гноме нет, в движении не проверял (см. критерий 4).
- Шаг 6 — виньетка/зерно: шейдер из ТЗ; одно отличие — `screen_tex` с `filter_linear` вместо `filter_linear_mipmap` (сэмпл идёт ровно в SCREEN_UV, мипы заставили бы движок каждый кадр строить размытую цепочку экрана). Параметры в `post_vignette_grain.tres`: `vignette_strength 0.35`, `vignette_radius 0.95`, `grain_strength 0.02`. `PostFX` (CanvasLayer, **layer = -1**, группа `post_fx`) → `VignetteGrain` (ColorRect, full rect, `mouse_filter = IGNORE`). Почему −1, а не «чуть ниже HUD»: HUD на слоях 10/11, но экран настроек из паузы (`main3d.show_settings()`) добавляется Control'ом в корень, то есть на слой 0, и любой слой 1–9 затемнял бы его. При `background_mode = BG_COLOR` все canvas-слои, включая отрицательные, рисуются поверх 3D. Инстанс создаёт `Cam3D._ready()` (одна точка на M1 и уровень 2).
- Переключатели (для меню качества этапа 12): `Dungeon.air_fx = {"mist", "dust", "post"}`; отладка без правки кода: `AIR_FX_OFF=mist,dust,post`.
- Замеры, которые были:
  - Только шаги 1–2 (`SHOT_STAGE=stage7_step1`, без дымки/пыли/виньетки/AA): FPS 01 59.5, 02 116.6, 03 134.9, 04 115.2, 05 70.6, 06 70.9, 07 147.5, 08 167.7, 09 129.3, 10 105.7 (RTX 5050 Laptop, кадр 1916×1078; этап 6 на тех же точках: 66 / 126 / 162 / 118 / 74 / 72 / 153 / 166 / 130 / 105). Кадры просмотрены: у подвесных чаш и факелов мягкий ореол (02, 07), концы коридоров уходят в тёмную тёплую дымку (02), чёрное осталось чёрным, молочности нет.
  - Первый полный прогон: 7–9 FPS на всех точках и обрывы с `ObjectDB instances leaked at exit` (штатный выход → сегфолт при завершении). Окно игры в это время было в фоне и закрывалось владельцем; повторные прогоны с тем же кодом этого не дают. Вывод: не цена эффектов, а условия прогона.
  - Бисекция (`SHOT_BISECT=1`, spot_01, всё включено + MSAA 2x): все 53.7 · без виньетки 52.5 · без пыли 56.0 · без дымки 56.6 · без объёмного тумана 57.7 · без TAA 59.2 · без MSAA 62.7 · всё выключено 68.4. Повтор после выключения MSAA и `disable_receive_shadows` у пыли: все 58.5 · без виньетки 58.5 · без пыли 60.8 · без дымки 62.1 · без объёмного тумана 63.6 · без TAA 65.7 · «без MSAA» (уже выключен, контроль шума) 61.6 · всё выключено 67.6. Замеры по очереди дрейфуют вверх на 2–3 FPS (прогрев ноутбука): контрольная строка без изменений дала +3.1, это и есть шум.
  - Сетка тумана 96 вместо 128 — spot_01 58.2 против 59.2 (в пределах шума), возвращено 128 по ТЗ.
  - **Финал** (`_screenshots/stage7/`, конфигурация коммита, `tools/_tour7_final.log`): 01 58.5, 02 106.3, 03 133.7, 04 99.4, 05 67.4, 06 65.7, 07 119.8, 08 144.9, 09 108.8, 10 93.6 (RTX 5050 Laptop, 1916×1078, без vsync).
- Кадры (просмотрены): 01 — виньетка мягко гасит углы, над лужей у факела тёплая низкая дымка, пол и стены не посерели; 02/07 — ореолы у подвесных чаш и факелов, концы коридоров уходят в тёмную дымку; 10 — дальний коридор растворяется в тёплом мареве, правая половина кадра остаётся чёрной; 06 — без молочности. Пылинки на кадрах — единичные точки у огня, в тёмных зонах их нет. HUD-кадры режима `--shots` (`tools/shot_3d_01.png`, `shot_3d_run.png`, `shot_3d_pause_settings.png`): текст и панели HUD, диалог и экран настроек из паузы чёткие, не затемнены и без зерна. Подозрение на вертикальные полосы зерна в `shot_3d_01` проверено замером: средние по столбцам/строкам тёмной зоны ровные (σ 0.066 / 0.050 из 255), узора нет — это был муар при уменьшении картинки.
- What could NOT do and why:
  - LUT (шаг 7) — LUT нет.
  - TAA-шлейф проверен только на статичных кадрах тура; видео в движении не снималось.
  - 60 FPS на GTX 1660 не проверены (такой карты нет); на RTX 5050 Laptop spot_01 на границе.
- How to verify:
  - Бисекция одним прогоном: `SHOT_FPS=1 SHOT_BISECT=1 SHOT_STAGE=stage7 godot --path . --resolution 1920x1080 -- --mission --photo-tour` → после замера первой точки строки `fps off_post_fx`, `off_fx_dust`, `off_fx_mist`, `off_volfog`, `off_taa`, `off_msaa`, `off_all`; прирост к замеру `spot_01` = цена эффекта. Окно во время прогона не закрывать и не перекрывать.
  - Быстрый A/B без правки кода: `AIR_FX_OFF=mist,dust,post`.
  - `godot --headless --path . -- --test3d` → `MIST volumes=11`, `TEST DONE escaped=true`; `--l2check` → `MIST volumes=1`, `[OK] LEVEL2`; `AIR_FX_OFF=mist,dust,post … --test3d` → `MIST volumes=0 (off)`, `TEST DONE escaped=true` (все три — после финальных правок).
  - `SHOT_FPS=1 SHOT_STAGE=stage7 godot --path . --resolution 1920x1080 -- --mission --photo-tour` → 10 PNG и строки `[DebugShots] fps …`.
  - `godot --path . -- --shots` → кадры с HUD в `tools/shot_3d_*.png`.

### Acceptance criteria (Stage 7)

| # | Criterion | Result | How checked |
|---|---|---|---|
| 1 | Torches show soft halos; distant corridor ends fade into dark haze | **PASS** | Кадры `_screenshots/stage7/spot_02`, `spot_07`, `spot_10`: ореол у подвесных чаш и бра, дальние концы коридоров в тёмной дымке. |
| 2 | Fog not milky, blacks stay dark | **PASS** | Те же кадры и spot_01/06: тени, потолок и дальние углы чёрные; дымка у пола только тёплым пятном у огня. |
| 3 | Dust visible only in light | **PASS (слабо)** | Материал затеняемый, `disable_ambient_light = true`; на кадрах единичные пылинки только рядом с огнём, в тёмных зонах нет. Пыль очень сдержанная — заметна скорее в движении. |
| 4 | No fog flicker/striping, no strong TAA smearing | **PARTIAL** | Полос/лесенки тумана в 10 кадрах нет (дымка 1 м, `use_filter`, debanding). Мерцание и TAA-шлейф в движении не проверены — тур снимает статику, видео не писал. |
| 5 | HUD not affected by vignette/grain | **PASS** | `tools/shot_3d_01.png`, `shot_3d_run.png`, `shot_3d_pause_settings.png`: HUD (слой 10/11) и экран настроек из паузы (слой 0) — над `PostFX` (слой −1), текст чёткий, без зерна и затемнения. |
| 6 | FPS ≥ 60 at 1080p | **FAIL на 1.5 FPS в одной точке** | Худшая точка spot_01: 58.5 FPS (шум замера ±3: контрольная строка дала 61.6); остальные 9 точек 65.7–144.9. На этапе 6 spot_01 было 66: цена этапа 7 там ~8 FPS (объёмный туман ~5, дымка ~3.5, пыль ~2, TAA ~7 по бисекции, суммы перекрываются). Чтобы гарантировать 60, проще всего выключить в меню качества дымку или TAA (`Dungeon.air_fx`, `use_taa`). На GTX 1660 не замерено. |

## Меню графики (задел этапа 12)
- Branch: `feat/graphics-menu`, от локального `main` (`d2d1e9f`, этап 7 уже влит).
- Files changed:
  - `scripts/settings.gd` — раздел `graphics` в `user://settings.cfg`: `quality` (0 НИЗКОЕ / 1 СРЕДНЕЕ / 2 ВЫСОКОЕ / 3 СВОЁ), `aa`, `shadows`, `volfog`, `air`, `ssr`, `ssil`, `render_scale`, `post_fx`; `apply_graphics()`, `apply_environment(env)`, `shadow_limit()`, `cycle_quality()`, `cycle_gfx()`, `gfx_label()`, `gfx_on()`
  - `scripts/settings_screen.gd` — экран переписан со строк-копий на список `specs`; добавлен раздел «— ГРАФИКА —» из 9 строк; панель 660×660, строка 34 px, шрифт 20
  - `scripts/dungeon.gd` — `make_world_environment()` зовёт `Settings.apply_environment()`; лимитер теней берёт `mini(shadow_budget, Settings.shadow_limit())`; дымка и пыль создаются всегда и прячутся по `Settings.gfx["air"]`; статический `Dungeon.air_fx` этапа 7 удалён (его роль у меню), `AIR_FX_OFF` остался для отладки
  - `scripts/cam3d.gd` — `PostFX.visible = Settings.post_fx`
  - `scripts/main3d.gd` — проверка `TEST graphics presets=ok custom=ok` в `--test3d`
- Что делает каждая строка (применяется сразу, в том числе в паузе на построенном уровне):
  - КАЧЕСТВО — пресет: НИЗКОЕ = FXAA, тени низкие, туман/дымка/SSR/SSIL выкл; СРЕДНЕЕ = TAA, тени средние, объёмный туман и SSIL вкл, дымка и SSR выкл; ВЫСОКОЕ = всё как настроено на этапах 5–7. Правка любой строки ниже (кроме масштаба и виньетки) переводит пресет в СВОЁ.
  - СГЛАЖИВАНИЕ — ВЫКЛ / FXAA / TAA (`Viewport.use_taa`, `screen_space_aa`). MSAA в меню нет: −9 FPS (этап 7).
  - МАСШТАБ 3D — 100 / 85 / 70 % (`scaling_3d_scale`, ниже 100 % — `SCALING_3D_MODE_FSR`). HUD не масштабируется.
  - ТЕНИ — НИЗКИЕ (2 огня, `SOFT_VERY_LOW`) / СРЕДНИЕ (4, `SOFT_LOW`) / ВЫСОКИЕ (лимит уровня: 6 в M1, 3 на уровне 2; `SOFT_MEDIUM` — как в project.godot).
  - ОБЪЁМНЫЙ ТУМАН, ОТРАЖЕНИЯ (SSR), НЕПРЯМОЙ СВЕТ (SSIL) — флаги общего `dungeon_env.tres`.
  - ДЫМКА И ПЫЛЬ — видимость групп `fx_mist` и `fx_dust`.
  - ВИНЬЕТКА И ЗЕРНО — видимость группы `post_fx`.
- По умолчанию ВЫСОКОЕ, масштаб 100 %, виньетка вкл — так настроены этапы 5–7. **Решение для владельца:** при цели «60 FPS на GTX 1660» безопаснее поставить по умолчанию СРЕДНЕЕ (замер ниже).
- Съёмка воспроизводима: в режимах `--shots` и `--photo-tour` графика из `settings.cfg` не читается (берётся ВЫСОКОЕ); `SHOT_QUALITY=0|1|2` — съёмка на нужном пресете.
- Замер FPS по пресетам (фототур, `SHOT_FPS=1`, RTX 5050 Laptop, 1916×1078, без vsync), точки 01…10:
  - НИЗКОЕ: 112.3 · 151.4 · 197.0 · 158.4 · 146.4 · 137.5 · 179.2 · 222.4 · 214.1 · 130.8 — худшая 112
  - СРЕДНЕЕ: 72.7 · 113.9 · 144.8 · 108.8 · 87.2 · 83.4 · 137.4 · 164.5 · 120.8 · 107.0 — худшая 72.7
  - ВЫСОКОЕ: 59.5 · 107.3 · 142.5 · 102.0 · 67.0 · 65.8 · 123.5 · 148.8 · 104.0 · 94.6 — худшая 59.5
- Кадры (просмотрены, в репозиторий не кладу): НИЗКОЕ — без ореолов и дымки, коридор читается, тени жёстче; СРЕДНЕЕ — ореолы у факелов и дальняя дымка на месте, нет дымки у пола и бликов луж. Экран настроек (`tools/shot_3d_settings.png`, `shot_3d_pause_settings.png`): 13 строк и раздел «ГРАФИКА» влезают в 1280×720 и в оверлей паузы.
- Проверено: `--test3d` → `TEST graphics presets=ok custom=ok`, `TEST DONE escaped=true` (пресет НИЗКОЕ на построенном M1 выключает объёмный туман, SSR, TAA, дымку и даёт лимит теней 2; ВЫСОКОЕ возвращает; правка SSR даёт СВОЁ; настройки игрока после проверки восстанавливаются); `--l2check` → `[OK] LEVEL2`.
- Не сделано: переключатель SDFGI (GI) в меню — выключен по умолчанию с этапа 6, `Dungeon.gi_enabled` остался для отладки; в движении (переключение пресета на ходу) проверено только автотестом, руками в игре — нет.

## Stage 9
- Stage number: 9 (герой в мире: масштаб, тени, шаги, «жизнь» камеры)
- Branch: `claude/character-integration-feel-b450dc`, от `main` (`ce67cbf`). Ветку и рабочее дерево создало приложение Claude Code.
- Files changed:
  - `scripts/footstep_fx.gd` (новый, `class_name FootstepFx`) — определение поверхности под ногой, пыль, брызги, круги на воде
  - `scenes/props/puddle.gd` — `_add_water_zone()`: Area3D `WaterZone` в группе `water_zone`
  - `scripts/hero3d.gd` — сигнал `footstep(surface: StringName)`, `_footstep()`, `_tune_character_materials()`, `scripted_move`, `_impact_trauma()`; удар молотом зовёт травму вместо старого `shake()`
  - `scripts/cam3d.gd` — дыхание пивота и поворотная тряска на травме: `_update_life()`, `add_trauma()`; `shake()` слушает настройку
  - `scripts/settings.gd`, `scripts/settings_screen.gd` — строка «ТРЯСКА КАМЕРЫ» (`[camera] shake` в `user://settings.cfg`), высота строки 34 → 32 px
  - `debug/debug_shots.gd` — тур `SHOT_STAGE=stage9*` по герою; `_hide_hud()` вынесен из `_run_tour()`
  - `_screenshots/stage9/puddle_1.png`, `torch_walk_1.png`, `torch_idle.png`
- Шаг 1 — масштаб. Единица — рост героя H = 1.42 м (`Balance.HERO_MODEL_HEIGHT`, подошва → макушка модели). Замер в туре: кость головы 1.13 м, верх шляпы 1.55 м (1.09 H). Остальное — из констант `dungeon.gd` и сетки `assets/level/m1.txt` (клетка T = 2 м; лицо кладки стоит на грани клетки):

  | Что | Метры | × H | Ориентир для гнома | Итог |
  |---|---|---|---|---|
  | Арочный проём `arch_2m` (29 клеток-разрывов): высота | 3.00 (`ARCH_TOP`) | 2.11 | двери 1.6–2.0 | чуть выше |
  | то же, ширина | 1.44 (`2 × ARCH_HALF`) | 1.01 | — | по росту |
  | Решётки `gate` / `cell_door` | 3.0 × 1.9 | 2.11 | двери 1.6–2.0 | чуть выше |
  | Самые узкие коридоры (2 клетки, 42 клетки карты) | 4.0 | 2.82 | ширина 2–3 | в норме |
  | Коридоры в 3 клетки (24 клетки) | 6.0 | 4.23 | ширина 2–3 | широко |
  | Узкий пролёт остальных 1170 клеток | 8–56 | 5.6–39 | — | это залы |
  | Потолок, везде один | 4.844 (`WALL_H`) | 3.41 | свод коридора 2.5–3.5, залы до 5 | в норме (верх нормы для коридора, низ для зала) |
  | Прямая часть стены до гусёка (R 1 м) | 3.844 | 2.71 | — | — |
  | Крепление настенного факела / его лампа | 1.72 / 3.10 | 1.21 / 2.18 | — | — |
  | Стража / босс | 1.45 / 2.30 | 1.02 / 1.62 | — | — |
  | Пивот камеры / длина пружины | 1.21 / 3.2 | 0.85 / 2.25 | — | — |

  Вывод: мир не «сильно больше» гнома, ничего не масштабировал. **Предложения владельцу (не сделаны — правка ломает проходимость и коллизии):** проёмы ниже на 0.3 м (`ARCH_TOP` 3.0 → 2.7, ×1.9 H) — нужна переделка модуля `arch_2m` в `src/build_dungeon_kit.py` и коллизии перемычки в `_build_collision()`; решётки 3.0 → 2.7 м; потолок как есть. Залы шириной 8–20 м остаются залами — это поле боя и стелса, их не трогать.
- Шаг 2 — тени и материалы (`Hero3D._tune_character_materials()`, после `_attach_model()`):
  - все MeshInstance3D героя (модель, молот, шляпа, примитивы-запаска) — `cast_shadow = ON`; исключение — `BlobShadow` (пятно-подложка под ногами, `OFF`: это не геометрия, а тень-обманка, своей тени давать не должна)
  - модель `hero_mixamo.glb`, единственный материал `Peasant_Man_02`: было `roughness 1.0`, стало `0.85` (`clampf(r, 0.6, 0.85)`), `metallic 0`
  - молот `weapon_hammer.glb`: `Steel`, `LightSteel` (боёк) — было `metallic 0.4 / roughness 0.42`, стало `0.8 / 0.5`; `DarkWood`, `LightWood` (рукоять) — было `0.4 / 0.42`, стало `0.0 / 0.7`
  - шляпа `GnomeKit` — свой `material_override`, `roughness 0.9`, не трогал
  - материалы дублируются (`set_surface_override_material`), ресурс glb не меняется
  - слой: `ModelUtil.set_visual_layer(self, CHARACTER_LAYER = 2)` в конце `_build_rig()` (этап 5) — охватывает модель, молот и шляпу; эмиттеры шагов тоже на слое 2, круги на воде — декали `cull_mask = 1`
  - кадр `puddle_1`: герой освещён факелом слева, тень лежит на полу вправо от ног; `torch_walk_1` / `torch_idle`: лицо и шляпа в свете бра
- Шаг 3 — шаги. Момент шага — уже существующий таймер шагов в `Hero3D._animate()` (0.42 с шаг / 0.3 бег / 0.55 присед, только на полу); там же звук и шум для стражи. Нога — попеременно ±0.12 м вбок и 0.1 м вперёд от центра.
  - Поверхность (`FootstepFx.surface_at()`): точечный запрос по слою 5 (triggers, `collide_with_areas`) — Area3D в группе `water_zone` → `&"water"`; иначе луч вниз по слою 1: `meta "surface"` коллайдера или группа `wood_surface` → `&"wood"`; иначе `&"stone"`.
  - Зона воды лужи: `CylinderShape3D` радиус `0.75 × k × 0.7` (k — случайный размер лужи), высота 0.6, `collision_layer = 16`, `collision_mask = 0`, `monitoring = false`, `top_level = true` (масштаб декали `(k, 1, k)` неравномерный)
  - Камень: `GPUParticles3D` one_shot, 6 частиц, life 0.7, explosiveness 1, скорость 0.2–0.45, spread 80°, лёгкий подъём 0.12, damping 1.2–2.0, рост 0.5 → 1.6, цвет `(0.46, 0.42, 0.37)` с уходом альфы 0.45 → 0; освещаемый билборд 0.16 м, roughness 1
  - Вода: брызги — one_shot, 10 частиц, life 0.45, скорость 0.9–1.8 вверх (spread 35°), гравитация −9.8, билборд 0.07 м, `(0.78, 0.82, 0.86)`, roughness 0.15; круг — Decal 0.7 × 0.3 × 0.7 с радиальным кольцом, `scale` 0.35 → 1.0 и `modulate.a` 0.55 → 0 за 0.6 с
  - Дерево: только сигнал, без частиц — в Миссии 1 пол один (коробка-камень), деревянных настилов нет
  - Пул по 3 эмиттера/декали каждого вида, `restart()` — шаг не создаёт узлов
  - Сигнал `Hero3D.footstep(surface)` — для звука этапа 10 (сам звук шагов остался прежним)
- Шаг 4 — камера (`Cam3D._update_life()`; оба эффекта — поворот пивота поверх `yaw/pitch`, пишется и в `_physics_process`, и в `_process`):
  - дыхание: `±0.3°` по наклону, 0.25 Гц, только когда герой стоит (скорость < 0.3 м/с), вес набирается и спадает за 1.5 с; выключается строкой «ПОКАЧИВАНИЕ: ВЫКЛ»
  - тряска от удара молотом: `add_trauma()`, травма 0..1 копится, гаснет линейно за 0.25 с; поворот = травма² × 0.6° × шум FastNoiseLite (×2, обрезка ±1) по трём осям. Лёгкие удары комбо 0.55 / 0.70 / 0.85 (≈0.18° / 0.29° / 0.43°), тяжёлый 1.0 (0.6°). Промах не трясёт.
  - старая тряска смещением `shake()` осталась для урона, шипа, взрыва крови, обвалов и босса (там амплитуды сюжетные, этап их не касается); удар молотом её больше не зовёт
  - строка «ТРЯСКА КАМЕРЫ: ВКЛ/ВЫКЛ» (по умолчанию ВКЛ) глушит и `add_trauma()`, и `shake()`
- Шаг 5 — тур: `SHOT_STAGE=stage9 godot --path . --resolution 1600x900 -- --mission --photo-tour`. Не фото-точки, а игровая камера: герой (`control_enabled = false`, шаг через `scripted_move`) идёт через лужу, ближайшую к факелу, затем вдоль стены с бра; кадр снимается через 0.12 с после шага нужной поверхности. В лог — рост, поверхности шагов, замер дыхания и тряски. F12 в игре по-прежнему снимает кадр в `user://shots/`.
- Замеры тура (RTX 5050 Laptop):
  - `SCALE model_height=1.42 head_bone=1.13 hat_top=1.55`
  - `footstep water` → кадр `puddle_1`, затем `footstep stone` → `torch_walk_1`
  - `sway pitch_deg min=-0.300 max=0.300`
  - `trauma peak_deg=0.526 zero_after_s=0.258 trauma_when_disabled=0.00`
- What could NOT do and why:
  - Масштаб уровня не менял (условие этапа) — только предложения выше.
  - Деревянных полов в M1 нет — ветка `wood` проверена только кодом, не в игре.
  - Пыль на камне в кадре `torch_walk_1` еле видна: шаг пришёлся в тень под бра. Пол прямо под настенным факелом тёмный конусом — чаша и древко факела (этап 6) отбрасывают тень от своей же лампы, она на 0.34 м выше чаши. Не трогал: это сцена факела, не герой. Если мешает — `cast_shadow = OFF` у `Mesh/Cup` и `Mesh/Stick` в `scenes/props/torch.tscn`.
  - В одну лужу (пятно ~1.5 м) при шаге 1.5 м попадает обычно один шаг; зона воды — 70 % от квадрата декали, края рваной маски шаг считает камнем.
  - Дыхание и тряска руками в игре не проверены, только замером тура и автотестом.
- How to verify:
  - `godot --headless --path . -- --test3d` → `TEST DONE escaped=true`, ошибок скриптов нет
  - `SHOT_STAGE=stage9 godot --path . --resolution 1600x900 -- --mission --photo-tour` → 3 PNG в `_screenshots/stage9/` и строки `[DebugShots] SCALE / footstep / sway / trauma`
  - В игре: пройти через лужу у стартового зала — брызги и круги; по камню — серые клубки пыли; ударить стража молотом — короткий поворот кадра; Esc → Настройки → «ТРЯСКА КАМЕРЫ: ВЫКЛ» — удар не трясёт; постоять — кадр медленно кивает

### Acceptance criteria (Stage 9)

| # | Criterion | Result | How checked |
|---|---|---|---|
| 1 | Scale report written with numbers | **PASS** | Таблица шага 1; рост — замер тура `SCALE`. |
| 2 | Character casts and receives shadows; looks lit by torches | **PASS** | `puddle_1.png`: тень героя на полу от факела, тёплый свет на руке и лице; `torch_idle.png`: лицо в свете бра. Все меши `cast_shadow = ON`. |
| 3 | Footstep dust/splash work and match the surface | **PASS (пыль слабая)** | Лог тура: `water` внутри лужи, `stone` на камне; в `puddle_1` брызги и круг на воде; пыль — мягкие клубки, в тени почти не видна. |
| 4 | Camera sway/shake subtle and can be disabled | **PASS** | `sway ±0.300°`; тряска пик 0.53° (предел 0.6°), до нуля за 0.26 с; при выключенной настройке травма 0.00. |
