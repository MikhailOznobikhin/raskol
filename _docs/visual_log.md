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
