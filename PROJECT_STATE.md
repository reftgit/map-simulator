# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure, build, and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-10-24 (performance diagnosis pass, Claude Code)

## Current phase

**Performance diagnosis pass before Phase 2 (user-approved order): measurements done, no permanent setting changed.** Phase 1 (mobile character control) is functionally accepted on an iPhone 13 Pro and a Samsung Galaxy Tab A7. This pass measured where the frame cost goes and which runtime settings could meet the user's targets; see "Performance diagnosis pass" below. Default game behaviour is unchanged: every experiment is a debug-only, runtime flag.

## Current objective

User decision on which measures to adopt (settings package and/or map-level work), then Phase 2. See "Recommended next task".

## Git

- Branch: `main`. Remote: `origin` → `https://github.com/reftgit/map-simulator.git`. Upstream: `origin/main`.
- `3c0771c`: development protocol bootstrap.
- `3a9a49b`: Phase 0, original map project imported (files matched the package manifest; Godot 4.7.2's first import added seven default-valued keys to `assets/istanbul_halic.glb.import`), audit recorded.
- `e221c56`: Phase 1 implementation.
- `6c37037`: test runner fails tests that log errors; SKIP without the GLB.
- `8865437`: joystick and actions released on focus loss and pause; interpolation reset on clamp.
- `565ff0f`: personal source paths replaced with `<SOURCE_PACKAGE>`.
- `b4d2b2c`: debug performance overlay, PERF/STARTUP logs, VIEW measurement viewpoints.
- `bab2b88`: fix for viewpoint names lost in exported builds.
- `fb1ab19`: export presets, icon, iOS build script, Phase 1 device results.
- Performance experiment flags, benchmark, host scripts, tests: the first commit after `fb1ab19`; measurement results and documentation: the commit after that (`git log`).

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Game code: composition root, world, player, camera, input, HUD with debug overlay. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition` (with two debug viewpoints). |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; ETC2/ASTC import (required for Android export); placeholder icon. |
| `export_presets.cfg` | "Android Debug" (arm64 APK, `com.mirongi.mapsimulator`), "Android Debug Compatibility" (same, with `--rendering-method gl_compatibility`), and "iOS Debug" (`com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, project-only export). No passwords or keystore paths. |
| `icon.svg` | Placeholder app icon (capsule character over water). |
| `tests/` | Headless runner, 46 unit tests, 8 integration tests, flat-map fixture, original map validation. |
| `tools/capture_screenshot.gd` | Windowed render to PNG with render stats. |
| `tools/build_ios_debug.sh` | iOS debug build without contacting the Apple Developer portal; optional `devicectl` install. |
| `game/debug/` | Debug-only performance experiments: `PerfConfig` (flags from JSON), `PerfExperiments` (applies them at runtime), `PerfBenchmark` (automatic measurement). |
| `tools/perf/` | Experiment definitions (`experiments/*.json`), device orchestration (`android_bench.sh`, `ios_bench.sh`, `run_batch.sh`), `parse_xctrace.py`, `summarize.py`. |
| `docs/perf/` | Raw results and conditions of every run (`results/`), 480 px screenshots per experiment (`android/`, `ios/`); 1.8 MB. |
| `build/.gdignore` | Keeps Godot from scanning or packing build output. Everything else in `build/` is ignored by Git. |
| `main.tscn`, `scripts/` | Original explorer demo, unchanged. Desktop only. |
| `assets/istanbul_halic.glb` | 502 MB, **not tracked**. Restore: `docs/maps/istanbul_halic/README.md`. |
| `.vscode/settings.json` | The user's editor colors. Untracked, intentionally not committed. |

## Implemented features

- Phase 1 controls: native `VirtualJoystick` (left 42 %), camera drag area (right 58 %), run toggle, camera-relative movement, Idle/Walk/Run states, spring-arm third-person camera, safe-area HUD, map loading with spawn, respawn, and bounds. Details in `docs/ARCHITECTURE.md`.
- Focus loss and pause release the joystick, the `move_*`/`run` actions, and the run toggle.
- Debug builds only: overlay with FPS, draw calls, primitives, objects, video memory, engine static memory; `PERF` log line every 2 s; `STARTUP` log line; VIEW button cycling Spawn → Karaköy street (facing north) → Galata street (facing south).
- Android and iOS debug export presets.
- Android Compatibility debug preset (same code, `--rendering-method gl_compatibility`) for renderer comparisons.
- Debug builds only: performance experiment flags (`PerfConfig`), applied at runtime without touching map files, and an automatic benchmark (`PerfBenchmark`) driven by host scripts in `tools/perf/`. Off unless an experiment file or `--perf-config` is given.

## Device results (2026-10-24, debug builds)

### Devices and builds

