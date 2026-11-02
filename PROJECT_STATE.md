# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure, build, and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-11-02 (the shader facade map as the default, Claude Code)

## Current phase

**After Phase 5: the shader facade map is the default (2026-11-02).** With D25's criterion 1 made relative by the user (the shader map no worse than İstanbul • Haliç under the same protocol) it passed on the Galaxy Tab A7: nine alternating launches each, one bad launch each, median 1 % low within +0.03 / −0.03 / +0.19 FPS of İstanbul's, average 30.0; the reviewer, to whom the user delegated it, approved the distant windows. So `istanbul_halic_cells_shader` became the first map in the registry in its own revertable commit (`b80c205`), and plain launches of debug and Release Perf builds start on it on both devices (STARTUP logs); İstanbul • Haliç, the test district, the cells map, and the light map stay selectable. A clone without the generated GLB starts on the first available map with a warning (İstanbul where its GLB is copied in, else the test district), and with no map available the game shows an error (`edadb59`). The tablet's presented frames, recorded without changing any setting, show that a bad launch's 28 → 42 → 30 ms loop cycle does not reach the screen, while every launch has about one 16.7 / 50 ms pair per second on the screen that the game loop does not see (open question 43). The `vehicle_sleep` and `extensibility` device scenarios passed again on both devices, starting on the default map (13 / 13 and 25 / 25 each). Details: "The shader facade map is the default" below.

Before it: **the shader facade was the chosen variant (D25) but did not become the default (2026-11-01).** A map switch now frees the old map before loading the next, behind a loading screen; on the Galaxy Tab A7 six switches between the shader map, İstanbul, and the cells map passed without the low-memory kills of before, and the `extensibility` and `vehicle_sleep` scenarios passed on both devices, but the cells map's load still peaked 64 MiB above the target. The tablet's long frames turned out to be a pacing state of single launches that hits any map (the shader map, İstanbul, the cells map, the panels without a shader), not the window shader; a 31 FPS cap did not remove it, and no fix was applied. The shader's distant windows are now filtered over the pixel footprint instead of fading (closer to the full facade, no more shimmering in a pan). D25's criteria: iPhone (60.00 FPS, 0 long frames, 10 minutes Nominal), the scenarios, and memory (tablet 641 MiB peak, iPhone 854–860 MiB) passed; the tablet's long-frame criterion failed in one of three runs (46 and 107 long frames), so İstanbul • Haliç stays the default; the visual approval is with the user. Details: "Shader facade toward the default" below.

Before it: **two lighter facades exist as experimental maps (2026-11-01); no map changed and none became the default (D24).** The generator's `--facade light` keeps every window's surround and glass and drops mullions, sills, and the windows behind neighbours (facade triangles −50.03 %); `--facade shader` draws windows, cornices, and string courses on one panel per wall with a shader (−92.26 %); every other mesh stays byte-identical and both are deterministic. As `istanbul_halic_cells_light` and `istanbul_halic_cells_shader` (cells map data, shared occluders, GLBs generated per machine) both met the iPhone criteria including 10-minute sessions, and both met the tablet's average and 1 % low thresholds; light also its long-frame limit, shader not (one run at Galata with 4.4 % long frames). On the iPhone they recover 174–184 MiB (light) and 422–429 MiB (shader) of the cells map's +280 MiB footprint; on the tablet the PSS barely drops (−10 / −18 of +128 MiB), because its increase came with the mesh count, while the engine's video memory falls 477 → 350 → 262 MiB. The `vehicle_sleep` scenario passed on the shader map on both devices, `extensibility` on the iPhone; on the tablet the app was killed by the low-memory killer while switching between two large maps. The user then chose the shader variant (D25). Details: "Lighter facades on the cells map" below.

Before it: **the cells map is in the game for measurement (2026-11-01); İstanbul • Haliç, the profiles, and the game's behaviour are unchanged.** The generator can mesh facade detail, tree crowns, and shrubs per cell inside each 150 m chunk (`--detail-cell`; without it the output is byte-identical), and a grouping-only comparison proves that no triangle changed. The 40 m variant (chosen over 75 m on the Mac: no nearby building blanked within 50 m on the low profile, 8.7 % within 100 m against 18.0 %) is a separate registry map, `istanbul_halic_cells`, whose GLB is generated on each machine and ignored by Git; its tests SKIP without it. On the devices (Release Perf, three runs) it met every criterion: Tab A7 low 30.00 / 29.99 / 29.99 FPS with 1 % low 25.90 / 25.83 / 25.28, iPhone high 60.00 FPS with at most 0.08 % long frames; its near facades are drawn where İstanbul blanks them, at +128 MiB PSS and +1.2 s map ready on the tablet and +280 MiB footprint on the iPhone. An experiment with 150 m ranges and no fog on the tablet kept the median 1 % low (one run had long-frame windows). The OSM input lost its Wi-Fi password tags with the output unchanged. Details: "Cell grouping and the cells map" below.

Before it: **the İstanbul • Haliç generator is in the repository and reproduces the current map (2026-11-01); the map, the game, the profiles, and the baselines are unchanged.** The package's Python scripts, their inputs, and the records of the shipped GLB were committed unchanged, then given `--source` / `--out` paths (output to the ignored `build/maps/istanbul_halic/`) and a pinned environment (Python 3.12, shapely 2.1.2). Two runs are byte-identical (157 s, 3.4–3.6 GiB peak resident each). The regenerated GLB is not byte-identical with the shipped one: 2,550 of 3,055 meshes match byte for byte, buildings, facades, trees, lamps, mosques, bridges, and terrain match (or differ in float noise), and the differences are the GEOS triangulation of roads, pavements, and quays (+1,148 triangles, +0.02 % area) and 6 of 223 traffic signal heads placed elsewhere (and, found later, the Atatürk bridge's seven piers 2.7–3.5 m away). In Godot both import to 827 static bodies with the same 438,012 collision triangles. The shipped GLB has flat per-face normals on every mesh. Safranbolu is deferred. Details: "Map generator in the repository" below.

Before it: **Phase 5 (extensibility: second map, second vehicle type, NPCs) done; the specification's phases 0–5 are implemented.** A map registry picks the map (İstanbul • Haliç by default and always in normal release builds; `--map`, an experiment key, and a debug MAP button otherwise) and a switch rebuilds player, vehicles, NPCs, camera, and occluders with the node count back where it was; a second map built from Godot primitives (the test district) runs without the GLB; the van is the second vehicle type in the game; NPCs patrol on the player's own controller with an AI input source and play a hit reaction when punched. Of the eight core systems the task names, only `WorldManager` needed code (three additive changes). The device scenario passed all 25 steps on both devices; release measurements with the two İstanbul NPCs met both devices' criteria after the NPCs got a level of detail (two walking NPCs under the controller cost the tablet 2.3–2.9 ms per physics step and 1.6–2.6 FPS of its 1 % low). The iPhone orientation check is NOT RUN again (the user could not do it). Details: "Phase 5" below; status of every phase: "Specification status".

Before Phase 5: **Phase 4d (export configuration, platform isolation, automatic device checks) done; Phase 4 is complete for its engineering items.** A `Platform` module is the only code that asks the OS about the platform (device logs unchanged); the export configuration is reviewed and pinned by a test (one version source, no permissions, minSdk 24 / targetSdk 36, iOS 15.0, all six presets exported); a debug-build `DeviceScenario` replays the vehicle checks with synthetic touches and passed every step on the Galaxy Tab A7 and the iPhone 13 Pro, and the tablet was turned between both landscape orientations by adb with the joystick held (PASS, settings restored). Open: the iPhone rotation check (the phone stayed flat; NOT RUN) and the map-level work. Details: "Phase 4d" below.

Before Phase 4d: **Phase 4c (on-device check of Phase 4b, screen layouts and safe areas) done; the user parts are partly NOT RUN.** The HUD takes its safe area from an injectable source and re-applies it when it moves without a resize (180° turn); a headless matrix of nine screens passed on foot and in the vehicle without any layout change (gameplay touch targets 9.6–21.6 mm). The Phase 4b check on the iPhone confirmed the parked car's sleep, wake on getting in, wake on a bump, and driving, and found one defect (the car stayed awake while the player stood against it on a slope), fixed in `5d6c8a7`. The Phase 4b check on the tablet and the two-orientation checks on both devices are NOT RUN: the user's answers were not borne out by logs or screenshots. P2's tablet criterion is accepted (D20). Details: "Phase 4c" below.

Before Phase 4c: **Phase 4b (P1 and P2 applied, D20) done, with one acceptance criterion missed (accepted later, D20).** P1: every iOS build runs the display at 60 Hz; on the iPhone 13 Pro the "1 % low" rose from ~40–42 to 56.3–58.7 FPS and the frames that were one refresh late (~49 %) went to 0, on foot and in the vehicle, with the 10-minute session at 60 FPS and thermal Nominal. P2: a parked vehicle at rest falls asleep and wakes when needed; on the Galaxy Tab A7 the physics step on foot fell by 0.75 / 0.86 / 0.79 ms (Spawn / Karaköy / Galata) against Phase 4a, short of the ≥ 0.8 ms criterion at Spawn and Galata. The on-device user check was not run. Details: "Phase 4b" below.

Before Phase 4b: **Phase 4a (release baseline and diagnosis, measurement only) done.** Release builds for measurement ("* Release Perf*" presets, `perf_bench` feature) run on both devices and are proven non-debug. Release changes little against debug. The iPhone's ~41 FPS "1 % low" is a frame-pacing artefact of the 60 FPS limiter on the 120 Hz display (frames alternate 8.3 / 25 ms); at 60 Hz the frames are an even 16.7 ms. On the Galaxy Tab A7 the physics step (≈ 4.7–5.7 ms, two per frame) splits into ≈ 1 ms for the player's `move_and_slide`, ≈ 1 ms for the parked car, and smaller parts; 30 Hz physics destabilizes the car, and Jolt is ~2 ms per step slower. No default was changed; the measured proposals are in `PROJECT_CONTEXT.md`, "Phase 4 proposals". Phases 1–3 and the quality profiles are unchanged.

## Current objective

