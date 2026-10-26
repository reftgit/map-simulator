# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure, build, and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-10-26 (Phase 4a measurements, Claude Code)

## Current phase

**Phase 4a (release baseline and diagnosis, measurement only) done.** Release builds for measurement ("* Release Perf*" presets, `perf_bench` feature) run on both devices and are proven non-debug. Release changes little against debug. The iPhone's ~41 FPS "1 % low" is a frame-pacing artefact of the 60 FPS limiter on the 120 Hz display (frames alternate 8.3 / 25 ms); at 60 Hz the frames are an even 16.7 ms. On the Galaxy Tab A7 the physics step (≈ 4.7–5.7 ms, two per frame) splits into ≈ 1 ms for the player's `move_and_slide`, ≈ 1 ms for the parked car, and smaller parts; 30 Hz physics destabilizes the car, and Jolt is ~2 ms per step slower. No default was changed; the measured proposals are in `PROJECT_CONTEXT.md`, "Phase 4 proposals". Phases 1–3 and the quality profiles are unchanged.

## Current objective

User decision on the Phase 4 proposals (60 Hz display on ProMotion iPhones first). See "Recommended next task".

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
- `e9ce135`: debug-only performance experiment flags, benchmark, host scripts.
- `11e98c7`: performance diagnosis results and proposed measures.
- `5024dd0`: quality profiles (high/low/none) with a per-platform default; shared `RenderSettings`.
- `526ac6f`: occluders baked once (`tools/bake_occluders.gd`, `maps/istanbul_halic/istanbul_halic_occluders.scn`).
- `c77fb03`: profile measurements and documentation.
- `2f84908`: punch and roll presses on the intent, HUD buttons, J/Space keys.
- `35f0209`: Punch and Roll states, action buffer, Hitbox/Hurtbox, CharacterVisual, tests.
- `bd8294d`: debug training dummy (DUMMY overlay button).
- `bcf9951`: Phase 2 device results, performance regression, and documentation.
- `80a4fa9`: active physics engine detected and logged (GodotPhysics3D).
- `bed52ca`: vehicle controller, definition, placeholder car, second test vehicle type.
- `a91747e`: getting in and out, HUD control groups, vehicle camera follow mode.
- `bd26331`: vehicle spawn on a Karaköy street, resets, hill hold.
- `2e68916`: physics step timing and in-vehicle benchmarks, `tools/perf/median.py`.
- `59aa62b`: debug CAR button (walk up to the vehicle).
- `9dd53df`: fix: the player's tick stops once it gets into a vehicle.
- `37050e3`: Phase 3 device results and documentation.
- `ef1e33e`: `perf_bench` feature gating, Release Perf presets, Android external-folder transport, perf build scripts.
- `0e1a35a`: runtime experiment flags, frame-time statistics, collider census, Jolt and 60 Hz measurement presets.
- Phase 4a results and documentation: the commit after `0e1a35a` (`git log`).

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Game code: composition root, world, player (with Punch/Roll states and `CharacterVisual`), combat areas, vehicle (controller, definition, interaction, visual), camera, input, HUD with on-foot and vehicle control groups and a debug overlay. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition` (with two debug viewpoints). |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; ETC2/ASTC import (required for Android export); placeholder icon. |
| `export_presets.cfg` | "Android Debug" (arm64 APK, `com.mirongi.mapsimulator`), "Android Debug Compatibility" (same, with `--rendering-method gl_compatibility`), and "iOS Debug" (`com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, project-only export). No passwords or keystore paths. |
| `icon.svg` | Placeholder app icon (capsule character over water). |
| `tests/` | Headless runner, 134 unit tests, 27 integration tests, fixtures (flat map, second vehicle type `test_van`), original map validation. |
| `tools/capture_screenshot.gd` | Windowed render to PNG with render stats. |
| `tools/build_ios_debug.sh` | iOS debug build without contacting the Apple Developer portal; optional `devicectl` install. |
| `tools/build_android_perf.sh`, `tools/build_ios_perf.sh` | Release Perf builds for measurements only (debug keystore via environment variables; Xcode Release without `-allowProvisioningUpdates`). |
| `game/quality/` | `RenderSettings` (applies render settings; shared by profiles and experiments), `QualityProfile`, `QualityProfiles` (selection rule), `profiles/high.tres`, `profiles/low.tres`. |
| `game/debug/` | Debug-only: `PerfConfig` (experiment flags from JSON, layered on a profile), `PerfBenchmark` (automatic measurement). |
| `maps/istanbul_halic/istanbul_halic_occluders.scn` | Baked occluders, 2,300,873 bytes (643 occluders, 317,518 triangles), referenced by the `MapDefinition`. |
| `tools/bake_occluders.gd` | Headless occluder bake. |
| `tools/perf/` | Experiment definitions (`experiments/*.json`), device orchestration (`android_bench.sh`, `ios_bench.sh`, `run_batch.sh`), `parse_xctrace.py`, `summarize.py`. |
| `docs/perf/` | Diagnosis pass: raw results and conditions (`results/`), 480 px screenshots (`android/`, `ios/`). Profile validation: `profiles/`. Phase 2 regression and HUD screenshots: `phase2/`. Phase 3 three-run results and screenshots: `phase3/`. Phase 4a release, diagnosis, and pacing results plus headless Jolt / 30 Hz / collider census: `phase4a/`. 3.6 MB in total. |
| `build/.gdignore` | Keeps Godot from scanning or packing build output. Everything else in `build/` is ignored by Git. |
| `main.tscn`, `scripts/` | Original explorer demo, unchanged. Desktop only. |
| `assets/istanbul_halic.glb` | 502 MB, **not tracked**. Restore: `docs/maps/istanbul_halic/README.md`. |
| `.vscode/settings.json` | The user's editor colors. Untracked, intentionally not committed. |

## Implemented features