| | Android | iOS |
|---|---|---|
| Device | Samsung Galaxy Tab A7 (SM-T500), Android 12, Snapdragon 662 / Adreno 610, 2000×1200 | iPhone 13 Pro (A15), iOS 26.6.1, 2532×1170, 120 Hz |
| Renderer (from engine log) | Vulkan 1.1.128, Forward Mobile | Metal, Forward Mobile, "Apple A15 GPU" |
| Build | `Android Debug` preset, APK 223.7 MB (195 MB of it the imported map), debug keystore, `adb install` | `tools/build_ios_debug.sh` flow, app bundle 286 MB, Xcode-managed wildcard team profile, `devicectl` install |
| Measurement source | overlay screenshots (`adb screencap`), `PERF`/`STARTUP` lines (`adb logcat`), `dumpsys meminfo`, `dumpsys battery`/`thermalservice` | overlay screenshots (`devicectl device capture screenshot`), `STARTUP`/`PERF` lines (Instruments "Logging" template), memory and thermal state (Instruments "Activity Monitor") |

### Startup

| | Android | iOS |
|---|---|---|
| Activity/process launch to first Android frame (`am start -W` TotalTime, cold) | 1,597 ms; 2,899 ms (two runs) | not measured |
| Engine start → map ready (`STARTUP map_ready_ms`) | 15,196 ms; 9,720 ms | 1,565 ms |
| Engine start → first game frame (`first_frame_ms`) | 20,683 ms; 12,452 ms | 1,649 ms |

### Frame statistics at the measurement viewpoints

Draw calls, primitives, and objects come from the overlay/PERF line at a fixed position and camera; they do not depend on temperature. FPS does.

| Viewpoint | Android FPS | Android draw calls / primitives / objects | iOS FPS | iOS draw calls / primitives / objects |
|---|---|---|---|---|
| Spawn (Galata Bridge) | 6–7 | 1,068 / 2,593,418 / 1,233 | 89 (cold, ~1.5 min after launch); 78 (~3.5 min); 44 (after ~2.5 h, thermal "Serious") | 1,192 / 2,840,670 / 1,359 |
| Karaköy street, facing north | 5–6 | 1,326 / 3,250,823 / 1,531 | 43 (after ~2.5 h, "Serious") | 1,495 / 3.37 M / 1,702 |
| Galata street, facing south | 7–8 | 946 / 2,252,298 / 1,147 | 53 (after ~2.5 h, "Serious") | 1,114 / 2.55 M / 1,319 |

iOS frame rates above 60 are possible because the 120 Hz display is not capped. The iPhone stayed in the app for about 2.5 hours at the spawn while waiting for the user's taps; this long run was not planned. The iPhone shows more objects than the tablet because its wider aspect ratio shows more of the scene.

### Memory and heat

| | Android | iOS |
|---|---|---|
| Process memory | PSS 507–528 MB (peak sampled 528,145 KB), plus 112–225 MB swap PSS | physical footprint 1.02 GiB (at ~3 min and at ~2.5 h); resident 385 MiB → 162 MiB |
| Engine-reported | video memory 559 MB; static 179–182 MB | video memory 670 MB; static 172–178 MB |
| Heat | battery 33.5 → 34.0 °C (run 1) and 35.0 → 35.5 °C (run 2, ~1.5 min); thermal status 0 | thermal state "Serious" at ~3 min and at ~2.5 h; CPU ~41–47 % |

### On-device checklist

| Item | Android | iOS |
|---|---|---|
| App opens | PASS | PASS |
| Joystick and camera drag at the same time | PASS (user) | PASS (user) |
| Drag starting on the run button does not turn the camera; run toggle on/off and reset on stick release | PASS (user) | PASS (user) |
| HUD clear of notch, rounded corners, home indicator | PASS (screenshot; the tablet has no notch) | PASS (screenshot: overlay and VIEW start inside the notch-side inset; controls sit above the home indicator) |
| Backgrounding with the joystick held does not leave the character walking | PASS (simulated: `adb input motionevent DOWN/MOVE`, HOME, relaunch → `Walk 4.5 m/s` before, `Idle 0.0 m/s` after, same session) | PASS (user) |
| Heat / stutter | Severe stutter from 5–8 FPS; no thermal warning in ~1.5 min | Thermal "Serious"; FPS fell from 89 to 43–53 |
| VIEW viewpoints | PASS after fix `bab2b88` (first build raised "Out of bounds get index") | PASS (user taps) |

User feedback: asked about touch feel, camera sensitivity, stutter, and heat, the user chose the prepared answer "Kontroller iyi, oyun yavaş" ("controls are fine, the game is slow"). No free-text comment was given.

## Performance diagnosis pass (2026-10-24, debug builds)

Goal (user): Galaxy Tab A7 class at a stable 30 FPS; iPhone 13 Pro capped at 60 FPS for a 10-minute session with thermal state at most "Fair" and FPS ≥ 55. Meeting them was not required; the pass measures which measures could.

### Builds, devices, protocol

