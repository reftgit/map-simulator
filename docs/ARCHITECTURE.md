# Architecture

How the game code is organized and how to extend and test it. Implementation status lives in `PROJECT_STATE.md`; decision rationale lives in `PROJECT_CONTEXT.md`.

Engine: Godot 4.7.2, GDScript with static typing. 1 unit = 1 m; forward is -Z.

## Directory layout

```text
game/
  main.tscn, game.gd        Composition root (main scene)
  world/                    WorldManager, MapDefinition
  player/                   PlayerController, PlayerIntent, input sources, player.tscn
    state_machine/          PlayerStateMachine, PlayerState, Idle/Walk/Run states
  camera/                   ThirdPersonCamera, CameraProfile, on-foot profile
  input/                    MobileInputController, TouchControl, TouchLookArea, TouchButton
  ui/                       UIController, hud.tscn
  quality/                  RenderSettings (applies render settings), QualityProfile, QualityProfiles, profiles/high.tres, low.tres
  debug/                    PerfConfig (experiments), PerfBenchmark (debug builds only)
maps/<map_name>/            One folder per map: scene, MapDefinition (.tres), map script, baked occluders (.scn)
assets/                     Map model and metadata (the 502 MB GLB is not in Git)
scripts/, main.tscn         Original explorer demo from the map package (desktop only, not used by the game)
tests/                      Headless test runner, unit and integration suites, fixtures
tools/                      Development tools (screenshot capture, iOS debug build, occluder bake, perf scripts)
docs/                       This file, map documentation
build/                      Export output, ignored by Git except build/.gdignore (keeps Godot from importing it)
export_presets.cfg          "Android Debug", "Android Debug Compatibility", and "iOS Debug" presets
```

## Runtime structure

```text
Main (game.gd) ─ wires everything once in _ready()
├── WorldManager          loads maps/<map>/<map>.tscn from a MapDefinition; respawn and bounds
│   └── IstanbulHalic     map scene: GLB, sky/ambient, sun, water shader, vertex-color fix
│       └── Occluders     baked occluders, added when the profile enables occlusion
├── Player                PlayerController (CharacterBody3D, layer 2)
│   └── StateMachine      Idle, Walk, Run (child nodes)
├── ThirdPersonCamera     top-level rig → PitchPivot → SpringArm3D → Camera3D
├── TouchPlayerInput      PlayerInputSource: stick + camera yaw → PlayerIntent
└── HUD                   UIController (CanvasLayer): safe area, debug overlay
    └── SafeArea/Controls MobileInputController
        ├── LookArea      TouchLookArea (right 58 %)
        ├── Joystick      native VirtualJoystick (left 42 %), drives move_* actions
        ├── RunButton     TouchButton, toggle
        ├── DebugViewButton     TouchButton "VIEW", debug builds only (extra_controls)
        └── DebugQualityButton  TouchButton "Q", cycles quality profiles, debug builds only
```

`game.gd` also owns a `RenderSettings` object (created after the map loads) that applies the quality profile.

Systems do not search for each other. `game.gd` is the only place that connects them.

## Per-frame data flow

1. **Touch.** The native `VirtualJoystick` writes the `move_left/right/forward/back` actions. `MobileInputController._input()` routes every other touch to one `TouchControl` in priority order (run button, `extra_controls`, then look area) and owns that finger until release. A finger that starts on the look area keeps turning the camera even if it slides over a button. Unclaimed touches fall through to the GUI, where the joystick takes them.
2. **Camera (`_process`).** `ThirdPersonCamera` consumes the look delta (radians), clamps pitch, follows the target's interpolated transform, and lets the `SpringArm3D` (sphere, world layer) pull the camera in front of walls.
3. **Player (`_physics_process`).** `PlayerController` clears its `PlayerIntent` and asks its `input_source` to fill it. `TouchPlayerInput` rotates the stick by the camera yaw (`camera_relative`). The active `PlayerState` picks the target speed and transitions, `apply_locomotion()` accelerates, turns the body, and applies gravity, then `move_and_slide()` runs.
4. **World (`_physics_process`).** `WorldManager` respawns tracked bodies below `kill_height` and clamps them to `bounds`.