- **Measurement builds (Phase 4a):** `BuildFeatures` gates the debug overlay (debug builds) and experiments/benchmarks/STARTUP (debug builds and release builds with `perf_bench`); "Android Release Perf", "iOS Release Perf", and the measurement-only variants "Android Release Perf Jolt" and "iOS Release Perf 60Hz" (feature-tagged overrides). Experiments gain runtime keys (physics rate, interpolation, player physics, vehicles, collider radius, V-Sync) and results gain frame-time percentiles, a histogram, long frames, physics and process times. None of this changes normal builds.
- **Phase 3 vehicle (all builds):** placeholder car (box body, cylinder wheels, brake and reverse lights) parked on a Karaköy street; interact button (car icon, E) while in reach and standing; vehicle controls ◀ ▶ (left), throttle, brake/reverse, handbrake "P" (bottom right), exit (top right); exit only at ≤ 1.5 m/s and beside the car (driver's side, else passenger side, else refused; the exit button fades while too fast); focus loss or pause releases the controls and holds the handbrake; hill hold when no pedal is pressed; reset to the spawn after falling below the kill height or 2 s flipped, with the driver; vehicle camera 7.5 m behind with follow mode. Details: `docs/ARCHITECTURE.md`, "Vehicles (Phase 3)".
- Debug builds: `STARTUP` reports the physics engine; CAR overlay button puts the player beside the vehicle; VIEW moves the vehicle while driving; benchmarks can run from the driver's seat and record physics step time.
- **Phase 2 character actions (all builds):** punch button (starburst icon) and roll button (circular arrow) bottom-right, one-shot on touch-down, J / Space on desktop; 0.18 s input buffer; `PunchState` (0.10 s startup, 0.10 s active with the hitbox open, 0.25 s recovery; the body stops and keeps its facing); `RollState` (6 m in 0.6 s at constant speed toward the camera-relative stick or the facing; gravity and collisions stay on; 0.8 s cooldown; the roll button fades during it); a roll cancels only the punch recovery; a punch pressed late in a roll runs after it; nothing starts in the air; focus loss or pause ends an action and returns to Idle. Visual feedback through `CharacterVisual` (placeholder: fist thrust, tuck-and-turn, lean with speed). `Hitbox` / `Hurtbox` (layer 3) report at most one hit per punch per target; no damage. Details: `docs/ARCHITECTURE.md`, "Character actions".
- Debug builds only: DUMMY overlay button toggles a training dummy next to the spawn that counts hits (`HITS n`, `DUMMY hits=n` log line).
- Phase 1 controls: native `VirtualJoystick` (left 42 %), camera drag area (right 58 %), run toggle, camera-relative movement, Idle/Walk/Run states, spring-arm third-person camera, safe-area HUD, map loading with spawn, respawn, and bounds. Details in `docs/ARCHITECTURE.md`.
- Focus loss and pause release the joystick, the `move_*`/`run` actions, and the run toggle.
- Debug builds only: overlay with FPS, draw calls, primitives, objects, video memory, engine static memory; `PERF` log line every 2 s; `STARTUP` log line; VIEW button cycling Spawn → Karaköy street (facing north) → Galata street (facing south).
- Android and iOS debug export presets.
- Android Compatibility debug preset (same code, `--rendering-method gl_compatibility`) for renderer comparisons.
- **Quality profiles (all builds):** high (60 FPS cap, occlusion, 200 m visibility range for trees/lamps/decor/facade detail) and low (occlusion, 400 m far plane + depth fog, 100 m ranges, 0.6 render scale, shadows off, LOD threshold 4, 30 FPS cap). Default: iOS → high, Android → low, desktop → none. `--quality=<name>` overrides; debug builds can cycle profiles with the Q button.
- **Baked occluders** loaded from `maps/istanbul_halic/istanbul_halic_occluders.scn` when a profile enables occlusion; runtime building from collision remains as a fallback with a warning.
- Debug builds only: performance experiment flags (`PerfConfig`) layered on top of the profile (experiment > profile > defaults), and an automatic benchmark (`PerfBenchmark`) driven by host scripts in `tools/perf/`. Off unless an experiment file or `--perf-config` is given.

## Phase 4a — release baseline, CPU/physics, and frame pacing diagnosis (2026-10-26)

Measurement only (D19): no default changed. Builds from `0e1a35a` ("* Release Perf*" presets); the 60 Hz iOS build was rebuilt once more after the `build_info` fix to prove its override (below). Three runs per device, experiment, and viewpoint (D17); medians with every run's value in `docs/perf/phase4a/results/`. Tablet without PSS sampling.

### Release Perf builds

- Android: release template, signed with the editor's debug keystore through `GODOT_ANDROID_KEYSTORE_RELEASE_*` (`tools/build_android_perf.sh`); `adb shell run-as` answers "package not debuggable"; experiment and results go through the app-specific external folder.
- iOS: Xcode Release configuration, automatic signing without `-allowProvisioningUpdates` (`tools/build_ios_perf.sh`); the app links `libgodot.a` of 188,887,256 bytes, the size of the template's `libgodot.ios.release.xcframework`.
- Every result file of both devices records `startup.debug_build: false` and `perf_feature: true`. No overlay or debug buttons (test-covered).
- Jolt build: `startup.physics_3d = "Jolt Physics"` (class-based detection). 60 Hz build: `ios_allow_high_refresh_rate: false` after the logging fix (`get_setting_with_override`; the first logging used `get_setting()`, which ignores feature overrides and showed `true` although the frame times show the 60 Hz display link).

### Debug vs release (profile_default, medians of three runs)

Debug = Phase 3 (`docs/perf/phase3/results/`), release = this pass. Physics = one physics step in ms (p99 in brackets). Draw calls drop by 21 everywhere in release: the debug overlay and its buttons.

| Device, view, mode | Avg FPS debug → release | 1 % low debug → release | Min FPS debug → release | Physics ms debug → release | Draw calls debug → release |
|---|---|---|---|---|---|
| Tab A7, Spawn, on foot | 30.00 → 29.99 | 25.28 → 25.39 | 22.58 → 20.85 | 4.90 (7.10) → 4.79 (9.84) | 101 → 80 |
| Tab A7, Karaköy, on foot | 30.00 → 30.00 | 25.56 → 25.99 | 23.40 → 20.81 | 4.73 (7.48) → 4.69 (8.18) | 93 → 72 |
| Tab A7, Galata, on foot | 30.00 → 29.99 | 24.88 → 24.89 | 20.71 → 21.75 | 5.56 (7.95) → 5.59 (9.99) | 56 → 35 |
| Tab A7, Spawn, in vehicle | 30.00 → 30.00 | 25.85 → 26.41 | 24.42 → 17.74 | 4.45 (8.74) → 3.54 (8.81) | 122 → 101 |
| Tab A7, Karaköy, in vehicle | 30.00 → 30.00 | 26.03 → 26.68 | 23.14 → 22.91 | 4.03 (8.41) → 3.57 (5.71) | 112 → 91 |
| Tab A7, Galata, in vehicle | 30.00 → 30.00 | 25.64 → 25.90 | 23.23 → 23.71 | 4.84 (5.80) → 4.22 (8.13) | 78 → 57 |
| iPhone, Spawn, on foot | 59.99 → 60.00 | 42.34 → 42.28 | 40.24 → 40.54 | 1.32 (1.91) → 1.31 (1.63) | 263 → 242 |
| iPhone, Karaköy, on foot | 60.00 → 59.99 | 41.72 → 41.86 | 40.28 → 40.27 | 1.35 (1.64) → 1.34 (2.09) | 162 → 141 |
| iPhone, Galata, on foot | 60.00 → 59.99 | 39.80 → 39.97 | 39.21 → 36.55 | 1.50 (2.28) → 1.39 (2.18) | 93 → 72 |
| iPhone, Spawn, in vehicle | 60.00 → 60.00 | 42.40 → 42.25 | 41.00 → 40.78 | 1.06 (1.28) → 0.99 (1.25) | 232 → 211 |
| iPhone, Karaköy, in vehicle | 60.00 → 60.00 | 42.04 → 42.18 | 40.70 → 40.78 | 1.08 (1.48) → 1.01 (1.51) | 196 → 175 |
| iPhone, Galata, in vehicle | 60.00 → 60.00 | 40.51 → 40.49 | 40.02 → 40.00 | 1.01 (1.34) → 0.94 (1.34) | 118 → 97 |

- Release changes little: the tablet's 1 % low moves by −0.1 to +0.7, its in-vehicle physics step drops 0.5–0.9 ms; the iPhone is within ±0.2 FPS and ±0.1 ms. Neither device is limited by debug-build overhead.
- iPhone 10-minute session on foot (`session_profile_default`, release, three runs): 59.97–60.00 FPS per minute, 1 % low 41.9 (median of minutes), thermal Nominal at every probe, footprint 989–1,011 MiB. PASS (D11/D12).
- `process_ms` (`Performance.TIME_PROCESS`) equals the frame interval (31–34 ms on the tablet, ~16–17 ms on the iPhone) whenever a frame limiter waits, so it is no CPU measure; it is recorded but not used.
- Startup (release, median of launches): tablet map ready 6,235 ms (30 launches, 5,974–9,235), first frame 6,661 ms; iPhone 1,391 ms (9 launches, 1,366–1,438), first frame 1,458 ms. Debug (Phase 3): 8,071 / 8,552 ms and 1,540 / 1,610 ms.

### Tablet physics: where the time goes (release, 20 s warm-up + 40 s per viewpoint, medians)

One 60 Hz physics step in ms (p99); at the 30 FPS cap each frame contains two steps. 1 % low for reference.

| Experiment | Physics step S / K / G | p99 S / K / G | 1 % low S / K / G |
|---|---|---|---|
| `c_baseline` (low profile, nothing changed) | 4.89 / 4.70 / 5.69 | 8.87 / 7.12 / 12.88 | 25.02 / 25.87 / 24.66 |
| `c_player_physics_off` (no `move_and_slide`) | 3.74 / 3.85 / 4.72 | 6.87 / 7.12 / 7.34 | 26.29 / 26.36 / 25.36 |
| `c_no_vehicles` (parked car out of the simulation) | 3.85 / 3.70 / 4.69 | 9.14 / 6.91 / 7.87 | 26.22 / 25.83 / 25.30 |
| `c_colliders_100m` (7 / 11 / 12 of 827 map bodies on) | 4.39 / 4.48 / 5.01 | 9.97 / 8.53 / 7.88 | 25.93 / 25.82 / 25.17 |
| `c_interpolation_off` | 4.60 / 4.66 / 5.52 | 9.09 / 9.36 / 10.50 | 26.20 / 26.26 / 24.87 |
| `c_physics_30hz` (one step per frame) | 4.76 / 4.99 / 5.54 | 12.97 / 10.49 / 8.61 | 27.00 / 26.66 / 26.33 |
| `c_physics_floor` (player, vehicle, all map colliders off) | 0.90 / 0.92 / 1.92 | 1.55 / 2.37 / 3.51 | 28.05 / 28.27 / 27.48 |

- **Largest separable sources:** the player's physics tick (`move_and_slide` against the trimesh terrain) ≈ 0.85–1.15 ms per step, and the parked, unused car ≈ 1.0 ms per step (it stays awake and its wheels raycast every step). Map colliders beyond 100 m ≈ 0.2–0.7 ms; physics interpolation ≈ 0.0–0.3 ms. Switching everything off leaves 0.9–1.9 ms. The parts do not add up exactly (≈ 2.5 ms individually vs ≈ 3.9 ms together): the player and the car interact with the same nearby trimesh bodies, so a further ~1.3 ms is shared and was not separated further.
- **Collider census** (`docs/perf/phase4a/headless/collider_census.txt`): all 827 map colliders are `ConcavePolygonShape3D` (trimesh), 438,012 triangles (buildings 371 bodies / 144,716 triangles, ground 272 / 172,802, tree trunks 184 / 120,494). Within 100 m of the viewpoints only 7–12 bodies (2,362–6,691 triangles); the bodies are large map chunks.
- **30 Hz physics:** the step costs the same, but there is one step per frame instead of two, so the tablet saves one step (~4.8–5.5 ms) per frame; 1 % low +0.8 to +2.0. Gameplay differences (headless suite at 30 Hz, `docs/perf/phase4a/headless/suite_physics_30hz.txt`): 148 passed, 13 failed. Real differences: the car is unstable (flat floor: 58.7 m/s against a 22 m/s limit, rolled over; map: 126.5 m in 5 s instead of 43.8 m), and the punch lasts 0.5 s instead of 0.45 s (phases snap to 33 ms ticks). The other failures count 60 Hz ticks in the tests (punch/roll/cooldown tick counts, flip-reset timing, hitbox re-entry). Walking and running speeds, roll distance, and camera follow pass.
- **Jolt Physics** (tablet, release, three full runs): physics step 6.69 / 6.78 / 6.88 ms on foot (GodotPhysics3D 4.79 / 4.69 / 5.59) and 6.14 / 6.18 / 6.36 ms in the vehicle (3.54 / 3.57 / 4.22); 1 % low 24.48 / 24.66 / 24.02 on foot (25.39 / 25.99 / 24.89); map ready 6,878 ms (6,235). Headless suite with Jolt (`suite_jolt.txt`): 160 passed, 1 failed, and that one is the test that pins GodotPhysics3D; the car's 5 s distance is the same 43.8 m. Jolt works with the current code but is ~2 ms per step slower on this device and scene.

### Frame pacing

**iPhone 13 Pro, 10 minutes at Karaköy on foot, three runs per method** (frames at refresh-interval multiples summed over all runs):

| Method | Avg FPS | 1 % low (median of minutes) | Long frames (> 1.25 × median) | Frame times | Thermal |
|---|---|---|---|---|---|
| M1: 120 Hz display (default), `Engine.max_fps` 60 | 60.0 | 41.9 | ~17,800 of 36,000 per run (49.5 %) | 8.3 ms 49 %, 25.0 ms 49 %, 16.7 ms 1–3 % | Nominal |
| M2: 60 Hz display (`allow_high_refresh_rate` off), `max_fps` 60 | 60.0 | 55.4–55.5 | 1 per run | 16.7 ms 100 % | Nominal (one probe without data) |
| M3: 60 Hz display, `max_fps` 0 (V-Sync only) | 60.0 | 55.4–56.8 | 1–2 per run | 16.7 ms 100 % | Nominal |

- With the default 120 Hz display link and a 60 FPS limiter, every second frame is one refresh late: frames alternate 8.3 / 25 ms. The ~41 FPS "1 % low" of every earlier iPhone run is exactly these 25 ms frames: a pacing artefact, not missing performance (open question 15).
- At 60 Hz the frames are 16.7 ms; the remaining "1 % low" of ~55 is ±1 ms timing jitter around 16.7 ms (p99 ~18 ms), not missed refreshes.
- The same 60 Hz pattern holds in the short release runs of the rebuilt 60 Hz app (p50 16.7 ms, no long frames).

**Galaxy Tab A7, 30 FPS (low profile)** (20 s + 40 s runs, three runs):

| Method | Avg FPS | 1 % low | Frame times | Long frames |
|---|---|---|---|---|
| `Engine.max_fps` 30 + Swappy (default) | 30.0 | 25.0 / 25.9 / 24.7 | runs 2–3: 98.8–99.8 % at 33.3 ms, 0.1–0.5 % at 50 ms; run 1: 86–92 % at 33.3 ms, 7–12 % at 50 ms | 1–6 per viewpoint in runs 2–3; 101–205 in run 1 |
| `max_fps` 0, Swappy auto (`pacing_android_uncapped`) | 37.0 / 36.8 / 39.9 | 25.1 / 25.6 / 26.4 | alternating 16.7 / 33.3 ms (Galata 50 / 50 %) | 161–768 |
| 30 Hz physics, `max_fps` 30 | 30.0 | 27.0 / 26.7 / 26.3 | 99.4–99.8 % at 33.3 ms | 1 |

- The default 30 FPS cap is well paced in runs 2–3; its "1 % low" below 30 is CPU-side frame-interval jitter up to ~40 ms (p99 38–41 ms), mostly without a 50 ms frame. Run 1 (the first run after the batch restart) had 7–12 % frames of 50 ms; the cause was not identified. Without the cap, Swappy does not settle at 30 and the frames alternate between one and two refreshes: higher average, uneven motion. 30 Hz physics tightens the jitter (p99 ~37 ms).

### Protocol deviations

- Tablet cool-down: the batch started at 27.5 °C and the first run heated the (charging) battery to 31.5 °C; waiting for 28.0 °C before every one of 36 runs would have taken many hours. The wait was capped at 120 s (`COOL_TIMEOUT_S=120`); the experiments were interleaved in the same order in every run and battery temperatures are recorded per run (31–39 °C; thermal status 0 throughout). The partial first attempt is not used.
- One tablet run (run 1 `profile_default`) lost its results when the adb server restarted mid-run (USB re-enumerated); `android_bench.sh` now waits out adb dropouts, and the run was repeated at the end (in `run1`). Run 1 of the C experiments shows more long frames than runs 2–3; medians are used.
- iPhone: one Instruments probe without data in one 60 Hz session; thermal state Nominal at every other probe.

## Phase 3 — vehicle system (2026-10-25/26)

### Physics engine

- `physics/3d/physics_engine` is `"DEFAULT"`; in Godot 4.7.2 that runs **GodotPhysics3D**. Evidence: the world's direct space state is `GodotPhysicsDirectSpaceState3D` and body states `GodotPhysicsDirectBodyState3D`; throwaway projects outside the repository report `JoltPhysicsDirectSpaceState3D` with `"Jolt Physics"` and the Godot classes with `"GodotPhysics3D"` and `"DEFAULT"`; a space created through `PhysicsServer3D` kept a parameter Jolt ignores and was reported at exit as a `GodotSpace3D` allocation. On the devices: the tablet's logcat shows `STARTUP … physics_3d=GodotPhysics3D (setting DEFAULT)`, and every benchmark result file from both devices records `"physics_3d": "GodotPhysics3D"`. `test_active_physics_engine_is_detected` pins it. The setting was not changed.
- `VehicleBody3D` on GodotPhysics3D showed no serious problem. Findings that shaped the code: it drives along +Z; positive steering turns left (front-wheel steering); the project's default linear damping (0.1) capped the car near 15 m/s; 8° of steering at 21 m/s rolled the car over (5° at top speed, 0.12 rad at 13 m/s, and full steering from 6–18 m/s stayed upright, slaloms and handbrake turns included); on a steep Karaköy street the car rolled back without a pedal (hence the hill hold). No jitter was seen: vertical speed stayed below 0.25 m/s at 21 m/s on a flat floor.

### Builds and devices

Debug builds from `2e68916` for the measurements (Android APK 226.1 MB; iOS `com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, automatic signing **without** `-allowProvisioningUpdates`), and from `59aa62b` (adds the debug CAR button) for the checklist. Same devices as before.

### Acceptance criteria (automated)

| Criterion | Result | Evidence |
|---|---|---|
| Interact button only in reach and on the floor | PASS | `test_interact_button_only_in_reach_and_on_floor` (hidden far away, shown in reach, hidden in the air, shown after landing) |
| Get in: on-foot HUD hidden, vehicle HUD shown, camera target and profile the vehicle's; get out: the reverse | PASS | `test_enter_and_exit_switch_hud_camera_and_player`, `test_vehicle_controls_layout_and_group_switch` |
| Exit refused while too fast, accepted when slow; blocked driver's side → other side; both blocked → refused | PASS | `test_exit_refused_while_too_fast`, `test_exit_tries_the_other_side_then_refuses`, `test_exit_point_prefers_driver_side_and_avoids_obstacles`, `test_exit_needs_a_floor` |
| Throttle accelerates forward; brake slows; brake at standstill reverses; steering direction correct; handbrake stops | PASS | `test_drive_command_rules`, `test_throttle_accelerates_forward_up_to_max_speed`, `test_brake_slows_then_reverses`, `test_positive_steer_turns_right`, `test_handbrake_stops_the_vehicle`, `test_drive_with_touch_buttons`, `test_keyboard_enters_drives_and_exits` |
| Focus loss in the vehicle: throttle released, handbrake held, no button stuck | PASS | `test_focus_out_drops_throttle_and_holds_handbrake`, `test_focus_out_while_driving_releases_controls` |
| Reset after flipping and after falling | PASS | `test_flipped_vehicle_resets_to_spawn`, `test_falling_below_kill_height_resets`, `test_vehicle_reset_takes_the_driver_along` (driver goes along; the world does not respawn the hidden player) |
| Punch/roll presses inert in the vehicle; Phase 2 tests still pass after getting out | PASS | `test_on_foot_actions_are_inert_while_driving`, `test_vehicle_keys_and_steer_buttons`; all Phase 2 tests pass |
| Real map: the car rests on flat ground at its spawn; 5 s of throttle cover at least X m without sticking | PASS | `test_vehicle_parked_on_a_flat_karakoy_street` (four wheels in contact, upright, on `Ground_`); `test_vehicle_drives_five_seconds_along_the_street`: **43.8 m** in 5 s, 14.9 m/s at the end, upright (lowest up 0.994), straight; threshold X = 35 m |
| Mutation checks (exit speed rule, HUD group switch) | PASS | exit speed always allowed → 2 tests fail; interaction skipping the speed check → 2 fail; no group switch → 9 fail; on-foot presses accepted while driving → 2 fail; no hill hold → 2 fail; 8° steering at top speed → the rollover check fails; the seated-tick fix removed → 1 fails |
| Extensibility: a second type from a definition plus a scene | PASS | `test_second_vehicle_type_from_definition_and_scene` (test van: 2200 kg, 14 m/s), `test_second_vehicle_type_enter_and_exit` |

Other checks: hill hold (`test_driven_vehicle_holds_on_a_slope_without_pedals`), vehicle spawn from `MapDefinition` (`test_spawns_vehicles_from_the_definition`), VIEW moves the vehicle (`test_view_cycle_moves_the_vehicle_while_driving`), camera follow mode (`test_follow_mode_swings_back_after_look_input_pauses`, `test_snap_uses_the_targets_follow_yaw`, `test_on_foot_profile_keeps_the_yaw`), in-vehicle benchmark (`test_short_benchmark_in_the_vehicle`), CAR button (`test_debug_car_button_walks_up_to_the_vehicle`), getting in while walking (`test_entering_while_walking_leaves_the_player_idle`).

### On-device checklist (user, 2026-10-25/26)

| Item | iPhone 13 Pro | Galaxy Tab A7 |
|---|---|---|
| Button reach and safe area (interact, vehicle controls) | PASS (user: "Rahat; binme/inme doğru"); screenshot `docs/perf/phase3/iphone_vehicle_hud.jpg`: vehicle controls inside the notch-side inset and above the home indicator, exit inside the top-right corner inset | PASS (user); `docs/perf/phase3/tablet_vehicle_hud.jpg` |
| Getting in and out | PASS (user) | PASS (user); logcat `CAR walk-up` |
| Exit blocked while fast; camera behind the car and swinging back after a look drag | PASS (user: "İkisi de doğru") | PASS (user) |
| Focus loss while holding the throttle: car stops (handbrake), no stuck button, throttle works again | PASS (user: "Doğru") | PASS (user) |
| Driving feel (steering, throttle, brake, reverse, handbrake) in the user's words | prepared answer "İyi, değişiklik gerekmez"; the user gave no own sentence | same |

The screenshots show the user driving on Karaköy streets on both devices. Getting in and out, the exit block, and focus loss leave no log line, so those items rest on the user's answers and the automated tests. The iPhone screenshot showed the overlay state "Walk 0.0 m/s" while driving; fixed in `9dd53df` (unit test only; not rechecked on a device).

### Performance regression (medians of three runs, cold start)

`profile_default` (on foot) and `profile_default_vehicle` (driver's seat, car moved to the viewpoint, no pedal). Tablet without PSS sampling. Values: median [run 1 / run 2 / run 3]. Before = Phase 2 build (tablet two runs, iPhone one run).

| Device, view | Avg FPS on foot | 1 % low on foot (before) | 1 % low in vehicle | Draw calls on foot / in vehicle (before) | Physics step ms on foot / in vehicle (p99) |
|---|---|---|---|---|---|
| Tab A7 low, Spawn | 30.00 | 25.28 [25.18 / 25.28 / 25.98] (23.96, 26.10) | 25.85 [23.69 / 25.87 / 25.85] | 101 / 122 (101) | 4.90 (7.10) / 4.45 (8.74) |
| Tab A7 low, Karaköy | 30.00 | 25.56 [25.56 / 25.21 / 25.97] (23.86, 26.58) | 26.03 [23.78 / 26.03 / 26.25] | 93 / 112 (93) | 4.73 (7.48) / 4.03 (8.41) |
| Tab A7 low, Galata | 30.00 | 24.88 [24.97 / 22.22 / 24.88] (23.12, 25.60) | 25.64 [23.19 / 25.65 / 25.64] | 56 / 78 (56) | 5.56 (7.95) / 4.84 (5.80) |
| iPhone high, Spawn | 59.99 | 42.34 [42.34 / 42.43 / 42.17] (42.42) | 42.40 [42.25 / 42.70 / 42.40] | 263 / 232 (263) | 1.32 (1.91) / 1.06 (1.28) |
| iPhone high, Karaköy | 60.00 | 41.72 [41.72 / 41.80 / 41.66] (41.73) | 42.04 [41.73 / 42.04 / 42.33] | 162 / 196 (162) | 1.35 (1.64) / 1.08 (1.48) |
| iPhone high, Galata | 60.00 | 39.80 [39.71 / 39.87 / 39.80] (40.42) | 40.51 [40.57 / 40.51 / 40.39] | 93 / 118 (93) | 1.50 (2.28) / 1.01 (1.34) |

- Average FPS in the vehicle: 30.00 (tablet) and 60.00 (iPhone) at every viewpoint, medians and all runs (29.99–30.00, 59.99–60.00).
- **iPhone 10-minute sessions in the vehicle** (`session_profile_vehicle`, Karaköy, parked: the driver presses nothing, the hill hold keeps the car still; three runs): per-minute median 59.97–60.00 FPS, 1 % low 41.78–42.01, physics step 1.05–1.16 ms; thermal state **Nominal** at every valid probe (14 probes per run; one probe each in runs 2 and 3 returned no data); footprint 1,021–1,044 MiB. **PASS** (≤ Fair, ≥ 55 FPS).
- **Tab A7 low, median average ≥ 30 at all three viewpoints: PASS** (on foot and in the vehicle). 1 % low medians on foot (24.88–25.56) lie within the range of the Phase 2 runs (23.12–26.58) and above its lower runs; all three medians are above 24, Galata included; thermal status 0 in all runs; battery 33.0–35.5 °C at the starts (warmer than earlier batches: 23.5–31.0 °C).
- **Draw calls:** on foot unchanged (the parked car is not in view at the viewpoints, the interact button is hidden). In the vehicle the camera is farther and higher and the car is in view: tablet +19 to +22, iPhone −31 to +34 depending on the view. HUD cost on the Mac: on-foot HUD 38 draw calls, interact button +5, vehicle HUD 51.
- **Physics step** (`Performance.TIME_PHYSICS_PROCESS`, one 60 Hz step): the tablet spends 4.0–5.6 ms per step, and with the 30 FPS cap each frame contains two steps, about 8–11 ms of the 33 ms frame. The iPhone spends 1.0–1.5 ms. In the vehicle the step is 0.3–0.7 ms cheaper than on foot (the player's `move_and_slide` stops while seated; the vehicle adds its wheel raycasts). Not measured before this task, so there is no earlier baseline.
- **Startup** (median of six launches per device): iPhone map ready 1,540 ms, first frame 1,610 ms (Phase 2: 1,660 ms, one launch); tablet 8,071 / 8,552 ms (Phase 2: 9,431 and 8,123 ms).
- **Protocol incidents:** the first iPhone batch (overnight) produced nothing: the phone was locked, every Instruments probe answered "Waiting for device to boot", and each run waited out the 40-minute cool-down timeout. `tools/perf/ios_bench.sh` now queries the device first (which brought the connection back) and stops after three unknown probes. During run 2 one probe returned nothing; the probe and the process query now tolerate a single dropout.

## Phase 2 — character actions (2026-10-25)

### Builds and devices

Debug builds from commit `bd8294d` on the same two devices as before (iPhone 13 Pro, iOS 26.6.1; Galaxy Tab A7 SM-T500, Android 12). Android: "Android Debug" APK, 226.0 MB, `adb install`. iOS: `tools/build_ios_debug.sh <udid>` (bundle `com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, automatic signing **without** `-allowProvisioningUpdates`, `devicectl` install).

### Behaviour and automated evidence

| Behaviour | Evidence (tests, macOS, Godot 4.7.2) |
|---|---|
| Buttons on the right, inside the safe area, over the look area, hit areas not overlapping; icons | `test_action_buttons_layout` |
| One-shot press on touch-down; holding or dragging does not repeat; a drag from the button does not turn the camera; a look drag ending on a button does not press it | `test_action_buttons_fire_once_on_touch_down`, `test_look_drag_over_action_button_stays_look` |
| Joystick + camera drag + punch + roll at the same time | `test_joystick_look_and_action_buttons_together` |
| J punches, Space rolls; key repeat ignored | `test_action_keys`, `test_input_actions` |
| Intent gets a press once | `test_touch_input_fills_one_shot_intent` |
| Punch: duration 27 ± 1 ticks; hitbox open exactly in the 6 active ticks; back to Idle | `test_punch_phases_and_hitbox_timing` |
| Punch stops the body, facing locked; Run resumes afterwards at full speed | `test_punch_slows_movement_and_locomotion_resumes`, `test_punch_on_bridge_then_walk` |
| Roll follows the camera-relative stick (camera turned 90°, rolled toward the camera's forward) | `test_roll_follows_camera_and_camera_follows_roll` |
| Roll direction from the stick, distance 6 m ± 0.3, body turned; without stick along the facing | `test_roll_follows_move_direction_for_its_distance`, `test_roll_without_stick_goes_where_the_body_faces`, `test_roll_direction` |
| Punch pressed in the last 0.1 s of a roll runs right after it; pressed early, it expires | `test_punch_pressed_late_in_roll_runs_right_after`, `test_punch_pressed_early_in_roll_expires` |
| Roll cancels the punch recovery at once; it cannot cancel startup or active (it starts on the first recovery tick) | `test_roll_cancels_punch_recovery`, `test_roll_cannot_cancel_punch_active_phase`, `test_roll_cannot_cancel_punch_startup`, `test_roll_pressed_at_punch_start_expires_before_recovery` |
| No action starts in the air; expired presses do not fire on landing | `test_actions_do_not_start_in_the_air` |
| Roll presses during the cooldown (and during the roll) are ignored | `test_roll_press_during_cooldown_is_ignored`, `test_roll_press_during_roll_is_ignored` |
| Focus loss / pause during a punch or roll: Idle at once, hitbox closed, visual reset, nothing buffered fires, walking works | `test_focus_out_ends_punch`, `test_pause_ends_punch`, `test_focus_out_ends_roll`, `test_pause_ends_roll` |
| Focus loss / pause: no action button stays down, pending presses dropped | `test_focus_out_releases_held_joystick_and_run`, `test_pause_releases_held_joystick_and_run` |
| One hit per punch per target, also when the target re-enters during the active phase; nothing behind is hit | `test_hitbox_hits_a_hurtbox_once_per_punch`, `test_target_reentering_during_active_phase_is_hit_once` |
| Training dummy on the real map: next to the spawn, on the deck, one hit per punch, removed by the second toggle | `test_training_dummy_is_hit_once_per_punch`, `test_debug_dummy_button_requests_the_dummy` |
| Visual replaceable: a recording visual receives `play punch 0.45 0.10`, `stop`, `play roll 0.60 -1.00`, `stop` and `set_locomotion` every tick | `test_visual_can_be_replaced`; placeholder poses: `test_placeholder_visual_animates_and_resets` |
| Camera during a roll: pivot on the interpolated player in every frame, never steps backwards, travelled 6.01 m over 89 frames | `test_roll_follows_camera_and_camera_follows_roll` |
| Real map: roll along Galata Bridge then walk, still on the deck; a roll toward the deck edge falls off and respawns | `test_roll_on_bridge_then_walk`, `test_roll_off_the_deck_edge_respawns` |

Mutation checks (each rule broken on purpose, then restored): recovery not cancellable → 3 tests fail; any phase cancellable → 3 fail; actions allowed in the air → 1 fails; presses kept while blocked → 2 fail; no interrupt on focus loss → 4 fail; no per-activation hit de-duplication → 1 fails (`test_target_reentering_during_active_phase_is_hit_once`, added because the first version of the hit test did not catch it).

### On-device checklist (user, 2026-10-25)

| Item | iPhone 13 Pro | Galaxy Tab A7 |
|---|---|---|
| Punch, roll, run buttons reachable with the right thumb; no clash with notch or edges | PASS (user: "Rahat, çakışma yok"); screenshot `docs/perf/phase2/iphone_hud.jpg`: controls inside the notch-side inset and above the home indicator | PASS (user); `docs/perf/phase2/tablet_hud.jpg` (no notch) |
| Joystick + camera drag + punch/roll together; a drag starting on a button does not turn the camera | PASS (user: "Hepsi çalıştı") | PASS (user) |
| Roll along the bridge then walk; roll toward the railing falls into the water and respawns | PASS (user: "Üçü de doğru") | PASS (user) |
| Training dummy: count rises by one per punch | PASS (user; screen afterwards shows `HITS 4`, `docs/perf/phase2/iphone_dummy_hits.jpg`) | PASS (user). The tablet log of the first ~95 minutes of the session had no `DUMMY` line; after the agent asked, the log shows `DUMMY on`, `DUMMY off`, `DUMMY on`, `DUMMY hits=1`, `DUMMY hits=2` |
| Feel of punch and roll, in the user's words | The user chose the prepared answer "İyi, değişiklik gerekmez"; no free-text sentence | Same |

Answers are the user's; the agent cannot observe touches. The roll on the bridge leaves no log line on the devices, so it rests on the user's answer (and on the integration tests).

### Performance regression (profile_default, cold start, same protocol as the profile validation)

Before = profile validation of 2026-10-24 (`docs/perf/profiles/results/`), after = this build (`docs/perf/phase2/results/`). Tablet runs without PSS sampling; two runs each.

| Device, view | Avg FPS before → after | 1 % low before → after | Min FPS before → after | Draw calls before → after |
|---|---|---|---|---|
| Tab A7 low, Spawn | 30.01, 30.00 → 30.01, 30.00 | 24.81, 27.44 → 23.96, 26.10 | 22.37, 25.09 → 21.51, 21.33 | 86 → 101 |
| Tab A7 low, Karaköy | 30.00, 30.00 → 30.00, 30.00 | 24.80, 24.65 → 23.86, 26.58 | 23.79, 22.86 → 19.88, 24.15 | 78 → 93 |
| Tab A7 low, Galata | 30.00, 30.00 → 30.00, 29.99 | 23.10, 23.38 → 23.12, 25.60 | 21.89, 22.35 → 22.13, 18.23 | 41 → 56 |
| iPhone high, Spawn | 59.99 → 59.99 | 42.71 → 42.42 | 37.79 → 40.94 | 248 → 263 |
| iPhone high, Karaköy | 60.00 → 59.99 | 42.25 → 41.73 | 40.65 → 40.77 | 147 → 162 |
| iPhone high, Galata | 60.00 → 59.99 | 40.37 → 40.42 | 39.83 → 39.89 | 78 → 93 |

- **iPhone 10-minute session** (Karaköy, `session_profile_default`): 59.98–60.0 FPS every minute (before 59.97–60.0), 1 % low 41.5–42.6 (before 41.4–41.7), thermal state Nominal at all 13 probes (before: Nominal), footprint 1,021–1,022 MiB (before 1,017–1,034). The profile run also stayed Nominal (footprint peak 1,034 MiB, as before). **PASS** (≤ Fair, ≥ 55 FPS).
- **Tab A7 average ≥ 30 at all three viewpoints: PASS** in both runs. Thermal status 0; battery 23.5 → 26.5 °C and 27.0 → 28.5 °C (before: 28.5 → 30.0 and 31.0 → 31.5 °C).
- **Draw calls +15 at every viewpoint on both devices:** the three new HUD buttons (punch, roll, DUMMY). On the Mac, hiding them took the frame from 105 to 90 draw calls (the whole HUD: 38). Primitives unchanged.
- **1 % low:** the largest drop against the earlier first run is 0.94 FPS (Karaköy, run 1); against the earlier repeat, Spawn run 1 is 3.48 lower, but the new repeat is 26.10. Identical runs differ by 2.1–2.7 FPS per viewpoint in both builds, so no systematic regression is visible; the HUD's extra draw calls are a small CPU cost that these runs cannot separate from the spread. D12's 1 % low ≥ 24: run 1 below at all three (23.96 / 23.86 / 23.12, marginal), run 2 above at all three (26.10 / 26.58 / 25.60), Galata included; Galata stays a known deviation (D12).
- **Startup:** tablet map ready 9,431 and 8,123 ms; iPhone 1,660 ms (before 1,506–1,563 ms; not investigated).
- **Protocol incident:** the first tablet attempt ran while the tablet was on its lock screen (it has a PIN; `run_batch.sh` only wakes the screen), so the app never came to the foreground and the run timed out after 40 min with no results. It was repeated after the user unlocked the tablet; the failed attempt is not in the tables.

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

## Quality profile validation (2026-10-24, debug builds)

Builds from commit `526ac6f` plus a log line listing the effective settings (in the documentation commit). Same protocol as the diagnosis pass: cold start (iPhone "Nominal", tablet battery back to its starting temperature), 30 s warm-up + 60 s per viewpoint; experiment files only start the benchmark (`profile_default*.json` set no render keys, so the platform default profile applies). Raw data: `docs/perf/profiles/results/`; screenshots: `docs/perf/profiles/`.

### Automatic profile selection (no flags)

- Galaxy Tab A7, plain launch, logcat: `QUALITY profile=low experiment=none occluders={"ms":89,"occluders":643,"source":"baked","triangles":317518} effective={"camera_far":400.0,"fog":true,"hide":[],"lod_threshold":4.0,"max_fps":30,"occlusion":true,"render_scale":0.6,"scaling_mode":"bilinear","shadows":"off","visibility_end":{"decor":100.0,"facade_detail":100.0,"lamps":100.0,"trees":100.0}}` and `STARTUP map_ready_ms=8961 first_frame_ms=9442 profile=low …`.
- iPhone 13 Pro, plain launch, unified log (Instruments "Logging"): `QUALITY profile=high experiment=none occluders={"ms":20,…,"source":"baked",…} effective={"camera_far":1500.0,"fog":false,…,"max_fps":60,"occlusion":true,"render_scale":1.0,…,"visibility_end":{"decor":200.0,"facade_detail":200.0,"lamps":200.0,"trees":200.0}}` and `STARTUP map_ready_ms=1563 first_frame_ms=1696 profile=high …`.
- The effective settings match the profile resources exactly, so the export conversion of the `.tres` profiles kept every value.
- Tests: `test_platform_rule` (iOS → high, Android → low, desktop → none), `test_profiles_switch_on_the_real_map`.

### Galaxy Tab A7 — low profile

Values Spawn / Karaköy / Galata. Thermal status 0 in every run.

| Experiment | Avg FPS (S / K / G) | 1% low | Min FPS | Draw calls | Primitives (M) | VRAM MiB | Peak memory | Thermal / temperature |
|---|---|---|---|---|---|---|---|---|
| profile_default | 30.0 / 30.0 / 30.0 | 24.8 / 24.8 / 23.1 | 22.4 / 23.8 / 21.9 | 86 / 78 / 41 | 0.05 / 0.06 / 0.05 | 493 | PSS not sampled | 28.5→30.0 °C, status 0→0 |
| profile_default_pss | 29.9 / 29.9 / 29.9 | 26.4 / 26.3 / 25.5 | 8.1 / 8.6 / 9.8 | 86 / 78 / 41 | 0.05 / 0.06 / 0.05 | 493 | PSS 550 MiB | 30.0→31.0 °C, status 0→0 |
| profile_default_repeat | 30.0 / 30.0 / 30.0 | 27.4 / 24.6 / 23.4 | 25.1 / 22.9 / 22.4 | 86 / 78 / 41 | 0.05 / 0.06 / 0.05 | 493 | PSS not sampled | 31.0→31.5 °C, status 0→0 |

### iPhone 13 Pro — high profile

| Experiment | Avg FPS (S / K / G) | 1% low | Min FPS | Draw calls | Primitives (M) | VRAM MiB | Peak memory | Thermal / temperature |
|---|---|---|---|---|---|---|---|---|
| profile_default | 60.0 / 60.0 / 60.0 | 42.7 / 42.2 / 40.4 | 37.8 / 40.6 / 39.8 | 248 / 147 / 78 | 0.21 / 0.26 / 0.32 | 673 | footprint 1034 MiB | Nominal→Nominal (max Nominal) |

10-minute session at Karaköy (`session_profile_default`); thermal state Nominal at all 13 probes (0–598 s), footprint 1,017–1,034 MiB:

| Minute | Avg FPS | 1% low | Min FPS | Draw calls | Primitives | Thermal (nearest probe) |
|---|---|---|---|---|---|---|
| 1 | 60.0 | 41.4 | 19.4 | 145 | 258,298 | Nominal |
| 2 | 60.0 | 41.7 | 41.0 | 147 | 262,676 | Nominal |
| 3 | 60.0 | 41.6 | 41.0 | 147 | 262,676 | Nominal |
| 4 | 60.0 | 41.7 | 40.9 | 147 | 262,676 | Nominal |
| 5 | 60.0 | 41.4 | 40.7 | 147 | 262,676 | Nominal |
| 6 | 60.0 | 41.7 | 41.0 | 147 | 262,676 | Nominal |
| 7 | 60.0 | 41.6 | 40.9 | 147 | 262,676 | Nominal |
| 8 | 60.0 | 41.7 | 40.8 | 147 | 262,676 | Nominal |
| 9 | 60.0 | 41.7 | 40.9 | 147 | 262,676 | Nominal |
| 10 | 60.0 | 41.6 | 40.3 | 147 | 262,676 | Nominal |

### Acceptance criteria (user, D12)

| Criterion | Result |
|---|---|
| iOS starts with high, Android with low, without flags | **PASS** (device logs above; unit test) |
| iPhone 13 Pro, high, 10 min: thermal ≤ Fair | **PASS** (Nominal throughout) |
| iPhone 13 Pro, high, 10 min: average FPS ≥ 55 | **PASS** (59.97–60.0 every minute) |
| Tab A7, low, Spawn: average ≥ 30 and 1 % low ≥ 24 | **PASS** (30.0; 24.81 and 27.44) |
| Tab A7, low, Karaköy | **PASS** (30.0; 24.80 and 24.65 — close to the limit) |
| Tab A7, low, Galata | **FAIL** on the 1 % low: 23.10 and 23.38 (average 30.0 passes). The same settings gave 25.8 in the diagnosis pass, so run-to-run spread is about ±2 FPS. Galata draws only 41 draw calls and 47 K primitives; the shortfall is more likely frame pacing (30 FPS cap on a 60 Hz display mixes 33 ms and 50 ms frames) and per-pixel cost of the wall-filled view than geometry. Not verified. |
| Baked occluders load; runtime occluder building is gone from startup | **PASS**: `source: baked` on both devices. Load time 87–89 ms on the tablet (runtime build was 114–118 ms) and 18–20 ms on the iPhone (21 ms); the saving is small. |
| Experiment flags still work | **PASS** (perf tests; experiments layer on the profile) |
| Full suite passes; GLB-less SKIP behaviour kept | see "Verified behaviors" |

- iPhone frame pacing: the 1 % low stays at ~41.4–41.7 FPS in the high profile as in every earlier 60-capped run; not addressed in this task (user decision).

### Startup

| Device | Before profiles (Phase 1, no occlusion) | With profile and baked occluders |
|---|---|---|
| Galaxy Tab A7, map ready / first frame | 9,720 / 12,452 ms and 15,196 / 20,683 ms | 7,806 / 8,224 ms (benchmark run) and 8,961 / 9,442 ms (plain launch) |
| iPhone 13 Pro, map ready / first frame | 1,565 / 1,649 ms | 1,506 / 1,571, 1,540 / 1,612, 1,563 / 1,696 ms |

The occluder step itself is small on both devices; the earlier tablet startup times varied between runs, so the lower values are not attributed to the bake.

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
| Automated tests pass. | `run_tests.gd` → `RESULT 161 passed, 0 failed, 0 skipped`, exit 0; unit only → 134 passed, exit 0; without the GLB → `RESULT 134 passed, 0 failed, 27 skipped`, exit 2 (2026-10-26, Phase 4a; GLB SHA-256 re-verified afterwards). With Jolt (temporary `override.cfg`): 160 passed, 1 failed (the GodotPhysics3D pin). At 30 Hz physics: 148 passed, 13 failed (see "Phase 4a"). `tests/map/validate_scene.gd` → `VALIDATION PASS`. |
| Phase 4a gating and flags. | `test_build_features.gd` (feature logic, release HUD without debug controls, presets: `perf_bench` only in Release Perf presets, `perf_jolt` / `perf_60hz` only in their presets, keystore fields empty, no personal paths), `test_release_perf_build_runs_benchmarks_without_debug_ui`, `test_normal_release_ignores_experiments`, `test_runtime_experiment_keys_apply_on_the_map`, `test_runtime_keys_parse_and_reject_typos`, `test_frame_time_distribution`, `test_measurement_overrides_do_not_touch_defaults`. |
| Phase 3 vehicle. | See "Phase 3 — vehicle system", including the mutation checks. |
| Phase 2 actions. | See "Phase 2 — character actions", including the mutation checks. |
| Quality profiles. | `test_render_settings.gd` (platform rule, `--quality`, profile values equal the measured packages, experiment > profile precedence, low profile applied, switching back restores every default, occluder fallback with warning, shared vertices keep triangles); integration: `test_profiles_switch_on_the_real_map`, `test_profile_uses_baked_occluders`, `test_baked_occluders_match_runtime_build` (643 occluders, 317,518 triangles, same extent). |
| Performance flags still work and do nothing by default. | `test_perf_experiments.gd` (parsing, only given keys become settings, typo and unknown-profile rejection, every experiment file parses and older ones pin profile none, frame statistics, slugs); integration: `test_perf_categories_cover_every_map_mesh`, `test_no_perf_experiment_by_default`, `test_short_benchmark_on_map`. |
| Runtime errors fail tests. | Before the fix, a null method call and an error after `await` were both reported PASS (exit 0). After: both FAIL with "logged error: …", exit 1. |
| Missing GLB is visible. | With the GLB moved away: `RESULT 42 passed, 0 failed, 7 skipped`, exit 2; unit only exit 0. GLB restored, SHA-256 re-verified. |
| Focus loss / pause reset input. | `test_focus_out_releases_held_joystick_and_run`, `test_pause_releases_held_joystick_and_run`; both failed on the previous controller. |
| Exported PackedStringArray guard. | `test_no_packed_string_array_exports`; fails if the old type is restored. |
| Debug viewpoints stand on ground on the map. | `test_debug_viewpoints_stand_on_ground`. |
| Original map validation. | `tests/map/validate_scene.gd` → `VALIDATION PASS | failures=0`. |
| Phase 1 behaviors (routing, speeds, camera collision on 192 street samples, respawn, safe-area math). | Unit and integration suites; see `docs/ARCHITECTURE.md`. |

## Unverified behaviors

- Phase 4a: the tablet's "1 % low" is measured from the CPU frame loop; actual presentation times (Swappy) were not recorded, so how much of the 33–40 ms jitter is visible is unknown.
- The ~1.3 ms of the tablet's physics step that the player and the parked car share with the nearby trimesh bodies was not separated further.
- `process_ms` is recorded but is not a CPU measure while a frame limiter waits.
- 30 Hz physics was measured for performance and in the headless suite, not played on a device.
- Jolt was measured on the tablet only.
- Why the first tablet run of the C batch had 7–12 % frames of 50 ms.

- Phase 3 driving feel in the user's own words: the user chose a prepared answer on both devices.
- The seated-tick fix (`9dd53df`) was found on the iPhone and is covered by a unit test, but no device build with it was checked.
- `tools/perf/ios_bench.sh`'s stop after three unknown probes was not exercised (the phone stayed unlocked in the repeated batch); its device query and single-dropout tolerance were.
- Vehicle behaviour on Jolt Physics: not tried (setting unchanged by decision).

- Phase 2 feel in the user's own words: the user chose a prepared answer on both devices.
- Roll on the bridge on devices: no log evidence (user answer only); covered by integration tests on the same map.
- Focus loss during a punch or roll on a device: covered by unit tests only.
- Whether the +15 HUD draw calls measurably affect the tablet's 1 % low: below the run-to-run spread.
- iPhone startup 1,660 ms vs 1,506–1,563 ms before: one run, not investigated.

- iOS process launch time to first frame (only engine-internal times were measured).
- iPhone single measures without a frame cap and the tablet's 10-minute session: not run (see "Not run").
- Quality profiles in a release build: the profiles are not debug-only, but only debug builds were measured.
- Cause of the tablet's Galata 1 % low shortfall (frame pacing suspected).
- Profile behaviour on devices other than the two test devices.
- Cause of the ~41 FPS 1 % low in every 60-capped iPhone run (frame pacing suspected).
- Whether MetalFX spatial scaling was active on the iPhone: no engine warning on the Mac's Metal Forward Mobile renderer (FSR did warn), but no device log was captured during the run.
- Release builds: none made (release signing out of scope).
- Smoothness of physics interpolation on the 120 Hz screen: not judged separately.
- Whether Android cancels a held touch by itself on backgrounding (the device test cannot tell that apart from the fix; the unit tests cover the fix).
- F4 (interpolation reset after a bounds clamp): no dedicated test; a meaningful check needs a moving body at the boundary.
- Codex reading `AGENTS.md`: not tested.

## Known bugs and limitations

- Placeholder car (boxes and cylinders); no engine sound, damage, or traffic. Brake lights also light while parked (handbrake held).
- Cars drive through railings, lamp posts, and kerbs (no collision) and can leave bridge decks and quays into the water; they reset to the spawn below the kill height (open question 12).
- Exit markers are fixed points beside the doors; on a narrow street with both sides blocked the player cannot get out until the car is moved.
- The debug overlay shows the player's state and speed while driving, not the vehicle's.

- Placeholder character: punch and roll are shown with capsule tweens; no model or animations (`CharacterVisual` is ready for them).
- The debug "DUMMY" label is wider than its 96-unit button on both devices (cosmetic, debug builds only).
- Punches only signal hits; no damage, reactions, or NPCs (open questions 22–23 in `PROJECT_CONTEXT.md`).
- A punch pressed more than 0.18 s before a roll ends, or a roll pressed in the first ~0.02 s of a punch, is dropped by design (T19).
- The perf batch cannot unlock a tablet with a PIN; unlock it before starting (a locked tablet produced a 40-minute run without results).

- Galaxy Tab A7 with the low profile: 1 % low at Galata 23.1–23.4 FPS, below the user's 24 FPS criterion; the visual cost of low (fog, no shadows, 0.6 render scale, blank nearby facades from chunk-granular ranges) is accepted for now (D12).
- Without a profile (desktop "none", or an experiment pinning "none") the map is as heavy as before: tablet 5.8–7.7 FPS.
- Per-chunk visibility ranges remove facade detail from nearby buildings: the map merges facade detail into 150 m chunks and Godot measures the range to the chunk's centre.
- On iOS, `get_tree().quit()` does not end the app; the benchmark hides the map and drops to 5 FPS, and `tools/perf/ios_bench.sh` terminates it.
- Railings, lamps, and decor have no collision; falling into the water respawns the player (same as the original demo).
- No jump (not requested); tall steps block the capsule.
- The original explorer demo still renders the city white.
- Placeholder character (no animations) and placeholder icon. The app name shown on devices is the project name "İstanbul • Haliç".
- Debug overlay and VIEW button appear in debug builds only; overlay text is English.
- Godot 4.7.2 export conversion dropped an exported `PackedStringArray` from a `.tres`; the project uses `Array[String]` instead (guarded by a test).

## Technical risks

- **Performance:** the profiles meet the iPhone criterion and the tablet's average; the tablet's 1 % low is marginal and its visual quality is low. Facade detail (64 % of triangles) remains the main geometry cost; the map-level work in `PROJECT_CONTEXT.md` is not started.
- **Physics cost on the tablet:** one 60 Hz physics step takes 4.7–5.7 ms (two per frame at the 30 FPS cap); ≈ 1 ms each is the player's `move_and_slide` and the parked car (Phase 4a); the rest is shared with the trimesh map colliders. Not changed yet.
- **iPhone pacing:** the default 120 Hz display with a 60 FPS limiter alternates 8.3 / 25 ms frames (visible judder); the fix (60 Hz display) is measured but not applied.
- Devices are assigned by platform only: a weak iPhone would get high, a strong Android phone low (open question 18 in `PROJECT_CONTEXT.md`).
- **Memory:** iPhone footprint 1.02 GiB; Android uses swap on a tablet with limited RAM.
- **Startup:** 10–15 s to map ready on the tablet, with variance between runs.
- A fresh clone lacks the GLB and will not run until it is restored.

## External blockers

- Final iOS identity: `com.mirongi.mapsimulator` must be registered only in the user's future Apple Developer account. Until then, iOS debug builds use the temporary team and `.dev` bundle ID.

## Required manual actions

- **iPhone: set Auto-Lock back to its previous value** (set to "Never" again for the Phase 4a measurements). The iPhone now has the "iOS Release Perf 60Hz" build installed and the tablet the "Android Release Perf" APK (no debug overlay); the next debug build replaces them.
- Decide on the Phase 4 proposals in `PROJECT_CONTEXT.md` ("Phase 4 proposals", not applied).
- Open questions 2 (car model source), 12 (barriers), 22–24 (damage, NPCs, roll immunity), 28–29 (camera distance, steering modes) remain.
- Decide on the map-level facade work and on bringing the map generation scripts into the repository (open questions 20–21).
- Later: create the new Apple Developer account, then update the team ID and bundle ID (decision D8).
- Provide or choose character and car models; decide the app name and icon.

## Current priorities

1. Review of Phase 4a and a decision on its proposals.
2. Phase 4b (apply the chosen proposals, then the remaining Phase 4 items) or the map-level facade work (user decision).

## Recommended next task

**Phase 4b: apply the two cheap, measured proposals, then re-measure.**

1. **iPhone: run the display at 60 Hz** (`display/window/ios/allow_high_refresh_rate = false`, keep `Engine.max_fps` 60 in the high profile). Measured: 1 % low 41.9 → 55.4–55.5, long frames 49.5 % → ~0, average 60.0 and thermal Nominal unchanged. No gameplay change; the only loss is a 120 Hz option the game does not use (high is capped at 60).
2. **Tablet: stop simulating parked cars** (freeze or sleep a vehicle with no driver at rest, keep its interaction area). Measured upper bound: ≈ 1.0 ms per physics step, ≈ 2 ms per frame at 30 FPS. Needs care for getting in, resets, and the hill hold.

Acceptance: both devices with the same three-run protocol, release perf builds; iPhone long frames < 1 % and 10 minutes Nominal; tablet physics step down by ≥ 0.8 ms on foot with no change in Phase 1–3 tests; device check that getting in and driving off a frozen car works.

Not recommended now (measured): 30 Hz physics (the car becomes unstable; would need substepping or retuning), Jolt (~2 ms per step slower here), disabling physics interpolation (≤ 0.3 ms, costs smoothness at 120 Hz), uncapped tablet frame rate (uneven 16.7 / 33.3 ms frames).

The map-level facade work stays the way to improve the tablet's picture (blank nearby facades, fog, no shadows) and to relax the low profile. The measurements do not make it the next step for frame time: at the low profile the tablet draws only 35–101 draw calls and ~0.05 M primitives, and its frame-time variance comes from CPU work (physics) and pacing. It remains blocked on the user's approval of map pipeline changes and on the generation scripts (open questions 20–21).
