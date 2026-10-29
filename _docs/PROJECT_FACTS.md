# PROJECT_FACTS.md

## LEVEL CONSTRUCTION METHOD
Mission 1 level (M1) is built procedurally by `res://scripts/dungeon.gd` (`class_name Dungeon`) at runtime via `Dungeon.build()`. The layout is loaded from `res://assets/level/m1.txt` (2D grid) parsed into `grid/map_w/map_h/dist/ceil_h/wtop/pier/arches`. Geometry is assembled from the `dungeon_kit.glb` mesh library (loaded from `res://assets/models/dungeon_kit/dungeon_kit.glb`, cached in `kit{}`), placed with `MeshInstance3D` nodes (walls/floors/corners/arches/ceilings/pillars/gap-fill). Collision is created procedurally with `StaticBody3D`/`CollisionShape3D`. The kit provides wall/floor/ceiling/arch pieces; the builder also procedurally adds torches, props, decals/atmosphere, lights, and builds a `WorldEnvironment` + lights in `dungeon._build_environment()`. The playable mission scene is constructed by `res://scripts/mission3d.gd` which instantiates `Dungeon`, calls `build()`, spawns `Hero3D` and `Cam3D`, etc. Level 2 uses `res://scenes/level2.tscn` built by `res://scripts/level2_builder.gd`.

## a) Godot version and renderer
- `project.godot` config/features: `PackedStringArray("4.4", "GL Compatibility")`
- `rendering/renderer/rendering_method`: `forward_plus` (desktop), `forward_plus` with mobile override `mobile` set
- Renderer: Forward+ (Godot 4.4). WARNING: Forward+ required for volumetric fog/SDFGI/SSIL/SSR; project uses Forward+.

## b) Main scene, level scenes, player scene/script
- Main scene: `res://main3d.tscn` (root `Node3D`, script `res://scripts/main3d.gd`)
- Playable level scenes: Mission 1 is procedural (no standalone .tscn file for the dungeon geometry except constructed at runtime) via `res://scripts/mission3d.gd` + `res://scripts/dungeon.gd`. Level 2: `res://scenes/level2.tscn` built by `res://scripts/level2_builder.gd`.
- Player scene/script: `res://scripts/hero3d.gd` (`class_name Hero3D`, extends `CharacterBody3D`). Instantiated by `mission3d.gd` as `Hero3D.new()`. Also used in showcase modes in `main3d.gd`.

## c) Camera setup
- Camera script: `res://scripts/cam3d.gd` (`class_name Cam3D`, extends `Node3D`)
- Node tree: `Cam3D` has child `SpringArm3D` (`spring`), `SpringArm3D` has child `Camera3D` (`camera`, current). Also adds an `OmniLight3D` as child of camera (attached light).
- SpringArm3D: `spring_length = 4.0`, `margin = 0.25`, `collision_mask = 1`. Camera offset `camera.position = Vector3(0.45, 0.10, 0.0)`. FOV `BASE_FOV = 70.0`. DOF enabled on camera attributes.

## d) Level geometry construction
- Method: Procedural generation by script (`res://scripts/dungeon.gd`). 
  - Loads map from `res://assets/level/m1.txt` (`_load_map()`), computes distances/heights/arches/pillars
  - Loads kit meshes from `res://assets/models/dungeon_kit/dungeon_kit.glb` via `_load_kit()` into `kit{}` dict
  - Builds: `_build_floor()`, `_build_walls()`, `_build_wall_corners()`, `_build_arches()`, `_build_ceiling()`, `_build_piers()`, `_build_gap_fill()`, `_build_collision()`, `_build_props()`, `_dress_rooms()`, `_scatter_torches()`, `_build_environment()`, `_add_atmosphere()`
- Uses `MeshInstance3D` with meshes from kit (e.g. `wall_4m`, `wall_2m`, `floor_4m`, `arch_*`, etc.). Also creates MultiMesh for gap fill. No GridMap/MeshLibrary/CSG visible as primary construction method.

## e) Environment asset/texture pack
- Kit: `res://assets/models/dungeon_kit/dungeon_kit.glb` (Medieval Underground Dungeon kit). Textures under `res://assets/models/dungeon_kit/textures/` (e.g. `brickwalls_basecolor.jpg`, `brickwalls_normal.jpg`, `brickwalls_mr.png`, etc.). Script references kit textures via `_kit_tex()`.
- 3D textures: `res://assets/tex3d/` contains various PNGs (used by shaders/materials).
- Kit contains meshes (walls/arches/floors etc.) as seen from code; license not explicitly read in files scanned.