Review of the default change and its measurements; then the next task (see "Recommended next task"): the streaming loader, and, if the user wants it, a presented-frame measurement of the tablet's display pairs (open question 43).

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
- `d63464d`: Phase 4a results and documentation.
- `ce22319`: P1, the iOS display at 60 Hz by default; the "iOS Release Perf 60Hz" preset removed.
- `54a5b97`: P2, parked vehicles sleep; the overlay shows the driven vehicle's speed.
- `4ffd799`: fix, the vehicle tracks its own parking sleep (reads between physics steps were wrong).
- `e30942e`: measurement-only `vehicle_sleep` runtime key and the paired A/B experiments.
- `e2a4290`: Phase 4b results and documentation (this list completed in the commit after it).
- `5fa3ed3`: Phase 4b commit list.
- `a13a534`: the HUD's safe area from an injectable `SafeAreaSource`; layout matrix tests; screenshot tool `--safe-area` / `--release-hud`.
- `21b252d`: the safe area re-applied when it moves without a resize, with every finger released.
- `5d6c8a7`: fix, the player wakes a parked car only while pushing (found in the Phase 4b on-device check).
- `4706867`: Phase 4c results and documentation.
- `ceb840f`: `Platform` module; quality rule, safe area, external folder, display rate, and build features re-wired; fake-platform tests and the scan.
- `10a82e6`: version name from the project only; `test_export_presets.gd`.
- `0456e98`: `DeviceScenario`, scenario experiments, `android_rotate_on_cue.sh`, debug-only gravity sensor.
- `f742b10`: fix, the rotation cue script no longer swallows log lines or reacts to an earlier run's cues (found on the tablet).
- `55aa7de`: Phase 4d results and documentation.
- `793f722`: this commit list completed with `f742b10`.
- `167835d`: map registry (`game/world/maps.tres`), map choice at startup (`--map`, experiment key), `switch_map()`, debug MAP button.
- `4e62602`: test district (`tools/build_test_district.gd`, `maps/test_district/`) in the registry; its tests run without the GLB.
- `b7a5c6f`: the van's files moved from `tests/fixtures/` into the game. By a staging mistake this commit holds only the moves (its tests would fail on the old paths); `5aaefe7` completes it.
- `5aaefe7`: the van's game paths and names, `MapDefinition.vehicle_scenes`, the van parked on the test district, CAR walks up to each vehicle in turn.
- `a89274b`: NPCs (`game/npc/`, `HitReactionState`, NPC routes on both maps, layer 5, `"npcs"` runtime key, `tools/perf/npc_cost.gd`).
- `eb7726f`: NPC far mode (Tween walk beyond 10 m from the player), `"npc_far_mode"` runtime key, `npcs_near` in results, NPC names.
- `21196a3`: `DeviceScenario` "extensibility".
- `32f7bb5`: fix, a far NPC returns to the controller when the far mode is switched off (found by `tools/perf/npc_cost.gd`).
- `0d4bcbc`: Phase 5 results and documentation.
- `3d4bb1a`: İstanbul • Haliç generator scripts, inputs, and reference records imported byte-identical from the source package.
- `87dee5e`: generator paths (`--source`, `--out`), pinned Python environment, `.gitignore` for `build/maps/` and `__pycache__/`.
- `94c6e21`: `tools/maps/istanbul_halic/compare_outputs.py`.
- `34d5d17`: generator import results and documentation (D22, T39, Safranbolu deferred).
- `faed04b`: the Wi-Fi password tags removed from the OSM input (output unchanged).
- `449dd32`: `build_map.py --detail-cell`, `compare_outputs.py --grouped`.
- `3e00ada`: the cells map (`istanbul_halic_cells`), `MapDefinition.required_files`, its occluders and tests, `bake_occluders.gd --out`, the device experiments.
- `b80d430`: cell grouping measurements and documentation (D23, T40).
- `8bb22f1`: `build_map.py --facade light`, `compare_outputs.py --facade`.
- `68f0cac`: `build_map.py --facade shader`, `facade_windows.gdshader`.
- `83c8f0a`: the experimental facade maps (`istanbul_halic_cells_light`, `istanbul_halic_cells_shader`), their tests and experiments; the shader's distant fade moved.
- `5679844`: facade comparison, measurements, and documentation (D24, T41, T42).
- `d8f78fb`: the map switch frees the old map before loading the next (loading screen, `unload_map_and_wait()`), the `map_switch` scenario, `tools/perf/pss_trace.py`.
- `4242efe`: stutter diagnosis tools (traced benchmarks, facade runtime keys, `facade_windows_simple.gdshader`, `c_stutter_*`).
- `56aaf0d`: distant windows filtered over the pixel footprint; `capture_views.gd` far views and pan; `tools/perf/pan_flicker.py`.
- `17f1a78`: measurements and documentation (D25, T43). No stutter fix and no default change were committed ("Shader facade toward the default").
- `edadb59`: the default is the first available map (fallback with a warning, an error screen when none is available); İstanbul's `required_files`.
- `b80c205`: the shader facade map first in the registry, the default (D25); experiments measured on İstanbul pin it; tests follow. Revertable on its own.
- Measurements and documentation (D25 update, T44, open question 43): the commit after `b80c205` (`git log`).

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Game code: composition root, world, player (with Punch/Roll states and `CharacterVisual`), combat areas, vehicle (controller, definition, interaction, visual), camera, input, HUD with on-foot and vehicle control groups and a debug overlay. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition` (two debug viewpoints, two NPC routes). |
| `maps/istanbul_halic_cells_light/`, `maps/istanbul_halic_cells_shader/` | The facade maps (2026-11-01, D24; the shader map is the default since 2026-11-02, D25): the cells map's scene structure and data on their generated GLBs; the shader map adds `facade_windows.gdshader` (filtered over the pixel footprint since 2026-11-01, T43), a script that puts it on the facade surfaces and reads the measurement-only facade keys, and `facade_windows_simple.gdshader` (measurement only). They share the cells map's occluders. |
| `maps/istanbul_halic_cells/` | The cells map (2026-11-01): İstanbul's scene structure on the generated `assets/istanbul_halic_cells.glb` (facade detail, tree crowns, shrubs in 40 m cells), a `MapDefinition` with İstanbul's data and `required_files`, its own baked occluders (2,300,915 bytes). |
| `maps/test_district/` | Second map (Phase 5): scene and box occluders generated from Godot primitives by `tools/build_test_district.gd`, `MapDefinition` (both vehicle types, three NPC routes, two viewpoints). |
| `game/world/maps.tres` | The map registry: the shader facade map (the default since 2026-11-02), İstanbul • Haliç, the test district, the cells map, the light facade map; a map whose GLB is missing is skipped, and the default is then the first available one. |
| `game/npc/` | `Npc`, `AiPatrolInput`, `PatrolRoute`, `npc.tscn` (inherits the player scene). |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; ETC2/ASTC import (required for Android export); placeholder icon. |
| `export_presets.cfg` | "Android Debug" (arm64 APK, `com.mirongi.mapsimulator`), "Android Debug Compatibility" (same, with `--rendering-method gl_compatibility`), "iOS Debug" (`com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, project-only export), and the measurement-only "Android Release Perf", "Android Release Perf Jolt", "iOS Release Perf" (`perf_bench`; release templates). No passwords or keystore paths. |
| `icon.svg` | Placeholder app icon (capsule character over water). |
| `tests/` | Headless runner, 195 unit tests, 84 integration tests (2026-11-02; 18 run on the test district without any GLB, the rest SKIP without their map's GLB), fixtures (flat map, fake platform), original map validation. The test van moved into the game in Phase 5. |
| `tools/capture_screenshot.gd` | Windowed render to PNG with render stats. |
| `tools/capture_views.gd` | Fixed-camera comparison shots of map variants (eight views, a profile, no HUD; `--views`, `--facade-shader`, `--pan`). |
| `tools/build_ios_debug.sh` | iOS debug build without contacting the Apple Developer portal; optional `devicectl` install. |
| `tools/build_android_perf.sh`, `tools/build_ios_perf.sh` | Release Perf builds for measurements only (debug keystore via environment variables, read from the editor settings: macOS path by default, `GODOT_EDITOR_SETTINGS` elsewhere; Xcode Release without `-allowProvisioningUpdates`). |
| `game/quality/` | `RenderSettings` (applies render settings; shared by profiles and experiments), `QualityProfile`, `QualityProfiles` (selection rule), `profiles/high.tres`, `profiles/low.tres`. |
| `game/debug/` | Debug-only: `PerfConfig` (experiment flags from JSON, layered on a profile), `PerfBenchmark` (automatic measurement). |
| `maps/istanbul_halic/istanbul_halic_occluders.scn` | Baked occluders, 2,300,873 bytes (643 occluders, 317,518 triangles), referenced by the `MapDefinition`. |
| `tools/bake_occluders.gd` | Headless occluder bake. |
| `tools/perf/` | Experiment definitions (`experiments/*.json`; those measured before 2026-11-02 pin `istanbul_halic`), device orchestration (`android_bench.sh`, `ios_bench.sh`, `run_batch.sh`, `android_rotate_on_cue.sh`, `android_startup_log.sh`, `ios_startup_log.sh`), `present_trace.py` (presented frames on Android), `relative_check.py` (D25's relative criterion), `parse_xctrace.py`, `summarize.py`, `median.py`, `trace_summary.py` (traced benchmarks), `pss_trace.py` (dense Android PSS trace and map-switch summary), `pan_flicker.py` (shimmering in pans; needs Pillow), `collider_census.gd`, `vehicle_sleep_cost.gd`, `npc_cost.gd`. |
| `tools/build_test_district.gd` | Generates the test district's scene and occluders (Phase 5). |
| `tools/maps/istanbul_halic/` | İstanbul • Haliç generator (Python 3.12): `build_map.py` (with `--detail-cell`, `--facade`) and its modules, `render_map.py` (Blender previews, not run), `compare_outputs.py` (with `--grouped`, `--facade`), `blank_facades.py`, `requirements.txt` (pinned), `.python-version`. Output goes to `build/maps/` (ignored). |
| `maps/istanbul_halic/source/` | Generator inputs (20.1 MB): OSM extract (19.4 MB), Terrarium tiles, building height overrides, OSM request metadata. `.gdignore`. |
| `maps/istanbul_halic/reference/` | The records the package's run wrote for the shipped GLB and its validation records (3.0 MB), for comparison. `.gdignore`. |
| `docs/perf/` | Diagnosis pass: raw results and conditions (`results/`), 480 px screenshots (`android/`, `ios/`). Profile validation: `profiles/`. Phase 2 regression and HUD screenshots: `phase2/`. Phase 3 three-run results and screenshots: `phase3/`. Phase 4a release, diagnosis, and pacing results plus headless Jolt / 30 Hz / collider census: `phase4a/`. Phase 4b results, the sleep-vs-freeze measurement, overlay screenshots, a tablet log excerpt, and the iPhone frames of the Phase 4b check (`phase4b/device_check/`): `phase4b/`. 4.3 MB in total. |
| `docs/perf/phase4d/` | Export check (aapt, Info.plist, privacy manifest), tablet and iPhone scenario logs and results, rotation logs, frames. 0.2 MB. |
| `docs/perf/phase5/` | Three-run release results of both devices (`results/`), the tablet's NPC cost probes (`probes/`, with a README), headless NPC costs (`headless/`), scenario logs, results, and frames (`tablet/`, `iphone/`), benchmark frames of both maps (`shots/`). 0.7 MB. |
| `docs/ui/` | Reference HUD shots for the layout matrix (16 shots, on foot and in the vehicle, insets shaded), device before/after shots, device log excerpts of Phase 4c. 0.9 MB. |
| `build/.gdignore` | Keeps Godot from scanning or packing build output (exports and `build/maps/`, the generator's output). Everything else in `build/` is ignored by Git. |
| `main.tscn`, `scripts/` | Original explorer demo, unchanged. Desktop only. |
| `assets/istanbul_halic.glb` | 502 MB, **not tracked**. Restore: `docs/maps/istanbul_halic/README.md`. Since 2026-11-02 a selectable map (listed in its `required_files`). |
| `assets/istanbul_halic_cells.glb` | 506 MB, **not tracked**, generated on each machine (SHA-256 `7973071a…`); its `.import` is tracked. Steps: `docs/maps/istanbul_halic/README.md`, "The cells map". |
| `assets/istanbul_halic_cells_light.glb`, `assets/istanbul_halic_cells_shader.glb` | 363 MB and 255 MB, **not tracked**, generated on each machine (`6531ca28…`, `60b9f729…`); their `.import` files are tracked. The shader one is the default map's: same README, "Running the game on a new machine". |
| `docs/perf/facade/` | Facade variants: the visual comparison (README, sheets), the facade analysis and generator evidence (`generator/`), three-run device results (`results/`). |
| `docs/perf/default_map/` | The shader facade map as the default (2026-11-02): README, the relative criterion's 18 launches with presented frame traces (`results/android/`, gzipped), the summary tables, the startup logs of both devices, the scenario logs. 3.4 MB. |
| `docs/perf/facade_v2/` | Shader facade toward the default (2026-11-01): README with every table, the distant-window sheets and pan GIFs, device frames, the stutter A/B (`results/android_ab/`, traces gzipped), three-run device results (`results/android`, `results/ios`), the map switch and scenario evidence with PSS traces (`scenarios/`). 5.6 MB. |
| `docs/perf/cells/` | Cell grouping evidence: generator comparisons, hashes, run times, the blank-facade estimate, the occluder comparison (`generator/`), the desktop benchmarks and side-by-side shots (`desktop/`), three-run device results (`results/`), side-by-side device shots (`shots/`). |
| `.vscode/settings.json` | The user's editor colors. Untracked, intentionally not committed. |

## Implemented features

- **Default map (2026-11-02; all builds):** the shader facade map (`istanbul_halic_cells_shader`) is first in the registry and the map plain launches and normal release builds load; the default is the first available map, so without its GLB the game starts on İstanbul • Haliç or the test district with a warning, and with no map available it shows "Harita yüklenemedi: harita dosyaları eksik." Host tools: presented frames (`present_trace.py`), the relative criterion (`relative_check.py`), the log lines of a plain launch on both platforms.
- **Map switch (2026-11-01; debug and Release Perf builds, where switches happen):** the old map is freed before the next loads, behind a loading screen; a second switch during one is refused. Debug builds: the `map_switch` scenario. Traced benchmarks and the facade runtime keys (debug and Release Perf builds).
- **Facade maps (2026-11-01; debug and Release Perf builds):** `istanbul_halic_cells_light` and `istanbul_halic_cells_shader` in the registry, skipped while their GLBs are missing; the shader map draws its facades with `facade_windows.gdshader`. Generator: `build_map.py --facade`, `compare_outputs.py --facade`; tool: `tools/capture_views.gd`.
- **Cells map (2026-11-01; debug and Release Perf builds):** `istanbul_halic_cells` in the registry, loaded with `--map`, an experiment's `"map"` key, or the MAP button; skipped while its generated GLB is missing (`MapDefinition.required_files`). Generator: `build_map.py --detail-cell`, `compare_outputs.py --grouped`, `blank_facades.py`.
- **Phase 5 (all builds):** map registry (`game/world/maps.tres`) with İstanbul • Haliç first (the shader facade map first since 2026-11-02); NPCs on both maps (patrol, hit reaction, far mode beyond 10 m from the player); the van parked on the test district; `WorldManager` places a vehicle type per spawn and the NPCs, and respawns NPCs at their own start. Debug and Release Perf builds: the start map from `--map=<id>` or an experiment's `"map"` key, the `"npcs"` / `"npc_far_mode"` runtime keys, `map` and `npcs` in `STARTUP` / `PERF` / results. Debug builds: MAP overlay button (`switch_map()`), CAR cycles through the map's vehicles, `DeviceScenario` "extensibility". The test district is packaged in every build but normal release builds never load it.
- **Phase 4d:** `Platform` module (all builds); debug builds: `DeviceScenario` (`vehicle_sleep`, `orientation`) from a `scenario` experiment, gravity sensor on for evidence; host script `tools/perf/android_rotate_on_cue.sh`.
- **Phase 4c (all builds):** the HUD's safe area comes from `SafeAreaSource` (DisplayServer on devices, unchanged), is re-applied when it changes without a resize (checked every 0.25 s), and such a change releases every finger; `SAFE_AREA` log lines in debug and Release Perf builds. The player wakes a parked car only while pushing into it.
- **Phase 4b (all builds):** iOS runs the display at 60 Hz (`display/window/ios/allow_high_refresh_rate = false`; P1). Parked vehicles fall asleep after 1 s at rest and wake for a driver, a move or reset, a hit, the player walking into them, or lost ground (P2; `docs/ARCHITECTURE.md`, "Parked vehicles sleep"). Debug overlay: the driven vehicle's speed while driving and `car asleep|awake`; `VEHICLE … asleep|awake` log lines and `vehicles_asleep` in benchmark results (debug and Release Perf builds).
- **Measurement builds (Phase 4a):** `BuildFeatures` gates the debug overlay (debug builds) and experiments/benchmarks/STARTUP (debug builds and release builds with `perf_bench`); "Android Release Perf", "iOS Release Perf", and the measurement-only variant "Android Release Perf Jolt" (feature-tagged override; the 4a "iOS Release Perf 60Hz" variant was removed in Phase 4b). Experiments gain runtime keys (physics rate, interpolation, player physics, vehicles, collider radius, V-Sync) and results gain frame-time percentiles, a histogram, long frames, physics and process times. None of this changes normal builds.
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

## The shader facade map is the default (2026-11-02)

Task of 2026-11-02 (user, after the reviewer): measure D25's criterion 1, now relative to İstanbul • Haliç, on the tablet; if it passes, make `istanbul_halic_cells_shader` the default in its own revertable commit with a fallback for clones without the generated GLB; record the tablet's presented frame times without changing any pacing setting; the profiles, the physics, the gameplay, the shader, and the GLBs do not change. Decisions: `PROJECT_CONTEXT.md`, D25 (update and result), T44, open questions 21, 36, 41 (closed), 43. Evidence: `docs/perf/default_map/` (README with every table).

### What exists now

- **Fallback** (`edadb59`): the default is the first available map (`MapRegistry.default_map()`); a map whose `required_files` are missing is passed over with a warning naming them, at startup and for `--map` / an experiment, in every kind of build; with no map available the game logs an error naming each map's missing files and shows "Harita yüklenemedi: harita dosyaları eksik." on the loading screen instead of loading. İstanbul • Haliç lists `assets/istanbul_halic.glb` in `required_files`.
- **Default** (`b80c205`): `istanbul_halic_cells_shader` is first in `game/world/maps.tres`, then İstanbul • Haliç, the test district, the cells map, the light map (all selectable). The 66 experiments without a `"map"` key pin `istanbul_halic` (what they measured), as do `tools/perf/vehicle_sleep_cost.gd` and `npc_cost.gd`; the four `scenario_*` experiments stay unpinned and start on the default. İstanbul's game tests request it as a selectable map. **Revert:** this commit alone switches the default; `git revert b80c205` restores İstanbul • Haliç first (`git apply -R --check` of the commit passed on the final HEAD; the revert was not applied).
- **Tools** (the documentation commit): `tools/perf/present_trace.py` (presented frames on Android), `tools/perf/relative_check.py` (D25's relative criterion), `tools/perf/android_startup_log.sh` and `tools/perf/ios_startup_log.sh` (the log lines of a plain launch; the iOS one reaches the engine's os_log lines through an Instruments "Logging" recording), the experiments `c_relative_shader` and `c_relative_istanbul`.
- Unchanged: the shader (`facade_windows.gdshader` of `56aaf0d`), all four GLBs, the quality profiles, the physics, the gameplay, the frame pacing settings.

### D25 criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1 (relative since 2026-11-02). Tab A7 low: ≥ 9 launches each, alternating; bad launches of the shader map ≤ İstanbul's + 1; median 1 % low ≥ İstanbul's − 0.5 per viewpoint; average ≥ 29.9 | **PASS**: 9 and 9 launches; bad launches 1 and 1; differences +0.03 / −0.03 / +0.19; averages 30.01 / 30.01 / 30.00 | below |
| 2. iPhone high | PASS on 2026-11-01, not measured again | "Shader facade toward the default" |
| 3. Scenarios on both devices | PASS on 2026-11-01; run again from the default map on the builds of `b80c205`: tablet 13 / 13 and 25 / 25, iPhone 13 / 13 and 25 / 25 | below |
| 4. Memory | PASS on 2026-11-01, not measured again | "Shader facade toward the default" |
| 5. Visual approval | **given**: the user delegated the visual decision to the reviewer, and the reviewer approved the footprint filter (`docs/perf/facade_v2/far_windows_high.jpg`, the pan GIFs) | D25 |

### Relative criterion (Galaxy Tab A7, Release Perf of `56aaf0d`, low profile, 2026-11-02)

Two unused warm-ups, then nine runs of shader → İstanbul (traced benchmark: 30 s warm-up and 60 s per viewpoint; PSS sampling off; cool-down to ≤ 32.0 °C before each launch, waits 0–150 s; battery 31.5–33.5 °C, thermal status 0 throughout).

| Map | Bad launches | Long frames per viewpoint in the bad launch (Spawn / Karaköy / Galata) | Long frames per viewpoint in the other launches | 1 % low median (Spawn / Karaköy / Galata) | Average FPS median |
|---|---|---|---|---|---|
| shader | 1 of 9 (run 7) | 46 / 53 / 105 (2.6 / 2.9 / 5.8 %) | 0–11 (≤ 0.6 %) | 25.80 / 25.89 / 25.17 | 30.01 / 30.01 / 30.00 |
| İstanbul | 1 of 9 (run 2) | 72 / 50 / 130 (4.0 / 2.8 / 7.2 %) | 0–7 (≤ 0.4 %) | 25.77 / 25.92 / 24.98 | 30.01 / 30.01 / 30.01 |

Per launch with temperatures and waits: `docs/perf/default_map/relative_table.md`. The shader map's median 1 % low is within 0.2 FPS of İstanbul's at every viewpoint (2026-11-01, three runs: −0.46 at Spawn).

### Presented frames (open question 43; recorded only)

| | Game loop: long frames | Presented: 50 ms intervals (away from polls) | Presented: 16.7 ms intervals |
|---|---|---|---|
| Shader, 21 good viewpoints (7 launches) | 68 of 37,821 (0.18 %) | 847 of 32,990 (2.57 %) | 1,114 |
| İstanbul, 24 good viewpoints (8 launches) | 79 of 43,224 (0.18 %) | 1,323 of 37,650 (3.51 %) | 1,664 |
| İstanbul, bad launch (3 viewpoints) | 252 of 5,403 (4.66 %) | 64 of 4,720 (1.36 %) | 87 |

- The bad launch's 28 → 42 → 30 ms cycle does not reach the screen: loop times of 18–46 ms were presented at an even 33 ms; the game's long-frame count over-reports such a launch.
- Every launch has its own pairs of a 16.7 and a 50 ms presented interval, about one a second, which the game loop does not see: the frames before them were queued and GPU-finished on the usual cadence and waited longer for the display (frame-ready to present median 22.6 against 16.9 ms).
- The polling delays a composition now and then (counted out) and does not touch the game loop (24 of 392 long game frames within 150 ms after a poll, about the 7 % of the time those stretches cover). The shader map's bad launch (run 7) and its run 8 have no presented trace for the measurement windows: the sampler stopped early on one empty `pidof` answer (fixed: three in a row now).

### Startup map and scenarios from the default (builds of `b80c205`)

- **Plain launches** (no arguments, no experiment file; `tools/perf/android_startup_log.sh`, `tools/perf/ios_startup_log.sh`): Android Debug `STARTUP … map=istanbul_halic_cells_shader profile=low` (map ready 8,641 ms), Android Release Perf the same with `"debug_build":false,"perf_feature":true` (7,279 ms), iOS Debug `map=istanbul_halic_cells_shader profile=high` (1,399 ms), iOS Release Perf the same, non-debug (1,201 ms). Builds: APKs 676,391,706 (debug) and 674,576,699 bytes, iOS `.pck` 648,570,500 and 648,570,548 bytes (five maps).
- **Scenarios** (debug builds, the unpinned `scenario_*` experiments, starting on the shader map): Galaxy Tab A7 `vehicle_sleep` 13 / 13, `extensibility` 25 / 25 (MAP through İstanbul 9.0 s, the test district 0.5 s, the cells map 8.4 s, the light map 7.6 s, back to the shader map 6.6 s; nodes 8,549 before and after; PSS peak 810 MiB in the debug build, the low-memory killer reclaimed only other apps' processes); iPhone 13 Pro `vehicle_sleep` 13 / 13, `extensibility` 25 / 25 (footprint peaks 875 and 639 MiB from 45 s probes, Nominal). The tablet loaded İstanbul with its new `required_files` in the exported build, so the entry counts as available there.
- **Clean clone of `b80c205`** (Mac, headless): no GLB → `WARNING: Default map 'istanbul_halic_cells_shader' is not available (missing: res://assets/istanbul_halic_cells_shader.glb); loading 'test_district'`, `STARTUP … map=test_district`; only İstanbul's GLB (import 11.9 s) → the same warning with `loading 'istanbul_halic'`; the shader GLB added (import 8.7 s) → `map=istanbul_halic_cells_shader`, no warning.

### Tests (2026-11-02)

| Run (2026-11-02) | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| `run_tests.gd`, all GLBs present, final tree | `RESULT 279 passed, 0 failed, 0 skipped`, exit 0 |
| on `edadb59` | `RESULT 278 passed, 0 failed, 0 skipped`, exit 0 |
| on `b80c205` | before the commit 278 passed, 1 failed (`test_same_map_data_as_the_cells_map` still expected the shader map after the cells map); that check was removed (the order is pinned in `test_map_registry.gd`) and both facade map test files passed again (13 and 10 tests); the final run has the same code |
| `-- unit` | `RESULT 195 passed, 0 failed, 0 skipped`, exit 0 |
| clean clone of `b80c205`, no GLB | `RESULT 213 passed, 0 failed, 66 skipped`, exit 2; `-- unit` 195 passed, exit 0 |
| clean clone, only İstanbul's GLB | `RESULT 247 passed, 0 failed, 32 skipped`, exit 2 |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| `git show b80c205 \| git apply -R --check` on the final tree | clean (the default change reverses on its own; not applied) |

New: `test_default_is_the_first_available_map` and `test_no_available_map_is_an_error` (unit, fixture registries in normal release and debug builds), `test_missing_default_map_falls_back_to_the_first_available`, `test_fatal_error_screen`, `test_starts_on_the_registry_default` (test district file, run without any GLB), `test_registry_order_and_generated_files`; İstanbul's game tests request it; the MAP button test computes the order from the registry. All four GLBs' SHA-256 unchanged at the start and the end. Every run ends with the engine's "16 resources still in use at exit" line, as before this task.

## Shader facade toward the default (2026-11-01)

Task of 2026-11-01 (user): after the user chose the shader facade (D25; open question 42 closed), free the old map before the next one loads on a map switch, find and fix the cause of the shader map's long frames on the tablet, adjust its distant windows, measure the criteria of D25 on both devices, and make `istanbul_halic_cells_shader` the default if criteria 1–4 pass; the profile values, the physics, and the gameplay do not change. Decisions: `PROJECT_CONTEXT.md`, D25, T43, open questions 37, 42, 43. Evidence: `docs/perf/facade_v2/` (README with every table).

### What exists now

- **Safe map switch** (`d8f78fb`): `Main.switch_map()` is a coroutine; the HUD shows a loading screen ("Yükleniyor...") with the controls hidden and stopped, the player's processing stops, `WorldManager.unload_map_and_wait()` frees the old map, its vehicles, and its NPCs, waits until they are gone and three more frames, and only then is the next map loaded. A second switch during one is refused. The `map_switch` device scenario and `tools/perf/pss_trace.py` measure the memory of switches (`docs/ARCHITECTURE.md`, "Maps and the map registry", "Device scenario").
- **Diagnosis tools** (`4242efe`): traced benchmarks (`"trace": true`) and `tools/perf/trace_summary.py`; the measurement-only runtime keys `facade_material`, `facade_priority`, `facade_warmup` of the shader map and `facade_windows_simple.gdshader`; the experiments `c_stutter_*`.
- **No fix for the long frames:** the A/B showed that the window shader does not cause them (below); no code was changed for them.
- **Distant windows** (`56aaf0d`): `facade_windows.gdshader` box-filters every element over the pixel's footprint instead of fading to an average colour (T43); the GLB is unchanged (`60b9f729…`). `tools/capture_views.gd` gained two far street views, `--views`, `--facade-shader`, and `--pan`; `tools/perf/pan_flicker.py` measures shimmering.
- **The default did not change then:** criterion 1 failed on the tablet (below), so İstanbul • Haliç stayed the default (D25); on 2026-11-02 the criterion was made relative and the shader map became the default (above).

### D25 criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1. Tab A7 low, shader map: long frames ≤ 1 % in every run (3 runs × 3 viewpoints) | **FAIL**: run 3 had 46 (2.6 %) at Spawn and 107 (5.9 %) at Galata (13 at Karaköy); runs 1–2 at most 3 per viewpoint | measured cause: a pacing state of single launches that hits any map (İstanbul in run 1 of the same session: 200 / 117 / 138), not the shader (below) |
| 2. iPhone high: average ≥ 59.5, long frames < 1 %, 10 minutes with thermal ≤ Fair | **PASS**: 60.00 at all viewpoints, 0 long frames in every run; the session 59.96–60.00 FPS every minute, at most 1 long frame per minute, Nominal at all 14 probes | `docs/perf/facade_v2/results/ios/` |
| 3. `vehicle_sleep` and `extensibility` on both devices | **PASS**: tablet 13 / 13 and 25 / 25, iPhone 13 / 13 and 25 / 25 (both with `ios_bench.sh`) | `docs/perf/facade_v2/scenarios/` |
| 4. Tablet PSS ≤ 650 MiB, iPhone footprint ≤ 1,000 MiB | **PASS**: tablet peak 641 MiB (dense trace; stable 615), iPhone 854–860 MiB | dense PSS trace of one launch; iPhone probes of every run |
| 5. The user's visual approval of the distant windows | open then; given on 2026-11-02 through the reviewer (above) | — |

### Map switch

- **Headless:** on the test district the old map, its vehicles, and its NPCs are freed (211 → 51 nodes) and its scene is out of the resource cache before the next map enters; the loading screen is up and the controls hidden meanwhile; the player does not fall; a second switch is refused (`test_map_switch_frees_the_old_map_before_loading_the_next`; it fails when the old order, load first and free later, is restored). On İstanbul the GLB's scene is released before the fixture map loads. The existing switch, refusal, and leak tests pass with the coroutine. Desktop switch times: 22–35 ms on the test district, 0.5–0.9 s to a big map (freed after 13–108 ms, 4–5 frames).
- **Tablet (debug build, `scenario_map_switch`, PSS every 0.23 s):** six switches between the shader map, İstanbul, and the cells map passed (node counts 8,549 / 5,475 as on the first visit), and the app was not killed (the low-memory killer reclaimed other apps' processes, none of this app). Each switch first drops to 402–420 MiB (the old map freed), then rises while the next map loads and falls back when the load ends. Against the target "peak ≤ the larger map's stable PSS + 50 MiB": 5 of 6 switches PASS; **shader → cells FAIL** with a peak of 810 MiB against 746 (cells stable 696): the loader's temporary data of a big map, 15–115 MiB above its stable PSS depending on how much the system swaps meanwhile. Stable PSS in the debug build: shader 661–673, cells 693–696, İstanbul 584–585 MiB. Switch times 6.8–9.5 s.
- **Before:** peaks of 821 and 978 MiB with two maps in memory and the app killed twice (`docs/perf/facade/scenarios/tablet/`). Now `extensibility` passes on the tablet (peak 809 MiB, through five maps).
- Normal release builds load one map and never switch; their startup is unchanged.

### Long frames on the tablet: diagnosis

Release Perf build of `4242efe`, three runs of six traced experiments, order rotated, after two unused warm-ups (battery 30.5–33.5 °C, thermal status 0):

| Experiment | Launches with a viewpoint over 1 % long frames | Long frames per viewpoint (Spawn / Karaköy / Galata; runs 1, 2, 3) |
|---|---|---|
| `c_stutter_shader` (as it is) | 0 of 3 | 4,4,1 / 4,3,2 / 0,5,3 |
| `c_stutter_flat` (panels with the wall colour, no shader) | 1 of 3 | 1,1,94 / 4,3,81 / 2,3,120 |
| `c_stutter_simple` (simplified shader) | 0 of 3 | 5,5,1 / 1,3,3 / 4,6,9 |
| `c_stutter_warmup` (facade drawn once after loading) | 1 of 3 | 1,74,2 / 0,61,3 / 5,120,5 |
| `c_stutter_priority` (panels drawn before the walls) | 1 of 3 | 219,3,4 / 131,2,7 / 118,1,3 |
| `c_stutter_cells` (full facade as geometry) | 1 of 3 | 206,0,4 / 79,1,2 / 152,3,4 |

- **Not the shader:** the variant without any window shader had a bad launch too, and so did the cells map; the shader itself had none here (one in the device measurements). A bad launch is bad at all three viewpoints from its first warm-up; 91–100 % of its long frames sit next to a short frame (frame times cycle about 28 → 42 → 30 ms), the average stays 30.00 FPS, the 1 % low drops to 22.5–23.7. Phase 4a saw the same on İstanbul ("Frame pacing": one run with 7–12 % frames of 50 ms).
- **Time distribution:** at the first viewpoint of every launch the first three frames take 240–300 ms (4 canvas and 5–6 specialization pipelines compiled, every variant); after a viewpoint change 67–88 ms; the simplified shader's first use after the install 753 ms once. All in the warm-up; no pipeline was compiled inside any measurement. Not periodic beyond the three-frame cycle of a bad launch.
- **Not the double pacing:** Godot paces a 30 FPS cap with its CPU limiter and with Swappy; a 31 FPS cap (the limiter out of Swappy's way, still 30.00–30.01 FPS) had 79 long frames at Galata in one of three runs. The cause sits in the device's frame delivery at the 30 FPS cap (Swappy, the display, or the system) and was not separated further.
- **GPU time** (`viewport_get_measured_render_time_gpu`) stayed at 24.4–26.4 ms in every experiment and viewpoint and changes only every few seconds; with the driver scaling the GPU clock it shows no cost difference between variants.
- **Consequence:** no shader fix and no low-profile shader path; the warm-up and the render priority change nothing. A remedy would change the low profile's frame pacing (open question 43).

### Distant windows

The first version faded the pattern to its average colour beyond 0.35–0.9 m of wall per pixel, which flattened the windows of buildings about 120 m away in the 960×540 comparison shots. The footprint filter keeps them up to the 200 m range and looks like the cells map there; at 1920×1080 old and new look alike. In a half-pixel-per-frame pan the ratio of temporal second difference to change is lowest for the filter in all three views (raised 1.28, `far_avenue` 1.34, `far_bridge` 1.44; first version 1.34 / 1.39 / 1.46; cells 1.47 / 1.46 / 1.51): no more shimmering than the first version while showing more detail. Sheets, GIFs, and commands: `docs/perf/facade_v2/README.md`. Unit test: both window shaders compile and the fixed fade is gone (`tests/unit/test_facade_shader.gd`).

### Devices (Release Perf builds of `56aaf0d`, three runs, medians)

| Galaxy Tab A7 low | Shader map (Spawn / Karaköy / Galata) | İstanbul |
|---|---|---|
| Average FPS | 30.00 / 30.00 / 29.98 | 30.00 / 30.00 / 30.00 |
| 1 % low (median [runs]) | 25.60 [26.14 / 25.60 / 23.60] / 25.95 [26.27 / 25.95 / 24.05] / 24.87 [25.39 / 24.87 / 22.51] | 26.06 [23.26 / 26.07 / 26.06] / 26.01 [23.35 / 26.05 / 26.01] / 25.11 [22.40 / 25.29 / 25.11] |
| Long frames per run | 0, 2, 46 / 3, 3, 13 / 2, 2, 107 | 200, 0, 3 / 117, 4, 1 / 138, 3, 7 |
| Map ready (median) | 5,822 ms | 6,596 ms |
| PSS peak / stable (dense trace, one launch) | 641 / 615 MiB | 568 / 502 MiB (+127 MiB swap) |
| Video memory (engine) | 262 MiB | 482 MiB |

| iPhone 13 Pro high | Shader map (Spawn / Karaköy / Galata) | İstanbul |
|---|---|---|
| Average FPS | 60.00 / 60.00 / 60.00 | 60.00 / 60.00 / 60.00 |
| 1 % low (median) | 57.91 / 56.93 / 56.03 | 55.21 / 57.02 / 56.03 |
| Long frames | 0 | 0 |
| Footprint (three runs) | 854–859 MiB | 997–1,005 MiB |
| Map ready (median) | 1,194 ms | 1,379 ms |

The shader map with 150 m ranges and no fog on the tablet (information): 1 % low 26.23 / 26.04 / 24.87, at most 5 long frames. Every result has `debug_build: false`, `perf_feature: true`, and the expected map; tablet battery 32.5–33.0 °C, thermal status 0; iPhone Nominal at every probe. Builds: APK 674,576,699 bytes, iOS `.pck` 648,569,620 bytes (five maps).

### Tests (2026-11-01)

| Run (2026-11-01) | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| `run_tests.gd`, all GLBs present | `RESULT 274 passed, 0 failed, 0 skipped`, exit 0 (also on each commit: `d8f78fb` 269, `4242efe` 272, `56aaf0d` 274) |
| without the three generated GLBs and their import results | `RESULT 242 passed, 0 failed, 32 skipped`, exit 2 |
| without any GLB | `RESULT 208 passed, 0 failed, 66 skipped`, exit 2 |
| `-- unit` | `RESULT 193 passed, 0 failed, 0 skipped`, exit 0 (also without any GLB) |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| Mutation: the switch loading the next map before the old one is freed (the old order) | `test_map_switch_frees_the_old_map_before_loading_the_next` FAIL (six of its checks), the older switch tests still PASS |

New: `test_map_switch_frees_the_old_map_before_loading_the_next` and `test_device_scenario_map_switch` (test district, no GLB), İstanbul's GLB scene released before the next map (`test_map_switch_replaces_the_map_and_frees_the_old_one`), `test_facade_experiment_keys` and `test_traced_benchmark` (shader map), `test_trace_and_facade_keys`, `tests/unit/test_facade_shader.gd` (both window shaders compile; the fixed fade is gone). All four GLBs' SHA-256 unchanged at the start and the end.

## Lighter facades on the cells map (2026-11-01)

Task of 2026-11-01 (user): analyse the facade detail, add a lighter (`light`) and a shader-drawn (`shader`) facade to the generator, add both as experimental maps, compare them visually and on the devices; `istanbul_halic`, `istanbul_halic_cells`, the profiles, the game's behaviour, and the physics do not change, and no map becomes the default (D24). Decisions: `PROJECT_CONTEXT.md`, D24, T41, T42, open question 42. Guide: `docs/maps/istanbul_halic/README.md`, "Facade variants". Evidence: `docs/perf/facade/`.

### What exists now

- `build_map.py --facade full|light|shader` (`8bb22f1`: light and `compare_outputs.py --facade`; `68f0cac`: shader and `maps/istanbul_halic_cells_shader/facade_windows.gdshader`).
- Two experimental maps after the cells map in the registry (`83c8f0a`): `istanbul_halic_cells_light` and `istanbul_halic_cells_shader`, with the cells map's data and occluders, their GLBs generated on each machine (ignored by Git; SHA-256 `6531ca28…` and `60b9f729…`), the shader map's script that puts the shader on the facade surfaces, tests, and device experiments.
- `tools/capture_views.gd` (the documentation commit after `83c8f0a`): fixed-camera comparison shots of map variants.

### What the facade is made of

From an instrumented copy of the generator (`docs/perf/facade/generator/facade_analysis.md`): of the cells map's 4,187,598 facade triangles, window surrounds and glass are 25.8 % each, mullions and sills 15.3 % each (every other window), balcony railings 6.3 %, string courses 4.8 %, cornices 2.0 %, roofs, chimneys, roof boxes, awnings, balcony slabs, and doors together 4.7 %. 540,159 windows on 41,221 walls of 8,875 buildings. Every face uses the single vertex palette material with per-vertex colour and a flat normal, no textures or UVs. 24.0 % of the windows face a taller neighbour within 1 m (21.7 % within 0.3 m, i.e. inside it).

### Proof that only the facade detail changed

| Check (pinned environment) | Result |
|---|---|
| `--facade full`, no cells / `--detail-cell 40` | all nine files byte-identical with `68237c46…` / `7973071a…` (also after the shader refactor) |
| `light` vs full (`compare_outputs.py --facade`) | PASS: 3,664 of 3,664 meshes outside `Detail_*` byte-identical (attributes, indices, material), 827 `-col`, header and materials unchanged; `Detail_*` 2,465 meshes, 4,187,598 → 2,092,604 triangles (**−50.03 %**), vertices −49.83 %; 129,412 windows and 28,103 of 141,792 bands hidden by neighbours |
| `shader` vs full | PASS: the same 3,664 meshes byte-identical, one material appended (`Istanbul_FacadeWindows`); `Detail_*` 4,187,598 → 324,120 triangles (**−92.26 %**), vertices −91.87 %, `TEXCOORD_0` / `TEXCOORD_1` on the facade meshes |
| Determinism | light: three runs byte-identical (`6531ca28…`), shader: three runs byte-identical (`60b9f729…`), all nine files |
| Size, run time (Mac, alone) | GLB 506 / 363 / 255 MB (full / light / shader), imported scene 201 / 144 / 102 MB; 157.9 / 139.0 / 122.8 s; peak resident 3.6 / 3.0 / 2.4 GiB |
| Occluders | baked from each variant's collision: 643 of 643 occluders identical to the cells map's bake (vertices and indices), so both share it |

### Visual comparison

`docs/perf/facade/` (README with the list of differences, `comparison_high.jpg`, `comparison_low.jpg`, `closeups_high.jpg`; 1.3 MB): four maps (İstanbul with chunks, cells, light, shader) from the same six camera positions (the spawn, Karaköy, Galata, two near streets, a raised view) with the high and the low profile, shot on the Mac with `tools/capture_views.gd`. In short: light loses the mullions and sills and the windows behind neighbours (not visible from the streets); shader keeps the layout and the mullions but is flat (no projecting surround, glass, or cornice), has other light glass tints, and its far windows are fainter (the pattern fades to an average beyond about two pixels per window). The shader's fade started at 0.12 m per pixel in the first shots and removed the windows of buildings 150 m away; it was moved to 0.35–0.9 m (`83c8f0a`).

### Tests

| Run (2026-11-01) | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| `run_tests.gd`, all GLBs present | `RESULT 267 passed, 0 failed, 0 skipped`, exit 0 (550 s) |
| without the three generated GLBs and their import results | `RESULT 237 passed, 0 failed, 30 skipped`, exit 2 |
| without any GLB | `RESULT 203 passed, 0 failed, 64 skipped`, exit 2 |
| `-- unit` | `RESULT 190 passed, 0 failed, 0 skipped`, exit 0 (also without any GLB) |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| Mutation: the shader map's script without the material override | `test_scene_collision_and_materials` FAIL (only that test) |

New: `tests/integration/facade_map_case.gd` (10 shared tests: the GLB's hash, the cells map's data and shared occluders, spawn with the car and two NPCs, scene setup, 827 colliders and the map's materials, facade detail at most 50 % (light) or 15 % (shader) of the cells map's triangles with every other mesh's 2,884,007 triangles unchanged, every mesh categorised and cells named, profile ranges on every facade cell, the shared occluders against this map's collision, viewpoints, a switch away and back without node or orphan leaks), `test_istanbul_halic_cells_light.gd`, `test_istanbul_halic_cells_shader.gd` (plus: the window shader on the facade cells with panels and nothing else, the panels' UV2 layout). The first full run found that 3 of the 2,465 shader facade cells have no panel (their buildings have no wall of 2.8 m) and keep the palette material; the test expected all cells and was corrected.

### Devices (Release Perf builds of `83c8f0a`, three runs, medians)

Protocol as for the cells map (D17): cold start per experiment, 30 s warm-up + 60 s per viewpoint, the two NPCs in the far mode, the order rotated per run; the cells map measured in the same session as the variants. Tablet without PSS sampling, battery 31.0–35.0 °C, after two unused warm-up runs, cool-down waits 0–390 s (capped at 420 s, never reached); iPhone thermal Nominal at every probe. Every result has `debug_build: false`, `perf_feature: true`, and the expected `map`. Builds with all five maps: APK 674,568,391 bytes, iOS `.pck` 648,560,428 bytes (with the cells map only: 428 MB / 402 MB). Raw data: `docs/perf/facade/results/`; benchmark frames: `docs/perf/facade/shots/`.

| Criterion | cells_light | cells_shader |
|---|---|---|
| Tab A7 low: average ≥ 29.9 | **PASS** 30.00 / 29.99 / 30.00 | **PASS** 30.00 / 30.00 / 30.00 |
| Tab A7 low: 1 % low ≥ 25.40 / 25.33 / 24.78 (the cells map's last medians − 0.5) | **PASS** 26.06 / 26.08 / 25.16 | **PASS** 26.04 / 25.80 / 24.88 |
| Tab A7 low: long frames ≤ 1 % in every run | **PASS** (at most 0.28 %) | **FAIL**: Galata run 2 79 of 1,801 (4.4 %); the other runs and viewpoints ≤ 0.33 % |
| Tab A7, 150 m / no fog: the same thresholds | **PASS** 30.00 / 30.00 / 29.99, 1 % low 26.27 / 26.13 / 24.87, long frames ≤ 0.22 % | 1 % low **PASS** 25.62 / 25.82 / 24.93; long frames **FAIL**: run 3 Spawn 21 (1.2 %), Galata 69 (3.8 %) |
| iPhone high: average ≥ 59.5, long frames < 1 % | **PASS** 60.00 / 60.00 / 60.00, 0 long frames | **PASS** 60.00 / 60.00 / 60.00, at most 1 of 3,600 |
| iPhone: 10 minutes at Karaköy, thermal ≤ Fair | **PASS** 59.96–60.00 FPS every minute, Nominal at all 14 probes, footprint 1,106 MiB | **PASS** 59.96–60.00 FPS, Nominal at all 14 probes, footprint 840 MiB |
| Memory: at least half of the cells map's increase recovered (tablet +128 MiB PSS, iPhone +280 MiB footprint) | iPhone **PASS** (1,096–1,106 MiB, −174 to −184); tablet **FAIL** (622 MiB, −10) | iPhone **PASS** (851–858 MiB, −422 to −429, below İstanbul's 987–1,000); tablet **FAIL** (614 MiB, −18) |

| Tab A7 low, viewpoint | cells: 1 % low [runs] | light: 1 % low [runs] | shader: 1 % low [runs] | Primitives (k) cells / light / shader | Physics ms cells / light / shader |
|---|---|---|---|---|---|
| Spawn | 26.02 [25.59 / 26.11 / 26.02] | 26.06 [26.06 / 26.01 / 26.30] | 26.04 [26.04 / 26.17 / 26.02] | 48.6 / 48.6 / 48.6 | 4.464 / 4.490 / 4.615 |
| Karaköy | 26.10 [25.86 / 26.10 / 26.37] | 26.08 [26.08 / 26.08 / 26.32] | 25.80 [25.80 / 25.07 / 26.05] | 56.6 / 53.6 / 50.5 | 4.396 / 4.457 / 4.345 |
| Galata | 25.45 [25.43 / 25.45 / 25.51] | 25.16 [25.16 / 25.20 / 25.16] | 24.88 [25.17 / 22.96 / 24.88] | 32.7 / 26.3 / 21.0 | 5.073 / 5.346 / 5.258 |

Draw calls are the same on the three maps (83 / 76 / 39 on the tablet, 261 / 167 / 90 on the iPhone). The 150 m / no-fog experiment: light 26.27 [26.18 / 26.45 / 26.27] / 26.13 [26.34 / 25.75 / 26.13] / 24.87 [25.11 / 24.67 / 24.87], shader 25.62 [25.62 / 26.51 / 24.02] / 25.82 [26.58 / 25.82 / 25.40] / 24.93 [24.93 / 24.98 / 22.59]; 97 / 86 / 43 draw calls; primitives light 65.0 / 63.3 / 29.9 k, shader 61.5 / 54.9 / 22.1 k.

| iPhone high, viewpoint | İstanbul | cells | light | shader | Primitives (k) İstanbul / cells / light / shader |
|---|---|---|---|---|---|
| Spawn: 1 % low | 57.85 | 57.96 | 57.89 | 57.96 | 207.0 / 201.9 / 191.9 / 182.4 |
| Karaköy | 56.97 | 57.02 | 57.04 | 57.01 | 262.1 / 171.4 / 138.7 / 111.9 |
| Galata | 55.96 | 56.05 | 56.08 | 56.09 | 322.7 / 115.8 / 85.9 / 58.7 |

| Startup and memory | İstanbul | cells | light | shader |
|---|---|---|---|---|
| Tab A7 map ready (median of three; İstanbul one launch) | 6,588 ms | 7,960 ms | 7,029 ms | 6,066 ms |
| Tab A7 peak PSS (one launch each with sampling) | 517,776 kB (506 MiB) | 647,487 kB (632 MiB) | 637,163 kB (622 MiB) | 628,980 kB (614 MiB) |
| Tab A7 video memory reported by the engine | 482 MiB | 477 MiB | 350 MiB | 262 MiB |
| iPhone map ready (median of three) | 1,390 ms | 1,612 ms | 1,365 ms | 1,187 ms |
| iPhone peak footprint (three runs) | 987–1,000 MiB | 1,280 MiB | 1,096–1,106 MiB | 851–858 MiB |
| iPhone video memory reported by the engine | 661 MiB | 845 MiB | 673 MiB | 438 MiB |

- **Why the tablet's PSS hardly moves:** the lighter geometry shows in the engine's video memory (477 → 350 → 262 MiB) and on the iPhone, whose footprint includes it, but the tablet's PSS does not include the GPU driver's memory on this device; the 128 MiB the cells map added to the PSS came with the 3,074 extra meshes, and the variants keep all 6,129 meshes.
- **Shader on the tablet:** the medians meet the thresholds, but Galata (walls filling the screen) has the lowest 1 % low of the three maps and each shader set had one run with a long-frame window; the extra fragment work of the window shader is the likely cause (not separated). Runs with long-frame windows also occurred on other maps in earlier tasks.

### Device scenarios on the shader map (debug builds of `83c8f0a`, all five maps)

| Scenario | Galaxy Tab A7 | iPhone 13 Pro |
|---|---|---|
| `vehicle_sleep` (13 steps) | **PASS** 13 / 13 (`docs/perf/facade/scenarios/tablet/`) | **PASS** 13 / 13 |
| `extensibility` (25 steps) | **FAIL**: the app was killed by Android's low-memory killer (lmkd, "min2x watermark is breached and swap is low") during a switch between two large maps: first run right after MAP loaded İstanbul from the shader map (peak PSS 821 MiB); the retry passed every test-district step (`map_switch`, the van, the NPC punch) and was killed on the way back while MAP loaded `istanbul_halic_cells_light` after `istanbul_halic_cells` (peak PSS 978 MiB; `lmkd_kills.txt`) | **PASS** 25 / 25 on the retry (`map_back`: node count 8,547 = 8,547). The first attempt produced no results in 1,270 s (the app stayed on the shader map at 778 MiB; an iOS "iCloud data isn't syncing" alert was on screen during the retry; cause not established) |

- **Finding:** a map switch loads the new map while the old one is only queued for freeing, so for a moment both are in memory; with five maps the MAP button (and the extensibility scenario's way back, which taps through the registry) passes through several large maps, and the 3 GB tablet runs out of memory. Phase 5's scenario only switched between İstanbul and the test district. This concerns debug and Release Perf builds (normal release builds load one map). Not changed in this task (game behaviour fixed by D24); see "Recommended next task".

## Cell grouping and the cells map (2026-11-01)

Task of 2026-11-01 (user): split İstanbul's facade detail and trees into small cells in the generator, add the result as a separate map, and measure it on the devices; the current map, `assets/istanbul_halic.glb`, the quality profile values, and the game's behaviour do not change. Decisions: `PROJECT_CONTEXT.md`, D23 and T40. Guide: `docs/maps/istanbul_halic/README.md`, "Cell grouping" and "The cells map". Evidence: `docs/perf/cells/`.

### What exists now

- **Input cleaning** (`faed04b`): the Wi-Fi password of OSM node 4924038719 (`internet_access:password` and the same password as its `description`) is removed from the OSM extract; no other `*:password` tag existed. The run on the cleaned input wrote the same nine files byte for byte (GLB `68237c46…`, 156.8 s). The tags are still in the history of `3d4bb1a`.
- **Generator option** (`449dd32`): `build_map.py --detail-cell METRES` and `compare_outputs.py --grouped`.
- **The cells map** (`3e00ada`): `maps/istanbul_halic_cells/` (scene, `MapDefinition`, its own baked occluders), third in `game/world/maps.tres`; `assets/istanbul_halic_cells.glb` (40 m cells, `7973071a…`, 505,589,800 bytes) is generated and ignored by Git, its `.import` committed with the shipped GLB's settings. `MapDefinition.required_files` / `is_available()`; the MAP button skips unavailable maps, `--map` falls back. `tools/bake_occluders.gd --out=`. Experiments `profile_default_cells`, `profile_default_cells_pss`, `c_cells_low_vis150_nofog`.
- `tools/maps/istanbul_halic/blank_facades.py` (the documentation commit after `3e00ada`): estimates the share of nearby buildings whose facade detail a visibility range hides.

### Extensibility finding (code changes for the new map)

| Where | Change | Why |
|---|---|---|
| `MapDefinition` | new exported `required_files`, `is_available()`, static `is_loadable()` (an imported file counts once the import result named in its `.import` exists) | the cells map's GLB is generated on each machine (D23); in a checkout without it the committed `.import` exists but nothing can be loaded |
| `MapRegistry.next_after()` | skips unavailable maps | the MAP button would otherwise load a missing scene |
| `Main._initial_map()` | an unavailable map from `--map` or an experiment falls back to the first map with a warning | as for an unknown id |
| `RenderSettings` | comment only | the cells are a new kind of mesh node, handled by the existing prefixes |

The scene and the `MapDefinition` are data (T5); `WorldManager`, the player, vehicle, NPC, camera, input, profile, and benchmark code are unchanged. The device scenario's `_switch_map()` already tapped MAP until the wanted map was loaded, so it now passes the cells map on its way back to İstanbul; the headless `test_device_scenario_extensibility` did that and passed.

### Proof that only the grouping changed

| Check (pinned environment) | Result |
|---|---|
| Without `--detail-cell` | all nine files byte-identical with the pinned run (GLB `68237c46…`) |
| `--detail-cell 40` vs the run without it (`compare_outputs.py --grouped`) | PASS: header and 2,529 of 2,529 other meshes byte-identical, 827 `-col` meshes; `Detail` 245 chunk meshes → 2,465 cells, `Trees` 184 → 870, `Shrubs` 97 → 265; every chunk's cells hold exactly its triangles (245/245, 184/184, 97/97); triangles 4,187,598 / 1,045,530 / 80,568, vertices and area equal; 6,129 mesh nodes; JSON records byte-identical except `statistics.json` and `map_metadata.json` (`mesh_nodes`, `detail_cell_m`) |
| `--detail-cell 75` | PASS the same way: 824 / 400 / 172 cells, 3,925 mesh nodes |
| Negative check: 40 m against the shipped GLB | FAIL as it must (504 other meshes differ; `Detail_08_07`'s float noise caught by the triangle comparison: 244 of 245 chunks) |
| Determinism | two 40 m runs byte-identical (all nine files); 157.9 s alone, peak resident 3.6 GiB, peak footprint 4.8 GiB |
| Godot import (throwaway projects, the shipped GLB's import settings) | 827 `StaticBody3D`, 438,012 collision triangles, 7,071,605 render triangles in all three; `MeshInstance3D` 3,055 / 3,925 / 6,129 |

### Choosing the cell size (Mac, before the device runs)

Desktop: the game's benchmark (`docs/perf/cells/desktop/`), debug build on the Mac (Metal, Forward Mobile, 1280×800), 4 s warm-up and 6 s per viewpoint, one run each; the blank-facade estimate from `blank_facades.py` over 3,000 street points.

| | 150 m chunks (pinned run) | 75 m cells | 40 m cells |
|---|---|---|---|
| Mesh nodes | 3,055 | 3,925 | 6,129 |
| GLB / imported `.scn` | 502,651,324 / 195,394,864 B | 503,488,068 / 199,986,165 B | 505,589,800 / 201,392,178 B |
| Import (throwaway project) | 10.8 s | 10.0 s | 11.6 s |
| Low: draw calls Spawn / Karaköy / Galata | 111 / 102 / 66 | 112 / 103 / 69 | 112 / 106 / 70 |
| Low: primitives (k) | 50.3 / 56.1 / 48.7 | 50.7 / 58.8 / 46.9 | 50.7 / 57.9 / 35.2 |
| High: draw calls | 228 / 154 / 101 | 236 / 163 / 105 | 240 / 174 / 111 |
| High: primitives (k) | 177.5 / 251.6 / 322.9 | 193.4 / 185.1 / 150.2 | 172.4 / 150.6 / 101.0 |
| Video / static memory, low (MiB) | 532 / 192 | 546 / 210 | 717 / 256 |
| Buildings within 50 m with blank facades (range 100 m) | 12.1 % | 0.0 % | 0.0 % |
| Within 100 m (range 100 m) | 34.6 % | 18.0 % | 8.7 % |
| Within 200 m (range 200 m, high) | 16.7 % | 8.8 % | 4.3 % |

**Chosen: 40 m** (T40). At the three viewpoints both cell sizes show the facades that the chunks blank (`docs/perf/cells/desktop/desktop_low_plain_75m_40m.jpg`); over the street sample 40 m halves the buildings blanked within 100 m against 75 m and draws the fewest primitives on the high profile, for 1–4 (low) and 10–20 (high) more draw calls than the chunks and clearly more memory (+185 MiB video, +64 MiB static on the Mac; 75 m +14 / +18). The device runs below were made with 40 m only.

### Occluders

`tools/bake_occluders.gd` on the cells map: 643 occluders, 317,518 triangles, 206,048 shared vertices (the same counts as İstanbul's file). Against İstanbul's committed bake (`docs/perf/cells/generator/occluders_cells_vs_istanbul.txt`): 640 occluders identical; `Ground_04_07` and `Ground_15_17` differ by ≤ 7.6 µm; `Ataturk_Bridge` by up to 3.5 m: the regenerated bridge's seven piers stand elsewhere than in the shipped GLB (the "Reproduction" table in "Map generator in the repository" was corrected). So the cells map got its own bake (`maps/istanbul_halic_cells/istanbul_halic_cells_occluders.scn`, 2,300,915 bytes; a second bake to another path had identical occluders). `test_baked_occluders_match_this_maps_collision` checks it against the runtime build from the map's collision.

### Tests

| Run (2026-11-01) | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| `run_tests.gd`, both GLBs present | `RESULT 246 passed, 0 failed, 0 skipped`, exit 0 (509 s; again on the final tree with the documentation: 246 passed, exit 0, 510 s) |
| without the cells GLB and its import result | `RESULT 237 passed, 0 failed, 9 skipped`, exit 2; the MAP button test visits only İstanbul and the test district |
| without both GLBs | `RESULT 203 passed, 0 failed, 43 skipped`, exit 2 |
| `-- unit` | `RESULT 190 passed, 0 failed, 0 skipped`, exit 0 (also without both GLBs) |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| Mutations (rule broken, unit suite, restored) | MAP not skipping unavailable maps → `test_maps_with_missing_generated_files_are_skipped` FAIL; `source/.gdignore` moved away → `test_generator_data_folders_carry_a_gdignore` FAIL |

New tests: `test_istanbul_halic_cells.gd` (9: the GLB's hash, the same map data as İstanbul, spawn on the bridge with the car and two NPCs, scene setup and 827 colliders, every mesh in a render category and every cell named `<Category>_<cx>_<cy>_<i>_<j>`, the profiles' ranges on every cell, occluders against the map's collision, viewpoints on the ground, a switch away and back with the node count equal and no orphan nodes), in `test_map_registry.gd` (3: unavailable maps skipped and `--map` falling back, an imported file loadable only with its import result, the registry order and the ignored GLB), `test_map_data_folders.gd` (2: the `.gdignore` files and no `.import` files in the generator data folders). Changed: `test_debug_map_button_loads_the_next_map` walks through every available map.

### Devices (Release Perf builds of `3e00ada` with both GLBs, three runs, medians)

Protocol of Phase 5 (D17): cold start per experiment, 30 s warm-up + 60 s per viewpoint, the two İstanbul NPCs walking in the far mode; both maps in the same session, order alternated per run (tablet: İstanbul / cells / extra experiment, then cells / extra / İstanbul, then extra / İstanbul / cells; iPhone: İstanbul / cells, cells / İstanbul, İstanbul / cells). Tablet without PSS sampling, battery 28.5–34.0 °C (the first experiments hit the 900 s cool-down timeout at 30 °C, see "Incidents"); iPhone thermal Nominal at every probe. Every result has `debug_build: false`, `perf_feature: true`, and the expected `map`. The APK is 428,147,021 bytes and the iOS `.pck` 402,138,992 bytes with both maps (224 MB / 198 MB before). Raw data: `docs/perf/cells/results/`.

| Criterion | Result | Evidence |
|---|---|---|
| Tab A7, low, cells map: average ≥ 29.9 at the three viewpoints | **PASS** | 30.00 / 29.99 / 29.99 |
| Tab A7: 1 % low at most 1 FPS below İstanbul's Phase 5 medians (25.55 / 26.17 / 25.07) | **PASS** | 25.90 / 25.83 / 25.28 (same session İstanbul: 26.09 / 25.88 / 25.30) |
| iPhone, high, cells map: average ≥ 59.5, long frames < 1 % | **PASS** | 60.00 / 60.00 / 60.00; long frames at most 3 of 3,600 per run and viewpoint (0.08 %) |
| No blank facades within 100 m (screenshots of both maps from the same points) | **PASS at the three viewpoints** | `docs/perf/cells/shots/tablet_low_istanbul_vs_cells.jpg`: the Galata and Karaköy facades that İstanbul blanks on low have their windows on the cells map; over the 3,000 street points of the estimate no building within 50 m is blanked, but 8.7 % within 100 m still are (their cell's centre is beyond 100 m) |

| Device, viewpoint | İstanbul: avg / 1 % low [runs] | Cells: avg / 1 % low [runs] | Draw calls | Primitives (k) | Physics ms |
|---|---|---|---|---|---|
| Tab A7, Spawn | 30.00 / 26.09 [23.59 / 26.09 / 26.57] | 30.00 / 25.90 [25.90 / 26.13 / 24.63] | 82 → 83 | 48.2 → 48.6 | 4.262 → 4.461 |
| Tab A7, Karaköy | 30.00 / 25.88 [23.62 / 26.39 / 25.88] | 29.99 / 25.83 [25.83 / 26.35 / 25.53] | 72 → 76 | 54.8 → 56.6 | 4.453 → 4.664 |
| Tab A7, Galata | 30.00 / 25.30 [22.67 / 25.37 / 25.30] | 29.99 / 25.28 [25.28 / 25.31 / 23.47] | 35 → 39 | 46.2 → 32.7 | 5.277 → 5.116 |
| iPhone, Spawn | 60.00 / 57.87 [57.87 / 57.97 / 54.99] | 60.00 / 57.98 [57.98 / 57.45 / 58.07] | 248 → 261 | 207.0 → 201.9 | 1.218 → 1.035 |
| iPhone, Karaköy | 60.00 / 57.04 [56.99 / 57.04 / 57.05] | 60.00 / 57.08 [56.55 / 57.08 / 57.09] | 141 → 167 | 262.1 → 171.4 | 1.225 → 1.249 |
| iPhone, Galata | 60.00 / 55.90 [55.84 / 55.90 / 55.93] | 60.00 / 56.19 [56.03 / 56.24 / 56.19] | 72 → 90 | 322.7 → 115.8 | 1.391 → 1.374 |

| Startup and memory | İstanbul | Cells |
|---|---|---|
| Tab A7, map ready (median of three launches) | 6,631 ms [6,687 / 6,631 / 6,604] | 7,843 ms [8,449 / 7,700 / 7,843] |
| Tab A7, peak PSS (one launch each with sampling, `pss/`) | 512,901 kB (501 MiB) | 644,120 kB (629 MiB) |
| iPhone, map ready | 1,366 ms [1,609 / 1,361 / 1,366] | 1,611 ms [1,626 / 1,611 / 1,594] |
| iPhone, peak physical footprint (Instruments probes, three runs) | 999–1,003 MiB | 1,280 MiB in all three |
| Video memory reported by the engine (tablet / iPhone) | 482 / 661 MiB | 477 / 845 MiB |

- The tablet's 1 % low windows vary between runs as in Phase 5: one run per experiment had a window with 40–130 long frames (İstanbul in run 1, the extra experiment in run 2, the cells map at Galata in run 3); the medians are not affected by a single such run.
- On Metal (the Mac and the iPhone) every extra mesh costs video memory (+184 MiB for the 3,074 extra meshes); on the tablet's Vulkan driver the reported video memory did not grow, and its PSS grew by 128 MiB.

### Extra experiment: the tablet's low profile with 150 m ranges and no fog (cells map, no profile change)

`c_cells_low_vis150_nofog`: the low profile with `visibility_end` 150 m for trees, lamps, decor, and facade detail and `fog: false` (the 400 m far plane stays); an experiment key only, the profile values are unchanged.

| Tab A7, viewpoint | Cells, low (100 m, fog): 1 % low [runs] | 150 m, no fog: avg / 1 % low [runs] | Draw calls | Primitives (k) | Long frames per run |
|---|---|---|---|---|---|
| Spawn | 25.90 [25.90 / 26.13 / 24.63] | 30.00 / 26.09 [26.09 / 23.54 / 26.34] | 83 → 97 | 48.6 → 68.8 | 3 / 43 / 2 |
| Karaköy | 25.83 [25.83 / 26.35 / 25.53] | 30.00 / 26.27 [26.66 / 23.79 / 26.27] | 76 → 86 | 56.6 → 73.4 | 0 / 21 / 4 |
| Galata | 25.28 [25.28 / 25.31 / 23.47] | 30.00 / 25.03 [25.36 / 22.41 / 25.03] | 39 → 43 | 32.7 → 38.2 | 1 / 130 / 3 |

The medians stay at the level of the low profile (and above the Phase 5 criterion) with 17–42 % more primitives, and the far facades, lamps, and trees up to 150 m are drawn (`docs/perf/cells/shots/tablet_low_cells_vs_vis150_nofog.jpg`); run 2 had long-frame windows at all three viewpoints (1 % low 22.4–23.8). Map ready 8,008 ms. Whether the low profile can be relaxed this way needs more runs and a longer session; a proposal, not applied.

### Incidents and findings on the way

- **Lamps keep the chunk granularity:** `StreetLamps_*` and `LampGlow_*` (and the decor category) are still one mesh per 150 m chunk, so on the low profile the lamp post beside the spawn is not drawn on either map (visible in the 150 m experiment's shot). Not in this task's scope.
- **Tree trunks stay in chunks** (they are collision meshes, T40): no trunkless crown was seen in the benchmark screenshots, but it can happen on the low profile.
- **The Atatürk bridge piers** of the regenerated GLB stand 2.7–3.5 m from the shipped ones (found by the occluder comparison; the earlier "rotated vertex order" in "Reproduction" was wrong and is corrected).
- **Tablet batch restarted:** the first batch started on an idle tablet at 24.0 °C, so its cool-down target (24.5 °C) was out of reach while the tablet sat at about 30 °C on the charger; it was stopped after one and a half experiments (results kept outside the repository, not used) and restarted at 28.5 °C. The tablet had been locked with a PIN before the batch; the user unlocked it.
- **adb restarts from another project:** during the batches another Godot project on this Mac (not this repository) ran headless Godot processes whose exits restarted the adb server repeatedly (the documented editor behaviour); the scripts tolerated it (every experiment has its results).
- Godot 4.7.2 writes `gltf/naming_version=2` and `gltf/texture_map_mode=1` for a newly imported GLB; the cells GLB's `.import` was set to the shipped GLB's values (1 and 0) before committing.

## Map generator in the repository (2026-11-01)

Task of 2026-11-01 (user): bring the İstanbul • Haliç generation pipeline into the repository and show that it reproduces the map; the map, `assets/istanbul_halic.glb`, the game code, the profiles, and the measurement baselines do not change, and a regenerated GLB does not replace the shipped one; Safranbolu is deferred. Decisions: `PROJECT_CONTEXT.md`, D22 and T39. Guide: `docs/maps/istanbul_halic/README.md`, "Regenerating the map".

### What exists now

- `tools/maps/istanbul_halic/`: `build_map.py` with `terrain.py`, `architecture.py`, `bridge.py`, `vegetation.py`, `street_details.py`; `render_map.py`; first committed byte-identical to the package (`3d4bb1a`), then changed only in their paths (`87dee5e`: `--source`, `--out`, 36 lines added and 22 removed in five files). `compare_outputs.py` (`94c6e21`). `requirements.txt` (numpy 2.5.4, shapely 2.1.2 / GEOS 3.13.1, mapbox_earcut 2.1.0, pillow 13.0.0) and `.python-version` (3.12).
- `maps/istanbul_halic/source/` (inputs, 20.1 MB) and `maps/istanbul_halic/reference/` (the shipped records, 3.0 MB), each with a `.gdignore`: after adding them, `godot --headless --path . --import` exits 0 with no new imported files. Added to the repository in total: 23.1 MB (scripts 84 KB).
- Output: `build/maps/istanbul_halic/` (ignored): `istanbul_halic.glb`, `map_metadata.json`, and seven JSON records.

### Reading before the first run

- The package `Istanbul_Halic_Godot_Paketi.zip` (SHA-256 `726fb7ee…5e46a2c`, the same before and after the task) was extracted outside the repository; all 55 files matched its `manifest.sha256`.
- All seven Python files were read in full before anything ran. They import only the standard library, numpy, shapely, mapbox_earcut, and Pillow (`render_map.py`: `bpy`, `mathutils`, and `os` for the `RENDER_ONLY` variable). There is no network access, no subprocess or shell call, no `eval`/`exec`, and no file deletion; the "http" strings in `architecture.py` (15) and `bridge.py` (1) are reference URLs in data. `render_map.py` deletes the objects of the open Blender scene before importing the GLB (in memory, not files).
- What the original scripts wrote: the GLB and `map_metadata.json` into the package's `Godot/assets/`, and `mosques.json`, `buildings.json`, `statistics.json`, `spawn.json`, `bridge_metadata.json`, `vegetation.json`, `street_details.json` into its `source/`, over the shipped copies; `render_map.py` overwrote `previews/` and the `.blend`. `street_details.py` reads the `vegetation.json` written earlier in the same run. Read as input: the OSM extract, `elevation/`, `building_height_overrides.json`. Not read: `osm_v4_metadata.json`, the validation records, and `validate_scene.gd` (identical to `tests/map/validate_scene.gd`).
- The OSM XML has no DOCTYPE or entity declarations. It contained a café's Wi-Fi password as public OSM tags (`internet_access:password`, repeated in the same node's `description`); both tags were removed from the input on 2026-11-01 by user decision, and the generator's output stayed byte-identical (all nine files, GLB `68237c46…`; 156.8 s).

### Reproduction (Mac, Apple Silicon, Python 3.12.15, pinned requirements)

| | Shipped (`reference/`, `assets/`) | Run 1 (default `--out`) | Run 2 (`--out build/maps/istanbul_halic_run2`) |
|---|---|---|---|
| GLB SHA-256 | `8b00c94b…f21611b1` | `68237c46…4dd819a` | `68237c46…4dd819a` |
| GLB bytes | 502,541,456 | 502,651,324 | 502,651,324 |
| Triangles / vertices | 7,070,457 / 14,810,669 | 7,071,605 / 14,814,113 (+1,148 / +3,444) | same as run 1 |
| Mesh nodes / `-col` nodes | 3,055 / 827 | 3,055 / 827 | same |
| Lamps, trees, shrubs | 4,008, 5,477, 1,119 | 4,008, 5,477, 1,119 | same |
| Buildings (estimated heights), mosques, crosswalks, signal heads | 9,001 (8,648), 125, 160, 223 | the same | same |
| Time / peak resident / peak footprint | — | 156.7 s / 3.61 GB / 5.07 GB | 157.5 s / 3.83 GB / 5.09 GB |

- **Mesh names:** the same 3,055 names except one (`SignalGlow_green_14_17` instead of `SignalGlow_red_14_17`); the order differs only at three positions in chunk 14_17.
- **Records:** `buildings.json`, `spawn.json`, `mosques.json`, `bridge_metadata.json`, `vegetation.json` are byte-identical with the shipped ones (and with the package manifest); `statistics.json` differs only in `triangles` and `vertices`; in `street_details.json` the lights and crossings are identical and 6 of the 223 signal heads stand elsewhere (112 list entries differ because the rest shift); `map_metadata.json` differs only in its `stats` (walk spawn, bounds, mosques, metro bridge, and lights identical).
- **Where the GLB differs** (`compare_outputs.py`):

| Meshes | Difference |
|---|---|
| 2,550 of 3,055 | byte-identical |
| `Road_*` (236), `Pavement_*` (234), `Quays_*` (3) | re-triangulated by GEOS: Road +568 triangles, area +0.02 %; Pavement +579, +0.02 %; Quays +1, same area. Delaunay triangles of each road buffer are kept when their centre lies inside it, so a different triangulation keeps a slightly different area |
| `TrafficSignals_*` (4), `SignalGlow_*` (5 and the renamed one), `RoadPaint_*` (10) | the 6 signal heads and their stop lines (`STRtree.nearest` picks another of two equidistant roads at a junction); RoadPaint same triangles, −0.1 % area |
| `Ataturk_Bridge-col` | same triangle count and area; the deck is the same, but its seven piers stand 2.7–3.5 m along the deck from where the shipped GLB has them (56 of 82 distinct vertices; found by the occluder comparison on 2026-11-01, "Cell grouping and the cells map"; first recorded here as a rotated vertex order) |
| `Ground_04_07-col`, `Ground_15_17-col`, `Detail_08_07`, 2 `Gardens_*`, 6 `MosqueDetail_*` | float noise: positions ≤ 7.6 × 10⁻⁶ m, normals ≤ 10⁻⁶ |

- **Which shapely:** same machine and numpy, three versions (2.2.0 with the original, unmodified scripts in a copy of the package layout; the others with the parametrized scripts):

| shapely (GEOS) | Byte-identical meshes | Triangles | `buildings.json` |
|---|---|---|---|
| 2.0.7 (3.11.4) | 2,032 | 7,060,212 | differs (footprint simplification) |
| **2.1.2 (3.13.1), pinned** | **2,550** | **7,071,605** | identical |
| 2.2.0 (3.14.1) | 2,503 | 7,071,558 | identical |

  All three place the same 6 signal heads differently from the shipped GLB, so the rest of the difference lies outside these wheels (the package's machine, GEOS build, and CPU are unknown; not investigated further).
- **Deterministic:** run 1, run 2, and a third run with the same versions made while another generator run was going produced byte-identical files (GLB and all eight JSON files); `compare_outputs.py` run 2 against run 1: 3,055 of 3,055 meshes identical, exit 0.
- **The path change is output-neutral:** with shapely 2.2.0, the parametrized scripts and the original, unmodified scripts (in a copy of the package layout) produced the same GLB (`a70a7dbf…`) and byte-identical JSON files, all nine.
- **Never writes into the repository:** the 27 files of `source/`, `reference/`, `assets/istanbul_halic.glb`, and `assets/map_metadata.json` had the same SHA-256 before and after the two runs; `git status --short --ignored` after the runs showed only `build/maps/` as new (ignored) and no `__pycache__/` (runs with `-B`). `--out` inside `--source` stops with exit code 2.
- **Godot import** (two throwaway projects outside the repository, Godot 4.7.2, the repository's `assets/istanbul_halic.glb.import` settings; the repository project was never run with the regenerated GLB):

| | Shipped | Regenerated |
|---|---|---|
| `--import` | exit 0, no errors | exit 0, no errors |
| `StaticBody3D` / `CollisionShape3D` / `MeshInstance3D` | 827 / 827 / 3,055 | 827 / 827 / 3,055 |
| Concave collision triangles | 438,012 | 438,012 |
| Render triangles | 7,070,457 | 7,071,605 |
| Imported `.scn` | 195,299,372 bytes | 195,394,864 bytes |

- **`render_map.py`** was not run (no Blender run in this task). With a stub `bpy` its paths are `build/maps/istanbul_halic/istanbul_halic.glb` in, `…/previews/*.png` and `…/Istanbul_Halic.blend` out by default, and the given folder with `-- --out DIR`.

### Normals in the shipped GLB (open since Phase 0)

All 3,055 primitives carry `NORMAL` and `COLOR_0` (`build_map.py` writes one normal per face from its first three points). Checked over every triangle: normals are unit length and identical on a triangle's three vertices (flat shading); 7,064,835 triangles agree with their counter-clockwise winding, 113 disagree (fans over non-planar or concave facade polygons: 66 `Detail_*`, 16 `MosqueDetail_*`, the rest in roads, pavements, gardens, paint), and 5,509 have zero area. The vertex palette material is single-sided.

### Safranbolu

Deferred (`PROJECT_CONTEXT.md`, "Deferred map candidate: Safranbolu"). The eight screenshots of its audit, kept outside the repository, were deleted; the user's own Safranbolu downloads were not touched.

## Phase 5 — extensibility: second map, second vehicle type, NPCs (2026-10-28)

User decisions in the task: a small test map from Godot primitives; NPCs that patrol 2–3 points and play a short hit reaction (no damage, health, death, attack, or pursuit); the test van moved into the game; 2 NPCs on İstanbul, 3 on the test map; a device item counts only with a log, a results file, or a screenshot. Decisions and rationale: `PROJECT_CONTEXT.md`, T34–T38. Code and guides: `docs/ARCHITECTURE.md`, "Maps and the map registry (Phase 5)" and "NPCs (Phase 5)".

### What exists now

- **Map registry and switch:** `game/world/maps.tres` lists İstanbul • Haliç (default; the only map normal release builds load) and the test district. Debug and Release Perf builds start on another map with an experiment's `"map"` key or `--map=<id>`; the debug MAP button loads the next map. `switch_map()` frees the old map with its vehicles, NPCs, and the training dummy, puts the player at the new spawn, and re-applies the profile (refused while driving). After İstanbul → test district → İstanbul the node count equals the count before (headless on both maps; 5,473 on both devices, see the scenario).
- **Test district** (`maps/test_district/`, generated by `tools/build_test_district.gd`): a 124 m ground slab, two crossing streets, seven box buildings, a 9.5° ramp up to a 2 m plaza, 3 m walls, İstanbul's sky and sun; 14 box/convex colliders; 7 box occluders (84 triangles); spawn (0, 0, 50) facing north, bounds ±59.5 m, kill height −10 m, the compact car and the van side by side, three NPC routes, two viewpoints. The quality profiles apply (fog, shadows, occlusion with its own occluders).
- **Second vehicle type in the game:** the van (`game/vehicle/placeholder_van.tscn`, `definitions/van.tres`), parked on the test district through `MapDefinition.vehicle_scenes`. Getting in and out, sleeping, the reset below the kill height, the camera profile, and driving work without code changes; the debug CAR button walks up to each vehicle in turn.
- **NPCs:** `game/npc/npc.tscn` inherits the player scene (controller, states, placeholder visual in teal) with an `AiPatrolInput` (half walking speed, waits at each point, gives a point up after 2 s without progress), a `Hurtbox`, and the new `HitReactionState` (0.5 s stagger, pushed 2 m/s away from the attacker, restarts on a second hit). Two NPCs walk the Galata Bridge deck 12 m and 25 m east of the spawn's walking line; three walk the test district (around the plaza, up and down the ramp, along a street). `WorldManager` respawns them at their own start below the kill height and keeps them in the bounds. Player and NPCs block each other (physics layer 5).
- **Far mode:** an NPC more than 10 m from the player (back within 8 m) is moved along its route by a Tween instead of the controller; see "Performance".

### Extensibility finding (changes to the core systems)

| Core system | Change | Why |
|---|---|---|
| PlayerController | none (code) | NPCs use it unchanged (`Npc` only sets its input source and starts the reaction). Data: `player.tscn`'s collision mask 9 → 25 (adds layer 5), so the player cannot walk through NPCs. |
| Player states | none changed; `HitReactionState` added as a new state | The state machine takes new states as child nodes (T3); the NPC scene adds it. |
| VehicleController | none | The van is a scene plus a definition (T24). |
| VehicleInteraction | none | A map switch is refused while driving, so no forced exit was needed. |
| WorldManager | (1) `spawn_vehicles()` takes the vehicle type per spawn from `MapDefinition.vehicle_scenes` (2 lines); (2) `spawn_npcs()`, the `npcs` list, and freeing them with the map (additive); (3) `track(body, spawn)` stores a respawn point per body and `respawn()` uses it | (1) a map could park only `Main.vehicle_scene`; (2) NPCs are placed and freed with the map like vehicles; (3) every tracked body respawned at the player's spawn, the task wants NPCs at their own start. Existing behaviour unchanged (all earlier tests pass). |
| ThirdPersonCamera | none | Switching maps calls `snap_behind_target()`, which existed. |
| MobileInputController | none (code) | Data: the MAP button is a new entry in `hud.tscn`'s `extra_controls`. |
| RenderSettings | none | A switch calls the existing `apply({})` to restore the scene defaults before the new map's `RenderSettings` captures them. |

Other files changed outside the listed core: `game.gd` (composition root: registry, `switch_map()`, NPC wiring, CAR cycling, runtime keys, STARTUP fields), `MapDefinition` (new fields `id`, `vehicle_scenes`, `npc_routes`), `UIController` (MAP signal, map name in the overlay and `PERF`), `PlaceholderCharacterVisual` (the `&"hit"` action), `PerfConfig` / `PerfBenchmark` / `DeviceScenario` (debug and measurement tools), `project.godot` (layer 5 name).

Findings beyond the code: (a) GodotPhysics3D moves a character body that is already in the space to a newly set transform only during the next physics step, so a body spawned at the origin and then teleported pushes what stands at the origin for that one step (a unit test caught an NPC landing on the player's head and riding along); NPCs therefore get their transform before entering the tree. (b) A character under the controller is expensive on the tablet, mostly script time (see "Performance"), so NPCs need a level of detail. (c) Headless on the Mac an NPC under the controller costs about the same on the test district's boxes as on İstanbul's trimesh bridge (0.29 vs 0.32 ms per step; far mode 0.11 vs 0.13 ms; `docs/perf/phase5/headless/`), so the collision shapes are not what makes characters expensive. (An earlier single comparison of 0.12 vs 0.38 ms, made before the far mode with a noisier method, is superseded.)

### Tests and mutation checks

- `run_tests.gd`: 232 passed (185 unit, 47 integration), exit 0; without the GLB 198 passed and 34 skipped (exit 2): the 13 test district tests run without it. New: `test_map_registry.gd` (5), `test_npc.gd` (9), `test_test_district.gd` (13: registry load, primitives and simple colliders, ramp slope 9.46° and walking up it, bounds and kill height, viewpoints, profiles and baked box occluders, a switch round trip with the node count, both vehicle types, CAR cycling, the van's drive / exit / sleep / reset, three NPCs patrolling for 15 s, punching an NPC with the punch button, an NPC's respawn at its own start); in `test_game_on_map.gd`: the switch İstanbul → fixture → İstanbul (node count, occluders, NPCs, the car drivable), the switch refused while driving, MAP İstanbul → test district → İstanbul (node count), the bridge NPCs, `test_device_scenario_extensibility`; in `test_world_manager.gd`: a vehicle type per spawn, NPCs spawned, tracked, respawned at their own start, held in the bounds, freed.
- Mutation checks (rule broken, suite run, code restored): no hit reaction on a hit → 3 tests fail (`test_hit_reaction_then_patrol_resumes`, `test_second_hit_restarts_the_reaction`, `test_player_punch_hits_once_and_the_npc_reacts`); a blocked point never given up → 1 fails (`test_gives_up_a_blocked_point`); NPCs respawned at the player spawn → 1 fails (`test_spawns_tracks_and_frees_npcs`); no far mode → 2 fail. The one-hit-per-punch rule is the Phase 2 `Hitbox` rule with its own mutation-checked tests; for NPCs it is checked in the unit test, the test district test, and the scenario.

### Device scenario "extensibility" (debug builds of `21196a3`)

Both devices, 25 of 25 steps PASS, the same values on both (physics at a fixed 60 Hz). Tablet: logcat 11:08:37–11:09:26 (`docs/perf/phase5/tablet/scenario_extensibility_log.txt`, results file `scenario_extensibility.json`); iPhone: the results file from the device (`docs/perf/phase5/iphone/scenario_extensibility.json`) and `devicectl` screenshots.

| Step | Galaxy Tab A7 | iPhone 13 Pro |
|---|---|---|
| MAP → test district | loaded in 1.5 s | 0.6 s |
| map_switch: player at the spawn, 2 vehicles, 3 NPCs | PASS (0.00 m; 218 nodes, İstanbul 5,473) | PASS (same) |
| van_parked (asleep), van_walk_up (CAR twice), van_get_in (awake, camera on the van) | PASS | PASS |
| van_throttle above 5 m/s | PASS (5.0 m/s) | PASS (5.0 m/s) |
| van_get_out (handbrake first), asleep again | PASS (0.06 m/s; asleep) | PASS |
| npc_patrols (nearest NPC on the player's level) | PASS (Npc3 moved 6.8 m in 3 s) | PASS |
| npc_hit_reaction (stick walk-up, punch button) | PASS (first punch; HitReaction) | PASS |
| npc_one_hit_per_punch | PASS (1 hit) | PASS |
| npc_patrol_resumes | PASS (Npc3 headed for its next point) | PASS |
| MAP → İstanbul | loaded in 6.8 s | 1.8 s |
| map_back: spawn, 1 vehicle, 2 NPCs, node count as before | PASS (5,473 = 5,473) | PASS (5,473 = 5,473) |
| the 13 `vehicle_sleep` steps on İstanbul afterwards | PASS (throttle 5.0 m/s, slope 12.6°) | PASS (same) |

Frames: `docs/perf/phase5/tablet/scenario_110843_van_driving.jpg`, `scenario_110855_npc_after_punch.jpg`, `docs/perf/phase5/iphone/scenario_110844_van.jpg`, `scenario_110849_npc_after_punch.jpg`.

### Performance (Release Perf builds of `21196a3`, three runs, medians)

Protocol of Phase 4b (D17): 30 s warm-up + 60 s per viewpoint for `profile_default` (now with the two İstanbul NPCs walking, in the far mode at every viewpoint: `npcs_near` 0.0), 20 + 40 s for the NPC A/B (`c_npcs_off_*`: NPCs out of the simulation; `c_npcs_far_*`: as in the game; `c_npcs_full_*`: both under the controller, the case of the player near both), order alternated per run; one viewpoint (Spawn) on the test district (`profile_default_test_district`). Tablet without PSS sampling, battery 33.5–35.5 °C; iPhone thermal Nominal at every probe, footprint 979–1,001 MiB on İstanbul, 277 MiB on the test district. Every result `debug_build: false`, `perf_feature: true`. Raw data: `docs/perf/phase5/results/`.

| Criterion | Result | Evidence |
|---|---|---|
| iPhone, high, 3 viewpoints with 2 NPCs: average ≥ 59.5, long frames < 1 % | **PASS** | 60.00 / 60.00 / 60.00 FPS; long frames 0 / 0 / 0 (of 3,600 per run and viewpoint) |
| Tab A7, low, 3 viewpoints with 2 NPCs: average ≥ 29.9 | **PASS** | 30.00 / 30.00 / 30.00 |
| Tab A7: 1 % low at most 1 FPS below the Phase 4b medians | **PASS** | 25.55 / 26.17 / 25.07 against 26.25 / 26.06 / 25.21 (−0.70 / +0.11 / −0.14) |

| Device, viewpoint | Avg FPS | 1 % low [runs] | Physics ms (Phase 4b) | Draw calls |
|---|---|---|---|---|
| iPhone, Spawn | 60.00 | 57.94 [57.94 / 57.83 / 58.02] | 1.145 (0.867) | 248 |
| iPhone, Karaköy | 60.00 | 56.90 [56.90 / 56.37 / 57.07] | 1.312 (1.115) | 141 |
| iPhone, Galata | 60.00 | 56.15 [55.90 / 56.22 / 56.15] | 1.350 (1.219) | 72 |
| Tab A7, Spawn | 30.00 | 25.55 [25.91 / 25.37 / 25.55] | 4.735 (4.035) | 82 |
| Tab A7, Karaköy | 30.00 | 26.17 [26.26 / 26.11 / 26.17] | 4.283 (3.834) | 72 |
| Tab A7, Galata | 30.00 | 25.07 [25.07 / 25.11 / 24.76] | 5.337 (4.798) | 35 |

**Physics cost per NPC** (A/B medians, ms per physics step; per NPC = difference ÷ 2):

| Device, viewpoint | NPCs off | Far mode (as in the game) | All under the controller | Per NPC, far | Per NPC, controller |
|---|---|---|---|---|---|
| Tab A7, Spawn | 4.026 | 4.636 | 6.727 | 0.31 | 1.35 |
| Tab A7, Karaköy | 3.916 | 4.551 | 6.485 | 0.32 | 1.28 |
| Tab A7, Galata | 4.947 | 5.494 | 7.207 | 0.27 | 1.13 |
| iPhone, Spawn | 0.899 | 1.089 | 1.710 | 0.10 | 0.41 |
| iPhone, Karaköy | 1.169 | 1.305 | 1.709 | 0.07 | 0.27 |
| iPhone, Galata | 1.245 | 1.374 | 2.196 | 0.06 | 0.48 |

- 1 % low in the A/B (40 s windows): tablet off 26.13 / 25.95 / 25.15, far 23.78 / 23.95 / 22.56, all under the controller 24.45 / 24.85 / 23.62; iPhone off 58.30 / 57.12 / 56.29, far 57.84 / 56.92 / 56.00, controller 57.00 / 57.15 / 54.45 (no long frames on the iPhone in any of them). The tablet's far-mode windows were good in run 1 (25.70 / 26.04 / 25.09, better than that run's off) and worse in runs 2–3 (20–107 long frames per window), while the standard 60 s `profile_default` runs with the same far NPCs had 1–12 long frames and met the criterion; the difference is not explained (one far-mode segment start, with its floor rays, takes 65–90 µs on the Mac).
- On the Mac (headless, `docs/perf/phase5/headless/`): per NPC 0.32 ms under the controller and 0.13 ms in the far mode on İstanbul, 0.29 and 0.11 ms on the test district.
- **Test district, one viewpoint (Spawn, 3 NPCs in the far mode, both vehicles asleep):** iPhone 60.00 FPS, 1 % low 56.57 [56.40 / 56.74 / 56.57], long frames 0, 96 draw calls, physics 1.232 ms; tablet 30.00 FPS, 1 % low 25.15 [25.13 / 25.20 / 25.15], long frames 3 [3 / 6 / 0], 56 draw calls, physics 5.208 ms. Map ready (median of three launches): tablet 1,318 ms (İstanbul 6,592 ms), iPhone 308 ms (İstanbul 1,353 ms).
- How the far mode came about (single-run probes on the tablet, `docs/perf/phase5/probes/README.md`): with the NPCs always under the controller (`a89274b`) the tablet failed the 1 % low criterion (24.4 / 24.6 / 23.6, physics +2.3–2.9 ms); a far mode that moved the NPCs with script every tick still cost 1.2–1.5 ms per step for the two; the Tween walk (`eb7726f`) brought the probe to +0.04–0.55 ms.

### iPhone two-orientation check (open question 33)

NOT RUN. Asked once as the task requires ("telefonu dik tutup scenario_orientation sırasında bir kez 180° çevirin"); the user answered "Yapamam". Not asked again.

### Incidents and findings on the way

- The first tablet probe sat on the lock screen (PIN; the scripts cannot unlock it) and was stopped; the user unlocked the tablet and the probe was repeated.
- `b7a5c6f` holds only the van's file moves because the `git add` in its command failed on a path that had already been moved and the commit ran anyway; `5aaefe7` completes it. History was not rewritten.
- A unit test found the GodotPhysics3D behaviour of character bodies teleported right after entering the tree (see the extensibility finding).
- `tools/perf/npc_cost.gd` found that switching the far mode off left already-far NPCs in it (`32f7bb5`); the device A/B was not affected (the key is set before any NPC goes far; `npcs_near` 2.0 in those results).

### Specification status (Phases 0–5)

| Phase (specification, `PROJECT_CONTEXT.md`) | Status | Where |
|---|---|---|
| 0 — Project audit and base architecture | Done | Map audit `docs/maps/istanbul_halic/README.md`, D5–D7 in `PROJECT_CONTEXT.md`, `docs/ARCHITECTURE.md` |
| 1 — Mobile character control | Done; on both devices | Joystick, camera, walk and run, collision ("Device results (2026-10-24, debug builds)") |
| 2 — Character actions | Done; on both devices | Punch, roll, buffer, hit areas ("Phase 2 — character actions") |
| 3 — Vehicle system | Done; on both devices | Get in and out, drive, reset, vehicle HUD and camera ("Phase 3 — vehicle system") |
| 4 — Mobile optimization and platform validation | Done for the engineering items | Renderer, profiles, P1/P2, safe areas, export review, platform module ("Phase 4 status" under Phase 4d); open: the map-level facade and collider work (user decision) and the iPhone orientation check |
| 5 — Extensibility | Done | A second map, a second vehicle type, NPCs, all through data and new classes; one core system changed (`WorldManager`, additive); device scenario on both devices; criteria met with the NPCs' far mode |

Remaining outside the phases: the user checks that were NOT RUN (iPhone orientation, the feel of the controls in the user's own words), real models, the map-level work, store preparation (`PROJECT_CONTEXT.md`, "After the specification").

## Phase 4d — export configuration, platform isolation, automatic device checks (2026-10-28)

### Platform module

- `game/platform/platform.gd` (T31) is the only code that reads OS feature tags, the build kind, the window and safe area, the screen refresh rate, and the external folder; `QualityProfiles`, `SafeAreaSource`, `PerfConfig`, `BuildFeatures`, `PerfBenchmark`, and `game.gd` were re-wired to it.
- Tests (`test_platform.gd`, fake platform `tests/fixtures/fake_platform.gd`): the iOS path (quality high, the HUD laid out in the fake iPhone safe area, 120 Hz panel paced at 60 and at 120 with the setting on, no external folder), the Android path (quality low, the safe area, the 90 Hz screen rate uncapped, the Documents folder), the desktop path (quality none, no safe area even if the display server reports one, no folder), the build features, and the real platform on this Mac. Scan `test_only_the_platform_module_asks_the_os`: PASS; mutation (`OS.has_feature("ios")` added to `game.gd`) → FAIL.
- Devices, debug builds of `0456e98`, values against Phase 4c/4b: tablet `SAFE_AREA window=(2000, 1200) safe=[(0, 0), (2000, 1200)] canvas 1500×900`, `QUALITY profile=low` with the same effective settings, `STARTUP` fields (`physics_3d`, setting, profile, vehicles, every `build` field) identical (`docs/perf/phase4d/tablet/plain_launch_log.txt`). iPhone: the app's results file records `startup` with the same platform values as the Phase 4b iPhone runs (quality high, `screen_refresh_rate` 120, `display_refresh_rate` 60, `ios_allow_high_refresh_rate` false, 60 Hz physics, `max_fps` 60), and the applied safe area (108.4, 0) + (1730.2 × 853.8) canvas units = 141 px on both sides and 60 px at the bottom on the device. Only `debug_build` / `perf_feature` differ, because the earlier runs were Release Perf builds. The iPhone's unified log captured no Godot lines in this session, so its `QUALITY` line is not in evidence; the profile name is.

### Export configuration (T32)

| Preset | Output | Size | Version | SDK / OS | Permissions |
|---|---|---|---|---|---|
| Android Debug | APK | 226,088,394 B | 0.1.0 (1) | minSdk 24, targetSdk 36, compileSdk 36 | none |
| Android Debug Compatibility | APK | 226,088,394 B | 0.1.0 (1) | same | none |
| Android Release Perf | APK | 224,273,387 B | 0.1.0 (1) | same | none |
| Android Release Perf Jolt | APK | 224,273,387 B | 0.1.0 (1) | same | none |
| iOS Debug | Xcode project (pck 198,268,320 B, 618 MiB) | — | 0.1.0 (1) | iOS 15.0, iPhone + iPad, requires A12 | — |
| iOS Release Perf | Xcode project (pck 198,268,352 B, 556 MiB) | — | 0.1.0 (1) | same | — |

- All six exported from the command line with exit 0; the only warning is Godot's own `Property not found: application/boot_splash/fullsize` on iOS. No install or upload. Android checked with `aapt` (build-tools 36.1.0): `versionName` 0.1.0 from the project, no `uses-permission` in any APK (debug included), arm64-v8a libraries only, `screenOrientation` userLandscape, `debuggable` only in the debug APKs. iOS: `MARKETING_VERSION` 0.1.0, `CURRENT_PROJECT_VERSION` 1, `IPHONEOS_DEPLOYMENT_TARGET` 15.0, landscape left/right, `UIRequiresFullScreen`, `UIRequiredDeviceCapabilities` = `iphone-ipad-minimum-performance-a12` (added by the exporter for the Mobile renderer), `ITSAppUsesNonExemptEncryption` false, and a generated `PrivacyInfo.xcprivacy` (file timestamp, system boot time, disk space reasons; tracking off). Evidence: `docs/perf/phase4d/export/export_check.txt`.
- Changed: the version name now comes only from `application/config/version`; the four Android `version/name` and two iOS `application/short_version` fields are empty. Everything else already matched the review.
- `test_export_presets.gd` (5 tests): PASS. Mutations: `permissions/internet=true` in "Android Debug" → FAIL; a keystore password filled in → FAIL (here and in `test_build_features.gd`).
- Privacy manifest and the remaining store work: `PROJECT_CONTEXT.md`, "Before a store release" (nothing created).

### Automatic device scenario (T33)

`DeviceScenario` (debug builds) plays the checks with synthetic touches and logs `SCENARIO step=… result=…`; headless on the real map all 14 steps pass (`test_device_scenario_on_the_map`); with the Phase 4c fix (`5d6c8a7`) reverted, four steps fail (both "asleep after stopping" and both "stays asleep beside it").

| Step | Galaxy Tab A7 (logcat, 01:06–01:07) | iPhone 13 Pro (results file from the device, 01:12) |
|---|---|---|
| parked car asleep | PASS (t 2.9 s) | PASS (2.6 s) |
| CAR button: beside the car, asleep, interact shown | PASS (2.5 m) | PASS (2.5 m) |
| walking into the car wakes it | PASS (on a wall, awake) | PASS |
| asleep after letting go | PASS (1.3 s) | PASS (1.3 s) |
| stays asleep while the player stands against it (3 s) | PASS (touching, 1.37 m) | PASS (touching, 1.37 m) |
| getting in wakes it | PASS | PASS |
| throttle above 5 m/s | PASS (5.0 m/s) | PASS (5.1 m/s) |
| get out (after the handbrake) | PASS (0.07 m/s) | PASS (0.08 m/s) |
| asleep after getting out | PASS | PASS |
| sloped street (VIEW to Galata while driving) | PASS (12.6° under the car) | PASS (12.6°) |
| slope: walking into it wakes it | PASS | PASS |
| slope: asleep after letting go | PASS (1.8 s) | PASS (1.8 s) |
| slope: stays asleep while the player stands against it | PASS (touching, 1.26 m) | PASS (touching, 1.26 m) |
| summary | `done result=PASS passed=14 failed=0` (with the orientation step) | `done result=PASS passed=13 failed=0` |

- This closes on the devices the Phase 4b/4c items that the user checks had left open: the tablet's car steps (NOT RUN in 4c) and the Phase 4c fix on a device (on both). Frames: `docs/perf/phase4d/iphone/scenario_011228_driving.jpg`, `scenario_011239_slope_asleep.jpg`.

### Both landscape orientations

- **Tablet: PASS (automatic).** During `scenario_vehicle_sleep_rotate` the cue script turned the display from rotation 3 to 1 at 01:07:02 while the scenario held the joystick (READY at 01:07:00), turned back to 3 at 01:07:15; on release the stick read zero and the player stopped (`rotate_release` PASS). A second run (`scenario_orientation`, 30 s): turned 1 → 3 at 01:09:36 after READY at 01:09:35, released at 01:10:06 (PASS), turned back at 01:10:08, original settings restored by the script at 01:10:12 (`accelerometer_rotation=1 user_rotation=0`). Logs `docs/perf/phase4d/tablet/rotation_run1.log`, `rotation_run2.log`, `scenario_*_log.txt`; frame in the turned orientation with the stick held (`rotated_270_holding_stick.jpg`). The app kept running through every turn (one process, no second `STARTUP`). The safe area stays the same on this full-screen tablet, so no new `SAFE_AREA` line appears; the re-application path itself is covered by the headless test (Phase 4c).
- **Incident:** in the first run the cue script's `adb` calls read its log pipe and swallowed the `done` line, so it did not restore the settings; they were restored by hand about a minute later (`accelerometer_rotation=1`, `user_rotation=0`, verified) and the script was fixed (`/dev/null` as stdin, only log lines from its own start). The second run shows the fixed script restoring them itself.
- **iPhone: NOT RUN.** The user answered "Çevirdim", but the scenario's gravity readings stayed (0, −0.2, −9.8) for the whole 90 s window: the phone lay flat and was not turned (`docs/perf/phase4d/iphone/scenario_orientation.json`). The hold and release themselves passed.

### Phase 4 status (specification items)

| Item (`PROJECT_CONTEXT.md`, "Phase 4") | Status |
|---|---|
| Mobile renderer suited to the Godot version | Done (Mobile; T1, Vulkan / Metal on the devices) |
| Avoid expensive shadows | Done (low: off; high: 2 splits, 60 m; shadows measured as no gain) |
| Review texture, material, map-size, and collision costs | Partly: measured (facade detail 64 % of triangles; 827 trimesh colliders); the map-level fixes wait for the user's map-pipeline decision (open questions 20, 21, 30) |
| Avoid needless per-frame work | Done for what was measured (parked vehicles sleep; physics diagnosed); P3/P6 not applied by decision (D20) |
| UI adapts to phone screens; safe area, notches, edges | Done: nine screens headless, both test devices, rotation on the tablet; other devices simulated only (open question 31); iPhone rotation NOT RUN (open question 33) |
| Comfortably large touch buttons | Done (gameplay targets ≥ 9.6 mm on phones, ≥ 18.3 mm on tablets) |
| Target 60 FPS; 30 FPS mode for weaker Android devices | Done on the test devices: iPhone 13 Pro 60 FPS with even 16.7 ms frames (P1); Tab A7 30 FPS profile (D12; Galata 1 % low a known deviation) |
| Targets measured on real devices | Done (Phases 4a–4b, release builds, three runs) |
| Review iOS and Android export configuration | Done (Phase 4d) |
| Isolate device and platform dependencies | Done (Phase 4d) |

Phase 4 is complete for the engineering items; what remains is the map-level work (a user decision) and one user check on the iPhone.

## Phase 4c — Phase 4b on-device check, screen layouts and safe areas (2026-10-27/28)

Task rule: a user answer counts only when a log or a screenshot supports it; otherwise the item is NOT RUN. No Android phone is available (user), so phone screens other than the iPhone are covered only by the headless matrix.

### Phase 4b on-device check (debug build of `e30942e`, 2026-10-27)

Evidence: iPhone screenshots about once a second (`devicectl`); the iPhone's Instruments log worked only after the user connected the cable (it failed with "Device got disconnected" over Wi-Fi) and then captured only parts of the session; tablet logcat and screenshots. Frames: `docs/perf/phase4b/device_check/iphone_<time>.jpg`.

| Step | iPhone 13 Pro | Galaxy Tab A7 |
|---|---|---|
| Parked car asleep before getting in (CAR, overlay `car asleep`) | PASS: 21:50:59 `Idle 0.0 m/s \| car asleep` beside the car (`iphone_215059`) | NOT RUN |
| Getting in wakes it | PASS: 21:51:04 `Driving 0.0 m/s \| car awake` (`iphone_215104`) | NOT RUN |
| After getting out it falls asleep again | PASS: out at 21:51:44 (`car awake`), 21:51:47 `Idle 0.0 m/s \| car asleep` (`iphone_215147`) | NOT RUN |
| Walking into the car wakes it | PASS: 22:01:15 `Walk 0.0 m/s \| car awake` (`iphone_220115`); asleep again 2 s later as the player walked on | NOT RUN |
| Standing still against it, it falls asleep again | **FAIL, fixed in `5d6c8a7`**: the player stood against the car on the sloped Galata street and the car stayed `car awake` for about 4.5 minutes (22:01:25–22:06:00, `iphone_220125`). Reproduced headless on a 6° cross slope (awake 300 of 300 ticks) and fixed; not rechecked on a device | NOT RUN |
| Throttle drives the car off | PASS: 22:06:03 onwards `Driving 6.7 … 25.9 m/s \| car awake` (`iphone_220609`, 22.8 m/s). The car was already awake before getting in this time (defect above); getting into a sleeping car was shown at 21:51, without throttle | NOT RUN |
| Stutter while turning the camera and driving | only the prepared answer "Akıcı, takılma yok", no sentence of the user's own; that the driving happened is shown by the frames | — |

- Tablet: the user answered twice that the steps were done, but the log has no `CAR walk-up`, the car never woke after 21:19 (every `PERF` line until 22:11 says `vehicles=asleep`), and the screenshots show the same Spawn frame throughout. NOT RUN.
- iPhone: twice an answer arrived before the screenshots showed the step (step 1 while other steps had been done; the first "Yaptım" for driving with no driving on screen). Each item above is counted from the frames only.

### Layout matrix (headless, `tests/unit/test_hud_layout.gd`, debug overlay shown)

| Screen (window px), safe area px | Canvas, px/unit | On foot | Vehicle | Smallest gameplay target on foot / vehicle | Smallest debug target | Smallest gameplay gap on foot / vehicle (units) |
|---|---|---|---|---|---|---|
| 16:9 1920×1080, none | 1600×900, 1.200 | PASS | PASS | 10.8 / 10.1 mm | 8.4 mm | 31 / 18 |
| 19.5:9 iPhone 13 Pro 2532×1170, notch left: (141, 0, 2250, 1107) | 1947×900, 1.300 | PASS | PASS | 10.2 / 9.6 mm | 7.9 mm | 31 / 18 |
| iPhone, notch right (iOS reports the same insets) | 1947×900, 1.300 | PASS | PASS | 10.2 / 9.6 mm | 7.9 mm | 31 / 18 |
| 20:9 2400×1080, punch-hole left, 3-button bar right: (110, 0, 2164, 1080) | 2000×900, 1.200 | PASS | PASS | 10.6 / 9.9 mm | 8.2 mm | 31 / 18 |
| 20:9, punch-hole right, 3-button bar left: (126, 0, 2164, 1080) | 2000×900, 1.200 | PASS | PASS | 10.6 / 9.9 mm | 8.2 mm | 31 / 18 |
| 20:9, punch-hole left, gesture handle: (110, 0, 2290, 1017) | 2000×900, 1.200 | PASS | PASS | 10.6 / 9.9 mm | 8.2 mm | 31 / 18 |
| 20:9, punch-hole right, gesture handle: (0, 0, 2290, 1017) | 2000×900, 1.200 | PASS | PASS | 10.6 / 9.9 mm | 8.2 mm | 31 / 18 |
| 4:3 iPad 2048×1536: (0, 48, 2048, 1448) | 1440×1080, 1.422 | PASS | PASS | 19.5 / 18.3 mm | 15.1 mm | 31 / 18 |
| 16:10 Tab A7 2000×1200, none (immersive) | 1500×900, 1.333 | PASS | PASS | 21.6 / 20.2 mm | 16.7 mm | 31 / 18 |

- Threshold 7 mm on the hit area (drawn diameter × 1.15); ppi assumed: 401 (16:9), 460 (iPhone), 411 (20:9), 264 (iPad), 224 (Tab A7). The debug VIEW and Q buttons' hit circles are 2 units apart (debug builds only).
- `test_safe_area_change_without_resize_is_applied_and_releases_fingers`: PASS (the punch-hole and the bar swap sides at the same window size; within 0.35 s the new safe area is applied and the held joystick and run button are released).
- Mutation checks: safe area not applied → 8 tests fail (the seven screens with insets and the rotation test; 16:9 and the Tab A7 have none); the exit button moved above the safe area → 10 fail (all nine screens and `test_vehicle_controls_layout_and_group_switch`); no periodic check → 1 fails; no finger release → 1 fails.
- No combination failed, so no control moved; the layout of T22/T25 stays. HUD draw calls were not re-measured (the task asks for it only if the layout changed); the periodic check is one `DisplayServer` query every 0.25 s.
- Reference shots: `docs/ui/<screen>_<on_foot|vehicle>.jpg`, release HUD, the area outside the safe area shaded, taken on the Mac at a smaller resolution with the same aspect ratio (for example 1266×585 for the iPhone). One iPhone set covers both orientations.

### Both landscape orientations on the devices (debug build of `5d6c8a7`)

- Neither test device changes its safe area on a 180° turn: the tablet runs immersive without a cutout (`SAFE_AREA window=(2000, 1200) safe=[(0, 0), (2000, 1200)]`, `docs/ui/device_check_logs.txt`), and the iPhone's side insets are symmetric. The re-application path is therefore covered only by the headless test.
- iPhone: answered "Yaptım, sorun yok", but the frames of 23:11–23:14 show the same idle Spawn picture without any joystick input, and the captured log (23:12–23:14) has no new `SAFE_AREA` line; a turn itself is not visible in screenshots. NOT RUN.
- Tablet: answered "Tablette yaptım", but the system rotation stayed at 270° (`SurfaceOrientation:3`) from 23:17 to 23:55 and the frames show the same Spawn picture without input. NOT RUN.
- HUD before and after on the devices: `docs/ui/device_after_iphone.jpg` and `device_after_tablet.jpg` (this build) match `docs/perf/phase4b/iphone_overlay_car_asleep.jpg` and `tablet_overlay_car_asleep.jpg` (Phase 4b build) control for control.

### Device classes not tested on hardware

Android phones of any kind, iPads, iPhones other than the 13 Pro (smaller screens, Dynamic Island, Home-button models), foldables, Android tablets with visible system bars. Only the headless matrix covers them, with assumed insets and ppi.

## Phase 4b — P1 (iOS 60 Hz display) and P2 (parked vehicles sleep) (2026-10-26/27)

User decision D20 (`PROJECT_CONTEXT.md`). Implementation: `ce22319` (P1), `54a5b97` (P2), `4ffd799` (fix of the sleep state read between steps, found on the device), `e30942e` (measurement-only `vehicle_sleep` runtime key). Rules: `docs/ARCHITECTURE.md`, "Parked vehicles sleep" and "iOS display refresh rate".

### Builds and protocol

- Release Perf builds from `4ffd799` for the main measurements ("Android Release Perf", "iOS Release Perf"; `run-as` "package not debuggable", `libgodot.a` 188,887,256 bytes as in Phase 4a, every result file `debug_build: false`, `perf_feature: true`). The paired tablet A/B used `e30942e` (the same game code plus the `vehicle_sleep` key).
- Same protocol as Phase 4a (D17): three runs, medians with every run's value; standard windows (30 s warm-up + 60 s per viewpoint) for `profile_default`, `profile_default_vehicle`, `session_profile_default`; 20 s + 40 s for the A/B (`c_vehicle_sleep_off` / `_on`). Tablet without PSS sampling, cool-down target = each run's starting battery temperature + 0.5 °C, capped at 120 s (as in 4a). Raw data: `docs/perf/phase4b/results/`.
- iOS STARTUP and results: `ios_allow_high_refresh_rate: false`, `display_refresh_rate: 60`, `screen_refresh_rate: 120` (the panel maximum, `UIScreen.maximumFramesPerSecond`). Android: `display_refresh_rate: 60`, frame pacing unchanged (the setting is iOS only).
- Every on-foot result: `vehicles_asleep` 1.000 (the parked car slept in every measured frame; `VEHICLE PlaceholderCar asleep` ~2.4 s after the first frame, never woken). In-vehicle results: 0.000 (the driven car is awake).

### Acceptance criteria

| Criterion | Result | Evidence (medians of three runs) |
|---|---|---|
| iPhone, 3 viewpoints on foot: 1 % low ≥ 54 and long frames < 1 % | **PASS** | 1 % low 58.28 / 57.23 / 56.26; long frames 0 / 0 / 0 (Phase 4a: 49.7 / 49.7 / 45.1 %) |
| iPhone, 10 min at Karaköy on foot (3 runs): average ≥ 59.5, thermal ≤ Fair | **PASS** | 59.96–60.00 FPS every minute of every run; thermal Nominal at all 42 probes (14 per run); footprint 996–998 MiB; 1 long frame per run (minute 1) of ~36,000 |
| iPhone in the vehicle, 3 viewpoints: long frames < 1 % | **PASS** | 0 / 0 / 0; 1 % low 58.68 / 57.32 / 56.67 |
| Tab A7 on foot: physics step ≥ 0.8 ms lower than Phase 4a at every viewpoint | **FAIL** (2 of 3) | 4.789 → 4.035 (−0.75), 4.694 → 3.834 (−0.86), 5.591 → 4.798 (−0.79) ms |
| Tab A7: average FPS ≥ 29.9 | **PASS** | 30.01 / 30.00 / 30.00 (in the vehicle 30.00 / 30.00 / 29.99) |
| Tab A7: 1 % low not below Phase 4a (±0.5) | **PASS** | 25.39 → 26.25, 25.99 → 26.06, 24.89 → 25.21 |
| Battery temperature and cool-down per run recorded | **PASS** | `*.meta.json`: `battery_c_start/end`, `cool_wait_s`, `cool_target_c` (new fields) |
| Sleep/wake tests; mutation checks for "wakes when a driver gets in" and "does not slide on a slope" | **PASS** | tests and mutations below |
| Phase 1–3 tests unchanged and passing | **PASS** | all pass; two Phase 3 integration tests got extra checks (the parked car falls asleep; the 5 s drive now starts from a sleeping car: 43.9 m, threshold 35 m unchanged) |
| Short on-device check with the user | **NOT RUN** | see "On-device check" |

### iPhone 13 Pro (release, high profile), Phase 4a → 4b

| Viewpoint, mode | Avg FPS | 1 % low | Min FPS | Long frames | Physics step ms (p99) | Draw calls |
|---|---|---|---|---|---|---|
| Spawn, on foot | 60.00 → 60.00 | 42.28 → 58.28 [58.28 / 58.44 / 57.49] | 40.54 → 52.70 | 49.7 % → 0 | 1.308 → 0.867 (1.87) | 242 → 242 |
| Karaköy, on foot | 59.99 → 60.00 | 41.86 → 57.23 [57.28 / 57.19 / 57.23] | 40.27 → 53.53 | 49.7 % → 0 | 1.337 → 1.115 (2.50) | 141 → 141 |
| Galata, on foot | 59.99 → 60.00 | 39.97 → 56.26 [56.31 / 56.26 / 56.23] | 36.55 → 49.53 | 45.1 % → 0 | 1.387 → 1.219 (1.91) | 72 → 72 |
| Spawn, in vehicle | 60.00 → 60.00 | 42.25 → 58.68 [58.68 / 58.69 / 58.38] | 40.78 → 55.26 | 49.7 % → 0 | 0.992 → 0.786 (1.71) | 211 → 211 |
| Karaköy, in vehicle | 60.00 → 60.00 | 42.18 → 57.32 [57.29 / 57.33 / 57.32] | 40.78 → 53.14 | 49.1 % → 0 | 1.009 → 1.070 (2.20) | 175 → 174 |
| Galata, in vehicle | 60.00 → 59.99 | 40.49 → 56.67 [56.67 / 56.82 / 56.66] | 40.00 → 55.00 | 46.2 % → 0 | 0.941 → 1.063 (1.55) | 97 → 97 |

- All frames are at 16.7 ms (p50 16.66–16.74 ms, p99 17.0–17.9 ms); the remaining gap between 60 and the "1 % low" is timing jitter below one refresh, as in the Phase 4a 60 Hz build.
- 10-minute session, median per minute: 1 % low 55.49–56.12 (4a at 120 Hz: 41.9). Thermal Nominal throughout.
- The on-foot physics step fell by 0.17–0.44 ms (the parked car sleeps); in the vehicle it is unchanged within the spread (the driven car is simulated in both).
- Startup (9 launches): map ready 1,371 ms, first frame 1,447 ms (4a: 1,391 / 1,458).

### Galaxy Tab A7 (release, low profile), Phase 4a → 4b

| Viewpoint, mode | Avg FPS | 1 % low | Min FPS | Physics step ms [runs] (p99) | Long frames | Battery at start (runs 1/2/3) |
|---|---|---|---|---|---|---|
| Spawn, on foot | 29.99 → 30.01 | 25.39 → 26.25 [26.25 / 26.37 / 25.71] | 20.85 → 22.41 | 4.789 → 4.035 [4.035 / 3.826 / 4.435] (10.51) | 0.17 → 0.11 % | 34.0 / 37.0 / 38.0 °C |
| Karaköy, on foot | 30.00 → 30.00 | 25.99 → 26.06 [26.42 / 26.06 / 24.63] | 20.81 → 22.27 | 4.694 → 3.834 [3.834 / 4.295 / 3.800] (10.22) | 0.11 → 0.11 % | |
| Galata, on foot | 29.99 → 30.00 | 24.89 → 25.21 [25.21 / 25.29 / 24.21] | 21.75 → 24.22 | 5.591 → 4.798 [4.539 / 5.017 / 4.798] (7.26) | 0.33 → 0.00 % | |
| Spawn, in vehicle | 30.00 → 30.00 | 26.41 → 26.12 | 17.74 → 23.87 | 3.537 → 3.717 (8.29) | 0.11 → 0.06 % | 35.0 / 37.5 / 38.0 °C |
| Karaköy, in vehicle | 30.00 → 30.00 | 26.68 → 26.44 | 22.91 → 21.77 | 3.569 → 4.263 (12.57) | 0.11 → 0.06 % | |
| Galata, in vehicle | 30.00 → 29.99 | 25.90 → 25.81 | 23.71 → 22.33 | 4.224 → 4.325 (8.50) | 0.06 → 0.11 % | |

- Thermal status 0 in every run; battery 34.0 → 38.5 °C over the batch (Phase 4a `profile_default`: 37.0–38.0 °C at the starts); cool-down waits 0–120 s (`cool_wait_s`).
- On foot 99.3–99.8 % of frames are at 33.3 ms (p99 38.1–39.7 ms). In the vehicle the physics step is unchanged or slightly higher within the run spread (the driven car is simulated in both phases).

**Paired A/B on the tablet** (`c_vehicle_sleep_off` / `_on`, same session, order alternated per run; physics step ms):

| Run | Spawn off → on | Karaköy off → on | Galata off → on | Battery |
|---|---|---|---|---|
| 1 | 4.520 → 3.759 (−0.76) | 5.147 → 4.523 (−0.62) | 5.777 → 4.964 (−0.81) | 36.5–38.0 °C |
| 2 | 4.514 → 3.996 (−0.52) | 4.286 → 3.863 (−0.42) | 5.256 → 4.902 (−0.35) | 38.0–39.0 °C |
| 3 | 7.876 → 4.501 | 6.084 → 4.210 | 5.368 → 5.202 (−0.17) | 27.0–30.0 °C |

- Run 3 was repeated a day later: the first attempt lost the adb connection for ~22 hours (USB dropped; 0 results, kept out of the tables), and its sleep-off half has outliers (1 % low 20.86, p99 17.7 ms at Spawn) on a tablet that had just reconnected cold. Runs 1–2 show a gain of 0.35–0.81 ms per step from sleeping; Phase 4a's "car removed" figure (≈ 1.0 ms, single session, 40 s windows) was an upper bound. Headless on the Mac the asleep car costs the same as a removed one within noise (`docs/perf/phase4b/headless/vehicle_sleep_cost.txt`), so the shortfall against 0.8 ms is not a known cost left in the sleeping car; the run-to-run spread of the tablet's physics step (up to 0.6 ms at a viewpoint) is of the same size.
- Unexplained: in A/B runs 1–2 the sleep-on half had more 50 ms frames at Galata (29 and 49 vs 0 and 2 long frames; 1 % low 23.2 vs 24.8–24.9). The main runs (60 s windows, sleep on) do not show it (0–16 long frames, 1 % low above 4a).

### Startup (tablet)

The 12 tablet launches of the batches had map ready at 9,370 ms (median; 7,412–14,324) against 6,235 ms in Phase 4a. An alternating check afterwards (same tablet, battery 30–31 °C, four launches each, no experiment) gave 7,054 ms for the Phase 4a APK (`d63464d`) and 6,977 ms for the Phase 4b APK: no difference between the builds; the slower batch launches came with the warmer tablet (34–39 °C).

### Sleep vs freeze (headless, real map)

`tools/perf/vehicle_sleep_cost.gd` (player physics paused, 600 ticks × 3 rounds, Mac): median physics step awake 0.42–0.59 ms, asleep 0.20–0.25, frozen 0.20–0.30, removed 0.14–0.23 ms; active bodies 1 / 0 / 0 / 0. A 400 kg box thrown at the car: asleep → woken and pushed 0.379 m; frozen → moved 0.000 m and stayed inactive. Sleep was chosen (`docs/ARCHITECTURE.md`).

### Tests and mutation checks

New tests: `test_parked_vehicle_falls_asleep_after_resting` (asleep after its rest time, 0 active bodies, handbrake kept), `test_rolling_vehicle_sleeps_only_after_it_has_stopped`, `test_vehicle_with_a_driver_stays_awake` (also between steps), `test_driver_wakes_a_sleeping_vehicle`, `test_moving_or_resetting_wakes_a_sleeping_vehicle`, `test_a_body_hitting_a_sleeping_vehicle_wakes_it`, `test_losing_the_ground_wakes_a_sleeping_vehicle`, `test_sleeping_vehicle_stays_on_a_slope_and_the_hill_hold_takes_over` (10° ramp: no movement in 5 s asleep, < 0.02 m after a driverless wake, < 0.1 m with a driver and no pedal — the Phase 3 limit; the hold creeps ~2 cm/s whether the car slept before or not), `test_interact_button_works_while_the_vehicle_sleeps`, `test_walking_into_a_sleeping_vehicle_wakes_it`, `test_overlay_status_shows_the_vehicle_while_driving`, `test_ios_display_runs_at_60_hz`, `test_vehicle_sleep_runtime_key`; extended: `test_vehicle_parked_on_a_flat_karakoy_street`, `test_vehicle_drives_five_seconds_along_the_street`, `test_short_benchmark_on_map`, `test_release_perf_build_runs_benchmarks_without_debug_ui`, `test_measurement_tags_only_in_their_presets`.

Mutation checks (each rule broken, unit suite run, code restored): no wake when a driver gets in → 4 tests fail; parked brakes off (no handbrake, no hold) → 7 fail, including the slope test (the car slid 318 m); no at-rest speed check → 1 fails (added after the first round, where nothing failed); no ground check → 1 fails; the player does not wake the car → 1 fails; `is_asleep()` from the server state alone → 1 fails (120 of 120 frames read "asleep" between steps). Not detectable, by analysis: removing `wake_up()` from `place_at()` / `reset_to_spawn()` (setting the velocities there already wakes the body in GodotPhysics3D), and a ground ray only one wheel radius long along world down (on a 10° slope the wheel centre is 0.326 m from the ground, inside the 0.35 m radius, so behaviour does not change).

### Found on the device and fixed

The first device run (build `54a5b97`) recorded `vehicles_asleep` 1.0 for the driven car in the in-vehicle benchmark. GodotPhysics3D's own sleep test marks a resting vehicle inactive at the end of every step and its wheel impulses wake it at the next callback, so the server state read between steps (overlay, benchmark, PERF) called an awake car asleep; the game logic, which reads during the physics tick, was not affected. Fixed in `4ffd799` (the controller tracks its own parking sleep); `can_sleep = false` was tried and rejected (an active body in the same island then kept the car awake). The batches of that build were stopped and discarded; all tables above come from `4ffd799` / `e30942e`.

### On-device check (user)

Debug builds of `54a5b97` on both devices. Screenshots and logs show the parked car asleep on both: overlay `Idle 0.0 m/s | car asleep` (`docs/perf/phase4b/iphone_overlay_car_asleep.jpg`, `tablet_overlay_car_asleep.jpg`), tablet log `VEHICLE PlaceholderCar asleep` 2.4 s after the first frame and 528 of 529 `PERF` lines with `vehicles=asleep` over 17 minutes (`tablet_debug_log_excerpt.txt`).

The user first chose the prepared answers ("Akıcı, takılma yok", "Evet, sorunsuz", "Evet, doğru", "Denedim, aynı"), but the logs and screenshots of both devices showed no interaction during that time (no CAR press, no getting in, the car never woken, the same Spawn frame before and after). Asked again, the user answered "Şimdi yapamam". **The check (stutter while turning the camera and driving, getting into a sleeping car and driving off, walking into the car) is NOT RUN.** On the devices, getting into the car from the benchmark's in-vehicle runs is shown by the results (driven car awake, `vehicles_asleep` 0.000); driving off from sleep and the player bump rest on the automated tests. Debug builds of the final code (`e30942e`) are now installed on both devices for the check. Checked on the iPhone in Phase 4c (see there).

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
| Automated tests pass. | 2026-11-02, the shader facade map as the default (`edadb59`, `b80c205`, and the documentation commit after them): `run_tests.gd` → `RESULT 279 passed, 0 failed, 0 skipped`, exit 0; unit only → 195 passed, exit 0; a clean clone without any GLB → 213 passed, 66 skipped, exit 2; with only İstanbul's GLB → 247 passed, 32 skipped, exit 2; `validate_scene.gd` → `VALIDATION PASS`; all four GLBs' SHA-256 checked. 2026-11-01, shader facade toward the default (`d8f78fb`, `4242efe`, `56aaf0d`, and the documentation commit after them): `run_tests.gd` → `RESULT 274 passed, 0 failed, 0 skipped`, exit 0; without the generated GLBs → 242 passed, 32 skipped, exit 2; without any GLB → 208 passed, 66 skipped, exit 2; unit only → 193 passed, exit 0; `validate_scene.gd` → `VALIDATION PASS`; all four GLBs' SHA-256 checked. 2026-11-01, with the facade maps (`83c8f0a` and the documentation commit after it): `run_tests.gd` → `RESULT 267 passed, 0 failed, 0 skipped`, exit 0 (550 s); without the generated GLBs → 237 passed, 30 skipped, exit 2; without any GLB → 203 passed, 64 skipped, exit 2; unit only → 190 passed, exit 0; `validate_scene.gd` → `VALIDATION PASS`; all four GLBs' SHA-256 checked. 2026-11-01, with the cells map (`3e00ada` and the documentation commit after it): `run_tests.gd` → `RESULT 246 passed, 0 failed, 0 skipped`, exit 0 (510 s); without the cells GLB → 237 passed, 9 skipped, exit 2; without both GLBs → 203 passed, 43 skipped, exit 2; unit only → 190 passed, exit 0; `validate_scene.gd` → `VALIDATION PASS`; both GLBs' SHA-256 checked. 2026-11-01, after the generator import (no game or test code changed): `run_tests.gd` → `RESULT 232 passed, 0 failed, 0 skipped`, exit 0 (491 s); `validate_scene.gd` → `VALIDATION PASS`; GLB SHA-256 unchanged. Phase 5: `run_tests.gd` → `RESULT 232 passed, 0 failed, 0 skipped`, exit 0; unit only → 185 passed, exit 0; without the GLB → `RESULT 198 passed, 0 failed, 34 skipped`, exit 2 (the 13 test district tests run without it) (2026-10-28, Phase 5; GLB SHA-256 re-verified afterwards). Phase 4d: 198; Phase 4c: 185; Phase 4b: 174; Phase 4a: 161. With Jolt (temporary `override.cfg`): 160 passed, 1 failed (the GodotPhysics3D pin). At 30 Hz physics: 148 passed, 13 failed (see "Phase 4a"). `tests/map/validate_scene.gd` → `VALIDATION PASS`. |
| İstanbul • Haliç generator. | See "Map generator in the repository": two runs byte-identical, the path change output-neutral, inputs and `assets/` unchanged, Godot import of the regenerated GLB in a throwaway project. |
| The shader facade map is the default; the fallback to the first available map. | See "The shader facade map is the default": the registry and startup tests, the fallback tests with and without the files, a clean clone, the STARTUP lines of plain launches of four device builds, the scenarios from the default map. |
| Map switch frees the old map first; shader facade's filter and diagnosis keys. | See "Shader facade toward the default": the switch tests (node counts, resource cache, loading screen, refusal) and a mutation check, the map switch scenario on the tablet and the device scenarios on both devices, the window shaders compile, the facade keys and traced benchmarks on the shader map. |
| Facade variants and their maps. | See "Lighter facades on the cells map": only `Detail_*` changes (`compare_outputs.py --facade` PASS for light and shader), three runs each byte-identical, the maps' tests and a mutation check, three-run device results and 10-minute iPhone sessions, the device scenarios on the shader map. |
| Cell grouping and the cells map. | See "Cell grouping and the cells map": output without the option byte-identical, `--grouped` PASS for 40 and 75 m (and FAIL against the shipped GLB), two 40 m runs byte-identical, the cells map's tests and the mutation checks, three-run device results on both devices. |
| Phase 5 maps, van, NPCs, far mode, scenario. | See "Phase 5", including the mutation checks. |
| Phase 4b sleep, wake, overlay, iOS 60 Hz. | See "Phase 4b", including the mutation checks. |
| Phase 4a gating and flags. | `test_build_features.gd` (feature logic, release HUD without debug controls, presets: `perf_bench` only in Release Perf presets, `perf_jolt` only in its preset and no `perf_60hz` preset left, keystore fields empty, no personal paths), `test_release_perf_build_runs_benchmarks_without_debug_ui`, `test_normal_release_ignores_experiments`, `test_runtime_experiment_keys_apply_on_the_map`, `test_runtime_keys_parse_and_reject_typos`, `test_frame_time_distribution`, `test_measurement_overrides_do_not_touch_defaults`. |
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

- The shader facade map as the default (2026-11-02): the presented frames were recorded on the tablet only (no presented-frame data on the iPhone); what in the display path makes the 16.7 / 50 ms pairs (SurfaceFlinger's latch, Swappy, the panel) and whether a setting removes them; whether players notice them; two of the 18 launches (the shader map's runs 7 and 8) have no presented trace for their measurement windows; criteria 2 and 4 were not measured again on the builds of `b80c205` (only the startup map and the scenarios); a release preset that packs only the default map does not exist, so a normal release build with the fallback was checked only headless and through the Release Perf builds.
- Shader facade toward the default (2026-11-01): what in the tablet's frame delivery causes the per-launch pacing state (Swappy, the display, the system; presented frame times were not recorded); whether the jitter is visible to a player; the shimmering check is a Mac pan at 960×540 (Metal), not a device recording; the footprint filter on devices was looked at only in the 640 px benchmark frames; the map switch memory was measured in a debug build (its stable PSS is 46–82 MiB above the Release Perf build's); the iPhone's footprint during switches comes from 45 s probes only; switches on the iPhone and in release builds with the loading screen were not timed separately; the user's visual approval of the filter is open. (2026-11-02: the presented frames were recorded and the approval was given through the reviewer; see "The shader facade map is the default".)
- Facade maps (2026-11-01): the shader on other GPUs than the Mac, the Adreno 610, and the A15; no in-vehicle runs or NPC A/B on the variants; why the first iPhone `extensibility` attempt (with the old switch code) produced no results (the retry and this task's runs passed with `ios_bench.sh`); the light variant's culled windows were checked by the culling rule, not by looking into the 1 m gaps.
- Cells map (2026-11-01): the device scenarios ran on the shader map (same data and collision), not on the cells map itself; no 10-minute session, no in-vehicle runs, and no NPC A/B on it; the 150 m / no-fog experiment has one set of three runs; the trunk-under-crown case on the low profile was not looked for systematically; the blank-facade figures are a geometric estimate (AABB centres of the meshes, 3,000 street points), not counted on screen; the generator option and the GLB hash were checked only on macOS arm64; `render_map.py` was not run on the cells output.
- Generator (2026-11-01): `render_map.py` was not run in Blender (paths checked with a stub `bpy` only); the generator ran only on macOS arm64 with Python 3.12.15; why the shipped GLB differs from every tried shapely version in the 6 signal heads and the road triangulation (the package's environment is unknown); the regenerated GLB was not run in the game, on devices, or measured.
- Phase 5: two NPCs near the player at once were measured only as the A/B "all under the controller" (`c_npcs_full_*`), not by playing among them; more than two NPCs near the player were not measured. The far mode's behaviour where a route is blocked (it walks through) is by design and not tested. NPC behaviour on Jolt Physics: not tried. The 1 % low gap of the tablet's 40 s far-mode A/B windows in runs 2–3 (below) is unexplained.
- iPhone: both landscape orientations with the joystick held through a turn (NOT RUN in Phases 4c, 4d, and 5; in Phase 5 the user answered that they could not do it; open question 33); the stutter while turning the camera and driving in the user's own words (only a prepared answer so far). The Phase 4b steps and the fix `5d6c8a7` are now verified on both devices by the device scenario (Phase 4d).
- iPhone `QUALITY` line from the device: not captured (the unified log had no Godot lines in Phase 4d); the profile name and the startup values come from the app's results file. (2026-11-02: an Instruments "Logging" recording around the launch, `tools/perf/ios_startup_log.sh`, captured the `QUALITY` and `STARTUP` lines.)
- Screens other than the iPhone 13 Pro and the Galaxy Tab A7 (Android phones, iPads, other iPhones): headless layout matrix only, with assumed insets and ppi.
- Why the tablet's paired A/B gain from sleeping (0.35–0.81 ms) is smaller than Phase 4a's "car removed" figure (≈ 1.0 ms), and why the A/B sleep-on runs had more 50 ms frames at Galata.
- The P2 gain on the iPhone in the vehicle (the driven car is awake; nothing to gain) and on other devices.

- Phase 4a: the tablet's "1 % low" is measured from the CPU frame loop; actual presentation times (Swappy) were not recorded, so how much of the 33–40 ms jitter is visible is unknown. (2026-11-02, low profile: the loop's jitter is absorbed by the swap chain; the display has its own 16.7 / 50 ms pairs, see "The shader facade map is the default".)
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

- Map switches (2026-11-01): fixed so that two maps are never in memory at once; loading a big map still holds 15–115 MiB of temporary data above its stable PSS (the tablet peaked at 810 MiB loading the cells map in a debug build, 64 MiB above the task's target), and the load blocks for 6.8–9.5 s on the tablet behind the loading screen. The tablet's low-memory killer reclaims other apps' processes during such loads.
- Tablet frame pacing (2026-11-01/02): some launches on the Galaxy Tab A7 (4 of 18 in the A/B and 3 of 9 in the device runs of 2026-11-01, 2 of 18 on 2026-11-02) run with game-loop frame times cycling about 28 → 42 → 30 ms (0.7–12 % long frames per viewpoint, 1 % low 22.3–24.1 at 30.00 FPS) on any map. That cycle does not reach the screen; instead every launch has about one 16.7 / 50 ms pair of presented intervals per second (2.6 % of the intervals on the shader map, 3.5 % on İstanbul), which the game loop does not see (open question 43).
- Facade maps (2026-11-01): light has no mullions or sills; shader is flat (no relief) and uses other glass tints (its distant windows are filtered since T43, no longer faded); builds with all five maps are 675 MB (APK) and 649 MB (iOS `.pck`).
- Cells map (2026-11-01): lamps, lamp glows, and decor keep their 150 m chunks, so on the low profile nearby lamp posts are not drawn (as on İstanbul); tree trunks stay in chunks while their crowns are in cells (T40); within 100 m about 8.7 % of the buildings still lose their facade detail on the low profile (estimate); the map costs +128 MiB PSS and +1.2 s to map ready on the tablet, +280 MiB footprint on the iPhone; a fresh clone must generate its GLB (about 2.5 minutes) before the map is offered.
- NPCs (Phase 5): far NPCs (more than 10 m from the player) pass through walls, cars, and each other, so routes must be clear; moving vehicles pass through NPCs as through the player; getting out of a vehicle does not check for NPCs at the exit point (the player is pushed out of an NPC standing there); no damage, health, or reactions beyond the stagger; placeholder capsules.
- Map switching (debug builds) blocks while the new map loads (6.8–9.5 s on the tablet between the big maps, behind a loading screen since 2026-11-01; about 1–1.5 s per switch on the iPhone, from the scenario's step times) and is refused while driving and during another switch.
- Placeholder car (boxes and cylinders); no engine sound, damage, or traffic. Brake lights also light while parked (handbrake held).
- Cars drive through railings, lamp posts, and kerbs (no collision) and can leave bridge decks and quays into the water; they reset to the spawn below the kill height (open question 12).
- Exit markers are fixed points beside the doors; on a narrow street with both sides blocked the player cannot get out until the car is moved.

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

- **Memory on the tablet (2026-11-01):** the PSS follows the mesh count, not the geometry (the facade variants keep the cells map's 6,129 meshes and its PSS within 18 MiB); a switch no longer holds two maps, but a big map's load peaks 15–115 MiB above its stable PSS, and the low-memory killer reclaims other processes meanwhile; any bigger map would need streaming.
- **Memory per mesh (2026-11-01):** on Metal every extra mesh costs video memory (the cells map's 3,074 extra meshes: +184 MiB on the iPhone and the Mac); smaller cells or more categories in cells raise it further. The tablet's PSS rose by 128 MiB.
- **Characters on the tablet (Phase 5):** a walking character under `PlayerController` costs about 1.1–1.4 ms per physics step on the Galaxy Tab A7 (three-run A/B; two steps per frame), mostly script and transform work; two NPCs near the player at once lower its 1 % low by about 2 FPS. The far mode keeps distant NPCs cheap; denser NPCs near the player need a cheaper character (open question 34).
- **Tablet physics margin:** with the parked car asleep the physics step on foot is 3.8–4.8 ms (two per frame at 30 FPS); the player's `move_and_slide` (≈ 1 ms) and the trimesh map colliders remain (open question 30).
- **Performance:** the profiles meet the iPhone criterion and the tablet's average; the tablet's 1 % low is marginal and its visual quality is low. Facade detail (64 % of triangles) remains the main geometry cost; the map-level work in `PROJECT_CONTEXT.md` is not started.
- Devices are assigned by platform only: a weak iPhone would get high, a strong Android phone low (open question 18 in `PROJECT_CONTEXT.md`).
- **Memory:** iPhone footprint 1.02 GiB; Android uses swap on a tablet with limited RAM.
- **Startup:** 10–15 s to map ready on the tablet, with variance between runs.
- A fresh clone lacks every map GLB: it starts on the test district with a warning until the default map's GLB is generated (about 2 minutes) or İstanbul's is copied in (T44).

## External blockers

- Final iOS identity: `com.mirongi.mapsimulator` must be registered only in the user's future Apple Developer account. Until then, iOS debug builds use the temporary team and `.dev` bundle ID.

## Required manual actions

- **Decide whether the tablet's display pairs deserve a task** (open question 43): about one 16.7 / 50 ms pair of presented intervals per second in every launch on the Galaxy Tab A7, not seen by the game loop (`docs/perf/default_map/`); a measurement task would test Swappy's mode or frame pacing off, one change at a time, against presented-frame criteria.
- **iPhone: set Auto-Lock back to its previous value**, if it is still on "Never". The debug builds of `b80c205` (all five maps, starting on the shader map) are installed on both devices.
- **iPhone rotation check** (open question 33): start `scenario_orientation` (commands in `docs/ARCHITECTURE.md`, "Device scenario"), hold the phone upright in landscape, and turn it 180° once during the 30 s; the gravity readings in the results file are the evidence.
- The stutter while turning the camera and driving on the iPhone, in your own words.
- Before any release: how ODbL share-alike applies (open question 38), and a release preset that packs only the default map's GLB (generated, SHA-256 checked) and leaves the other maps out (question 36). Open questions 39 and 40 were decided (D23).
- The other directions after the specification (real models, store preparation) stay open: `PROJECT_CONTEXT.md`, "After the specification".
- Open questions 2 (car model source), 12 (barriers), 22–24 (damage, NPC behaviour beyond Phase 5, roll immunity), 28–29 (camera distance, steering modes), 31–32 (test devices, button sizes), 33 (iPhone orientation), 34–37 (character cost, vehicle–character collisions, the test district in release packages, blocking map loads) remain.
- Later, before any store release: the checklist in `PROJECT_CONTEXT.md`, "Before a store release" (new Apple account and Team ID, final bundle ID, release keystore, AAB build, store metadata; none created).
- Provide or choose character and car models; decide the app name and icon.

## Current priorities

1. Review of the default change and its measurements ("The shader facade map is the default").
2. The streaming loader (below; definition in `PROJECT_CONTEXT.md`, "Planned features"), before any further map is added to the registry.
3. If the user wants it, a presented-frame measurement of the tablet's display pairs (open question 43).

## Recommended next task

Order of the remaining work by the measurements of 2026-11-01/02 (each a separate task, measured against them):

| # | Work | Why in this place | Measurable acceptance |
|---|---|---|---|
| 1 | **Streaming loader** (definition: `PROJECT_CONTEXT.md`, "Planned features") | The default map now holds the cells map's 6,129 meshes: tablet stable PSS 615 MiB against İstanbul's 502, map ready 5.8 s, a switch 6.8–9.5 s (debug) with 15–115 MiB of temporary data (810 MiB peak); the PSS follows the mesh count | Tablet (Release Perf, three runs): stable PSS ≤ 502 MiB, map ready ≤ 4.0 s, switch peak ≤ the larger map's stable PSS + 50 MiB with no low-memory reclaim of this app, no frame over 50 ms from part loading, long frames by D25's relative criterion, 1 % low within 0.5 FPS of 25.80 / 25.89 / 25.17; iPhone footprint ≤ 860 MiB, 60 FPS with 0 long frames, map ready ≤ 1.2 s; look, collision, and tests unchanged |
| 2 | **The tablet's display pairs** (open question 43; only if the user wants it; measurement first, then at most one setting change) | Every launch shows about one 16.7 / 50 ms pair of presented intervals per second (2.6 % of the intervals on the shader map, 3.5 % on İstanbul) that the game loop does not see; the per-launch loop cycle is not visible | With `present_trace.py`, nine launches per variant: presented 50 ms intervals at most half of today's share (away from polls) at every viewpoint, the game loop's averages and 1 % low not worse, the iPhone unchanged |
| 3 | **Simple colliders** | The tablet's physics step (4.4–5.5 ms) is unchanged on every map and variant and the largest CPU cost | Physics step ≥ 0.5 ms lower at the three viewpoints (three runs); Phase 1–5 tests pass |
| 4 | **Occluders from building footprints** | Occlusion works (39 draw calls at Galata on the tablet); the bake costs about 40 MiB and 86–220 ms at load | Occluder triangles −80 %; draw calls within 10 %; load time and memory reported |
| 5 | **A release preset with only the default map** (before store preparation) | A build made where all GLBs exist packs five maps (APK 675 MB); a release must carry only the shader map's GLB (open question 36) | Release APK and `.pck` with one İstanbul map; the plain launch on both devices starts on it; a preset test pins the exclusions |
| 6 | **Normals and degenerate triangles** | No measurable effect | Zero-area and flipped triangles 0, the rest byte-identical |

Smaller follow-up: lamps, lamp glows, and decor in cells (the lamp post beside the spawn is still missing on the low profile).

**Recommendation:** task 1, the streaming loader: the largest remaining memory and startup gain on the tablet, now on the default map.
