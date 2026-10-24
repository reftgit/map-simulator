# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure, build, and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-10-24 (Phase 1 device validation, Claude Code)

## Current phase

**Phase 1 — mobile character control: implemented and checked on two physical devices.** Debug builds run on an iPhone 13 Pro and a Samsung Galaxy Tab A7. Touch controls passed the user's on-device checklist on both. Frame rate is far below the 60 FPS target on the Android tablet (5–8 FPS) and drops under thermal throttling on the iPhone (89 FPS cold → 43–53 FPS after long use). Performance work belongs to Phase 4 and has not started.

## Current objective

Review of the device results, then a user decision on the next step (Phase 2, or an earlier performance pass; see "Recommended next task").

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
- Export presets, icon, iOS build script, and these device results: the commit after `bab2b88`.

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Game code: composition root, world, player, camera, input, HUD with debug overlay. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition` (with two debug viewpoints). |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; ETC2/ASTC import (required for Android export); placeholder icon. |
| `export_presets.cfg` | "Android Debug" (arm64 APK, `com.mirongi.mapsimulator`) and "iOS Debug" (`com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, project-only export). No passwords or keystore paths. |
| `icon.svg` | Placeholder app icon (capsule character over water). |
| `tests/` | Headless runner, 46 unit tests, 8 integration tests, flat-map fixture, original map validation. |
| `tools/capture_screenshot.gd` | Windowed render to PNG with render stats. |
| `tools/build_ios_debug.sh` | iOS debug build without contacting the Apple Developer portal; optional `devicectl` install. |
| `build/.gdignore` | Keeps Godot from scanning or packing build output. Everything else in `build/` is ignored by Git. |
| `main.tscn`, `scripts/` | Original explorer demo, unchanged. Desktop only. |
| `assets/istanbul_halic.glb` | 502 MB, **not tracked**. Restore: `docs/maps/istanbul_halic/README.md`. |
| `.vscode/settings.json` | The user's editor colors. Untracked, intentionally not committed. |

## Implemented features

- Phase 1 controls: native `VirtualJoystick` (left 42 %), camera drag area (right 58 %), run toggle, camera-relative movement, Idle/Walk/Run states, spring-arm third-person camera, safe-area HUD, map loading with spawn, respawn, and bounds. Details in `docs/ARCHITECTURE.md`.
- Focus loss and pause release the joystick, the `move_*`/`run` actions, and the run toggle.
- Debug builds only: overlay with FPS, draw calls, primitives, objects, video memory, engine static memory; `PERF` log line every 2 s; `STARTUP` log line; VIEW button cycling Spawn → Karaköy street (facing north) → Galata street (facing south).
- Android and iOS debug export presets.

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

## Verified behaviors (automated, macOS, Godot 4.7.2)

| Behavior | Evidence |
|---|---|
| Project imports cleanly. | `godot --headless --path . --import`: exit 0, no errors or warnings (after adding `build/.gdignore`). |
| Automated tests pass. | `run_tests.gd` → `RESULT 54 passed, 0 failed, 0 skipped`, exit 0; unit only → `RESULT 46 passed, 0 failed, 0 skipped`, exit 0. |
| Runtime errors fail tests. | Before the fix, a null method call and an error after `await` were both reported PASS (exit 0). After: both FAIL with "logged error: …", exit 1. |
| Missing GLB is visible. | With the GLB moved away: `RESULT 42 passed, 0 failed, 7 skipped`, exit 2; unit only exit 0. GLB restored, SHA-256 re-verified. |
| Focus loss / pause reset input. | `test_focus_out_releases_held_joystick_and_run`, `test_pause_releases_held_joystick_and_run`; both failed on the previous controller. |
| Exported PackedStringArray guard. | `test_no_packed_string_array_exports`; fails if the old type is restored. |
| Debug viewpoints stand on ground on the map. | `test_debug_viewpoints_stand_on_ground`. |
| Original map validation. | `tests/map/validate_scene.gd` → `VALIDATION PASS | failures=0`. |
| Phase 1 behaviors (routing, speeds, camera collision on 192 street samples, respawn, safe-area math). | Unit and integration suites; see `docs/ARCHITECTURE.md`. |

## Unverified behaviors

- iOS process launch time to first frame (only engine-internal times were measured).
- Mobile vs Compatibility renderer on these devices: not compared.
- Release builds: none made (release signing out of scope).
- Smoothness of physics interpolation on the 120 Hz screen: not judged separately.
- Whether Android cancels a held touch by itself on backgrounding (the device test cannot tell that apart from the fix; the unit tests cover the fix).
- F4 (interpolation reset after a bounds clamp): no dedicated test; a meaningful check needs a moving body at the boundary.
- Codex reading `AGENTS.md`: not tested.

## Known bugs and limitations

- Android tablet at 5–8 FPS; startup to first frame 12–21 s.
- Railings, lamps, and decor have no collision; falling into the water respawns the player (same as the original demo).
- No jump (not requested); tall steps block the capsule.
- The original explorer demo still renders the city white.
- Placeholder character (no animations) and placeholder icon. The app name shown on devices is the project name "İstanbul • Haliç".
- Debug overlay and VIEW button appear in debug builds only; overlay text is English.
- Godot 4.7.2 export conversion dropped an exported `PackedStringArray` from a `.tres`; the project uses `Array[String]` instead (guarded by a test).

## Technical risks

- **Performance:** street-level frames carry 0.95–1.5 k draw calls and 2.3–3.4 M primitives with no occlusion culling. The Adreno 610 tablet manages 5–8 FPS; the iPhone reaches a "Serious" thermal state within minutes. Candidate measures are listed in `PROJECT_CONTEXT.md` (none implemented).
- **Memory:** iPhone footprint 1.02 GiB; Android uses swap on a tablet with limited RAM.
- **Startup:** 10–15 s to map ready on the tablet, with variance between runs.
- A fresh clone lacks the GLB and will not run until it is restored.

## External blockers

- Final iOS identity: `com.mirongi.mapsimulator` must be registered only in the user's future Apple Developer account. Until then, iOS debug builds use the temporary team and `.dev` bundle ID.

## Required manual actions

- Decide the minimum target devices and whether the Galaxy Tab A7 class must reach 30 FPS (open questions in `PROJECT_CONTEXT.md`).
- Decide the next step: Phase 2 or a performance pass first.
- Later: create the new Apple Developer account, then update the team ID and bundle ID (decision D8).
- Provide or choose character and car models; decide the app name and icon.

## Current priorities

1. Review of the device results.
2. User decision on the next step.

## Recommended next task

A measurement-only performance pass before Phase 2: on the same two devices and three viewpoints, measure the effect of individual low-risk settings (camera far plane with fog, visibility ranges for lamps/trees/decor, occlusion culling, shadows off, 3D render scale, a 60 FPS cap on iOS), one at a time, and record which reach 30 FPS on the tablet and reduce iPhone heat. At 5–8 FPS the Android controls cannot be judged properly, and Phase 2 animation work would be measured on an unusable baseline. This changes the phase order and needs the user's approval.