## Module map

The specification suggested these modules. Status as of Phase 1:

| Module | Implementation | Status |
|---|---|---|
| PlayerController | `game/player/player_controller.gd` | Phase 1 |
| PlayerStateMachine | `game/player/state_machine/` | Phase 1: Idle, Walk, Run |
| ThirdPersonCamera | `game/camera/third_person_camera.gd` + `CameraProfile` | Phase 1 |
| MobileInputController | `game/input/mobile_input_controller.gd` + touch controls | Phase 1 |
| WorldManager | `game/world/world_manager.gd` + `MapDefinition` | Phase 1 |
| UIController | `game/ui/ui_controller.gd` | Phase 1: safe area, debug overlay |
| Quality profiles | `game/quality/` (`RenderSettings`, `QualityProfile`) | High (iOS) and Low (Android) |
| PlayerCombat | not started | Phase 2 |
| PlayerAnimation | not started; will listen to `PlayerStateMachine.state_changed` | Phase 2 |
| VehicleController, VehicleInteraction | not started | Phase 3 |

## Extension points

- **New map:** add `maps/<name>/<name>.tscn` and a `MapDefinition` resource (scene path, spawn position and yaw, bounds, kill height), then point `Main.map_definition` at it. Player, camera, and input code stay unchanged.
- **New player action (punch, roll):** add a `PlayerState` child under `Player/StateMachine` and a field on `PlayerIntent`. States switch with `machine.transition_to(&"Name")`.
- **Other drivers (AI, bots, replays):** subclass `PlayerInputSource` and implement `fill_intent()`. The controller does not know where intents come from.
- **Vehicles (Phase 3 plan):** call `ThirdPersonCamera.set_target(vehicle, vehicle_profile)` with a vehicle `CameraProfile`; give the HUD a vehicle control set next to the on-foot one.
- **New touch control:** subclass `TouchControl`, add it under `HUD/SafeArea/Controls`, and register it in `MobileInputController`'s priority list.

## Physics layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Map static bodies (GLB `-col` nodes). Mask of the player and the camera spring arm. |
| 2 | player | Player body. |

The map has collision on `Ground_*` terrain (streets included), `Buildings_*`, `Mosque_*`, `TreeTrunks_*`, landmarks, and the two bridge decks. Roads, pavements, railings, lamps, decor, and water have no collision of their own.

## Input

- Touch is primary. Several fingers work at once; each finger belongs to one control until it lifts.
- Running is a toggle button that turns off when the joystick finger lifts (`run_resets_on_release`).
- Desktop development: WASD or arrow keys move, Shift runs, and the mouse emulates touch (`emulate_touch_from_mouse`), so left-drag on the left half is the joystick and left-drag on the right half turns the camera.
- When the app loses focus or pauses, `MobileInputController.release_all_touches()` drops routed fingers, turns the run toggle off, sends touch releases so the native joystick forgets its finger, and releases the `move_*` and `run` actions.

## Debug measurement tools (debug builds only)

- Overlay (top left): FPS, draw calls, primitives, objects, video memory, engine static memory (current and peak), player state and speed, current viewpoint, quality profile.
- Log lines: `PERF profile=… view="…" fps=… draw_calls=… …` every 2 s; `QUALITY profile=… experiment=… occluders={…} effective={…}` whenever settings are applied; `STARTUP map_ready_ms=… first_frame_ms=… profile=… occluders={…}` once; `VIEW <name>` on each switch.
- Q button: cycles quality profiles none → high → low (the debug experiment, if any, stays on top).
- VIEW button: cycles Spawn → the map's `debug_viewpoints` (`MapDefinition`, names in `debug_viewpoint_names`).
- Reading the logs: Android `adb logcat -s godot`; iOS: Godot output goes to the unified log, not to `devicectl --console`; record it with `xcrun xctrace record --template Logging --device <udid> --all-processes` and export the `os-log` table. Screenshots: `adb exec-out screencap -p`, `xcrun devicectl device capture screenshot`. iOS memory and thermal state: Instruments "Activity Monitor" template (`memory-physical-footprint`, `device-thermal-state-intervals`).

