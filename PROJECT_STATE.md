# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-10-24 (Phase 1, Claude Code)

## Current phase

**Phase 1 — mobile character control: implemented, awaiting review.** On the İstanbul • Haliç map, a placeholder character walks and runs with a touch joystick, and a touch-controlled third-person camera follows it. Verified with headless automated tests and desktop window renders. **Not tested on any physical phone or tablet.**

## Current objective

External review of Phases 0–1, a first device test, then user approval before Phase 2 (punch, roll, animation/state).

## Git

- Branch: `main`. Remote: `origin` → `https://github.com/reftgit/map-simulator.git`. Upstream: `origin/main`.
- `3c0771c`: development protocol bootstrap.
- `3a9a49b`: Phase 0, original map project imported (files matched the package manifest; Godot 4.7.2's first import added seven default-valued keys to `assets/istanbul_halic.glb.import`), audit recorded.
- Phase 1 is the commit after `3a9a49b` (`git log`).

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Phase 1 game code: composition root, world, player, camera, input, HUD. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition`. |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; physics layer names. |
| `tests/` | Headless runner, 42 unit tests, 7 integration tests, flat-map fixture, original map validation. |
| `tools/capture_screenshot.gd` | Windowed render to PNG with render stats. |
| `main.tscn`, `scripts/` | Original explorer demo, unchanged. No longer the main scene. Desktop only. |
| `assets/istanbul_halic.glb` | 502 MB, **not tracked**. Restore: `docs/maps/istanbul_halic/README.md`. |
| `.vscode/settings.json` | The user's editor colors. Untracked, intentionally not committed. |

## Implemented features (Phase 1)

- Landscape layout with a safe-area-aware HUD (margins from `DisplayServer.get_display_safe_area()` on mobile).
- Left side: Godot's native `VirtualJoystick` in dynamic mode over the left 42 % of the screen, analog, 360°.
- Right side: camera drag area over the remaining 58 %, and a run toggle button.
- Multi-touch: each finger belongs to one control until release; camera drags and buttons do not steal each other's fingers.
- Movement relative to the camera; walking speed follows stick tilt (up to 4.5 m/s); running at 8.0 m/s.
- Player state machine: Idle, Walk, Run; the body turns toward the movement direction.
- Third-person camera: yaw and pitch from touch drags, pitch limited to −65°…35°, spring-arm collision so the camera stays in front of walls.
- `WorldManager`: map loading from a `MapDefinition`, spawn on Galata Bridge facing Karaköy, respawn below y = −5 (for example after falling into the water), bounds clamping.
- Map look: vertex colors applied, so the city renders in color (the original Godot import rendered it white).
- Debug overlay in debug builds: FPS, state, speed (updated every 0.5 s).
- Desktop development controls: WASD/arrows, Shift to run, mouse drag emulating touch.

## Verified behaviors

All on 2026-10-24, macOS, Godot 4.7.2.

| Behavior | Evidence |
|---|---|
| Project imports cleanly. | `godot --headless --path . --import`: exit 0, no errors or warnings in the log. |
| Automated tests pass. | `godot --headless --path . --script res://tests/run_tests.gd` → `RESULT 49 passed, 0 failed` (42 unit, 7 integration), exit 0, no script errors in the log. |
| Runner reports failures. | A deliberately failing test and a deliberately broken test file each produced `FAIL` and exit 1; both files were removed. |
| Original map validation still passes with the new settings. | `tests/map/validate_scene.gd` → `VALIDATION PASS | failures=0`. |
| Joystick drives movement through the real input pipeline. | `test_touch_routing.gd`: half deflection gives 0.375 after the 0.2 dead zone; full deflection forward gives y = −1; release gives zero. |
| Joystick and camera drag work at the same time. | `test_joystick_and_look_work_simultaneously`. |
| Buttons and camera drag do not interfere. | `test_run_button_toggles_without_turning_camera`, `test_look_drag_over_button_stays_look`, `test_second_finger_in_look_area_is_ignored`. |
| Walk and run speeds, transitions, facing. | `test_player_controller.gd` on a flat fixture: 4.5 m/s, 8.0 m/s, analog half speed, Idle→Walk→Run→Idle, faces movement, stops at a wall. |
| On the real map: spawn, touch walking and running along Galata Bridge. | `test_game_on_map.gd`: spawn on the Galata Bridge collider at y ≈ 4.55 facing along the deck; touch walk 2 s → Walk at 4.5 m/s, > 8 m along the bridge, still on the deck; run toggle + stick 2 s → Run at 8.0 m/s, > 14 m, still on the deck. |
| Movement follows the camera. | `test_movement_follows_camera_direction`: after a 90° look drag, stick-up movement aligns with the camera direction (> 0.9). |
| Camera stays out of geometry on the map. | `test_camera_stays_out_of_geometry_on_streets`: 24 ground points around Karaköy/Galata × 8 directions = 192 samples; the spring arm shortened in 44; 0 samples had geometry between the pivot and the camera. |
| Camera stays in front of a wall and ignores the player capsule. | `test_third_person_camera.gd`. |
| Falling into the water respawns the player. | `test_falling_into_water_respawns`: one respawn, back on the bridge deck. |
| Safe-area math. | `test_ui_controller.gd`: iPhone 13 Pro landscape insets (141 px sides, 63 px bottom) convert to 108.46 / 851.54 canvas units. |
| Windowed render with the Mobile renderer. | `tools/capture_screenshot.gd` at 1266×585 and 1180×820: "Metal 4.0 – Forward Mobile", map in color, HUD at the expected positions, touch-driven run reached `Run 8.00 m/s` at a 1.535 window-to-canvas scale. |

## Measurements (desktop only, not device performance)

Apple M5, macOS, Mobile renderer on Metal, 1266×585 window, spawn view: 60 FPS (vsync), about 1,190–1,410 draw calls, about 1,220–1,440 objects, about 2.5–2.8 million primitives per frame depending on view direction. These numbers show the scene's weight; they say nothing about phone frame rates.

## Unverified behaviors

- **Everything on physical iOS and Android devices: NOT RUN.** Includes touch feel, multi-touch on real hardware, safe area on notched phones, frame rate, thermal behavior, memory, load time.
- iOS and Android export: NOT RUN. No `export_presets.cfg` exists.
- Behavior when the app is paused or switched while a finger is on the native joystick: not tested (the router's own fingers are dropped on focus loss; the native joystick's handling was not tested).
- Visual smoothness of physics interpolation on 120 Hz screens: not observed.
- Desktop keyboard controls: bindings verified by test; movement with keys was only seen in an ad-hoc diagnostic, not in a committed test.
- Codex reading `AGENTS.md`: not tested.

## Known bugs and limitations

- Railings, lamps, and decor have no collision, so the player can walk off bridge decks and quays and fall into the water, then respawns at the bridge. Same as the original demo. See open question 12 in `PROJECT_CONTEXT.md`.
- No jump (not requested). The capsule can get onto small curbs only when its rounded bottom slides over them; tall steps block it.
- The original explorer demo still renders the city white; the vertex-color fix applies only to the game's map scene.
- Placeholder character with no animations. Debug overlay text is English and visible in debug builds.

## Technical risks

- **Map weight on phones:** about 2.5–2.8 M primitives and about 1,300 draw calls at street level, with 7.07 M triangles in the model. Very likely too heavy for 60 FPS, and possibly for 30 FPS, on mid-range phones. Phase 4 must measure and reduce (visibility ranges, occlusion culling, LOD tuning, decor culling, possibly map splitting).
- Import needs about 3.3 GB peak memory on desktop; export size and device memory with the 502 MB model are unknown.
- A fresh clone lacks the GLB and will not run until it is restored.

## External blockers

None for review. Device testing needs export presets (app name, bundle IDs, signing; open question 5).

## Required manual actions

- Run the game on a device or in the editor (F5) and judge touch feel, camera sensitivity (`look_sensitivity` 2.6), and the run toggle (open question 13).
- Decide export identifiers and signing so a device build can be made.
- Provide or choose character and car models (open questions 1–2).

## Current priorities

1. Review of Phases 0–1.
2. First device build and on-device check of controls and frame rate.
3. Phase 2 after user approval.

## Recommended next task

Create debug export presets for Android and iOS, install on the available test devices, and record touch behavior, safe-area layout, and FPS at the spawn view. This is the evidence still missing for Phase 1 and the baseline Phase 4 needs. Requires the user's export identifiers and signing choices.