## f) WorldEnvironment nodes and Environment resources
- Mission level: created in `dungeon._build_environment()` (line ~1092+ in dungeon.gd). Adds `WorldEnvironment` with `Environment`.
  - background_mode = BG_COLOR, background_color = Color(0.02,0.018,0.016)
  - ambient_light_source = AMBIENT_SOURCE_COLOR, ambient_light_color = Color(0.34,0.42,0.56), ambient_light_energy = 0.48
  - tonemap_mode = TONE_MAPPER_ACES, tonemap_exposure = 1.35
  - glow_enabled = true, glow_intensity = 0.26, glow_bloom = 0.035, glow_hdr_threshold = 1.1
  - fog_enabled = true, fog_light_color = Color(0.085,0.09,0.115), fog_density = 0.009
  - ssao_enabled = true, ssao_radius = 1.2, ssao_intensity = 2.0
  - ssil_enabled = true, ssil_radius = 2.0, ssil_intensity = 1.2, ssil_sharpness = 0.98
  - volumetric_fog_enabled = true, volumetric_fog_density = 0.01, volumetric_fog_albedo = Color(0.12,0.1,0.08), volumetric_fog_emission_energy = 0.0, volumetric_fog_anisotropy = 0.45, volumetric_fog_length = 40.0
  - adjustment_enabled = true, adjustment_brightness = 1.04, adjustment_contrast = 1.08, adjustment_saturation = 0.88
- Also adds DirectionalLight3D (fill) in `_build_environment()`: light_color = Color(0.58,0.66,0.86), energy 0.5, shadow_enabled false, rotation (-55,32,0)
- Level2: `level2_builder._build_environment()` similar setup (tonemap AGX)
- Showcase modes in `main3d.gd` create temporary environments

## g) Light nodes
- Dungeon places torches via `_scatter_torches()` and `_torch()` calls (mission3d calls `dungeon._torch()` twice at start). Torches create lights (OmniLight3D) with flame VFX.
- `dungeon.lights` array holds lights; `_count_lights()` in tests counts all Light3D. Test warns if > 30.
- `dungeon` also has `flames` array. DirectionalLight3D fill added in environment. Camera has attached OmniLight3D (lamp) in Cam3D.
- No obvious LightmapGI/VoxelGI/ReflectionProbe seen in scanned code.

## h) Water/puddles
- `dungeon.mat_puddle_water: StandardMaterial3D` defined. Code searches for puddles/water in stage description context; need to look up actual puddle nodes. From grep/results earlier and dungeon codebase patterns, puddles may be MeshInstance3D with `mat_puddle_water`. Also mission has references to puddles in photo spot suggestions. Check: `dungeon` builds puddles? Look for "puddle" in dungeon.gd more closely.

## i) Collision setup
- Physics layers: layer_1="world_static", layer_2="player", layer_3="npc", layer_4="props_dynamic", layer_5="triggers" (from project.godot)
- Hero is CharacterBody3D on layer 2, mask 1. Enemies similar. Dungeon creates collision via `_build_collision()` with StaticBody3D shapes.

## j) Materials
- Materials created in dungeon: `mat_floor` (ShaderMaterial), `mat_wall` (ShaderMaterial), `mat_ceil` (Material), `mat_metal`, `mat_wood`, `mat_dark`, `mat_glow`, `mat_flame`, `mat_flame_core`, `mat_puddle_water` (StandardMaterial3D), `mat_banner` (StandardMaterial3D), `mat_cap` (ShaderMaterial), `mat_brick` (StandardMaterial3D), plus `_mat_dirt`. Many use kit textures via `_brick_material()` and `_kit_tex()`. UV scaling/triplanar depends on shader/material setup.

## k) Anti-aliasing and related settings
- project.godot rendering section doesn't show explicit msaa/screen_space_aa/taa settings visible in scanned lines; defaults apply. Need to check full project settings.

## l) Character height
- Hero capsule: radius 0.36, height 1.5, collision shape position (0,0.78,0). Model scale/height varies if using glTF model; code sets up rig. Typical door/corridor heights from dungeon constants: `WALL_H := 4.844`, `ARCH_TOP := 3.0`, corridors built from kit pieces.

## HOW TO RUN A LEVEL DIRECTLY
- Mission 1: run from main scene `res://main3d.tscn` and go to mission (or `main3d.start_mission()`). Can also use `--mission` arg. For debugging, `mission3d` is instantiated directly.
- For photo tour per stage 0 instructions: use `godot --path . -- --photo-tour --photo-scene=res://main3d.tscn` or load mission directly; may need to start mission. Check main3d args - it goes to menu by default, has `--mission`. Also debug_shots waits 3s after scene change.