- Builds: debug, current `main` plus the experiment code. Android "Android Debug" APK (Vulkan 1.1.128, Forward Mobile, Adreno 610) and "Android Debug Compatibility" APK (same code, `--rendering-method gl_compatibility`, OpenGL ES 3.2). iOS via `tools/build_ios_debug.sh` (Metal, Forward Mobile, A15).
- Viewpoints: Spawn (Galata Bridge), Karaköy street facing north, Galata street facing south. Per viewpoint 30 s warm-up, 60 s measurement (every frame time recorded); app closed between runs; run definitions in `tools/perf/experiments/`.
- Cold start: Android waited until the battery was back at the batch start temperature +0.5 °C (33.5 °C start; runs started at 34.0–35.5 °C); iOS waited for the Instruments thermal state "Nominal" before every run.
- Thermal and memory: Android battery temperature and thermal status at start and end, peak PSS from `dumpsys meminfo` every 15 s; iOS thermal state and app physical footprint from 3 s Instruments probes every ~45 s (probe times in `docs/perf/results/ios/*.meta.json`).
- Measurement side effects found: `dumpsys meminfo` sampling causes single 100+ ms frames on the tablet. Without it (`combo_e_aggressive_cap30_nopss`) the minimum FPS rose from ~8.5 to 23.6–25.1 at the same average. Minimum FPS of the other Android runs therefore reflects the sampler; averages are unaffected (the two runs differ by ≤ 0.1 FPS).
- Drift check: `baseline_repeat`, run two hours after `baseline`, matched within 0.02 FPS average.
- iOS protocol deviation: every run without a frame cap, and every run with the 60 FPS cap but without geometry reduction, reached "Serious" (uncapped baseline at ~91 s; four 60-capped runs at the same ~141 s probe). Such runs are marked INVALID; repeating them is pointless because the onset is reproducible. Single measures were therefore measured on top of the 60 FPS cap (the user's target condition), and the time to "Fair"/"Serious" is reported as the thermal result.
- Screenshots of each experiment: `docs/perf/android/`, `docs/perf/ios/` (taken by the benchmark after each viewpoint; the debug overlay in them shows the counters).

### Galaxy Tab A7 (SM-T500) — all runs

Values are Spawn / Karaköy / Galata. Memory is peak PSS. Thermal status stayed 0 in every run.

| Experiment | Avg FPS (S / K / G) | 1% low | Min FPS | Draw calls | Primitives (M) | VRAM MiB | Peak memory | Thermal / temperature |
|---|---|---|---|---|---|---|---|---|
| baseline | 6.7 / 5.8 / 7.7 | 6.1 / 5.4 / 7.1 | 4.7 / 4.3 / 6.7 | 1068 / 1326 / 946 | 2.59 / 3.25 / 2.25 | 561 | PSS 500 MiB | 33.5→35.0 °C, status 0→0 |
| baseline_repeat | 6.7 / 5.8 / 7.7 | 6.2 / 4.4 / 6.7 | 4.8 / 4.2 / 5.2 | 1068 / 1326 / 946 | 2.59 / 3.25 / 2.25 | 561 | PSS 514 MiB | 34.0→35.0 °C, status 0→0 |
| combo_a_geometry | 17.7 / 16.1 / 16.1 | 15.4 / 14.5 / 14.0 | 7.5 / 7.0 / 8.0 | 117 / 122 / 72 | 0.12 / 0.25 / 0.32 | 561 | PSS 513 MiB | 35.0→35.5 °C, status 0→0 |
| combo_b_geometry_scale075 | 26.0 / 23.9 / 23.5 | 18.2 / 16.9 / 17.1 | 8.1 / 8.7 / 7.7 | 117 / 122 / 72 | 0.12 / 0.25 / 0.32 | 521 | PSS 549 MiB | 35.5→35.5 °C, status 0→0 |
| combo_c_aggressive | 37.4 / 37.1 / 40.6 | 26.7 / 26.7 / 26.0 | 8.4 / 9.1 / 12.9 | 81 / 73 / 36 | 0.05 / 0.06 / 0.05 | 492 | PSS 577 MiB | 35.5→35.5 °C, status 0→0 |
| combo_d_aggressive_scale075 | 29.9 / 29.9 / 30.6 | 19.1 / 19.5 / 19.0 | 8.4 / 8.6 / 10.4 | 81 / 73 / 36 | 0.05 / 0.06 / 0.05 | 512 | PSS 558 MiB | 35.5→35.5 °C, status 0→0 |
| combo_e_aggressive_cap30 | 29.9 / 29.9 / 29.9 | 26.6 / 26.2 / 25.3 | 8.7 / 8.7 / 8.4 | 81 / 73 / 36 | 0.05 / 0.06 / 0.05 | 492 | PSS 558 MiB | 35.5→35.0 °C, status 0→0 |
| combo_e_aggressive_cap30_nopss | 30.0 / 30.0 / 30.0 | 26.3 / 26.6 / 25.8 | 24.0 / 25.1 / 23.6 | 81 / 73 / 36 | 0.05 / 0.06 / 0.05 | 492 | PSS not sampled | 34.5→34.5 °C, status 0→0 |
| far400_fog | 13.4 / 12.4 / 13.1 | 12.2 / 11.1 / 11.3 | 6.9 / 7.1 / 6.8 | 221 / 253 / 221 | 0.56 / 0.81 / 0.78 | 561 | PSS 527 MiB | 34.0→35.0 °C, status 0→0 |
| hide_buildings | 5.7 / 5.5 / 6.4 | 5.4 / 5.2 / 5.9 | 4.3 / 4.3 / 5.5 | 937 / 1163 / 828 | 2.54 / 3.19 / 2.21 | 562 | PSS 519 MiB | 34.0→35.5 °C, status 0→0 |
| hide_decor | 6.9 / 5.9 / 8.0 | 6.6 / 5.5 / 7.1 | 6.3 / 4.3 / 5.1 | 968 / 1199 / 859 | 2.54 / 3.14 / 2.10 | 561 | PSS 511 MiB | 34.0→35.0 °C, status 0→0 |
| hide_facade_detail | 12.0 / 9.9 / 11.9 | 10.9 / 9.0 / 10.4 | 6.5 / 7.5 / 8.9 | 937 / 1163 / 828 | 0.73 / 1.05 / 0.91 | 561 | PSS 496 MiB | 34.0→35.5 °C, status 0→0 |
| hide_ground | 7.7 / 6.2 / 9.1 | 7.1 / 5.9 / 8.2 | 4.8 / 4.5 / 7.9 | 708 / 872 / 634 | 2.33 / 2.91 / 2.01 | 561 | PSS 506 MiB | 34.0→35.0 °C, status 0→0 |
| hide_lamps | 6.9 / 6.0 / 7.9 | 6.5 / 5.4 / 7.1 | 6.0 / 4.5 / 6.9 | 878 / 1101 / 793 | 2.54 / 3.18 / 2.20 | 561 | PSS 509 MiB | 34.0→35.5 °C, status 0→0 |
| hide_trees | 7.2 / 6.4 / 8.6 | 6.7 / 5.9 / 7.8 | 5.2 / 4.6 / 7.5 | 936 / 1156 / 810 | 2.29 / 2.80 / 1.83 | 561 | PSS 504 MiB | 34.0→35.5 °C, status 0→0 |
| hide_water | 6.9 / 5.8 / 7.8 | 6.3 / 4.7 / 7.2 | 5.0 / 4.1 / 7.0 | 1066 / 1324 / 944 | 2.59 / 3.25 / 2.25 | 561 | PSS 512 MiB | 34.0→35.0 °C, status 0→0 |
| lod_4 | 9.2 / 8.0 / 10.4 | 8.4 / 7.5 / 9.1 | 7.3 / 6.5 / 7.0 | 1068 / 1326 / 946 | 1.32 / 1.70 / 1.15 | 561 | PSS 508 MiB | 34.0→35.0 °C, status 0→0 |
| lod_8 | 10.8 / 9.3 / 11.1 | 9.6 / 8.4 / 9.4 | 6.1 / 5.3 / 6.5 | 1068 / 1326 / 946 | 0.85 / 1.17 / 0.96 | 561 | PSS 521 MiB | 34.0→35.0 °C, status 0→0 |
| occlusion | 10.3 / 14.0 / 16.4 | 9.4 / 12.7 / 14.1 | 7.6 / 7.5 / 8.0 | 273 / 150 / 78 | 1.29 / 0.59 / 0.47 | 561 | PSS 550 MiB | 34.0→35.5 °C, status 0→0 |
| renderer_compat | 8.0 / 7.0 / 9.2 | 7.3 / 6.4 / 8.1 | 6.9 / 4.5 / 7.0 | 1073 / 1349 / 958 | 2.59 / 3.25 / 2.25 | 453 | PSS 914 MiB | 35.0→35.0 °C, status 0→0 |
| scale_060 | 13.0 / 11.3 / 13.6 | 11.9 / 10.6 / 12.0 | 8.2 / 9.6 / 8.2 | 1068 / 1326 / 946 | 2.59 / 3.25 / 2.25 | 502 | PSS 522 MiB | 34.0→35.0 °C, status 0→0 |
| scale_075 | 11.3 / 10.0 / 11.8 | 10.2 / 9.1 / 10.9 | 6.9 / 6.1 / 6.4 | 1068 / 1326 / 946 | 2.59 / 3.25 / 2.25 | 522 | PSS 512 MiB | 34.0→35.0 °C, status 0→0 |
| shadows_off | 6.8 / 5.9 / 8.3 | 6.3 / 5.5 / 7.6 | 4.6 / 4.2 / 7.4 | 1047 / 1287 / 911 | 2.55 / 3.11 / 1.96 | 551 | PSS 523 MiB | 34.0→35.0 °C, status 0→0 |
| shadows_single | 6.6 / 5.7 / 7.8 | 6.1 / 5.4 / 7.2 | 4.5 / 4.6 / 7.0 | 1068 / 1326 / 948 | 2.58 / 3.21 / 2.17 | 561 | PSS 524 MiB | 34.0→35.0 °C, status 0→0 |
| visrange_100 | 15.5 / 13.6 / 15.3 | 14.2 / 12.5 / 13.3 | 7.1 / 7.0 / 7.5 | 515 / 666 / 456 | 0.32 / 0.43 / 0.37 | 561 | PSS 503 MiB | 34.0→35.5 °C, status 0→0 |
| visrange_200 | 14.2 / 12.5 / 13.8 | 12.9 / 11.2 / 12.2 | 7.1 / 8.0 / 7.2 | 534 / 682 / 479 | 0.38 / 0.58 / 0.56 | 561 | PSS 512 MiB | 34.0→35.5 °C, status 0→0 |
| visrange_400 | 12.7 / 11.6 / 12.5 | 11.4 / 10.5 / 10.9 | 7.7 / 7.3 / 7.5 | 568 / 716 / 526 | 0.56 / 0.77 / 0.81 | 561 | PSS 501 MiB | 34.0→35.5 °C, status 0→0 |

### Cost attribution by category (Galaxy Tab A7, hide one category at a time)

Categories by node-name prefix (table in `docs/ARCHITECTURE.md`); static share of the 7.07 M LOD0 triangles: facade_detail 64.2 %, trees 17.6 %, ground 9.6 %, lamps 4.3 %, decor 2.2 %, buildings 2.0 %, water ~0 %.

| Hidden category | View | Draw calls (Δ, % of baseline) | Primitives (Δ, % of baseline) | Avg FPS (baseline → hidden) |
|---|---|---|---|---|
| buildings | Spawn | 131 (12 %) | 56,676 (2 %) | 6.7 → 5.7 |
| buildings | Karaköy | 163 (12 %) | 65,876 (2 %) | 5.8 → 5.5 |
| buildings | Galata | 118 (12 %) | 42,889 (2 %) | 7.7 → 6.4 |
| decor | Spawn | 100 (9 %) | 48,817 (2 %) | 6.7 → 6.9 |
| decor | Karaköy | 127 (10 %) | 108,720 (3 %) | 5.8 → 5.9 |
| decor | Galata | 87 (9 %) | 148,972 (7 %) | 7.7 → 8.0 |
| facade_detail | Spawn | 131 (12 %) | 1,859,980 (72 %) | 6.7 → 12.0 |
| facade_detail | Karaköy | 163 (12 %) | 2,205,190 (68 %) | 5.8 → 9.9 |
| facade_detail | Galata | 118 (12 %) | 1,347,277 (60 %) | 7.7 → 11.9 |
| ground | Spawn | 360 (34 %) | 263,613 (10 %) | 6.7 → 7.7 |
| ground | Karaköy | 454 (34 %) | 337,627 (10 %) | 5.8 → 6.2 |
| ground | Galata | 312 (33 %) | 238,761 (11 %) | 7.7 → 9.1 |
| lamps | Spawn | 190 (18 %) | 57,374 (2 %) | 6.7 → 6.9 |
| lamps | Karaköy | 225 (17 %) | 74,230 (2 %) | 5.8 → 6.0 |
| lamps | Galata | 153 (16 %) | 52,462 (2 %) | 7.7 → 7.9 |
| trees | Spawn | 132 (12 %) | 303,608 (12 %) | 6.7 → 7.2 |
| trees | Karaköy | 170 (13 %) | 455,726 (14 %) | 5.8 → 6.4 |
| trees | Galata | 136 (14 %) | 418,983 (19 %) | 7.7 → 8.6 |
| water | Spawn | 2 (0 %) | -2 (-0 %) | 6.7 → 6.9 |
| water | Karaköy | 2 (0 %) | -2 (-0 %) | 5.8 → 5.8 |
| water | Galata | 2 (0 %) | -2 (-0 %) | 7.7 → 7.8 |

Reading: the tablet is limited by geometry (facade detail is 60–72 % of drawn primitives; hiding it gives 1.6–1.8× FPS) and by pixel fill (0.75 render scale alone: 1.5–1.7×), much less by draw calls (hiding lamps removes 16–18 % of draw calls for +0.2 FPS). Hiding building shells lowered FPS by 0.3–1.3, likely because the shells write depth early and keep the geometry behind them from being shaded (not verified further).

### iPhone 13 Pro — all runs

Values are Spawn / Karaköy / Galata; memory is the peak app physical footprint.

| Experiment | Avg FPS (S / K / G) | 1% low | Min FPS | Draw calls | Primitives (M) | VRAM MiB | Peak memory | Thermal / temperature |
|---|---|---|---|---|---|---|---|---|
| baseline | 82.2 / 64.8 / 63.8 | 53.1 / 42.7 / 39.8 | 49.5 / 39.4 / 38.6 | 1192 / 1408 / 1137 | 2.84 / 3.33 / 2.63 | 672 | footprint 1055 MiB | Nominal→Serious (max Serious; Fair at 40 s, Serious at 91 s) — INVALID (Serious) |
| cap60_combo_occ_vis200 | 60.0 / 60.0 / 60.0 | 43.2 / 41.6 / 40.5 | 42.1 / 40.6 / 40.1 | 243 / 142 / 73 | 0.21 / 0.26 / 0.32 | 672 | footprint 1024 MiB | Nominal→Nominal (max Nominal) |
| cap60_combo_occ_vis200_lod4 | 60.0 / 60.0 / 60.0 | 42.6 / 41.6 / 40.4 | 41.1 / 40.8 / 39.9 | 243 / 142 / 73 | 0.20 / 0.26 / 0.32 | 672 | footprint 1034 MiB | Nominal→Nominal (max Nominal) |
| cap60_lod_4 | 60.0 / 60.0 / 60.0 | 46.9 / 46.3 / 45.7 | 45.0 / 42.8 / 45.0 | 1192 / 1408 / 1137 | 1.44 / 1.76 / 1.30 | 672 | footprint 1055 MiB | Nominal→Fair (max Fair; Fair at 91 s) |
| cap60_occlusion | 60.0 / 60.0 / 60.0 | 43.7 / 42.0 / 40.4 | 41.4 / 41.1 / 39.8 | 384 / 174 / 79 | 1.55 / 0.71 / 0.47 | 672 | footprint 1106 MiB | Nominal→Nominal (max Nominal) |
| cap60_scale_075 | 60.0 / 60.0 / 60.0 | 45.9 / 46.5 / 46.2 | 44.6 / 44.8 / 44.9 | 1192 / 1408 / 1137 | 2.84 / 3.33 / 2.63 | 614 | footprint 1001 MiB | Nominal→Serious (max Serious; Fair at 40 s, Serious at 141 s) — INVALID (Serious) |
| cap60_scale_075_metalfx | 60.0 / 60.0 / 60.0 | 46.0 / 46.8 / 46.1 | 44.9 / 44.4 / 44.9 | 1192 / 1408 / 1137 | 2.84 / 3.33 / 2.63 | 614 | footprint 1001 MiB | Nominal→Serious (max Serious; Fair at 40 s, Serious at 141 s) — INVALID (Serious) |
| cap60_shadows_off | 60.0 / 60.0 / 60.0 | 46.1 / 46.8 / 46.2 | 44.8 / 45.0 / 44.4 | 1164 / 1365 / 1102 | 2.76 / 3.18 / 2.33 | 662 | footprint 1044 MiB | Nominal→Serious (max Serious; Fair at 40 s, Serious at 141 s) — INVALID (Serious) |
| cap60_visrange_200 | 60.0 / 60.0 / 60.0 | 45.2 / 45.7 / 45.3 | 42.0 / 44.8 / 43.8 | 598 / 725 / 561 | 0.42 / 0.60 / 0.62 | 672 | footprint 990 MiB | Nominal→Nominal (max Nominal) |
| fps_cap_30 | 30.0 / 30.0 / 30.0 | 24.4 / 29.3 / 29.4 | 23.9 / 28.3 / 28.7 | 1192 / 1408 / 1137 | 2.84 / 3.33 / 2.63 | 672 | footprint 1055 MiB | Nominal→Fair (max Fair; Fair at 142 s) |
| fps_cap_60 | 60.0 / 60.0 / 60.0 | 46.2 / 46.9 / 45.9 | 44.5 / 44.8 / 44.8 | 1192 / 1408 / 1137 | 2.84 / 3.33 / 2.63 | 672 | footprint 1065 MiB | Nominal→Serious (max Serious; Fair at 40 s, Serious at 141 s) — INVALID (Serious) |

The Compatibility renderer could not start on the iPhone (`cap60_renderer_compat`, iOS 26.6.1): the unified log shows `[GDTOpenGLLayer createFramebuffer] failed to make complete framebuffer object`, "Failed to create frame buffer!", `CopyShaderGLES3: Vertex shader compilation failed`, and "Too many varyings used in shader (1 used, maximum supported is 0)" for the water shader; iOS saved a crash report. No results.

### iPhone 10-minute session (60 FPS cap, occlusion + 200 m visibility range, Karaköy)

| Minute | Avg FPS | 1% low | Min FPS | Draw calls | Primitives | Thermal (nearest probe) |
|---|---|---|---|---|---|---|
| 1 | 60.0 | 41.3 | 16.7 | 140 | 257,917 | Nominal |
| 2 | 60.0 | 41.4 | 40.9 | 142 | 262,288 | Nominal |
| 3 | 60.0 | 41.5 | 40.8 | 142 | 262,288 | Nominal |
| 4 | 60.0 | 41.4 | 40.8 | 142 | 262,288 | Nominal |
| 5 | 60.0 | 41.5 | 40.7 | 142 | 262,288 | Nominal |
| 6 | 60.0 | 41.6 | 41.1 | 142 | 262,288 | Nominal |
| 7 | 60.0 | 41.3 | 38.0 | 142 | 262,288 | Nominal |
| 8 | 60.0 | 41.5 | 40.8 | 142 | 262,288 | Nominal |
| 9 | 60.0 | 41.6 | 39.2 | 142 | 262,288 | Nominal |
| 10 | 60.0 | 41.6 | 41.0 | 142 | 262,288 | Nominal |

Thermal state: Nominal at all 13 probes (0–601 s). App footprint 1,022–1,044 MiB. The minute-1 minimum is a single frame right after the teleport.

### Results against the targets

- **Galaxy Tab A7, stable 30 FPS: average yes, strict no, at a heavy visual cost.** `combo_c_aggressive` (occlusion, 400 m far plane with fog, 100 m visibility range for trees/lamps/decor/facade detail, 0.6 render scale, shadows off, LOD threshold 4) averaged 37.1–40.6 FPS; capped at 30 (`combo_e_*`) it held 29.9–30.0 average with the 1 % low at 25.3–26.6 FPS (minimum 23.6–25.1 without the PSS sampler). Cost (screenshots `docs/perf/android/combo_c_*`): nearby buildings lose their windows because facade detail is merged per 150 m chunk and the visibility range is measured to the chunk centre; no shadows; fog; softer image. `combo_d` (same at 0.75 scale) averages ~30 but its 1 % low is ~19.
- **iPhone 13 Pro, 60 FPS cap, 10 minutes, ≤ Fair, ≥ 55 FPS: met by average FPS** with the 60 FPS cap + occlusion + 200 m visibility range: 60.0 FPS every minute, thermal state Nominal throughout. The 1 % low stays at ~41.5 in this and every other 60-capped run, including the heaviest; a frame-pacing effect of the 60 FPS cap on the 120 Hz display is the suspected cause (not verified). Visual cost (screenshots `docs/perf/ios/cap60_combo_*`): buildings beyond ~200 m lose window detail and some trees.
- **Renderer:** on the tablet, Compatibility was ~20 % faster than Mobile on the unchanged scene (8.0 / 7.0 / 9.2 vs 6.7 / 5.8 / 7.7 FPS) but used 914 MiB peak PSS vs ~510 MiB and has no occlusion culling; Mobile with occlusion alone reached 10.3 / 14.0 / 16.4. Compatibility does not start on the iPhone.

### Not run

- FSR (E): Godot 4.7.2 reports "FSR1 3D scaling is only available when using the Forward+ renderer"; the experiment was removed before device runs.
- iPhone single measures without a frame cap (occlusion, shadows, scale, LOD, visibility range): invalid by protocol (Serious within ~91 s even for the baseline); measured on top of the 60 FPS cap instead.
- iPhone cost attribution (A), `shadows_single`, `scale_060`, `far400_fog`, `visrange_100/400`, `lod_8`: not run on the iPhone to limit device time and heat; the attribution is device-independent in draw calls and primitives and was measured on the tablet.
- iPhone frame cap 30 with geometry reduction, and the tablet's 10-minute session: not run.
- Occluder baking in the editor: Godot exposes no bake method to scripts; occluders were built at runtime from the map's building and ground collision (643 occluders, 317,518 triangles; 21 ms on the iPhone, 114–118 ms on the tablet; about +40 MiB memory on both devices).

## Verified behaviors (automated, macOS, Godot 4.7.2)

| Behavior | Evidence |
|---|---|
| Project imports cleanly. | `godot --headless --path . --import`: exit 0, no errors or warnings (after adding `build/.gdignore`). |
| Automated tests pass. | `run_tests.gd` → `RESULT 65 passed, 0 failed, 0 skipped`, exit 0; unit only → `RESULT 54 passed, 0 failed, 0 skipped`, exit 0 (2026-10-24, after the performance pass). |
| Performance flags do nothing by default and apply as specified. | `test_perf_experiments.gd` (8 unit tests: parsing and typo rejection, category matching, applying to a fixture map in a SubViewport, frame statistics, file-name slugs, every experiment file parses); integration: `test_perf_categories_cover_every_map_mesh` (all 3,055 map meshes categorized), `test_no_perf_experiment_by_default`, `test_short_benchmark_on_map` (occlusion + benchmark on the real map). |
| Runtime errors fail tests. | Before the fix, a null method call and an error after `await` were both reported PASS (exit 0). After: both FAIL with "logged error: …", exit 1. |
| Missing GLB is visible. | With the GLB moved away: `RESULT 42 passed, 0 failed, 7 skipped`, exit 2; unit only exit 0. GLB restored, SHA-256 re-verified. |
| Focus loss / pause reset input. | `test_focus_out_releases_held_joystick_and_run`, `test_pause_releases_held_joystick_and_run`; both failed on the previous controller. |
| Exported PackedStringArray guard. | `test_no_packed_string_array_exports`; fails if the old type is restored. |
| Debug viewpoints stand on ground on the map. | `test_debug_viewpoints_stand_on_ground`. |
| Original map validation. | `tests/map/validate_scene.gd` → `VALIDATION PASS | failures=0`. |
| Phase 1 behaviors (routing, speeds, camera collision on 192 street samples, respawn, safe-area math). | Unit and integration suites; see `docs/ARCHITECTURE.md`. |

## Unverified behaviors

- iOS process launch time to first frame (only engine-internal times were measured).
- iPhone single measures without a frame cap and the tablet's 10-minute session: not run (see "Not run").
- Cause of the ~41 FPS 1 % low in every 60-capped iPhone run (frame pacing suspected).
- Whether MetalFX spatial scaling was active on the iPhone: no engine warning on the Mac's Metal Forward Mobile renderer (FSR did warn), but no device log was captured during the run.
- Release builds: none made (release signing out of scope).
- Smoothness of physics interpolation on the 120 Hz screen: not judged separately.
- Whether Android cancels a held touch by itself on backgrounding (the device test cannot tell that apart from the fix; the unit tests cover the fix).
- F4 (interpolation reset after a bounds clamp): no dedicated test; a meaningful check needs a moving body at the boundary.
- Codex reading `AGENTS.md`: not tested.

## Known bugs and limitations

- Android tablet at 5–8 FPS with default settings; startup to first frame 12–21 s.
- Per-chunk visibility ranges remove facade detail from nearby buildings: the map merges facade detail into 150 m chunks and Godot measures the range to the chunk's centre.
- On iOS, `get_tree().quit()` does not end the app; the benchmark hides the map and drops to 5 FPS, and `tools/perf/ios_bench.sh` terminates it.
- Railings, lamps, and decor have no collision; falling into the water respawns the player (same as the original demo).
- No jump (not requested); tall steps block the capsule.
- The original explorer demo still renders the city white.
- Placeholder character (no animations) and placeholder icon. The app name shown on devices is the project name "İstanbul • Haliç".
- Debug overlay and VIEW button appear in debug builds only; overlay text is English.
- Godot 4.7.2 export conversion dropped an exported `PackedStringArray` from a `.tres`; the project uses `Array[String]` instead (guarded by a test).

## Technical risks

- **Performance (measured, not yet addressed):** with default settings the tablet runs at 5.8–7.7 FPS and the iPhone reaches "Serious" in ~91 s uncapped or ~141 s at 60 FPS. Settings alone reach the iPhone target; the tablet reaches a 30 FPS average only with heavy visual cuts. Facade detail (64 % of triangles) is the main cost. Proposed measures: `PROJECT_CONTEXT.md` (none applied).
- **Memory:** iPhone footprint 1.02 GiB; Android uses swap on a tablet with limited RAM.
- **Startup:** 10–15 s to map ready on the tablet, with variance between runs.
- A fresh clone lacks the GLB and will not run until it is restored.

## External blockers

- Final iOS identity: `com.mirongi.mapsimulator` must be registered only in the user's future Apple Developer account. Until then, iOS debug builds use the temporary team and `.dev` bundle ID.

## Required manual actions

- **iPhone: set Auto-Lock back to its previous value** (it was set to "Never" for the measurements).
- Decide which measures to adopt: the iPhone settings package, the tablet package (heavy visual cost), and/or map-level work on facade detail (`PROJECT_CONTEXT.md`).
- Decide whether the Galaxy Tab A7 class stays a 30 FPS target given the measured cost.
- Later: create the new Apple Developer account, then update the team ID and bundle ID (decision D8).
- Provide or choose character and car models; decide the app name and icon.

## Current priorities

1. Review of the performance diagnosis.
2. User decision on the measures, then Phase 2.

## Recommended next task

Map-level reduction of facade detail, in a copy of the map pipeline and only with the user's approval to change the map: replace the geometric window frames, sills, and balconies (4.54 M of 7.07 M triangles) with lighter geometry or textured/shader facades, generate stronger LODs for what remains, and split detail into smaller cells (about 30–50 m or per building) so visibility ranges and occlusion work without blank nearby facades. Measure with the same protocol and experiments (`tools/perf/`). Basis: hiding facade detail alone took the tablet from 6.7 / 5.8 / 7.7 to 12.0 / 9.9 / 11.9 FPS, and it is the cost that forces the tablet package's visual cuts. Alternative if Phase 2 should start first: turn the measured iPhone package (60 FPS cap + occlusion + 200 m visibility range) into a permanent, per-device quality preset with occluders baked once instead of at load.