## Rendering and performance settings

- Mobile renderer on all platforms (`rendering_method` and `rendering_method.mobile`). Measured on macOS: Metal, "Forward Mobile".
- Quality profiles change the values below on devices; see "Quality profiles".
- Sun: 2-split directional shadows, 60 m distance (the original demo used 4 splits and 450 m).
- Camera far plane 1500 m. MSAA 3D 2× (inherited from the map project). Physics interpolation is on (60 Hz physics, smooth on 120 Hz screens).
- Landscape (`sensor_landscape`), 1440×900 base canvas with `canvas_items` stretch and `expand` aspect, so phones get a wider canvas at 900 units tall.
- Touch sizes: joystick 220 units and run button 124 units. On an iPhone 13 Pro (1170 px landscape height, 460 ppi) that is about 95 pt / 16 mm and 54 pt / 9 mm; Apple's minimum touch target is 44 pt. Calculated, not measured on a device.

## Testing

```bash
godot --headless --path . --import                                 # after adding or renaming scripts
godot --headless --path . --script res://tests/run_tests.gd         # all suites
godot --headless --path . --script res://tests/run_tests.gd -- unit # unit suite only
godot --headless --path . --script res://tests/map/validate_scene.gd # original map validation
```

- Output: one `PASS`, `FAIL`, or `SKIP` line per test, then `RESULT <n> passed, <n> failed, <n> skipped`.
- A test fails when a check fails **or** when any engine or script error is logged while it runs (captured with a `Logger` via `OS.add_logger`). GDScript runtime errors abort only the failing function, so a test that crashes halfway would otherwise look like a pass. Warnings are printed but do not fail a test. A test file that fails to load counts as a failure.
- Exit code: `0` no failures and no skips; `1` any failure, an error logged outside a test, or nothing passed; `2` no failures but some tests skipped.
- `tests/unit/` runs without the map. `tests/integration/` loads the real map; when `assets/istanbul_halic.glb` is missing its tests are reported as `SKIP` (via the file's `skip_reason()`), and the full run exits 2.
- Tests send touches through `Input.parse_input_event`, the same pipeline device touches use, with positions converted from canvas units to window pixels.
- Visual check without a device (opens a window):

  ```bash
  godot --path . --resolution 1266x585 --script res://tools/capture_screenshot.gd -- --out=/abs/path/shot.png --walk --run
  ```

  The tool prints renderer, FPS, draw calls, and primitive counts for the frame.

## Quality profiles

Permanent render settings per device class, applied in every build.

| Profile | Default on | Settings (unset keys keep the scene default) |
|---|---|---|
| none | desktop, editor, tests | none |
| high | iOS | 60 FPS cap, occlusion culling, 200 m visibility range for trees, lamps, decor, facade detail |
| low | Android | 30 FPS cap, occlusion culling, 100 m visibility ranges (same categories), 400 m far plane with depth fog, shadows off, 0.6 render scale, LOD threshold 4 |

- **Resources:** `QualityProfile` (`game/quality/quality_profile.gd`), `game/quality/profiles/{high,low}.tres`. `to_settings()` returns only the keys the profile sets.
- **Selection** (`QualityProfiles`, strongest first): a debug experiment's `profile` key → `--quality=<none|high|low>` on the command line → platform rule (`OS.has_feature("ios")` → high, `"android"` → low, otherwise none). No GPU detection.
- **Applying:** `RenderSettings` (`game/quality/render_settings.gd`) applies a settings dictionary over the defaults it captured from the scene: map-category visibility and visibility ranges, camera far plane, depth fog on the loaded environment, sun shadow mode, viewport scale/LOD/occlusion, `Engine.max_fps`. Keys a layer leaves out are reset to the defaults, so `set_quality_profile()` can switch at runtime.
- **Precedence:** experiment > profile > defaults (`RenderSettings.merge`, per key; dictionary keys such as `visibility_end` are replaced as a whole).
- **Occluders:** with occlusion on, `RenderSettings` loads `MapDefinition.occluders_path` (baked); if it is missing it builds occluders from the `buildings` and `ground` collision and logs a warning.
- **Baking occluders** (after any map change):

  ```bash
  godot --headless --path . --import
  godot --headless --path . --script res://tools/bake_occluders.gd   # -- --map=res://maps/<name>/<name>.tres
  ```

  Output for İstanbul • Haliç: `maps/istanbul_halic/istanbul_halic_occluders.scn`, compressed binary, 2,300,873 bytes; 643 occluders, 317,518 triangles, 206,048 shared vertices (the runtime build has 952,554 unshared). `test_baked_occluders_match_runtime_build` checks count, triangles, and extent against the runtime build.

## Performance experiments (debug builds only)

Temporary settings layered on top of a profile for measurements. With no experiment and the "none" profile the game runs with scene defaults (`test_no_perf_experiment_by_default`).

- **Flags:** `PerfConfig` (`game/debug/perf_config.gd`) holds one experiment, parsed from JSON; unknown keys, categories, or profiles are rejected. Keys: `experiment`, `profile` (`none`/`high`/`low`; omitted = platform default), the `RenderSettings` keys `hide` (categories), `visibility_end` ({category: metres}), `camera_far` + `fog`, `shadows` (`default`/`off`/`single`), `render_scale` + `scaling_mode` (`bilinear`/`metalfx`; FSR is Forward+ only in Godot 4.7.2), `max_fps`, `occlusion`, `lod_threshold`, and an optional `bench` section (`warmup_s` 30, `measure_s` 60, `views`, `session_minutes`, `session_view`, `screenshots`, `quit_when_done`). Experiments from the 2026-10-24 diagnosis pin `"profile": "none"`, the condition they were measured under.
- **Applying:** `game.apply_perf_experiment()` merges the experiment over its profile and applies it through the same `RenderSettings`; there is no separate experiment code path.
- **Categories** (by node-name prefix, checked in this order; every one of the 3,055 map meshes matches one, enforced by `test_perf_categories_cover_every_map_mesh`; defined in `RenderSettings.CATEGORIES`):

  | Category | Prefixes | Mesh nodes | Triangles (LOD0, from the GLB) |
  |---|---|---|---|
  | facade_detail | `Detail_`, `MosqueDetail_`, `LandmarkDetail_` | 371 | 4,536,517 (64.2 %) |
  | decor | bridge details and glass, `RoadPaint_`, `TrafficSignals_`, `SignalGlow_`, `Ferry_` | 299 | 159,048 (2.2 %) |
  | lamps | `StreetLamps_`, `LampGlow_` | 517 | 305,368 (4.3 %) |
  | trees | `Trees_`, `TreeTrunks_`, `Shrubs_` | 465 | 1,246,592 (17.6 %) |
  | buildings | `Buildings_`, `Mosque_`, `Landmark_` | 371 | 144,716 (2.0 %) |
  | ground | `Ground_`, `Road_`, `Pavement_`, `Quays_`, `Gardens_`, bridge decks | 1,031 | 678,214 (9.6 %) |
  | water | `Water` | 1 | 2 |

- **Loading:** `game.gd` reads `--perf-config=<path>` from the command line (desktop) or a one-shot `user://perf_bench.json` (devices; deleted when read). Experiment definitions live in `tools/perf/experiments/*.json`.
- **Benchmark:** `PerfBenchmark` visits each viewpoint, waits `warmup_s`, then records every frame time for `measure_s`: average FPS (frames / time), 1 % low (FPS at the 99th-percentile frame time), minimum FPS (longest frame), and per-second averages of draw calls, primitives, and objects, plus peak video memory and engine static memory. Each result records the active profile. It logs `BENCH {json}` lines, writes `user://bench_results.json` (with the profile, the occluder source and load time, and the startup times), saves 640 px JPEG screenshots to `user://bench/`, then quits (Android) or hides the map and drops to 5 FPS until the host terminates it (iOS ignores `quit()`).

### Measurement protocol and host scripts

```bash
# Android (debug APK installed; do not run Godot --import/--export meanwhile: the editor stops adb on exit)
tools/perf/run_batch.sh android build/perf/android tools/perf/experiments/baseline.json ...
# iOS (debug app installed; Auto-Lock off)
IOS_UDID=<udid> tools/perf/run_batch.sh ios build/perf/ios tools/perf/experiments/baseline.json ...
python3 -I tools/perf/summarize.py build/perf/android   # Markdown tables
```

- Cold start for every run. Android: the batch waits until the battery is back to its starting temperature (+0.5 °C) and keeps the screen on while plugged in (`svc power stayon usb`, restored afterwards). iOS: each run waits for the Instruments thermal state "Nominal".
- Per viewpoint (Spawn, Karaköy, Galata): 30 s warm-up, 60 s measurement. The app is closed between runs.
- Recorded per run: Android battery temperature and thermal status at start and end, peak PSS (`dumpsys meminfo` every 15 s); iOS thermal state and app physical footprint from 3 s "Activity Monitor" probes every ~45 s (`tools/perf/parse_xctrace.py`). A run that reaches "Serious" on iOS is invalid.
- The probes themselves add load. On the tablet, `dumpsys meminfo` every 15 s causes single 100+ ms frames, which lowers the minimum FPS (average unaffected); set `SAMPLE_PSS=0` for frame-pacing measurements. On iOS an Instruments session runs for 3 s of every ~45 s.
- Results, conditions, and screenshots of the 2026-10-24 pass are kept in `docs/perf/` (`results/<device>/<experiment>.json` and `.meta.json`; 480 px screenshots). Regenerate the tables with `python3 -I tools/perf/summarize.py docs/perf/results/android --compact`.
- Renderer comparison: Android uses the "Android Debug Compatibility" preset (`--rendering-method gl_compatibility` embedded); iOS passes the same argument at launch (`APP_ARGS`).

## Device builds (debug)

Never upload to a store, TestFlight, or Play Console from these steps.

```bash
# Android: arm64 APK signed with the Godot editor's debug keystore (local editor settings)
godot --headless --path . --export-debug "Android Debug" build/android/map-simulator-debug.apk
adb install -r build/android/map-simulator-debug.apk

# iOS: Xcode project export + xcodebuild WITHOUT -allowProvisioningUpdates (no portal changes)
tools/build_ios_debug.sh               # build only
tools/build_ios_debug.sh <device-udid> # build and install with devicectl
```

- Identifiers: Android `com.mirongi.mapsimulator`; iOS debug `com.mirongi.mapsimulator.dev` on the temporary team in `export_presets.cfg`. The final iOS ID `com.mirongi.mapsimulator` must not be registered from this Mac (`PROJECT_CONTEXT.md` D8–D9).
- Requirements: Godot 4.7.2 export templates; Android SDK, JDK, and debug keystore configured in the Godot editor settings; Xcode with a signing identity and a matching team profile.
- The imported map is about 195 MB of the 224 MB APK.

## Conventions

- One `class_name` per reusable module; `##` doc comments at the top of each script; tabs for indentation.
- Scenes are `.tscn` text files; shared tunables live in resources (`CameraProfile`, `MapDefinition`).
- Commit the `.uid` files Godot generates next to scripts.
- Exported script properties use `Array[String]`, not `PackedStringArray`: Godot 4.7.2's export conversion of `.tres` files dropped an exported `PackedStringArray`. `test_no_packed_string_array_exports` enforces this.
