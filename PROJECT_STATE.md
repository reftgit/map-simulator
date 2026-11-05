# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`; code structure, build, and test commands are in `docs/ARCHITECTURE.md`.

Last updated: 2026-11-05 (Phase 6e, maps loaded on threads behind a moving loading screen, the release filter written from the registry, Claude Code)

## Current phase

**Phase 6e: maps load on threads behind a moving loading screen; the release filter is written from the release registry (2026-11-05); the iPhone release builds meet the 100 ms frame criterion, map ready is longer, the tablet was not run.** With a RenderingDevice, every map (the start and a switch) is read with `load_threaded_request()` and instantiated on a worker thread while the loading screen's arc turns in every frame and its bar follows the load; then the map is set up in steps over frames (materials and shaders prepared one per frame, the map added hidden, its warm cells, the player, vehicles, and NPCs, the categories grouped a part per frame, the occluders read on threads, the profile, the first cells, the map shown category by category), and a switch frees the old map a part per frame. Headless runs and `"threaded_load": false` load at once as before. On the iPhone 13 Pro the release build's longest loading frame is 72–78 ms (Release Perf 67–71 ms) instead of one frame of about 452 ms, but map ready is 828–886 ms against 726–746 ms loaded at once; the debug build and the Mac's editor still have one reading frame of 104–156 ms (a run of the collision shapes' set-up on the main thread). The Phase 6c worker-thread crash was reproduced (5 of 40 launches) and placed (several loading threads creating the same materials while the main thread waits in `load_threaded_get()`); the loader never waits that way and the final code started 20 of 20 times on the Mac. `tools/release_package.gd -- --write` writes the release presets' exclude filter from `maps_release.tres` (`build_release.sh` runs it); the release packages hold the Phase 6d files plus three new scripts. The Galaxy Tab A7 ran only intermediate builds (no charger: its battery reached 0 %), so its repeat and its checks of the final code are NOT RUN. The iPhone's scenarios passed (13 / 13, 25 / 25, 9 / 9, 21 / 21). Details: "Phase 6e" below.

Before it: **Phase 6d: release presets with only the default map (2026-11-05); the package, check, and device criteria pass; the tablet's repeat was not run.** A map whose GLB is missing is available when its streaming index can be used (`MapDefinition.is_available()`; a missing model does not make the index stale, a changed one does), and "Android Release" and "iOS Release" presets pack the game and only the maps of a separate release registry (`game/world/maps_release.tres`, chosen by the build kind; `main.tscn` names no registry): today the default map as its streaming folder, without its GLB. `tools/build_release.sh android|ios` checks the preset and the cells (it stops with the `cell_map.gd` command when they are missing or stale), exports, and compares the package with the expected files. The APK is 133,546,944 B instead of 1,450,872,615 B and the iOS `.pck` 106,711,460 B instead of 1,423,246,812 B; both hold exactly the 2,707 expected project files. Plain launches of the release builds start on the streamed default map on both devices (`STREAMING … primed` lines; tablet stable PSS 452–464 MiB, iPhone footprint 564–568 MiB) with no debug overlay or MAP button. The iPhone's scenarios passed with the final code (`vehicle_sleep` 13 / 13 and `extensibility` 25 / 25, on the Kenney town 9 / 9 and 21 / 21); in three traced launches streamed and three whole, Galata had no long frame, and the two 20.9 / 21.5 ms frames streamed at other viewpoints came with no cell attached, requested, or freed and no pipeline compiled. The tablet's map-ready, relative long-frame, and route criteria were **not run**: on the user's powered hub the battery still fell from 57 to 53 % in the 10-minute check with the game running (maximum charge current 250–350 mA), and the user chose NOT RUN. Details: "Phase 6d" below.

Before it: **Phase 6c: one streaming loader for every map (2026-11-04, D26); the memory, switch, look, missing-cell, and scenario criteria pass; the tablet's map ready, Safranbolu's memory, and the relative long-frame criterion do not or were not completed, and the route and iPhone criteria pass only in part.** A common cell step (`tools/cell_map.gd`; the import tool runs it) splits any map by its own categories: the facade detail, tree, lamp, and decor meshes go into 50 m cells by the centre of each mesh, uncut, and a resident scene keeps every node, collider, and occluder; `MapStreamer` loads the cells within each category's visibility range + 30 m of the camera (and 1.5 s ahead of it) on a worker thread, one at a time, gives them their meshes within 2 ms per frame, frees them beyond range + 60 m, and loads the needed ones before the frame after a jump (teleport, respawn, VIEW, a switch). Every registry map with streamable meshes (the four İstanbul maps, the Kenney town, the abstract city) and the two test imports were split by the same command; the Apollo relief and the test district have nothing to stream, and a map without its generated cells loads whole. On the Galaxy Tab A7 the default map's stable PSS is 464 MiB instead of 622 (≤ 502: PASS) and six map switches took 3.1–4.7 s with peaks of 547–559 MiB (PASS); on the iPhone 13 Pro the footprint is 597 MiB instead of 862 and the map is ready in 0.77 s instead of 1.22 s at 60 FPS (PASS), but single long frames of 25–40 ms appear at Galata in two of three runs where the whole map has none (no cell loads in those windows); the look within the ranges is identical pixel for pixel on the İstanbul maps, no needed cell was ever missing along a 515 m route walked and driven, and the device scenarios passed on both devices. Not met: the tablet's map ready (median 4.5 s in the measured three-run set, 3.5 s in another session; the battery drained throughout, the Mac's USB port gives less than the load draws), Safranbolu's PSS (341 MiB; only its facade detail streams), the relative long-frame criterion (one pair at 6 % battery, below the limit; eight launches each not run), and the route criterion only partly (no frame over 50 ms next to a cell load and no presented interval longer than the whole map's, but 4 game frames of 51–55 ms the whole map did not have). Details: "Phase 6c" below.

Before it: **Phase 6b: the import tool passed a blind test on two maps it had never seen, after general fixes (2026-11-03, D26).** The unchanged Phase 6a tool was run first on two unseen public-domain maps, converted to GLB without any unit or axis change: Keenan Crane's abstract city (the whole city in one OBJ mesh, arbitrary units, no names) and NASA's Apollo 11 landing site relief (an STL for 3D printing: Z-up, millimetres, inside out). Blind, neither was written (C2 FAIL with a scale suggestion of 20; C3 FAIL "looks Z-up"); with the suggested configuration both played (7 of 8 gameplay tests each), but the city was a toy in one `buildings` mesh and only the relief's base was drawn. General fixes followed, none using the maps' names: axis, unit, and inside-out detection (C2, C3, C7), splitting a mesh that holds many objects and new shape rules (R1, R3), colliders by shape (capsules for trunks and posts, boxes for fences, trimesh for concave buildings, R2), scored spawn and vehicle places, and a report that says how to improve the map and compares runs. Both blind maps are now in the game with a user-style configuration (the city: `"scale": 100`, the tool's own new suggestion; the relief: a display name only) and pass 11 and 10 gameplay tests; the device scenarios passed on both on the Galaxy Tab A7 and the iPhone 13 Pro. Shape classification: 58 of 60 hand-labelled city objects; shape alone matches the names on 92.6 % of the Kenney town and 88.1 % of Safranbolu. Every mesh category of the eight maps is unchanged (25,955 meshes), the Kenney town's car parks on a road, its trees and fences stop the player. Details: "Phase 6b" below.

Before it: **Phase 6a: the project is a map infrastructure (2026-11-02, D26).** A map contract (`docs/MAP_CONTRACT.md`) says what a GLB must and should provide; the render categories moved from `RenderSettings` into each map's data (every one of the five existing maps' 21,458 mesh categories unchanged, the default map's Mac benchmark identical); a general import tool (`tools/import_map.gd`, one command) checks a GLB against the contract, fixes what it can (scale and axes when configured, normals, vertex colours), classifies its meshes, builds colliders and occluders, places the spawn, a vehicle, an NPC route, and viewpoints with physics queries, and writes the map files, the registry entry, and a report. Three maps were imported with configuration only: a CC0 town composed from Kenney's kits (in the game), the user's Safranbolu package (test input only), and the shipped İstanbul GLB under a test id (its 827 collision bodies and 643 occluders reproduced exactly); on each the player spawns, walks 10 s, punches and rolls, the car drives, the NPC patrols, the profiles apply, and a map switch leaves no nodes behind. The device scenario reads its positions from the map and passed on the imported town on both devices. Details: "Phase 6a" below.

Before it: **the shader facade map is the default (2026-11-02).** With D25's criterion 1 made relative by the user (the shader map no worse than İstanbul • Haliç under the same protocol) it passed on the Galaxy Tab A7: nine alternating launches each, one bad launch each, median 1 % low within +0.03 / −0.03 / +0.19 FPS of İstanbul's, average 30.0; the reviewer, to whom the user delegated it, approved the distant windows. So `istanbul_halic_cells_shader` became the first map in the registry in its own revertable commit (`b80c205`), and plain launches of debug and Release Perf builds start on it on both devices (STARTUP logs); İstanbul • Haliç, the test district, the cells map, and the light map stay selectable. A clone without the generated GLB starts on the first available map with a warning (İstanbul where its GLB is copied in, else the test district), and with no map available the game shows an error (`edadb59`). The tablet's presented frames, recorded without changing any setting, show that a bad launch's 28 → 42 → 30 ms loop cycle does not reach the screen, while every launch has about one 16.7 / 50 ms pair per second on the screen that the game loop does not see (open question 43). The `vehicle_sleep` and `extensibility` device scenarios passed again on both devices, starting on the default map (13 / 13 and 25 / 25 each). Details: "The shader facade map is the default" below.

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

Review of Phase 6e; then the next task (see "Recommended next task").

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
- `69357a7`: measurements and documentation (D25 update, T44, open question 43).
- `cbaf661`: the map contract (`docs/MAP_CONTRACT.md`), D26.
- `e7e2c51`: the render categories as map data (`CategoryRules`), equivalence and scan tests, per-test skip.
- `6edfbf1`: the import tool: checks, fixes, categories, colliders, occluders, report.
- `7737eb9`: the import tool's placement and map files (scene, `MapDefinition`, registry).
- `5264d9a`: the three imported maps (the Kenney town in the game, Safranbolu and the İstanbul import as test imports) and their tests.
- `0e542f9`: the device scenario on each map's own points (`sloped_viewpoint`, `scenario.maps`).
- `0aea505`: Phase 6a measurements and documentation.
- `3db25ed`: the blind test of the unchanged tool recorded (two unseen maps, `tools/convert_to_gltf.gd`, `tools/capture_map_shots.gd`).
- `518de92`: up axis, common units, and inside-out shells detected from the geometry (C2, C3, C7).
- `d038df8`: shape classification on real maps: splitting, profiles, a second look at buildings; evaluation tools.
- `80adf44`: colliders by shape: capsules, boxes, trimesh for concave buildings.
- `548d3e5`: scored spawn and vehicle places; the report's improvement advice and comparison.
- `cc21cbe`: the blind-test maps in the game; the Phase 6a maps re-imported.
- `6a59417`: Phase 6b measurements and documentation.
- `5f96ab7`: the streaming design note (`docs/STREAMING.md`).
- `fce9b0c`: the cell step (`tools/cell_map.gd`, `tools/map_import/map_cells.gd`), `MapCell`, `MapStreamingIndex`, `MapDefinition.streaming_index_path`; the import tool runs it.
- `7605e39`: the streaming loader (`MapStreamer`), `WorldManager`, `Main`, the map scripts' `prepare_streamed()`, overlay and logs, runtime keys.
- `a01767f`: every map split and linked, the default map included.
- `104d913`: the route benchmark, the loader changes from the device runs (one request in flight, warm cells, `prepare_streamed_materials()`, the overlay guard, the faster index check), the measurement tools, and the Phase 6c evidence (`docs/perf/phase6c/`).
- `7b94d0d`: Phase 6c documentation.
- `ddaf573`: a map is available through its streaming cells alone (`MapDefinition.is_available()`, `has_required_files()`, `MapStreamingIndex.usable()`, `problem(need_model)`).
- `cc16d76`: the release registry (`game/world/maps_release.tres`, `MapRegistry.for_build()`), the "Android Release" and "iOS Release" presets, `tools/release_package.gd`, `test_release_package.gd`.
- `dd8f785`: the export flow: `tools/build_release.sh`, `tools/check_release.gd`, `tools/release_contents.py`.
- `c202e4f`: measurement tools: cell requests and frees in traces, `streaming_summary.py --timeline`, battery state per Android run, `STREAMING` in `ios_startup_log.sh`, the iPhone's traced viewpoint experiments.
- `1521209`: Phase 6d measurements and documentation.
- `23b4dbd`: maps loaded on threads behind the loading screen, in steps over frames (`MapLoad`, `WorldManager.begin_load()`/`add_loaded()`/`start_streamer()`/`end_load()`, `Main._load_behind_screen()`, `LoadingFrames`, `MapStreamer.prime_some()`/`warm_next()`, `CategoryRules.add_to_groups()`, `RenderSettings.use_loaded_occluders()`, the runtime key `threaded_load`), tests.
- `1e7d539`: the loading screen's turning arc and progress bar (`LoadingSpinner`), tests.
- `9d79333`: the release presets' exclude filter written from the release registry (`tools/release_package.gd -- --write`), test.
- `a432870`: the loading steps' per-frame budget tuned on the iPhone's release build, the 12 ms service window.
- `4e101fb`: the old map freed a part per frame on a switch.
- Phase 6e measurements and documentation: the commit after `4e101fb` (`git log`).

## Repository contents

| Path | Notes |
|---|---|
| `game/` | Game code: composition root, world, player (with Punch/Roll states and `CharacterVisual`), combat areas, vehicle (controller, definition, interaction, visual), camera, input, HUD with on-foot and vehicle control groups and a debug overlay. See `docs/ARCHITECTURE.md`. |
| `maps/istanbul_halic/` | Game map scene (GLB + sky/ambient + sun + water shader + vertex-color fix) and its `MapDefinition` (two debug viewpoints, two NPC routes). |
| `maps/istanbul_halic_cells_light/`, `maps/istanbul_halic_cells_shader/` | The facade maps (2026-11-01, D24; the shader map is the default since 2026-11-02, D25): the cells map's scene structure and data on their generated GLBs; the shader map adds `facade_windows.gdshader` (filtered over the pixel footprint since 2026-11-01, T43), a script that puts it on the facade surfaces and reads the measurement-only facade keys, and `facade_windows_simple.gdshader` (measurement only). They share the cells map's occluders. |
| `maps/istanbul_halic_cells/` | The cells map (2026-11-01): İstanbul's scene structure on the generated `assets/istanbul_halic_cells.glb` (facade detail, tree crowns, shrubs in 40 m cells), a `MapDefinition` with İstanbul's data and `required_files`, its own baked occluders (2,300,915 bytes). |
| `maps/test_district/` | Second map (Phase 5): scene and box occluders generated from Godot primitives by `tools/build_test_district.gd`, `MapDefinition` (both vehicle types, three NPC routes, two viewpoints). |
| `game/world/maps.tres` | The map registry: the shader facade map (the default since 2026-11-02), İstanbul • Haliç, the test district, the cells map, the light facade map, the Kenney town (Phase 6a); a map whose GLB is missing is skipped, and the default is then the first available one. Debug and Release Perf builds load it (`MapRegistry.for_build()`). |
| `game/world/maps_release.tres` | The release registry (Phase 6d): the maps a release package carries (the default map); normal release builds load it. |
| `tools/build_release.sh`, `tools/check_release.gd`, `tools/release_package.gd`, `tools/release_contents.py` | Phase 6d: the release package's check, export, and listing (`docs/ARCHITECTURE.md`, "Release builds"). |
| `docs/perf/phase6d/` | Phase 6d evidence (README): the release packages' contents and listings, the release builds on both devices, the tablet's battery check, the iPhone's scenarios and traced viewpoint runs (`.gdignore`). |
| `game/world/category_rules.gd`, `category_rule.gd` | A map's render categories (Phase 6a): ordered rules (prefix, regex, words, material, group), a default category, the occluder categories. `maps/istanbul_halic/istanbul_halic_categories.tres` (shared by the four İstanbul maps), `maps/test_district/test_district_categories.tres`. |
| `docs/MAP_CONTRACT.md` | The map contract (Phase 6a): rules C1–C8 and R1–R8, vocabulary, placement, configuration, outputs, user steps. |
| `tools/import_map.gd`, `tools/map_import/` | The map import tool (Phase 6a, hardened in 6b): importer, units and axes, geometry, classifier, colliders, placement, writer, report; evaluation tools `sample_sheet.gd` and `compare_categories.gd` (Phase 6b). |
| `tools/convert_to_gltf.gd`, `tools/capture_map_shots.gd` | Phase 6b: OBJ, STL, FBX to GLB without unit or axis change; the four report shots of a map. |
| `maps/abstract_city/`, `maps/apollo11_site/` | The Phase 6b blind-test maps made by the import tool (registry entries 9 and 10): scene, `MapDefinition`, category rules, processed model (7,798,796 B with its textures; 3,363,215 B), occluders; `source/` (`.gdignore`): the converted GLB, its configuration, the city's public-domain README. Sources and licences: `docs/maps/imported/abstract_city_source.md`, `apollo11_site_source.md`. |
| `maps/kenney_town/` | The CC0 Kenney town made by the import tool (re-imported in Phase 6b with colliders by shape and a scored car place): scene, `MapDefinition`, category rules, processed model (975,741 B), occluders; `source/` (`.gdignore`): the composed GLB (2,463,348 B), its configuration, Kenney's licence. Composer: `tools/maps/kenney_town/compose_town.gd`. |
| `docs/maps/imported/` | Import reports of the five imported maps (the Kenney town, Safranbolu, the İstanbul import, the abstract city, the Apollo relief), the sources and licences, four shots per map (`shots/`, `.gdignore`); `blind/`: the Phase 6b blind runs (reports, configurations, logs, shots), the hand labels and shape-only comparisons (`labels/`), and the final comparison (README). |
| `game/world/map_streamer.gd`, `map_streaming_index.gd`, `map_cell.gd` | Streaming (Phase 6c): the loader, the index, a cell. `docs/STREAMING.md`. |
| `game/world/map_load.gd`, `game/ui/loading_spinner.gd`, `game/debug/loading_frames.gd` | Loading on threads (Phase 6e): a map scene read and instantiated on worker threads, the loading screen's arc, the loading screen's frame record. `docs/STREAMING.md`, "Loading a map". |
| `tools/cell_map.gd`, `tools/map_import/map_cells.gd` | The cell step (Phase 6c): any map into a resident scene and streaming cells. |
| `maps/<map>/streaming/` | **Not tracked**: each map's resident scene, cells, materials, and index, written by `tools/cell_map.gd -- --all` on each machine (the default map 104 MB; the four İstanbul maps 649 MB, plus 103 MB for the default map's 100 m comparison split in `streaming_100/`); without them a map loads whole. |
| `tools/capture_streaming.gd`, `tools/perf/make_route.gd`, `tools/perf/streaming_summary.py` | Phase 6c: streaming on and off side by side with the pixel difference; a route over walkable ground for the route benchmark; streaming in benchmark results. |
| `docs/perf/phase6c/` | Phase 6c evidence (README): the look comparison (40 sheets), the Mac cell sizes, probes, and every streamed map on and off, the tablet's memory, routes, relative pair, Safranbolu, switch, and scenarios, the iPhone's runs of builds B, D, F (`.gdignore`; large files gzipped). 5.7 MB. |
| `docs/perf/phase6b/` | Phase 6b evidence: device scenario results and logs, the tablet measurements, the Mac benchmarks of the default map, the category dumps (`.gdignore`). |
| `docs/perf/phase6a/` | Phase 6a evidence: device scenario results and logs, the tablet measurements, the Mac benchmarks of the default map, the category dump (`.gdignore`). 0.35 MB. |
| `tests/imported/` | **Not tracked**: the test imports of Safranbolu and of the shipped İstanbul GLB (regenerated with the commands in their reports); excluded from every export with the rest of `tests/`. |
| `game/npc/` | `Npc`, `AiPatrolInput`, `PatrolRoute`, `npc.tscn` (inherits the player scene). |
| `project.godot` | Main scene `res://game/main.tscn`; Mobile renderer; sensor landscape; `expand` aspect; physics interpolation; input actions; mouse emulates touch; ETC2/ASTC import (required for Android export); placeholder icon. |
| `export_presets.cfg` | "Android Debug" (arm64 APK, `com.mirongi.mapsimulator`), "Android Debug Compatibility" (same, with `--rendering-method gl_compatibility`), "iOS Debug" (`com.mirongi.mapsimulator.dev`, team `8N7RYA42S6`, project-only export), and the measurement-only "Android Release Perf", "Android Release Perf Jolt", "iOS Release Perf" (`perf_bench`; release templates). No passwords or keystore paths. |
| `icon.svg` | Placeholder app icon (capsule character over water). |
| `tests/` | Headless runner (a single test can `skip()`), 235 unit tests, 139 integration tests (2026-11-03, Phase 6b; in a clean clone without any GLB 287 run, among them the test district's, the Kenney town's, and the two blind maps', and 87 SKIP), fixtures (flat map, fake platform, the old category table, import configurations), original map validation; `imported/` holds the test imports (not tracked). The test van moved into the game in Phase 5. |
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

- **Loading on threads (Phase 6e, 2026-11-05; builds with a RenderingDevice):** every map load at the start and on a switch reads and instantiates the map on worker threads and sets it up in steps over frames behind a loading screen whose arc turns in every frame and whose bar shows the progress; a switch frees the old map a part per frame; `LOADING` lines in every build. Headless runs and `"threaded_load": false` load at once. The release presets' exclude filter is written from the release registry (`tools/release_package.gd -- --write`, run by `tools/build_release.sh`).
- **Release presets (Phase 6d, 2026-11-05):** "Android Release" and "iOS Release" build the game with only the release registry's maps (the default map, streamed, without its GLB), no `perf_bench`, for local testing (debug keystore, development profile); `tools/build_release.sh` checks, exports, and lists them. A map is available from its cells alone (all builds); normal release builds load the release registry.
- **Streaming (Phase 6c, 2026-11-03/04; all builds):** a map whose definition points at a usable streaming index loads its resident scene and streams its facade detail, trees, lamps, and decor around the camera (`MapStreamer`); every map of the registry with such meshes is linked (the cells are generated on each machine by `tools/cell_map.gd`; without them maps load whole). Debug and Release Perf builds: `STREAMING` and `STARTUP` lines, the runtime keys `streaming` and `streaming_index`, the route benchmark. Debug builds: the overlay's cells line. Tools: the cell step (also run by the import tool), `capture_streaming.gd`, `make_route.gd`.
- **Import tool hardening (Phase 6b, 2026-11-03):** axis, unit, and inside-out detection, splitting of single-mesh cities, shape rules, colliders by shape, scored placement, improvement advice and comparisons in the report (desktop tool, not in builds); the abstract city and the Apollo relief in the registry (debug and Release Perf builds can select them; normal release builds load only the default); the Kenney town re-imported (trees, lamps, fences collide; its car on a road).
- **Map infrastructure (Phase 6a, 2026-11-02):** render categories from each map's `CategoryRules` (all builds; behaviour of the existing maps unchanged); the import tool (`tools/import_map.gd`, desktop tool, not in builds); the Kenney town in the registry (debug and Release Perf builds can select it; normal release builds load only the default); the device scenario on any map's points (debug builds).
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

## Phase 6e — maps loaded on threads behind a moving loading screen; the release filter written from the registry (2026-11-05)

Task of 2026-11-05 (user): the resident scene (and any map loaded whole) loaded with `load_threaded_request` at the start and on a switch behind a loading screen whose indicator moves every frame, adding the map, the first cells, and the material set-up split over frames, single-frame jobs measured; the Phase 6c worker-thread crash reproduced and its cause researched; requests safe on focus loss, pause, and a switch, two maps never in memory at once; the main-thread path kept headless; the release presets' exclude filter written from `maps_release.tres`; verification on the Mac and both devices; the tablet's criteria repeated only with a charger that keeps up. The user first chose a charger with wireless adb; the tablet stayed on a 250 mA supply, reached 0 %, and the user then answered that there is no charger and that the tablet's checks of the final code are not run. Decisions: `PROJECT_CONTEXT.md`, T59, T60; design: `docs/STREAMING.md`, "Loading a map"; evidence: `docs/perf/phase6e/` (README).

### What exists now

- **Loading on threads** (`23b4dbd`, `a432870`, `4e101fb`; T59): `MapLoad` (`game/world/map_load.gd`) reads a map scene with `load_threaded_request()` (its scripts loaded on the main thread first) and instantiates it on a `WorkerThreadPool` task; `WorldManager.begin_load()`, `add_loaded()`, `start_streamer()`, `end_load()` (and `finish_load()`/`load_map()` at once); `Main._load_behind_screen()` polls it once per frame with 12 ms of service (status checks that run the rendering server's queued work, the loading thread's physics work run in between), then `_steps_after_reading()` over frames: the occluders read on threads (`RenderSettings.use_loaded_occluders()`), a streamed map's materials prepared one per frame (`prepare_streamed_materials()`) and the script's shaders built one per frame, the map added hidden, its streamer and warm cells (`MapStreamer.warm_next()`), the player, vehicles, and NPCs (hidden), the meshes grouped a part per frame (`CategoryRules.add_to_groups()`), the profile with every category hidden, the first cells (`MapStreamer.prime_some()`), the map shown category by category; at most 16 ms of steps and 1–4 steps whose cost shows in the frame's drawing per frame (`Main._run_loading_steps()`). A switch frees the old map's crowded nodes 512 per frame after stopping its streamer (`WorldManager.unload_map_and_wait()`). `Main.threaded_loading` follows whether there is a RenderingDevice; headless runs, the capture tools, and the runtime key `"threaded_load": false` load at once as before.
- **The loading screen** (`1e7d539`): a turning arc (`LoadingSpinner`) that moves by the frame's time in every frame it is shown (also while paused) and a bar with the load's progress (`UIController.set_loading_progress()`).
- **The record** (`LoadingFrames`, `game/debug/loading_frames.gd`): `LOADING`, `LOADING_STEPS`, `LOADING_LOAD`, `LOADING_FRAMES` lines after every load in every build (short enough for Android's log); perf builds keep each frame's steps, render times, pipeline compilations, and marks in `STARTUP`'s `loading`; `map_switch` scenario steps carry their switch's summary.
- **The release filter** (`9d79333`, T60): `tools/release_package.gd -- --write` (`--check`) writes both release presets' exclude filter from the release registry; `tools/build_release.sh` writes it before every export and `check_release.gd` stops on a preset that carries another. Written today it is the Phase 6d filter reordered (22 patterns, no map named by hand in the fixed part).
- **Measurement:** experiments `e_load_start_high` / `e_load_start_low` (and `…_at_once`), `scenario_map_switch_load` (and `…_at_once`); `tools/perf/ios_startup_log.sh` keeps the `LOADING` lines.

### Acceptance criteria (task of 2026-11-05)

| Criterion | Result | Status |
|---|---|---|
| No frame over 100 ms while loading, the indicator moving every frame (tablet and iPhone; Mac measured) | iPhone release build: longest 75.3 / 72.1 / 78.4 ms (three plain launches), the arc in every frame (18 / 25 / 30 of 18 / 25 / 30); Release Perf: 71.1 / 68.7 / 67.1 ms. iPhone debug build: 145–156 ms at the start and 148–151 ms in each of four switches (the reading's collision set-up). Mac (debug): one frame of 104–118 ms in 16 of 20 starts (median longest 107.8 ms), 86.5–108.1 ms in four switches. Galaxy Tab A7: final code not run; intermediate builds 178–222 ms | PASS iPhone release builds; FAIL iPhone debug and Mac (one reading frame); NOT RUN tablet |
| Map ready no worse (iPhone ~765 ms; tablet ≤ 4.0 s if measured) | iPhone Release Perf: 886 / 847 / 828 ms threaded against 746 / 726 / 739 ms at once (first frame 900 / 858 / 844 against 810 / 791 / 798 ms); Mac: median 884.5 against 805 ms; tablet (intermediate): 4.7–5.1 s against 3.6 s at once | FAIL (+100–150 ms on the iPhone) |
| A switch's peak PSS ≤ the larger map's stable PSS + 50 MiB, no low-memory kill; two maps never at once (test) | tablet not run; the test `test_a_switch_loads_behind_the_screen_with_one_map_at_a_time` (the old map freed before the new one enters the tree) passes; Mac RSS peaks 499–559 MiB threaded against 491–520 MiB at once (four switches each); iPhone footprint (probes every ~45 s) 549 against 530 MiB | NOT RUN (tablet); the rule tested |
| 0 of 20 crashes on the Mac on the threaded path (or a justified safe path) | the Phase 6c crash reproduced (5 of 40) and placed; the final code 0 of 20 twice (`a432870`, and before the split into commits) | PASS |
| The release filter written from `maps_release.tres`; test; the package's content and size unchanged | `test_release_package.gd` (the written filter, a fake new map folder left out with the package unchanged); APK 133,572,011 B (Phase 6d: 133,546,944), `.pck` 106,734,472 B (106,711,460), `.app` 189,756 KiB (189,732); 2,710 project files = Phase 6d's 2,707 + `map_load.gd`, `loading_frames.gd`, `loading_spinner.gd`; 0 unexpected, missing, or orphaned | PASS |
| Tablet criteria with enough power, else NOT RUN with the reason | no charger (the supply reported 250 mA, the battery reached 0 %; `docs/perf/phase6e/tablet/power.md`) | NOT RUN |
| iPhone scenarios with the final code | debug build of `4e101fb`: `vehicle_sleep` 13 / 13, `extensibility` 25 / 25, on the Kenney town 9 / 9 and 21 / 21 | PASS |
| Every Phase 1–6d test; Platform, preset, `.gdignore` tests | every commit: full suite 0 failed, 0 skipped (exit 0), unit 0 failed (below) | PASS |

### Loading screen frames, before and after

"At once" is the same build with `"threaded_load": false`, the load as before Phase 6e (one frame from the load's start to the first frame drawn with the map; at the start the boot splash stays on screen meanwhile).

| Where | Threaded: longest frame (its steps), frames over 100 ms | At once: the load's frame | Map ready, threaded / at once |
|---|---|---|---|
| iPhone 13 Pro, release build, start (3) | 75.3, 72.1, 78.4 ms (the warm cells, the player, the grouping); 0; 18–30 frames after 73–104 ms of boot | — (Phase 6d's release build loaded at once) | — (no `STARTUP` in release builds) |
| iPhone, Release Perf, start (3 pairs) | 71.1, 68.7, 67.1 ms; 0 | 454.3, 451.5, 452.4 ms | 886, 847, 828 / 746, 726, 739 ms |
| iPhone, debug, start (scenario runs) | 145.0–155.6 ms (reading); 1 | 573.8 ms | 1,018–1,022 / 883 ms |
| iPhone, debug, four switches | 148.0–151.3 ms (reading); 1 each; 40–47 frames, 846–979 ms | 523.9–552.7 ms; 739–887 ms | — |
| Mac (M5, editor debug), low, start (20 / 10) | median 107.8 ms (33.6–117.5, reading); 16 of 20 launches | 452.4–471.9 ms | median 884.5 (850–1,668) / 805 (789–820) ms |
| Mac, profile none, four switches | 86.5–108.1 ms (reading); 3 of 4; 79–123 frames | 1,431–2,243 ms | — |
| Galaxy Tab A7, intermediate Release Perf, low (`tablet/intermediate/`) | 177.6–221.7 ms (reading); 1–7 | 2,362–2,372 ms | 4,735–5,113 / 3,631–3,659 ms (first launches after install 9.7–10.1 s) |

- **The long reading frame** is a run of the physics work the loading thread queued (its collision shapes are set up on the main thread; GodotPhysics3D is not threaded here): one run goes on while the loading thread keeps adding to it, so it cannot be split (`serve_max_ms` 148–181 ms on the tablet's intermediate builds; the rest of a long frame lands in the next frame's physics step). Moving it off the main thread would need `physics/3d/run_on_separate_thread`, a change to the physics' threading (open question 37).
- **Single-frame jobs measured on the tablet** (intermediate and probe builds, one step per frame): the map entering the tree with its script's `_ready()` 96–121 ms frames, the first build of the window shader 79–144 ms, a warm cell 69–104 ms, the car 61–80 ms of main-thread time (frames 72–109 ms with the player's placing), the frame in which the map's sky was first drawn 68–160 ms; before the steps were split the frame that added the map took 0.5–1 s and the first drawing of the unlimited map 0.2–0.6 s.
- **Why map ready is longer:** the frames between steps (each step after the reading waits for a frame when it is costly) and the boot splash's first frame now drawn before the map loads. On the iPhone the reading itself is not slower (the scene read in 259–265 ms on threads against 306–312 ms at once; the run of collision set-up 34 ms there).
- **Memory:** iPhone footprint 601–602 MiB threaded against 568–570 MiB at once (video memory 286 against 274 MiB, the same objects and draw calls); not investigated further.

### The Phase 6c crash (Mac, `docs/perf/phase6e/desktop/crash/`)

Reproduced with the old threaded prime from `Main._ready()` when the loading threads created the streamed materials for the first time: 3 of 20, then 2 of 20 launches crashed in a worker thread, at the same addresses as Phase 6c's eleven crash reports. With the main thread not waiting in `load_threaded_get()` while the loads ran: 0 of 40; with one request at a time: 0 of 40; with the materials loaded on the main thread first (the current setup): 0 of 20. The official binary has no symbols for Godot's code; Godot 4.7.2's source shows a race that fits (`load_threaded_get()` on the main thread runs `RenderingServer::sync()` every millisecond, which executes queued `material_set_shader()` calls deleting a material's data while a loading thread's `mesh_generate_pipelines()` reads it). The loader follows the rules that avoid it (`docs/STREAMING.md`, "Loading a map"); the final code: 0 of 20 launches crashed (and 0 of 20 before the split into commits), no leaked objects at exit.

### Release packages (`docs/perf/phase6e/release/`)

`tools/build_release.sh android|ios` of `4e101fb`: the written filter is current ("already current"), the check passes, APK 133,572,011 B, iOS `.pck` 106,734,472 B, `.app` 189,756 KiB; 2,710 project files in each, the Phase 6d list plus the three new scripts (`expected_files_vs_6d.diff`); no Android permissions; minSdk 24, targetSdk 36.

### The tablet: NOT RUN

The user chose a charger with wireless adb; adb was put on TCP over Wi-Fi from USB, but the tablet stayed on a supply reporting a maximum charge current of 250 mA and went from 31 % to 0 % (−0.73 to −1.06 A under load) during the probe builds; the user then answered "no charger" (the repeat: NOT RUN) and, after it switched off, not to check the final code on it either. Its numbers above come from intermediate builds (README in `tablet/intermediate/`). Open question 51 stays open.

### Tests (2026-11-05)

- `godot --headless --path . --import`: exit 0.
- Full suite in this checkout (every GLB, the test imports, every map's cells): `23b4dbd` 425 passed; `1e7d539` 427; `9d79333` 429; `a432870` 429; `4e101fb` (with the documentation commit's experiments and test rule) 429; 0 failed and 0 skipped each, exit 0. Unit only: 273, 275, 277, 277, 277, exit 0.
- Clean clones without any GLB, test import, or cells (SKIPs expected, exit 2): `23b4dbd` 336 passed, 89 skipped; `1e7d539` 338 / 89; `9d79333` 340 / 89; `a432870` 340 / 89; `4e101fb` 340 / 89; 0 failed each; unit 273, 275, 277, 277, 277, exit 0; `check_release.gd` exits 1 there with the `cell_map.gd` command.
- The same with the default map's streaming folder copied in and no GLB (`4e101fb`): 341 passed, 0 failed, 88 skipped (exit 2), unit 277; the game starts on the default map from its cells (`STREAMING istanbul_halic_cells_shader primed …`); `check_release.gd` exits 1 (no model to compare the cells with). Records: `docs/perf/phase6e/tests/test_runs.txt`.
- New tests: `test_map_load.gd` (6), `test_world_manager.gd` (+3), `test_ui_controller.gd` (+2), `test_loading_screen.gd` (3), `test_release_package.gd` (+2).
- `tests/map/validate_scene.gd`: `VALIDATION PASS | failures=0`.
- GLB SHA-256 at the start and the end: `8b00c94b…`, `7973071a…`, `6531ca28…`, `60b9f729…`, unchanged.
- Before the commits: a secret scan of the staged changes, a search for personal home-folder paths (only the test that forbids them matches), the release presets' and every preset's keystore fields empty; the evidence's home-folder paths replaced by `~`, Instruments recordings and full device logs left out, no device serials or UDIDs.

## Phase 6d — release presets with only the default map; the tablet's repeat not run (2026-11-05)

Task of 2026-11-05 (user): a map with a usable streaming index available without its GLB; "Android Release" and "iOS Release" presets that pack the game and only the default map, streamed, with a release registry, a check before export that stops when the cells are missing or stale, and one command to export; package sizes and contents, the release build on both devices; the tablet's map-ready, relative long-frame, and route criteria repeated with enough power (only if the battery holds for 10 minutes); the iPhone's scenarios with the final code and its Galata long frames checked against cell loading. The user chose a powered USB hub for the tablet; when the battery still fell, the user chose NOT RUN. Evidence: `docs/perf/phase6d/` (README).

### What exists now

- **Availability:** `MapDefinition.is_available()` is true when the required files (the GLB) can be loaded, or else when the streaming index can be used (`MapStreamingIndex.usable()`: the resident scene, every cell, material, and shared mesh present; a model that is there and changed size makes it stale, a model that is not there does not). `has_required_files()` is the old rule, used where the whole scene is needed (the cell step's `--all`, comparisons with the map loaded whole). A map without its required files streams even with `"streaming": false`. Warnings and the no-map error say when an index cannot be used either.
- **Release registry:** `game/world/maps_release.tres` lists the maps a release carries (the default map). `main.tscn` no longer names a registry; `Main._ready()` takes `MapRegistry.for_build()`: `maps.tres` in debug and Release Perf builds, the release registry in normal release builds.
- **Release presets:** "Android Release" and "iOS Release" (no custom features, `com.mirongi.mapsimulator` / `com.mirongi.mapsimulator.dev` on team `8N7RYA42S6`, empty keystore fields, iOS development export of the Xcode project). Their exclude filter leaves out `tests/`, `tools/`, `docs/`, `assets/*` (every GLB), the explorer demo, `maps.tres`, `maps/*/streaming_*`, and every map file the release maps do not use; what stays of the maps: the default map's definition, script, shaders, and streaming folder, İstanbul's map script and category rules, the cells map's occluders, `scripts/water.gdshader`.
- **Export flow:** `tools/build_release.sh android|ios [udid]`: `tools/check_release.gd` (library `tools/release_package.gd`) checks the preset against what the release maps need and the release maps' cells against their GLB on this machine, and stops with the `cell_map.gd` command when they are missing or stale; then the export (Android through `build_android_perf.sh`, signed with the debug keystore; iOS Xcode Release with development signing, no `-allowProvisioningUpdates`) and `tools/release_contents.py`, which lists the APK or `.pck` and compares it with the expected files.
- **Measurement tools:** traced benchmarks list the frames in which cells were requested and freed besides the attaches; `streaming_summary.py --timeline` places every long frame against them and against pipeline compilations; `android_bench.sh` records the battery's level, charge current, and source at the start and end of each run; `ios_startup_log.sh` keeps `STREAMING` lines.

### Acceptance criteria (task of 2026-11-05)

| Criterion | Result | Status |
|---|---|---|
| `is_available()` works with an index; tests | GLB present/missing/changed × index none/usable/incomplete (`test_a_usable_index_makes_a_map_available_without_its_model`), the game starting from the cells alone with streaming on and off (`test_a_map_without_its_model_starts_from_its_cells`), a clean clone with only the default map's streaming folder copied in (below) | PASS |
| Release presets and a one-command export; preset test; export stops with a clear message without cells | both presets, `tools/build_release.sh`; `test_release_package.gd` (registry per build kind, exclusions against every map of the full registry, no `perf_bench`, keystores, D8, the simulated packages, the export check on a synthetic map); in a clean clone `check_release.gd` exits 1 with `RELEASE istanbul_halic_cells_shader: no cells written (…_index.tres missing). Write them: godot --headless --path . --script res://tools/cell_map.gd -- --map=istanbul_halic_cells_shader, then godot --headless --path . --import`, and with only the cells copied in (no GLB) with `its cells cannot be packed (missing res://.godot/imported/istanbul_halic_cells_shader.glb-….scn, the model to compare the cells with)` | PASS |
| Package sizes clearly below 1.45 GB / 1.42 GB; contents as expected | APK 133,546,944 B (−90.8 %), iOS `.pck` 106,711,460 B (−92.5 %; the signed `.app` 189,732 KiB); both hold exactly the 2,707 expected project files (0 unexpected, 0 missing, 0 orphaned); no Android permissions | PASS |
| The release build starts on the streamed default map on both devices; no debug tools | tablet: three plain launches, `STREAMING istanbul_halic_cells_shader primed 6 cells`, stable PSS 464 / 452 / 464 MiB, screenshots with gameplay controls only; iPhone: `STREAMING … primed 38 cells`, footprint 564 / 568 / 566 MiB, screenshots with gameplay controls only | PASS |
| Tablet: map ready, relative criterion, routes with enough power | the 10-minute check failed (57 → 53 % with the game running, −0.67 to −0.91 A, maximum charge current 250–350 mA on the hub); not measured, by the task's rule and the user's choice | NOT RUN |
| iPhone scenarios with the final code; Galata long frames checked | debug build of `c202e4f`: `vehicle_sleep` 13/13, `extensibility` 25/25, on the Kenney town 9/9 and 21/21; Galata: three traced launches streamed and three whole: no long frame at Galata in any; two frames of 20.9 and 21.5 ms at the other viewpoints streamed (none whole), with no cell attached, requested, or freed and no pipeline compiled in their windows; the pacing state in 7 of 9 streamed and 6 of 9 whole windows | PASS (scenarios; the long-frame check reported: nothing ties the frames to cell loading) |
| Phase 1–6c tests; Platform, preset, `.gdignore` tests | full suite 0 failed, 0 skipped (exit 0) at every commit: 407, 412, 413, 413 passed at `ddaf573`, `cc16d76`, `dd8f785`, `c202e4f`; unit 258–264; clean clones 0 failed at every commit (exit 2, SKIPs expected) | PASS |

### Packages (2026-11-05)

| | Release Perf (Phase 6c, every map) | Release (Phase 6d) |
|---|---|---|
| Android APK | 1,450,872,615 B | 133,546,944 B |
| iOS `.pck` | 1,423,246,812 B | 106,711,460 B |
| iOS `.app` (signed, before install) | 1,475,412 KiB | 189,732 KiB |
| Project files packed | 10,468 (iOS) | 2,707 |

What the release package holds (`docs/perf/phase6d/release/`, `*_contents.txt`, full listings gzipped): `maps/istanbul_halic_cells_shader/streaming/` 2,621 packed files, 103.4 MB (index, resident scene, 2,612 cells, 7 materials); the cells map's occluders 2.3 MB; the default map's definition, script, and two shaders; İstanbul's map script and category rules; `scripts/water.gdshader`; the game code and scenes (`game/`), the icon, the release registry. No GLB, no imported GLB scene, no other map, no `streaming_100/`, no `tests/`, `tools/`, or `docs/`. `aapt dump permissions`: none; package `com.mirongi.mapsimulator`, version 0.1.0 (1), minSdk 24, targetSdk 36, not debuggable.

### The release build on the devices (2026-11-05)

| | Galaxy Tab A7 (low) | iPhone 13 Pro (high) |
|---|---|---|
| Launch | plain, three times (`am start`, no experiment) | plain under an os_log recording, then three plain launches |
| Log | `QUALITY profile=low …`, `STREAMING istanbul_halic_cells_shader primed 6 cells in 16 ms …, load {"index_ms":32.8,"scene_ms":1697.3,…,"streamed":true}` | `QUALITY profile=high …`, `STREAMING istanbul_halic_cells_shader primed 38 cells in 11 ms …, load {"index_ms":13.4,"scene_ms":341.1,…,"streamed":true}` |
| Memory after 60 s / 25 s | stable PSS 475,181 / 462,360 / 475,211 kB (464 / 452 / 464 MiB), peak 465 / 462 / 464 MiB | footprint 564 / 568 / 566 MiB, thermal Nominal |
| Process start to the `STREAMING` line | 4.99 / 3.99 / 4.02 s (battery draining, see below) | — |
| Screen | joystick, roll, punch, run; no overlay, VIEW, Q, DUMMY, CAR, or MAP | the same |

Normal release builds print `QUALITY` and `STREAMING` (no `STARTUP`: that needs `perf_bench`). The tablet's first attempt ran into the lock screen (the tablet had locked itself; 43 MiB PSS, no game log); the user unlocked it and the three launches above followed.

### The tablet's repeat: NOT RUN

The task allowed the repeat only if the battery held for 10 minutes. With the tablet on the user's powered hub ("AC powered"), the game running at the spawn on the low profile, read every 30 s (`docs/perf/phase6d/tablet/power/check1.tsv`): level 57 → 53 %, current −0.67 to −0.91 A with the game in front (−0.51 A at the first reading, before it), temperature 29.5 → 32.5 °C, maximum charge current reported 250–350 mA (the same as on the Mac's port in Phase 6c). The user chose NOT RUN. Map ready (three runs), D25's relative criterion (nine alternating launches each), and the routes (three runs each with presented frames) remain open (open question 51).

What can be said without new runs, from the Phase 6c route traces (build F, battery draining; `streaming_summary.py --timeline`, which now also counts pipeline compilations next to a long frame): the walk out has a heavy spot about 20 s in (90 m from the start) in every run: 52.1 ms (F), 51.8–52.1 ms (D run 2, three frames), 51.3 ms (E) streamed, and 46.7 ms with the map loaded whole (D); GPU time there is 29–30 ms in all of them against a median of 25–26 ms. Two of F's four frames over 50 ms had a pipeline compiled within one frame (one of them with 25.5 ms of render CPU time); the nearest attach was 3–10 frames away; the Phase 6c traces have no requests or frees. So at least part of the 51–55 ms frames are a place that is heavy with or without streaming, pushed over 50 ms by a few milliseconds; whether a cell's first draw (a new pipeline) or a load in flight adds those milliseconds needs the repeat with the new trace fields.

### iPhone (Release Perf and debug builds of `c202e4f`, 2026-11-05)

Scenarios (debug build, plain start on the default map, streamed; `docs/perf/phase6d/iphone/scenarios/`): `vehicle_sleep` 13 / 13 and `extensibility` 25 / 25 on the default map, 9 / 9 and 21 / 21 on the Kenney town (the Phase 6c runs used the debug build C, before the warm cells and the one request in flight).

Galata and the single long frames (Release Perf, high profile, three viewpoints per launch, 30 s warm-up and 60 s per viewpoint, traced; three launches streamed and three whole, alternating; thermal Nominal throughout; `docs/perf/phase6d/iphone/galata/`, `timeline.md`):

| Run | Streamed: long frames Spawn / Karaköy / Galata | Longest frame | 1 % low at Galata | Whole: long frames | Longest frame | 1 % low at Galata |
|---|---|---|---|---|---|---|
| 1 | 0 / 0 / 0 | 20.0 ms | 53.59 | 0 / 0 / 0 | 20.1 ms | 56.02 |
| 2 | 1 / 0 / 0 | 20.9 ms | 53.52 | 0 / 0 / 0 | 20.8 ms | 53.32 |
| 3 | 0 / 1 / 0 | 21.5 ms | 53.44 | 0 / 0 / 0 | 20.4 ms | 53.25 |

- **Galata:** no long frame in any of the six launches (the Phase 6c streamed runs had 25.1 and 39.8 ms frames there in two of three).
- **The two long frames** (20.9 ms at the spawn, 21.5 ms at Karaköy; the benchmark counts frames longer than 1.25 times the window's median, here 16.6–16.7 ms, so about 20.9 ms) came with no cell attached, requested, or freed anywhere in their measurement windows (the streamer did nothing at the fixed viewpoints after the warm-up) and no pipeline compiled; the whole map's longest frames are as long (20.1–20.8 ms) and just under the threshold. Nothing ties them to cell loading.
- **The pacing state** (the engine's process time near 16.5–17 ms instead of about 5 ms; Phase 6c: 15 of 27 streamed windows against 2 of 27 whole) was in 7 of 9 streamed and 6 of 9 whole windows in this session, so it is not a streaming effect either; the Galata 1 % low of 53.3–53.6 comes with it, streamed or whole (the whole map's 56.0 in run 1 is the window without it).
- Footprint 595 / 590 / 591 MiB streamed, 858 / 862 / 859 MiB whole; map ready 741 / 749 / 764 ms streamed, 1,275 / 1,207 / 1,211 ms whole.
- GPU times read 0.0 on iOS in these traces (Godot reports none with Metal here), so the frames cannot be split into CPU and GPU from the trace.

### Tests (2026-11-05)

- `godot --headless --path . --import`: exit 0.
- Full suite in this checkout (every GLB, the test imports, every map's cells): `ddaf573` 407 passed; `cc16d76` 412; `dd8f785` 413; `c202e4f` 413; 0 failed and 0 skipped each, exit 0. Unit only: 258, 263, 264, 264, exit 0.
- Clean clones without any GLB, test import, or cells (SKIPs expected, exit 2): `ddaf573` 318 passed, 89 skipped; `cc16d76` 323 / 89; `dd8f785` 324 / 89; `c202e4f` 324 / 89; 0 failed each; unit 258, 263, 264, 264, exit 0. A plain launch in such a clone still falls back to the test district, now with `Default map 'istanbul_halic_cells_shader' is not available (missing: res://assets/istanbul_halic_cells_shader.glb; its streaming index cannot be used); loading 'test_district'`. `tools/check_release.gd` exits 1 there with the `cell_map.gd` command (`docs/perf/phase6d/tests/test_runs.txt`).
- The same with the default map's streaming folder copied in and no GLB ("GLB missing, index present"): 325 passed, 0 failed, 88 skipped (exit 2), unit 264: `test_the_registry_maps_cells_are_current` runs instead of skipping, and `test_starts_on_the_registry_default` starts the game on the default map from its cells (`STREAMING istanbul_halic_cells_shader primed …`, no warning); `check_release.gd` exits 1 because there is no GLB to compare the cells with.
- `tests/map/validate_scene.gd`: `VALIDATION PASS | failures=0`.
- GLB SHA-256 at the start and the end: `8b00c94b…`, `7973071a…`, `6531ca28…`, `60b9f729…`, unchanged.

## Phase 6c — a streaming loader for any map (2026-11-03/04)

Task of 2026-11-03 (user): one streaming mechanism for every map the import tool writes and for the İstanbul generator's maps (D26), with no map-specific code; a map without an index loads whole, as before; the look within the profiles' ranges, collision, gameplay, the profile values, the physics, and the default map unchanged. The user's blind-test field was left empty ("YOK"), so no new map was imported blind. Decisions: `PROJECT_CONTEXT.md`, T54–T56; design: `docs/STREAMING.md`; evidence: `docs/perf/phase6c/` (README).

### What exists now

- **Design note** (`docs/STREAMING.md`, `5f96ab7`).
- **The cell step** (`fce9b0c`, T54): `tools/cell_map.gd` (library `tools/map_import/map_cells.gd`) splits any map from its `MapDefinition`: the facade detail, tree, lamp, and decor meshes (by the map's own `CategoryRules`) go into `MapCell` files of a 50 m grid by their centres; the resident scene keeps every node and collider with those meshes taken out; materials and meshes used in more than one place get files of their own; a `MapStreamingIndex` is linked from `MapDefinition.streaming_index_path`. The import tool runs it after writing a map (`--no-cells` skips it). Outputs are generated on each machine and ignored by Git.
- **The loader** (`7605e39`, T55): `MapStreamer` (`game/world/`), added by `WorldManager` for a map with a usable index; `Main` gives it the camera and the ranges and primes it after loads. Cells within range + 30 m of the camera (and 1.5 s ahead of it) are loaded with `load_threaded_request`, nearest first (four in flight in this commit, one since `104d913`), attached within 2 ms per frame, freed beyond range + 60 m; a camera jump beyond 30 m loads the needed cells before the frame on the main thread. Map scripts set streamed meshes up in `prepare_streamed()` (İstanbul's vertex colours, the shader facade). Overlay (`cells <loaded>/<all> +<waiting> <MB> MB`), `PERF`, `STARTUP`, `STREAMING` lines, and benchmark results show the cells; runtime keys `streaming` (off: whole) and `streaming_index` (another index).
- **Every map split** (`a01767f`): the six maps with streamable meshes are linked to their indexes; the test district and the Apollo relief have nothing in a streamed category and load whole. `docs/maps/istanbul_halic/README.md` step 5 (and `docs/ARCHITECTURE.md`) gives the command for a new machine.
- **Loader changes from the device runs** (`104d913`, T55): one threaded request in flight (four gave more 51–57 ms frames on the tablet); warm cells (the index names the smallest cell per material; loaded with the map, never freed); `prepare_streamed_materials()`, so a map script changes the streamed meshes' materials at load instead of at their first cell (the İstanbul maps' vertex colours).
- **Route benchmark and measurement tools** (`104d913`): `"bench": {"route": …}` moves the player or the car along a fixed route both ways (`tools/perf/make_route.gd` makes one over walkable ground; the default map's is 515 m); `tools/capture_streaming.gd` (streaming on and off side by side with the pixel difference); `tools/perf/streaming_summary.py`; `pss_trace.py stable`. Also there: `MapStreamingIndex.problem()` lists the cells' folder once instead of 2,612 `ResourceLoader.exists()` calls, `WorldManager.load_report` (index, scene, and instancing times in `STARTUP`), and the overlay no longer reads a streamer freed by a map switch.

### Acceptance criteria (task of 2026-11-03)

| Criterion | Result | Status |
|---|---|---|
| Tablet (Release Perf, three runs, median): default map stable PSS ≤ 502 MiB | 464 / 464 / 475 MiB, median **464** (whole: 622) | PASS |
| Tablet: default map ready ≤ 4.0 s | the three memory launches 4,520 / 3,711 / 5,315 ms, median **4,520** (whole: 6,884 / 6,500 / 9,238); in another session (build D, four route launches) median 3,534; the battery was draining in every session (below, and open question 51) | FAIL (met in one session only) |
| Tablet (debug): a switch's peak PSS ≤ the larger map's stable PSS + 50 MiB; lmkd does not kill the app | six switches: peaks 547–559 MiB against limits of 595–606 MiB, 3.1–4.7 s each; lmkd reclaimed background processes, never the app | PASS |
| Tablet: along a fixed route of ≥ 500 m, walking and driving, both ways, no frame over 50 ms caused by cell loading (traced; presented frames recorded) | final code (F), one run each: no frame over 50 ms in or next to a frame that attached cells; the drive's presented intervals at most 50.5 ms (the whole map: 50.6), none two refreshes late; but 4 game frames of 51–55 ms elsewhere (the whole map's runs: none). Builds C and D had one 100–167 ms stall per run after an attach, fixed in E | PARTIAL |
| Tablet: long frames by D25's relative criterion against the default map without streaming; 1 % low at most 0.5 below 25.80 / 25.89 / 25.17 | one pair (nine launches each required) at 6–9 % battery: streamed 25.10 / 24.56 / 22.98 with 9 / 9 / 39 long frames, whole 25.42 / 25.83 / 25.01 with 4 / 4 / 3 | FAIL on the one pair; not completed |
| Safranbolu: PSS < 328 MiB | 341 MiB streamed, 345 MiB whole (one run each) | FAIL |
| Safranbolu: the cause of Phase 6b's View B long frames (three runs) | not investigated | NOT RUN |
| iPhone (Release Perf): default map footprint ≤ 860 MiB (lower is the goal), 60 FPS, 0 long frames, map ready ≤ 1.2 s | build F, three runs: footprint 597 / 597 / 595 MiB (whole: 857–863), 60.00 FPS, map ready 781 / 765 / 765 ms (whole: 1,214–1,221); long frames 0 at Spawn and Karaköy, at Galata 1 / 0 / 1 (25.1 and 39.8 ms; the whole map 0), no cell loaded in those windows; routes walked and driven at 60.00 FPS without a long frame | PARTIAL (footprint, FPS, map ready PASS; long frames: median 1 at Galata) |
| Seven maps (+ the Safranbolu and İstanbul test imports) split by the same command without configuration; a map without an index loads whole (test) | every map by `tools/cell_map.gd --all` (Safranbolu also through the import tool); the Apollo relief and the test district have nothing to stream and load whole; no blind map was given; `test_a_map_without_an_index_loads_whole`, `test_index_that_cannot_be_used_loads_the_map_whole` | PASS |
| The look within range unchanged: streaming on and off side by side at ≥ 2 points on every map; collision and every gameplay test unchanged | 40 sheets (every streamed map, low and high, 3–4 points each): 0 pixels differ on the four İstanbul maps; 1 pixel or one 120-pixel edge sliver (explained below) on the imported maps; the drawn sets equal in the tests; every gameplay and collision test passes on the streamed maps | PASS |
| No unloaded cell within the player's range along the route (budget delay aside, with a documented bound) | 0 frames with a needed cell missing on every route run (Mac, tablet, iPhone, the tests at 4.5–20 m/s); the bound: the 30 m margin, 2 s at 15 m/s | PASS |
| Device scenarios (`vehicle_sleep`, `extensibility`) on the default map and an imported map on both devices | tablet (debug F) and iPhone (debug C): 13 / 13, 25 / 25, Kenney town 9 / 9 and 21 / 21 | PASS |
| Every Phase 1–6b test; the Platform, preset, and `.gdignore` tests | 405 passed, 0 failed, 0 skipped (exit 0); unit 257; every Phase 6c commit in a clean clone without GLBs: 0 failed | PASS |

### Every map split by the same command

`godot --headless --path . --script res://tools/cell_map.gd -- --all` (Mac, 10.8 s for all; the test imports with `--definition=…`), no configuration (output: `docs/perf/phase6c/desktop/cells.txt`):

| Map | Streamed meshes | Cells (50 m) | Resident scene | Cells | Note |
|---|---|---|---|---|---|
| Shader facade map (default) | 4,726 of 6,129 (facade detail 2,591, trees 1,319, lamps 517, decor 299) | 2,612 | 31.4 MB | 67.2 MB | from its GLB scene (imported 102 MB) |
| İstanbul • Haliç | 1,652 of 3,055 | 1,056 | 31.3 MB | 155.3 MB | facade detail still in 150 m chunks (one mesh per chunk) |
| Cells map | 4,726 of 6,129 | 2,613 | 31.4 MB | 161.7 MB | |
| Light facade map | 4,726 of 6,129 | 2,613 | 31.4 MB | 107.0 MB | |
| Kenney town | 93 of 269 (trees 41, lamps 20, decor 32) | 27 | 0.7 MB | 0.1 MB | colliders stay resident under the stand-in nodes |
| Abstract city | 13 of 220 (decor) | 2 | 0.3 MB | 0.0 MB | + 7 MB of material files (its two textures) |
| Apollo 11 site | 0 of 1 | — | — | — | nothing to stream (one ground mesh): loads whole |
| Test district | 0 | — | — | — | nothing to stream: loads whole |
| Safranbolu (test import) | 523 of 1,173 (facade detail) | 87 | 9.6 MB | 5.7 MB | also through the import tool (temporary build) |
| İstanbul import (test import) | 1,652 of 3,055 | 1,056 | 18.5 MB | 79.4 MB | |

### The look within range

`tools/capture_streaming.gd` (Mac, Metal, 960×540): the same camera at the spawn and every viewpoint, streamed and whole, player, vehicles, and NPCs hidden, the game clock stopped, the water hidden; 40 sheets in `docs/perf/phase6c/look/` (`look.txt`):

| Map | Views (low and high) | Pixels that differ (over 2 of 255) |
|---|---|---|
| Shader facade map, İstanbul • Haliç, cells map, light map | 3 each × 2 profiles × 4 maps | **0** in all 24 |
| Kenney town | 4 × 2 | 0 in 7; 1 pixel (12/255) in one |
| Abstract city | 4 × 2 | 0 in 6; 1 pixel (14/255) in one; 120 pixels (0.02 %) in one: a 5 × 36 px sliver along one edge in "View A" on the low profile, with both of its cells loaded in both runs (so the same meshes are drawn; the edge's pixels are resolved differently, probably by the changed drawing order) |

In the tests the set of meshes Godot draws (a mesh, visible, its centre within its category's range) is the same with and without streaming: the synthetic map at five points, and the default map at the spawn and both viewpoints on the low and the high profile (`test_what_is_drawn_is_the_same_with_and_without_streaming`, `test_the_default_map_streams_what_its_profiles_draw`). The Mac benchmarks count the same draw calls with and without streaming at every viewpoint of every streamed map (below, "Every streamed map on and off"), apart from occasional outliers after a prime that also occur without streaming (below, "Found on the way").

### Memory and startup

| Galaxy Tab A7 (Release Perf, low profile; dense PSS trace, `docs/perf/phase6c/tablet/memory/`) | Streaming on (50 m) | Streaming off (the whole map) | On, 100 m cells |
|---|---|---|---|
| Stable PSS (three launches; median) | 464 / 464 / 475 MiB (**464**) | 622 / 621 / 633 MiB (**622**) | 464 / 463 / 475 MiB (**464**) |
| Peak PSS | 481 / 482 / 492 MiB | 638 / 638 / 649 MiB | 483 / 480 / 491 MiB |
| Map ready (same launches) | 4,520 / 3,711 / 5,315 ms | 6,884 / 6,500 / 9,238 ms | 3,814 / 5,239 / 5,225 ms |
| Of that: the index check, the scene's load, instancing | 32–45 ms, 1,587–2,152 ms, 231–339 ms | —, 4,463–6,186 ms, 319–450 ms | 17–23 ms, 1,620–2,149 ms, 229–337 ms |
| Map ready in other sessions | build D, route launches: 3,631 / 4,161 / 3,424 / 3,437 ms (median 3,534); build F: 3,855 ms, and 7,305 ms in the session's first launch (first launches after installing or restarting took 4.5–7.3 s); 8,818 ms at 6 % battery | build D: 5,984 / 6,351 ms; 9,337 ms at 6 % battery | — |

The memory runs used build B (no warm cells: six cells, 0.1 MB, are loaded at the start since build E).

| iPhone 13 Pro (Release Perf F, high profile, three runs; `docs/perf/phase6c/iphone/F/`) | Streaming on | Streaming off |
|---|---|---|
| Footprint (probes every ~45 s; highest per run) | 597 / 597 / 595 MiB, median **597** (lowest probe 568) | 857 / 862 / 863 MiB, median 862 (lowest 837) |
| Map ready | 781 / 765 / 765 ms, median **765** | 1,214 / 1,221 / 1,217 ms, median 1,217 |
| Of that: the index check, the scene's load, instancing | 10–11 ms, 306–311 ms, 18 ms | —, 812–821 ms, 26–29 ms |
| Average FPS (Spawn / Karaköy / Galata) | 60.00 / 60.00 / 60.00 (59.98 once) | 60.00 / 60.00 / 60.00 |
| Long frames per viewpoint (three runs) | 0,0,0 / 0,0,0 / **1,0,1** (25.1 and 39.8 ms) | 0,0,0 / 0,0,0 / 0,0,0 |
| 1 % low (median) | 54.62 / 55.41 / 56.07 | 57.99 / 56.92 / 56.02 |
| Draw calls | 261 / 167 / 90 (91 once), as off | 261 / 167 / 90 |
| Thermal state | Nominal at every probe | Nominal |

Builds B and D (same protocol, `iphone/B/`, `iphone/D/`): footprint 594 / 594 / 594 and 590 / 577 / 594 MiB streamed against 858–862 whole, map ready 765–823 ms against 1,220–1,252 ms; one long frame in one of nine windows each time (B: 21.0 ms at Spawn; D: 21.6 ms at Spawn and 25.5 ms at Karaköy). Over the three builds the streamed runs have 5 single long frames in 27 viewpoint windows, the whole map none; no cell was loaded or freed in any of those windows (all of them came with the prime), so they are not cell loads. In 15 of the 27 streamed windows (Karaköy in all nine, Spawn in six) the engine's process time reads 17.5–18 ms at the 99th percentile instead of 6–8 ms (the frame limiter's wait counted inside it) and the 1 % low is 1.5–3.6 FPS lower; the whole map shows that state in 2 of 27 windows. Why streaming makes it more frequent was not found.

Routes on the iPhone (build F, high profile, `iphone/F/route/`): walking 515 m out and back at 4.5 m/s, 6,872 frames each way, and driving at 15 m/s, 2,062 frames each way, all at 60.00 FPS with no long frame (longest 19.6 ms walking, 17.9 ms driving), no frame with a needed cell missing, at most 0.25 ms attaching cells in a frame; 161 + 72 cells loaded on the drive.

The tablet's map ready depends on its state: within a session it rose with the battery's temperature (33.5 → 37 °C) and, as found afterwards, the battery was draining towards 0 % (the Mac's USB port gives 300–350 mA, the measured load draws about 1.1 A), so the later launches ran slower, streamed or not (on/off pairs: 4.5 / 6.9, 3.7 / 6.5, 5.3 / 9.2 s). The PSS does not depend on it.

### Every streamed map on and off

Mac (Metal, 960×540, one launch each, warm-up 5 s and 3 s at every viewpoint; `docs/perf/phase6c/desktop/allmaps/`): map ready, the scene's load, and the highest engine static memory and video memory over the viewpoints. Draw calls are the same on and off at every viewpoint of every map.

| Map | Profile | Map ready, on / off | Scene load, on / off | Static memory, on / off | Video memory, on / off | Cells loaded at the viewpoints |
|---|---|---|---|---|---|---|
| Shader facade map (default) | low | 1,360 (the batch's first launch) / 1,326 ms | 301 / 756 ms | 181 / 249 MB | 130 / 294 MB | 13 / 27 / 38 of 2,612 |
| | high | 930 / 1,319 ms | 276 / 767 ms | 186 / 252 MB | 181 / 342 MB | 44 / 62 / 101 |
| İstanbul • Haliç | low | 838 / 1,559 ms | 263 / 1,044 ms | 171 / 193 MB | 133 / 518 MB | 9 / 14 / 17 of 1,056 |
| | high | 830 / 1,474 ms | 246 / 950 ms | 174 / 196 MB | 190 / 566 MB | 23 / 31 / 40 |
| Cells map | low | 884 / 1,775 ms | 256 / 1,217 ms | 181 / 257 MB | 135 / 703 MB | 12 / 26 / 37 of 2,613 |
| | high | 881 / 1,813 ms | 242 / 1,211 ms | 185 / 260 MB | 198 / 751 MB | 43 / 61 / 100 |
| Light facade map | low | 869 / 1,517 ms | 241 / 967 ms | 181 / 255 MB | 132 / 530 MB | 12 / 26 / 37 of 2,613 |
| | high | 949 / 1,514 ms | 280 / 958 ms | 186 / 258 MB | 188 / 579 MB | 43 / 61 / 100 |
| Kenney town | low | 456 / 466 ms | 24 / 25 ms | 63 / 63 MB | 69 / 69 MB | 27 of 27 everywhere |
| | high | 487 / 481 ms | 22 / 23 ms | 63 / 63 MB | 117 / 117 MB | 27 of 27 |
| Abstract city | low | 557 / 488 ms | 57 / 43 ms | 55 / 55 MB | 98 / 99 MB | 2 of 2 everywhere |
| | high | 514 / 515 ms | 51 / 52 ms | 56 / 56 MB | 147 / 147 MB | 2 of 2 |

On the two small imported maps every cell lies within range + margin of every viewpoint, so streaming loads all of them and saves nothing (nor costs anything measurable). The Apollo relief and the test district have nothing to stream and load whole.

iPhone 13 Pro (Release Perf F, high profile, one launch each, warm-up 15 s and 20 s at every viewpoint; `docs/perf/phase6c/iphone/F/allmaps/`; the default map: the three-run table above):

| Map | Footprint (highest probe), on / off | Map ready, on / off | Scene load, on / off | Average FPS, long frames (on and off) |
|---|---|---|---|---|
| İstanbul • Haliç | 571 / 989 MiB | 714 / 1,404 ms | 307 / 1,017 ms | 59.99–60.00, none |
| Cells map | 590 / 1,270 MiB | 778 / 1,650 ms | 306 / 1,243 ms | 60.00, none |
| Light facade map | 581 / 1,096 MiB | 788 / 1,396 ms | 307 / 1,004 ms | 59.99–60.00, none |
| Kenney town | 298 / 306 MiB | 403 / 386 ms | 27 / 27 ms | 59.99–60.00, none |
| Abstract city | 323 / 323 MiB | 405 / 404 ms | 53 / 55 ms | 59.99–60.00, none |

Draw calls equal on and off at every viewpoint; thermal state nominal.

The tablet ran the default map (above) and Safranbolu (below); the other maps on the tablet were not run (the battery; the user chose to finish with the data at hand).

### Routes (Galaxy Tab A7, Release Perf, low profile)

The default map's route (`tools/perf/experiments/c_route_*.json`): 515 m over walkable ground from the Galata Bridge over the Karaköy waterfront up to the Galata street (13 points from `tools/perf/make_route.gd`), walked at 4.5 m/s and driven at 15 m/s, out and back, every frame traced, the presented frames recorded beside it on the drives (and on build C and D's walks). Builds: C (the loader of `7605e39` with the overlay guard and the faster index check), D (materials set at load), E (warm cells), F (warm cells and one request in flight: the final code); whole: the map loaded whole (build D). Raw files: `docs/perf/phase6c/tablet/routes_*`; table from `tools/perf/streaming_summary.py`.

| Build, mode, direction | Frames, avg FPS, 1 % low | Long frames | Frames over 50 ms (of them next to an attach) | Longest frame | Cells loaded / freed | Longest attaching in a frame | Frames with a needed cell missing | Presented: longest interval, intervals over 67 ms |
|---|---|---|---|---|---|---|---|---|
| C drive, out | 1,024, 29.79, 25.60 | 5 | 3 (2) | 157.2 ms | 93 / 59 | 1.56 ms | 0 | 199.9 ms, 1 |
| C drive, back | 1,031, 29.99, 25.61 | 3 | 1 (0) | 56.1 | 62 / 96 | 0.66 | 0 | 50.4, 0 |
| C walk, out | 3,426, 29.90, 26.01 | 9 | 5 (4) | 167.0 | 69 / 36 | 0.80 | 0 | 216.9, 2 |
| C walk, back | 3,436, 30.00, 25.99 | 4 | 1 (1) | 51.6 | 40 / 71 | 0.60 | 0 | 50.5, 0 |
| D drive (two runs), out | 1,026 / 1,025, 29.86 / 29.83, 25.01 / 24.88 | 5 / 8 | 4 (2) / 5 (2) | 105.0 / 105.3 | 93 / 59 | 1.29 / 1.13 | 0 / 0 | 166.8, 1 / 166.7, 1 |
| D drive, back | 1,031 / 1,030, 29.99 / 29.98, 25.55 / 25.48 | 1 / 1 | 0 / 0 | 48.3 / 46.4 | 61 / 95 | 0.80 / 0.70 | 0 / 0 | 50.6, 0 / 50.3, 0 |
| D walk (two runs), out | 3,431 / 3,429, 29.95 / 29.93, 25.58 / 25.49 | 12 / 17 | 2 (2) / 8 (4) | 109.4 / 100.2 | 69 / 36 | 1.68 / 1.13 | 0 / 0 | 166.7, 1 / 150.0, 1 |
| D walk, back | 3,436 / 3,435, 30.00 / 29.99, 25.79 / 25.81 | 5 / 6 | 0 / 2 (2) | 46.2 / 56.7 | 40 / 71 | 0.75 / 0.75 | 0 / 0 | 50.5, 0 / 50.5, 0 |
| E walk, out | 3,434, 29.98, 25.89 | 7 | 3 (1) | 56.5 | 69 / 36 | 1.04 | 0 | — |
| E walk, back | 3,436, 30.00, 25.96 | 3 | 1 (0) | 50.9 | 40 / 71 | 2.91 | 0 | — |
| **F drive, out** | 1,028, 29.91, 24.86 | 6 | 3 (**0**) | 55.3 | 89 / 55 | 0.69 | 0 | **50.4, 0** |
| **F drive, back** | 1,031, 30.00, 25.44 | 0 | 0 | 40.9 | 56 / 90 | 0.65 | 0 | **50.5, 0** |
| **F walk, out** | 3,434, 29.98, 26.02 | 7 | 1 (**0**) | 52.1 | 69 / 36 | 2.04 | 0 | — |
| **F walk, back** | 3,436, 30.00, 25.81 | 5 | 0 | 47.9 | 40 / 71 | 0.57 | 0 | — |
| Whole drive, out | 1,029, 29.94, 25.28 | 4 | 0 | 47.8 | — | — | — | 50.4, 0 |
| Whole drive, back | 1,031, 30.00, 25.43 | 0 | 0 | 41.2 | — | — | — | 50.6, 0 |
| Whole walk, out | 3,435, 29.99, 25.76 | 4 | 0 | 47.7 | — | — | — | 50.7, 0 |
| Whole walk, back | 3,436, 30.00, 25.77 | 2 | 0 | 42.9 | — | — | — | 50.8, 0 |

"Next to an attach": in the frame before, of, or after a frame in which cells got their meshes. Presented intervals: at 30 FPS on the 60 Hz panel a frame is shown for 33.3 ms; 50 ms is one refresh late, which every run has 15–84 times per direction, the whole map too (the tablet's display pairs, open question 43); over 67 ms a frame was shown two or more refreshes late. The 100–217 ms stalls of builds C and D came once per run at the same spot (the first traffic-signal glow), right after an attach that itself took 0.2 ms (below, "Found on the way"); build E removed them. With the final code (F) no frame over 50 ms falls next to an attach and no presented interval is longer than the whole map's, but the streamed runs have 4 game frames of 51–55 ms elsewhere (drive out 3, walk out 1) where the whole map's runs have none; one run each, so whether the loading thread causes them was not settled. The drive keeps up with one request in flight: the camera at 15 m/s never had a needed cell missing (the margin of 30 m is 2 s of driving), and the loader's longest main-thread time in a frame was 0.69 ms.

### Relative criterion (Galaxy Tab A7, Release Perf F, low profile)

One pair only, the default map streamed and whole at the three viewpoints (`docs/perf/phase6c/tablet/frames/run1/`), at 6–9 % battery (33.0–34.5 °C, no cool-down wait):

| | Spawn | Karaköy street | Galata street |
|---|---|---|---|
| Streamed: average FPS, 1 % low, long frames | 30.01, 25.10, 9 | 30.01, 24.56, 9 | 30.01, 22.98, 39 |
| Whole: average FPS, 1 % low, long frames | 30.00, 25.42, 4 | 30.01, 25.83, 4 | 30.01, 25.01, 3 |
| The task's lower limit for the 1 % low (25.80 / 25.89 / 25.17 − 0.5) | 25.30 | 25.39 | 24.67 |

No frame over 50 ms in either launch (longest 42.9–46.5 ms) and no cell loaded while measuring (all cells in range came with the prime). The streamed launch is below the limit at all three viewpoints. One launch is not D25's protocol (nine alternating launches each); Galata's 39 long frames resemble the per-launch pacing state of earlier phases ("Known bugs and limitations", "Tablet frame pacing"), which hits any map, but that was not shown for this launch. The other eight launches each were not run: the tablet's battery was at 6 % and the user chose to finish with the data at hand.

### Map switch (Galaxy Tab A7, debug F, `scenario_map_switch`, dense PSS trace)

| Switch | Time | Peak PSS | Limit: larger stable PSS + 50 MiB |
|---|---|---|---|
| 1 shader map → İstanbul • Haliç | 3,387 ms | 547 MiB | 595 MiB |
| 2 İstanbul • Haliç → cells map | 3,354 ms | 557 MiB | 602 MiB |
| 3 cells map → İstanbul • Haliç | 3,129 ms | 548 MiB | 602 MiB |
| 4 İstanbul • Haliç → shader map | 3,300 ms | 559 MiB | 605 MiB |
| 5 shader map → cells map | 3,272 ms | 559 MiB | 605 MiB |
| 6 cells map → shader map | 4,664 ms | 559 MiB | 606 MiB |

Stable PSS: the median of the 15 s before a switch and of the 14 s from 5 s after it. Before streaming the same switches took 6.8–9.5 s and the cells map's load peaked at 810 MiB (2026-11-01). The low-memory killer reclaimed four background processes (score 999) during the run, never the app (`lmkd.txt`). 6 / 6 PASS (`docs/perf/phase6c/tablet/debug/switch/`).

### Safranbolu (Galaxy Tab A7, a temporary Release Perf build F with the test import in the registry, low profile, one run each)

| | Streamed | Whole |
|---|---|---|
| Stable PSS (dense trace) | 341 MiB | 345 MiB |
| Peak PSS | 357 MiB | 362 MiB |
| Map ready | 6,881 ms (the first launch after installing) | 3,064 ms |
| Of that: the scene's load, instancing | 807 ms, 50 ms | 1,006 ms, 40 ms |
| Average FPS (Spawn / View A / View B / View C / sloped street) | 26.27 / 26.53 / 24.91 / 25.90 / 26.70 | 26.48 / 25.94 / 24.57 / 25.45 / 26.65 |
| Draw calls | 95 / 55 / 210 / 75 / 92 | the same |

Only Safranbolu's facade detail streams (523 of 1,173 meshes, 5.7 MB of cells; no trees, lamps, or decor were classified there); its buildings, ground, and the rest stay resident (9.6 MB), so streaming saves 4 MiB and the < 328 MiB criterion is not met. Where its 341 MiB go was not measured further. The cause of Phase 6b's long frames at View B (three runs) was not investigated (NOT RUN; the tablet's battery). Raw files: `docs/perf/phase6c/tablet/safranbolu/`. The build: the user's Safranbolu GLB imported with the import tool (which ran the cell step) into the registry, the APK built, then the import removed and the registry restored (SHA-256 checked); the two experiments were temporary files, not committed.

### Device scenarios

| Scenario (debug builds) | Galaxy Tab A7 (build F) | iPhone 13 Pro (build C) |
|---|---|---|
| `vehicle_sleep` (default map) | 13 / 13, peak PSS 520 MiB | 13 / 13, footprint 604 MiB |
| `extensibility` (through every map of the registry and back) | 25 / 25, 560 MiB | 25 / 25, 461 MiB |
| `vehicle_sleep_kenney_town` | 9 / 9, 312 MiB | 9 / 9 |
| `extensibility_kenney_town` | 21 / 21, 323 MiB | 21 / 21 |
| `map_switch` | 6 / 6 (above) | not run |

Thermal state nominal throughout. The iPhone's debug build C predates warm cells and one request in flight (the iPhone's Release Perf F runs cover the final code). Raw files: `docs/perf/phase6c/tablet/debug/scenarios/`, `docs/perf/phase6c/iphone/scenarios/`.

### Cell size

50 m (100 m compared; `docs/STREAMING.md`, "Cell size", T56): the tablet's stable PSS is the same within the runs' spread (464 / 464 / 475 against 464 / 463 / 475 MiB); on the Mac 100 m loads half as many cells on the driving route (49 + 31 against 93 + 60) but holds more around the camera on the high profile (0.9–1.6 against 0.8–1.4 MB of cells) and attaches larger cells (at most 0.72 against 0.27 ms in a frame).

### Found on the way

- **Threaded loads from `Main._ready()` crashed a worker thread** (signal 11, the official engine without symbols) in 7 of 20 quick launches on the Mac (Metal), and 4 of 8 three-viewpoint benchmarks; never with the map loaded whole. With the first prime on the main thread: 0 of 20; final code (every prime on the main thread, the frame loop's loads threaded): 0 of 20, and no crash in any later Mac, iPhone, or tablet run. Not reproduced by a stress test of 300 rounds of four concurrent cell loads. Probes: `docs/perf/phase6c/desktop/probes.md`.
- **Headless runs** cannot create meshes off the main thread (the dummy renderer's mesh storage is not thread-safe; 37 RID errors when 2,612 cells loaded at once), so cells load on the main thread there (`threaded` follows whether the renderer has a RenderingDevice).
- **Occlusion culling after a long frame** (an engine behaviour): a frame of about 20 ms or more right after a camera jump can leave Godot's occlusion culling drawing more hidden objects at that spot until the camera moves on (Galata: 96–103 objects instead of 22 with the HUD hidden); reproduced with the map loaded whole and a 25 ms stall after each jump (6 of 25 jumps; 0 without the stall; 0 with occlusion culling off). A prime is such a frame, so benchmarks at fixed viewpoints can count more draw calls in some launches (Mac: 10 of 47 streamed launches at Galata or Karaköy, 0 of 13 unstreamed). Nothing more is visible (the extra objects are hidden behind others). The Phase 6b Mac "glitch" belongs to the same family.
- **The overlay's own objects:** on a streamed map the debug overlay's longer third line adds 22–24 objects and 44–48 primitives to the counters (same draw calls); Release Perf builds have no overlay.
- **Stalls when a material was first changed on the tablet** (build C): on the walking and driving routes one or two frames of 120–167 ms (followed by one of 72–80 ms) came right after a cell was attached, although attaching took 0.2 ms: the İstanbul maps' vertex-colour flag was set on the materials only streamed meshes use (lamp lenses, signals, glass, the facade panels' GLB material) when their first cell arrived, and the renderer built their shaders in that frame. Since build D the map script sets them when the map loads (`prepare_streamed_materials()`), which removed one of the stalls; one frame of 100–109 ms and one of 77–79 ms stayed, once per run at the same spot (the first cell bringing a material into the scene, the first traffic-signal glow), never with the whole map. Since build E the index names a warm cell per material (the smallest cell using it), loaded with the map and never freed (6 cells, 0.1 MB, on the default map); with them the stall was gone from every later route run. Evidence: `docs/perf/phase6c/tablet/routes_C/`, `routes_D/`, `routes_E/`.
- **Four requests in flight** (builds C–E) gave the routes more game frames of 51–57 ms than the whole map had; with one in flight (build F) fewer remained (4 in four directions) and the car at 15 m/s still never missed a needed cell.
- **The overlay read a freed streamer** during a map switch (its timer fires while the old map is being freed): fixed in `104d913` (the HUD drops the streamer when a switch begins and checks `is_instance_valid`), with a test.
- **The index check** listed 2,612 files one `ResourceLoader.exists()` at a time (60 ms on the Mac); one folder listing now (32–45 ms on the tablet, 10–11 ms on the iPhone).
- **The tablet's power:** connected to the Mac it discharges under the measured load (about −1.1 A against a 300–350 mA supply); its battery reached 0 % during the first tablet session, which was stopped; the user charged it before the remaining runs, and the last session ended at 6 %, when the user chose to finish with the data at hand (the relative criterion's other launches and Safranbolu's View B were not run). Map ready and long frames vary with it; the PSS does not (open question 51).

### D26: what streaming adds to the evidence

| Kind of map | Streaming |
|---|---|
| The İstanbul generator's maps (four, 3,055–6,129 meshes) | split by the same command from their GLB scenes; the drawn set and the pixels identical at every compared view; the default map measured on both devices |
| Imported maps with names (the Kenney town; Safranbolu, the İstanbul import as test imports) | split by the same command (Safranbolu also through the import tool itself); colliders stay resident under the stand-in nodes; the Kenney town's tests and scenarios pass streamed |
| An imported map with few streamable meshes (the abstract city: 13 decor) | split; nearly nothing to gain |
| A map with nothing in the streamed categories (the Apollo relief, the test district) | the step says so and the map loads whole |
| A map whose cells were not written (a fresh clone), or a stale index | loads whole (tested), with a log line or a warning |

### Tests (2026-11-04)

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `run_tests.gd` (every suite, with the four GLBs, the test imports, and the cells) | `RESULT 405 passed, 0 failed, 0 skipped`, exit 0 (the code of `104d913`; the documentation commit after it changes no code) |
| `run_tests.gd -- unit` | `RESULT 257 passed, 0 failed, 0 skipped`, exit 0 |
| Clean clones without any GLB, test import, or cells (each Phase 6c commit) | `5f96ab7` 287 passed, 87 skipped; `fce9b0c` 294 / 87; `7605e39` 312 / 88; `a01767f` 312 / 89; `104d913` 316 / 89; 0 failed and exit 2 (skips) each; unit only 235, 242, 254, 254, 257 passed, exit 0 |
| `tests/map/validate_scene.gd` | `VALIDATION PASS | failures=0` |
| The four GLBs' SHA-256 at the start and the end | unchanged (`8b00c94b…`, `7973071a…`, `6531ca28…`, `60b9f729…`) |
| Before the commits | secret scan of the staged files, a search for personal home-folder paths (only the test that forbids them matches), the evidence's gzipped files searched too, device serials absent, full device logcats left out (the evidence keeps the game's lines and the low-memory killer's), `export_presets.cfg` keystore fields empty |

New tests: `tests/unit/test_map_cells.gd` (8), `tests/unit/test_map_streamer.gd` (12), `tests/integration/test_map_streaming.gd` (9), and in `test_perf_experiments.gd` the route keys. Found by the last run: two streamer tests assumed four requests in flight; they now set four themselves, and a new test pins the default of one.

## Phase 6b — blind test of the import tool and general hardening (2026-11-03)

Task of 2026-11-03 (user, after the reviewer's findings on Phase 6a): prove D26's "a map the tool has never seen" claim. Two unseen maps were run through the unchanged tool first and the results recorded unedited; then only general fixes (geometry, materials, scene structure, contract rules; no words from the blind maps' names), each tied to a contract rule or a reviewer finding, with the existing maps' categories and tests unchanged. Decisions: `PROJECT_CONTEXT.md`, T49–T53; contract: `docs/MAP_CONTRACT.md`; blind runs, labels, and the final comparison: `docs/maps/imported/blind/README.md`.

### What exists now

- **Converter** (`tools/convert_to_gltf.gd`, `3db25ed`): OBJ (MTL or a same-named texture), STL (binary, ASCII), FBX (Godot's `FBXDocument`) to GLB with no unit or axis change; the contract's "Supported formats".
- **The two blind-test maps in the game** (`cc21cbe`): `maps/abstract_city/` (Keenan Crane's public-domain abstract city, one OBJ mesh for the whole city in arbitrary units) and `maps/apollo11_site/` (NASA's Apollo 11 landing site relief, an STL for 3D printing: Z-up, millimetres, inside out), registry entries 9 and 10, converted sources in their `source/` folders.
- **Up axis, units, inside-out shells** (`518de92`, T50): C3 detects and fixes any of ±X, ±Y, ±Z up; C2 recognises millimetres, centimetres, inches, feet and suggests a scale from the separate objects; C7 turns closed inside-out meshes outward.
- **Shape classification** (`d038df8`, T51): one mesh holding several grounded objects is split; new rules for flat tiles, closed slabs, trees, poles, barriers, enclosures, low and repeated objects, roofs, slender towers; a second look at meshes on buildings (facade detail, roofs); evaluation tools `sample_sheet.gd`, `compare_categories.gd`.
- **Colliders by shape** (`80adf44`, T52): capsules for trunks and posts, boxes for blocks and fences, trimesh for concave building parts (courtyards, L and U plans, walls without a roof), nothing below 0.5 m or 0.3 m high.
- **Scored placement and a better report** (`548d3e5`, T53): spawn and vehicle scored by drive or walk, street, room, clutter, distance, slope; the report's "How to improve this map" and `--compare`.
- **Tools for the reports:** `tools/capture_map_shots.gd` (spawn, vehicle, the map from above with posts, the NPC; or a raw glTF view).

### Acceptance criteria (task of 2026-11-03)

| Criterion | Result | Evidence |
|---|---|---|
| Two unseen maps obtained, licences documented; at least one structurally different | **PASS** | the abstract city (public domain, Keenan Crane) and the Apollo 11 relief (NASA, "free and without copyright"), both structurally different from the Phase 6a maps (one-mesh city in arbitrary units; Z-up, millimetres, inside out, STL); `docs/maps/imported/abstract_city_source.md`, `apollo11_site_source.md` (the user's field was empty: both from public sources) |
| Blind results recorded unedited (report, tests, shots) | **PASS** | `3db25ed`: the unchanged tool's reports with and without the suggested configuration, logs, the gameplay test log, raw and in-game shots, the classification of each finding (`docs/maps/imported/blind/`) |
| General fixes only: no word from the unseen maps in the vocabulary (diff); each fix tied to a contract rule or a reviewer finding | **PASS** | the `VOCABULARY` block of `map_classifier.gd` is byte-identical to `0aea505` (SHA-256 `0e61da2e…` both); the category rule resources and game code unchanged; fixes: C2, C3, C7 (`518de92`), R1, R3 (`d038df8`), R2 and the reviewer's collider finding (`80adf44`), C8 and the reviewer's placement finding, the report (`548d3e5`) |
| Classification accuracy measured on the blind maps (hand-labelled sample) | **PASS** (with a caveat) | 60 random objects of the abstract city labelled by hand: fixed 58 / 60, blind 56 / 60; the relief: ground by shape (the old rule: none); also shape-only Kenney 92.6 %, Safranbolu 88.1 %. Caveat: a sample nearly all buildings, labelled by the agent; some rules written after seeing it (T51) |
| Decor, tree, and courtyard colliders work (the player cannot pass a tree or a fence; a yard is walkable); the tablet's physics step increase reported | **PASS** | `test_trees_and_fences_block_the_player` (the real player on the Kenney town), `test_map_colliders.gd` (a U building's yard reachable by a ray and the player's capsule; trunk, fence, small stone); tablet: Kenney +0.20 ms mean physics step, Safranbolu ±0.00 ms (`docs/perf/phase6b/`) |
| Vehicle placement scored; the Kenney car on a road | **PASS** | `548d3e5`; `test_car_parks_on_a_road` (`road-straight_11_8`), `test_vehicle_and_spawn_prefer_a_street_to_a_grove` |
| Both blind maps playable or the reason given by a contract rule; their tests PASS / SKIP | **PASS** | both playable with a user-style configuration: 11 / 11 and 10 / 10 gameplay tests (committed models, they run in every checkout) |
| The five existing maps' categories unchanged; all Phase 1–6a tests, Platform, preset, `.gdignore` tests PASS; the default map's Mac benchmark unchanged | **PASS** | 25,955 meshes of eight maps byte-identical before and after; the full suite 374 passed (`RESULT 374 passed, 0 failed, 0 skipped`), validation PASS, the four GLBs unchanged; Mac benchmark identical before and after (one glitched window in the first run before, see `docs/perf/phase6b/README.md`) |
| The scenarios pass on at least one blind map on both devices | **PASS** | the abstract city: `vehicle_sleep` 9 / 9 and `extensibility` 21 / 21 on the Galaxy Tab A7 and the iPhone 13 Pro; the relief: `vehicle_sleep` 13 / 13 with the slope steps on both |

### Blind result and fixed result

| | Abstract city | Apollo 11 landing site |
|---|---|---|
| Structure | the whole city in one OBJ mesh (219 objects), arbitrary units (1.4 × 1.25 units), no names, no normals, ground plane in a second OBJ; textures | one closed STL mesh, Z-up, millimetres (255.5 × 255.5 × 18.7), inside out (its top faced down), no colours, no normals |
| Blind, no configuration (`0aea505`) | not written: C2 FAIL, suggested `"scale": 20` | not written: C3 FAIL "looks Z-up", `"up_axis": "z"` suggested |
| Blind, with the suggested configuration | written: a toy city (towers 0.3–5.6 m wide) in one `buildings` mesh; play on the bare ground plane beside it; gameplay 7 of 8 (the profile test needs visibility-range meshes) | written: playable, but only the relief's base was drawn (inside out); the category came from the name by chance (`landing` → `land`); gameplay 7 of 8 |
| Fixed tool, user configuration | `{"scale": 100}` (the tool's new suggestion) + display name: the mesh split into 219 objects (buildings 203, decor 13, none 3), 187 hulls, 17 concave parts as trimesh, 13 boxes; spawn in an alley at the city's edge, car 15 m away beside the towers; 11 of 11 tests | display name only: C3 FIXED (+Z up, by the base), C7 FIXED (turned outward), ground by shape too, a 6.7° sloped viewpoint; 10 of 10 tests |
| Devices (debug builds of `cc21cbe`) | `vehicle_sleep` 9 / 9 and `extensibility` 21 / 21 on the tablet and the iPhone | `vehicle_sleep` 13 / 13 with the slope steps (6.7°) on the tablet and the iPhone |
| Reports | `docs/maps/imported/abstract_city.md` (blind runs side by side) | `docs/maps/imported/apollo11_site.md` |

Findings of the blind runs and their kind (contract violation or tool deficiency): `docs/maps/imported/blind/README.md`, "What failed, and whose problem it is".

### Classification accuracy

| Sample | How | Result |
|---|---|---|
| Abstract city (blind), 60 of its 219 objects at random | labelled by hand on rendered views (`docs/maps/imported/blind/labels/`) before reading the tool's answers: 56 towers or blocks, 4 low slabs | blind tool 56 of 60 (one category for the whole mesh), fixed tool **58 of 60** (2 medium blocks in no category) |
| Apollo relief (blind), 1 mesh | ground | blind: ground only through the name; by shape the old rule gave nothing (46 % of its area faces up, 50 % needed); fixed: ground by shape |
| Kenney town, 269 meshes, shape only (`"use_default_name_rules": false`) vs its names | `compare_categories.gd` | **249 of 269 (92.6 %)**; the 20 misses are lamps as decor (lamps are a name-only category); before the fixes this run crashed, and the old ground rule finds none of its 10 m tiles |
| Safranbolu, 1,173 meshes, shape only vs its names | same | **1,033 of 1,173 (88.1 %)**; 86 facade-detail meshes as buildings, 38 buildings and 5 ground meshes in no category |

The low-object and slender-tower rules were written after seeing the city's unclassified objects, and the facade-detail and roof pass after seeing Safranbolu's shape-only result (T51): no rule uses a name, but these samples are not blind to the rules.

### D26: how far the claim is proven (2026-11-03)

| Kind of map | Evidence |
|---|---|
| Named, metric, Y-up, many meshes (a modelling tool's or a generator's export: the Kenney town, Safranbolu, the İstanbul import) | proven on three maps (Phase 6a), re-imported with the hardened tool (Phase 6b); every gameplay test and the device scenarios pass |
| The whole area in one mesh, arbitrary units, no names (the abstract city) | proven on one blind map: split, classified by shape (58 of 60 sampled objects right), playable; the scale is the author's choice (the tool suggests one) |
| Z-up, millimetres, inside out, terrain only, one huge mesh (the NASA relief) | proven on one blind map: turned and faced outward by the tool, playable, scenarios on both devices; units that give a plausible size cannot be detected |
| Centimetre, inch, or foot models; −Y, ±X up | synthetic unit tests only |
| `.gltf` with external buffers and textures; FBX; GLB with lights, cameras, skeletons, animations | not run through the import tool on a real file (the converter's FBX path tried on one CC0 terrain piece; R8 removes lights, cameras, skeletons, animation players without a dedicated test) |
| Unnamed lamps and facade detail | partly: shape alone gives decor and buildings (Safranbolu 88.1 %, Kenney 92.6 % with lamps the misses) |
| Indoor levels (floors under ceilings), multi-storey walkable buildings | not supported: the placement casts rays from above (C4 would fail) |
| Maps beyond 2,000,000 triangles | imported (the İstanbul import, 7.07 M: C6 WARN, 12 s, about 2 GB), but too heavy for the tablet class without streaming |

### Vocabulary unchanged

`git diff 0aea505 HEAD -- tools/map_import/map_classifier.gd` changes only `category_by_shape()` and adds `shape_key()`; the `VOCABULARY` lines are byte-identical (no word added or removed); the configured rules of the five existing maps are untouched.

### Colliders and placement on the Phase 6a maps

| | Phase 6a | Phase 6b |
|---|---|---|
| Kenney town colliders | 443 shapes (144 ground trimesh, 299 building hulls); trees, lamps, fences without | 792 shapes: 249 hulls, 194 trimesh (ground, 50 concave building parts), 192 boxes (fences, decor), 157 capsules (trunks, lamp posts, fence posts); 152 small or low parts without |
| Kenney town car | on a lawn (`tile-low_6_6`) among trees, 8 m from the spawn | on a road (`road-straight_11_8`) between houses, 41 m from the spawn (score 4.11: 40 m drive, houses on both sides, no tree, lamp, or decor within 6 m) |
| Kenney town tests | 10 | 12 (+ the player stops at a tree trunk and a fence; the car is on a road) |
| Safranbolu colliders | 600 hulls, 50 ground trimesh | 561 hulls, 89 trimesh (39 concave building parts: walls without a roof, L plans) |
| Safranbolu car | 70 m from the spawn | 84 m, on 3.6° ground, buildings on both sides |
| İstanbul import | 827 `-col` trimesh bodies | unchanged (collision nodes are used as they are); tool run 12.0 s (9.0–9.4 s), 1.6–2.1 GB peak |
| Categories | — | all 25,955 meshes of the eight maps (the five existing maps, the Kenney town, Safranbolu, the İstanbul import) byte-identical in a dump before and after |

### Devices

| Scenario | Galaxy Tab A7 | iPhone 13 Pro |
|---|---|---|
| `scenario_vehicle_sleep_abstract_city` | 9 / 9 PASS (slope steps skipped: no sloped viewpoint), map ready 2.6 s | 9 / 9 PASS, footprint 334 MiB, Nominal |
| `scenario_extensibility_abstract_city` (test district visited directly) | 21 / 21 PASS, switches 0.4 s each way, peak PSS 302 MiB | 21 / 21 PASS, 0.1 s and 0.2 s, footprint 331 MiB |
| `scenario_vehicle_sleep_apollo11_site` | 13 / 13 PASS with the slope steps on the relief (6.7°), peak PSS 315 MiB | 13 / 13 PASS, footprint 365 MiB |
| `scenario_vehicle_sleep_kenney_town` (re-imported) | 9 / 9 PASS, peak PSS 299 MiB | 9 / 9 PASS, footprint 319 MiB |

Debug builds of `cc21cbe` (APK 689,617,151 B; the iOS build without `-allowProvisioningUpdates`). Raw files: `docs/perf/phase6b/`.

### Tablet measurement (Release Perf, one run each, informational)

| Map | Average FPS | 1 % low | Physics step, Phase 6a → 6b | Peak PSS | Map ready |
|---|---|---|---|---|---|
| Kenney town | 29.87–29.93 | 24.94–25.54 | 4.08–4.99 (mean 4.39) → 4.33–4.90 ms (mean 4.58, **+0.20 ms**) | 262 MiB (6a: 260) | 2.3 s |
| Safranbolu (temporary measurement build) | 28.69–29.93 | 17.71 (View B: 150 long frames) – 26.00 | 4.35–6.38 (mean 4.88) → 4.47–6.03 ms (mean 4.87, **±0.00**) | 332 MiB (6a: 328) | 2.7 s |
| Abstract city | 29.85–29.90 | 24.38–24.93 | → 5.15–5.28 ms | 255 MiB | 1.5 s |
| Apollo 11 site | 29.85–29.91 | 24.41–24.98 | → 5.86–6.34 ms (one 142,768-triangle trimesh) | 297 MiB | 1.6 s |

Low profile, one run each, PSS sampling on, thermal status 0, battery 28.5 → 36.5 °C; the viewpoints moved with the scored placement, so compare ranges. Safranbolu ran on a temporary build (its test import registered for that APK only, then removed; `game/world/maps.tres` restored byte for byte). Full table and conditions: `docs/perf/phase6b/README.md`.

### Tests (2026-11-03)

| Run | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| Full suite at the final code (all four GLBs, the test imports present) | `RESULT 374 passed, 0 failed, 0 skipped`, exit 0 (337 after Phase 6a: 37 new tests) |
| Unit suite | `RESULT 235 passed, 0 failed, 0 skipped`, exit 0 (221 after Phase 6a) |
| A clean clone of `cc21cbe` (no GLB, no test import) | full `RESULT 287 passed, 0 failed, 87 skipped`, exit 2 (the skips as in Phase 6a: the İstanbul GLBs and the two test imports; the Kenney town's and both blind maps' tests run); unit 235 passed, exit 0 |
| Per commit | `3db25ed` 340 passed (and a clean worktree's unit suite 224); `518de92` 344 (its unit tests re-run on the exact commit state: 228); `d038df8` 347 (re-run: 231); `80adf44` 350; `548d3e5` 369 passed and 3 failed, all three in the next commit's test files that were already in the working tree (the blind maps not yet registered, the shared profile test not yet generalized); `cc21cbe` 374 (each exit 0 except `548d3e5`'s run) |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| The four GLBs' SHA-256 | unchanged at start and end (`8b00c94b…`, `7973071a…`, `6531ca28…`, `60b9f729…`) |

New tests: `test_convert_to_gltf.gd` (3: OBJ polygons and winding, objects and textures, STL axes through a GLB round trip), `test_map_import.gd` (+7: Z-up detected and turned, up direction from box, faces, and base, inside-out shells, units, the scale suggestion from separate objects, shape rules on measured meshes, a one-mesh town split, facade detail and roof on a building), `test_map_colliders.gd` (3: a U building's yard, trunks, poles, fences, small stones, an upright capsule on a turned tree), `test_map_placement.gd` (+1: a street beats a grove), `test_imported_abstract_city.gd` (11), `test_imported_apollo11_site.gd` (10), `test_imported_kenney_town.gd` (+2: the player stops at a tree and a fence; the car on a road). Tests changed: `imported_map_case.gd`'s profile test accepts maps without visibility-range meshes; `test_map_registry.gd` the registry order; `test_map_import.gd` the lamp and decor colliders, a tall thin wall as a building, the axis values.

## Phase 6a — map infrastructure: contract, categories as map data, import tool, three maps (2026-11-02)

Task of 2026-11-02 (user, after the reviewer): make the project a map infrastructure (D26): a documented map contract, the render categories moved from `RenderSettings` into each map's data, a general import tool (checks, fixes, categories, colliders, occluders, placement, map files, report), and the proof on three maps imported without hand work (configuration only): the user's Safranbolu package (test input only), the shipped `istanbul_halic.glb` under a test id, and a CC0 model; the device scenario generalized and run on an imported map on both devices; an informational tablet measurement. The existing maps, the default map, their look and measurements, the profile values, the physics, and the gameplay unchanged; the İstanbul generator unchanged. Decisions: `PROJECT_CONTEXT.md`, D26, T45–T48, open questions 44–47. Contract: `docs/MAP_CONTRACT.md`; tool: `docs/ARCHITECTURE.md`, "Import tool"; reports: `docs/maps/imported/`.

### What exists now

- **Map contract** (`docs/MAP_CONTRACT.md`, `cbaf661`): mandatory rules C1–C8 (glTF, metres, +Y up, walkable ground, coordinates, triangle budget, closed one-sided geometry, room to play) and recommended rules R1–R8 (names or category rules, collision nodes, separate objects, normals, colour, single-sided materials, water, only meshes), each with its check, message, and fix; the category vocabulary, the default name vocabulary, the shape classification, the placement requirements, the configuration keys, the files written, the user's steps, and the three examples.
- **Categories as map data** (`e7e2c51`): `CategoryRules` / `CategoryRule` (`game/world/`), `MapDefinition.category_rules`; the İstanbul maps share `maps/istanbul_halic/istanbul_halic_categories.tres`, the test district has its own; `RenderSettings` holds no map names (scan test) and fades the fog to the map's sky horizon colour.
- **Import tool** (`6edfbf1`, `7737eb9`): `tools/import_map.gd` + `tools/map_import/` (importer, geometry, classifier, colliders, placement, writer, report); one command, the GLB only read; `RenderSettings.build_occluders` now also takes convex and box shapes.
- **Three imported maps** (`5264d9a`): the CC0 Kenney town in the game (`maps/kenney_town/`, last registry entry, source in `maps/kenney_town/source/`), Safranbolu and the İstanbul import in `tests/imported/` (ignored by Git, not exported); `tests/integration/imported_map_case.gd` and one test file per map.
- **Generalized device scenario** (`0e542f9`): positions from the map's definition, `MapDefinition.sloped_viewpoint` (1 on the İstanbul maps), the extensibility scenario's visited map from `scenario.maps`; experiments `scenario_vehicle_sleep_kenney_town`, `scenario_extensibility_kenney_town`, `profile_default_kenney_town`.

### Acceptance criteria (task of 2026-11-02)

| Criterion | Result | Evidence |
|---|---|---|
| `docs/MAP_CONTRACT.md` exists; every check of the tool belongs to a contract rule | **PASS** | every `checks` entry of the importer and the placement carries a contract id (C1–C8, R1–R8); the reports list them |
| Categories in the map's data; the five existing maps' assignments identical; no İstanbul-specific constant left in `RenderSettings` | **PASS** | all 21,458 mesh assignments byte-identical before and after (dump from `cbaf661` vs `e7e2c51`), `test_map_categories_unchanged.gd` (5 maps), `test_render_settings_has_no_map_specific_names` |
| One command, documented; a report per map in `docs/maps/imported/` | **PASS** | `kenney_town.md`, `safranbolu_test.md`, `istanbul_halic_import.md` (+ `kenney_town_source.md`); command in `docs/MAP_CONTRACT.md` |
| §2.D tests of the three maps | **PASS** | 8 shared tests per map (spawn, 10 s walk, punch and roll, vehicle, NPC, profiles, switch, device scenario) plus map-specific ones: Kenney town 10, Safranbolu 8, İstanbul import 9, all PASS (Safranbolu and the İstanbul import where their generated files exist; SKIP otherwise) |
| Generalized device scenario on an imported map on both devices | **PASS** | `vehicle_sleep` 9 / 9 and `extensibility` 21 / 21 on the Kenney town, on the Galaxy Tab A7 and the iPhone 13 Pro (debug builds of `0e542f9`); the default map's `vehicle_sleep` 13 / 13 on both (slope steps from `sloped_viewpoint`) |
| Phase 1–5 and existing map tests, Platform / preset / `.gdignore` tests; the default map's Mac benchmark unchanged | **PASS** | full suite 337 passed (exit 0), unit 221, a clean clone 250 passed and 87 skipped (exit 2), `validate_scene.gd` PASS; the platform, export preset, build feature, and `.gdignore` tests among them; Mac benchmark of the default map (low and high, three viewpoints) identical before (`69357a7`), after the category move, and at the final HEAD |

### The three maps

| | Kenney town (CC0) | Safranbolu (test input) | İstanbul • Haliç import (test id) |
|---|---|---|---|
| Source | composed GLB, 2,463,348 B, 269 nodes, 52,942 triangles | the package's GLB, 13,848,844 B, 1,173 meshes, 929,216 triangles | `assets/istanbul_halic.glb`, 502,541,456 B, 3,055 meshes, 7,070,457 triangles |
| Configuration | `"scale": 10`, a display name | none | `category_rules_resource`: the İstanbul rules, a display name |
| Contract FAIL before fixing | C2 (12.6 × 12.6 units; the tool suggested scale 10) | — | — |
| Fixed by the tool | C2 (scale, by configuration) | R4: flat normals on all 1,173 meshes | R5: vertex colours on the 6 materials |
| Warnings | R6 2 double-sided materials; C7 9 of 32 houses open, 580 zero-area triangles | R6 17 double-sided materials; C7 83 of 600 building meshes open (roofs), 322 zero-area triangles | R6 3; C6 7.07 M triangles; R3 487 meshes wider than 150 m (the 150 m chunks); C7 371 of 371 building chunks open, 5,700 zero-area triangles |
| Categories | buildings 32, decor 32, ground 144, lamps 20, trees 41 (vocabulary) | buildings 600, facade detail 523, ground 50 (vocabulary) | as the shipped map, every mesh (configured rules) |
| Colliders | generated: 144 ground trimeshes, 299 building hulls (176 bodies; 152 flat or small parts skipped) | generated: 50 ground trimeshes (217,247 triangles), 600 building hulls | the 827 `-col` trimesh bodies, 438,012 triangles (= shipped) |
| Occluders | 443, 14,134 triangles | 650, 237,177 triangles | 643, 317,518 triangles (= the shipped bake) |
| Placement | walkable 63.4 %; spawn with 40 m of walk; car 8 m away with 40 m of road; NPC route 16 m; 3 viewpoints; no slope | walkable 72.9 %; spawn 40 m walk; car 70 m away, 40 m of road; route 12 m; 3 viewpoints; a 6.5° sloped street | walkable 49.3 %; spawn 40 m walk; car 11 m away, 40 m of road; route 12 m; 3 viewpoints; an 8.7° sloped street |
| Gameplay tests (headless) | 10 PASS: walk 44.4 m in 10 s, 5 s of throttle 44.1 m, scenario 9 / 9 and extensibility 21 / 21 | 8 PASS: walk 43.6 m, throttle 43.2 m, scenario with the slope steps | 9 PASS: walk 44.9 m, throttle 41.7 m, scenario with the slope steps, collision and categories equal the shipped map |
| Tool run (Mac) | 0.3 s | 1.5–1.7 s | 9.0–9.4 s, 1.75 GB peak resident |
| Model file | 919,683 B (in Git) | 15,892,138 B (ignored) | 102,286,085 B (ignored) |

### Extensibility finding (core changes)

| Change | Where | Why |
|---|---|---|
| The category table, occluder categories, and fog colour constant removed; categories come from the map | `RenderSettings` (and its callers: `Main._load_map()` passes the rules, one line; `tools/bake_occluders.gd`, `collider_census.gd`) | D26: a map other than İstanbul says what its meshes are without code (T45) |
| New resources `CategoryRules`, `CategoryRule`; `MapDefinition.category_rules`, `MapDefinition.sloped_viewpoint` | `game/world/` | the categories and the scenario's sloped point as map data |
| Occluders also from convex and box colliders (`RenderSettings.shape_faces()`) | `RenderSettings.build_occluders` | the tool's building colliders are convex hulls (T46) |
| Experiments validate categories against `CategoryRules.CATEGORIES` | `PerfConfig` | the table moved |
| Positions from the map's definition; `scenario.maps` for extensibility | `DeviceScenario` | the scenario on any map |
| A single test can report SKIP (`skip()`) | `tests/test_case.gd`, `tests/run_tests.gd` | per-map skips |
| The Kenney town appended to the registry | `game/world/maps.tres` | the CC0 map in the game |

Unchanged: `PlayerController` and its states, the vehicle, NPC, camera, input, HUD, `WorldManager`, `MapRegistry`, the quality profiles, the physics settings.

### Proof that the existing maps did not change

- Categories: a dump of every mesh's category on the five maps (21,458 lines) from the old code (`cbaf661`, `RenderSettings.category_of`) and from the maps' rules (`e7e2c51`) is byte-identical (SHA-256 `2d6996e6…` both); `test_map_categories_unchanged.gd` checks each mesh against the old table (`tests/fixtures/legacy_categories.gd`) and the low profile's fog colour.
- Default map on the Mac (Metal, 960×540, the game started with an experiment: 5 s warm-up, 6 s per viewpoint), before (`69357a7`, two runs), after the category move, and at the final HEAD: low 114 / 107 / 70 draw calls and 51,142 / 52,464 / 23,465 primitives (Spawn / Karaköy / Galata), high 218 / 178 / 116 and 135,639 / 101,720 / 59,619, objects 427 / 460 / 419 and 535 / 535 / 471: identical in every run.
- The default map's device scenario after the generalization: `vehicle_sleep` 13 / 13 on both devices with the slope steps on Galata (12.6°), as before.

### Devices (debug builds of `0e542f9`: APK 677,421,535 B, iOS `.pck` 649,601,780 B)

| Scenario | Galaxy Tab A7 | iPhone 13 Pro |
|---|---|---|
| `scenario_vehicle_sleep_kenney_town` | 9 / 9 PASS (slope steps skipped: no sloped viewpoint), map ready 3.9 s, peak PSS 338 MiB | 9 / 9 PASS, map ready 0.6 s, footprint 327 MiB, Nominal |
| `scenario_extensibility_kenney_town` (test district visited directly) | 21 / 21 PASS; town → test district 0.4 s, back 0.5 s; node count 1,435 before and after | 21 / 21 PASS; 0.1 s and 0.2 s; footprint 306 MiB |
| `scenario_vehicle_sleep` (the default map, regression) | 13 / 13 PASS, slope 12.6° on Galata | 13 / 13 PASS, footprint 874 MiB |

Raw files: `docs/perf/phase6a/`.

### Tablet measurement (Release Perf, one run each, informational; `docs/perf/phase6a/`)

| Map | Average FPS (4–5 viewpoints) | 1 % low | Draw calls | Primitives | Peak PSS | Map ready |
|---|---|---|---|---|---|---|
| Kenney town (committed tree) | 29.83–29.91 | 25.40–26.25 | 61–91 | 15–28 k | 260 MiB | 2.2 s |
| Safranbolu (temporary measurement build, not committed) | 29.84–29.88 | 23.48 (sloped street) – 25.71 | 68–189 | 174–208 k | 328 MiB | 3.6 s |

Low profile, PSS sampling on (single 100+ ms frames, minimum FPS 7.6–9.8), battery 30.0–35.5 °C, thermal status 0; the default map for comparison: 615 MiB stable PSS, 5.8 s to map ready. Safranbolu was measured with its test import temporarily written to `maps/safranbolu_test/` and registered for that one APK, then removed (`game/world/maps.tres` restored byte for byte), because test imports are not exported (T48). Tool run times: 0.3 s (Kenney), 1.5–1.7 s (Safranbolu), 9.0–9.4 s (İstanbul, 1.75 GB peak resident).

### Tests (2026-11-02)

| Run | Result |
|---|---|
| `godot --headless --path . --import` | exit 0, no errors or warnings |
| Full suite at the final code (all four GLBs, the test imports present) | `RESULT 337 passed, 0 failed, 0 skipped`, exit 0 (279 before the task: 58 new tests) |
| Unit suite | `RESULT 221 passed, 0 failed, 0 skipped`, exit 0 |
| A clean clone of `0e542f9` (no GLB, no test import) | full `RESULT 250 passed, 0 failed, 87 skipped`, exit 2 (the Kenney town's 10 tests run there); unit 221 passed, exit 0 |
| Per commit | `e7e2c51` 291 passed; `6edfbf1` 304; `7737eb9` unit 221 (only tools and a unit test changed; integration not re-run); `5264d9a` 333; `0e542f9` 337 (each exit 0) |
| `tests/map/validate_scene.gd` | `VALIDATION PASS` |
| The four GLBs' SHA-256 | unchanged at start and end (`8b00c94b…`, `7973071a…`, `6531ca28…`, `60b9f729…`) |

New tests: `test_category_rules.gd` (7: rule kinds, order, validation, word splitting, the İstanbul rules against the old table, the scan of `RenderSettings`), `test_map_categories_unchanged.gd` (5 maps), `test_map_import.gd` (13: configuration, vocabulary, shape rules, flat normals, shells and parts, scale and axis checks and fixes, classification and groups, colliders, collision nodes, materials, occluders, bounds), `test_map_placement.gd` (6: the synthetic town, a road through a building, no ground, no room for a car, configured points, the written files), `imported_map_case.gd` (8 per imported map) with `test_imported_kenney_town.gd` (+2), `test_imported_safranbolu.gd`, `test_imported_istanbul_halic.gd` (+1).

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
| Automated tests pass. | 2026-11-05, Phase 6e (`23b4dbd` … `4e101fb` and the documentation commit after them): `run_tests.gd` → `RESULT 429 passed, 0 failed, 0 skipped`, exit 0 (425, 427, 429, 429, 429 at the five commits); unit only → 277 passed, exit 0; clean clones without GLBs: see "Phase 6e", "Tests". |
| Phase 6e: loading on threads, the loading screen's indicator, the written release filter. | See "Phase 6e": `test_map_load.gd`, `test_world_manager.gd`, `test_ui_controller.gd`, `test_loading_screen.gd` (the start and a switch on threads, one map at a time, paused and unfocused), `test_release_package.gd` (the written filter, a fake new map left out); the Mac's 20 threaded starts without a crash or a leak; the iPhone's release and Release Perf loading frames under 100 ms. |
| Phase 6d: availability from the cells alone, the release registry and presets, the export check and listing. | See "Phase 6d": the availability matrix and the game starting from the cells alone, `test_release_package.gd` (the simulated packages, exclusions, identifiers, the export check), both release packages listed against the expected files, plain launches of both release builds, the iPhone scenarios, a clean clone with only the default map's cells. |
| Phase 6c: the cell step, the streaming loader, every map split, the route benchmark. | See "Phase 6c": the cell, streamer, and streaming tests (the drawn set equal with and without streaming, no needed cell missing walking and driving, teleport and respawn primes, a switch frees the cells, maps without an index load whole), the 40 look sheets, the device runs. |
| Phase 6b: the blind test, axis, unit, and inside-out detection, splitting and shape rules, colliders by shape, scored placement, the two blind maps in the game. | See "Phase 6b": the blind reports and logs, the unit tests on synthetic scenes (Z-up, centimetres, inches, inside out, a U building, trunks, fences, a street and a grove), the gameplay tests on the five imported maps, the category dump, the hand-labelled sample, the shape-only comparisons, the scenarios on both devices, the tablet measurement, the default map's Mac benchmark. |
| Phase 6a: categories as map data, the import tool, the three imported maps, the generalized scenario. | See "Phase 6a": the category dump and equivalence test, the scan test, the unit tests of the tool on synthetic scenes, the gameplay tests and the device scenario on each imported map, the scenarios on both devices, the default map's Mac benchmark. |
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

- Phase 6e (2026-11-05): the final code on the Galaxy Tab A7 (the loading screen's frames, map ready, a switch's peak PSS and the low-memory killer; only intermediate builds ran, at 15–18 % battery; NOT RUN by the user's choice after the battery reached 0 %); the tablet's repeat of map ready, D25's relative criterion, and the routes (NOT RUN: no charger); the Android release build on a device; what the iPhone's +31 MiB footprint and +12 MiB video memory with threaded loading are made of; the Phase 6c crash's exact function (no engine symbols; the race is read from the source); whether the loading's single-frame jobs fall under 100 ms on other devices.
- Phase 6d (2026-11-05): the tablet's map ready, D25's relative criterion, and the routes with a power supply that holds (NOT RUN: the battery fell on the user's hub, open question 51); whether the release packages install and run from a store-signed build (only debug-keystore and development signing were used); the release build's startup and long frames measured under the benchmark (normal release builds have no `STARTUP` line or benchmark; only the log's times and memory were taken); a release build on other devices; the iOS release `.app` size after App Store thinning.
- Phase 6c (2026-11-04): the tablet's criteria with a power supply that keeps up (map ready, the relative criterion's nine launches each, the routes repeated; open question 51); what causes the streamed routes' 51–55 ms game frames on the tablet (one run each) and the iPhone's single 21–40 ms frames and more frequent pacing state at fixed viewpoints with streaming (no cell loads there; open question 51); Safranbolu's View B long frames (NOT RUN) and what its 341 MiB consist of (open question 50); the iPhone scenarios with build F (they ran debug C, before warm cells and one request in flight); streaming on the Compatibility renderer and on other GPUs (cells load on the main thread without a RenderingDevice, tested headless only); the Mac's worker-thread crash at startup in the engine itself (avoided by priming on the main thread, not root-caused); a map with very large decor or tree meshes (a mesh streams whole); the 100 m cells on the tablet's routes (only the memory runs); a release package without the GLBs (no preset does it yet).
- Phase 6b (2026-11-03): two blind maps only, neither a typical named, multi-object GLB from a modelling tool (no complete CC0 town scene in a format Godot reads was found; T49); no `.gltf` with external files, no FBX map, no GLB with lights, cameras, or skeletons ran through the import tool (the converter's FBX path was tried on one CC0 FBX terrain piece only; R8 has unit tests only); the hand-labelled sample is 60 objects of one map, nearly all buildings (no trees, lamps, fences, or ground in it), labelled by the agent, not by the user; the shape rules were partly written after seeing the samples they are measured on (T51); the courtyard rule was checked on a synthetic U building and on the maps' concave parts, not on a real courtyard map; Safranbolu on the tablet only in a temporary build, not on the iPhone; the blind maps' look checked in Mac shots only; the abstract city's scale of 100 is a choice (arbitrary units), and its packed centre is not walkable at any scale.
- Phase 6a (2026-11-02): the import tool only on the three maps and synthetic scenes (no Z-up or centimetre GLB from another tool, no GLB with lights, skins, or line primitives, no `.gltf` with external files); the shape classification only on synthetic meshes (every real mesh matched a name rule); the placement's choice is functional, not good-looking (the Kenney town's car stands in a courtyard among trees, which have no colliders); Safranbolu on the tablet only in a temporary build, not on the iPhone; the imported maps' look checked only in four Mac shots and the benchmark frames; occluders from convex hulls can hide what stands in a concave building's courtyard (not looked for); `--force` (writing a map that fails a mandatory rule) not exercised; `.scn` outputs are not byte-identical between runs (same size).

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

- Loading on threads (Phase 6e, 2026-11-05): a run of the collision shapes' set-up that the loading thread queued is one frame on the main thread (104–156 ms on the Mac's editor and the iPhone's debug build, 148–181 ms on the tablet's intermediate builds; 34 ms on the iPhone's release builds); the map script's `_ready()`, the first build of a large shader, and the sky's first drawing are one frame each; map ready is about 100–150 ms longer on the iPhone than loading at once (and was about 1.2 s longer on the tablet's intermediate builds); the iPhone's footprint is 31 MiB higher after a threaded start (video memory +12 MiB). The capture tools load at once.
- Release presets (Phase 6d, 2026-11-05): they carry the debug and measurement code (`game/debug/`: the benchmark, the scenarios, the training dummy), inactive without debug or `perf_bench` but packed (the scripts are referenced by `game.gd`); their exclude filter names the maps it leaves out, so a new map folder is packed until the presets exclude it (the preset test fails when that happens); a package without the GLB cannot check the cells against it at run time (the export check does); signing is the debug keystore and the development profile (local testing only).
- Streaming (Phase 6c, 2026-11-04): the resident scene's load still blocks behind the loading screen (3.1–4.7 s per switch on the tablet, debug; open question 37); only the four visibility-range categories stream, so a map whose memory is in its buildings or ground saves little (Safranbolu −4 MiB; open question 50); a mesh streams whole, so a huge decor mesh loads whenever its centre is near; the cells are generated on each machine and ignored by Git, so a fresh clone (or a machine that did not run `tools/cell_map.gd --all` after generating the GLBs) loads every map whole; the staleness check compares the model files' sizes, so a model edit that keeps a file's size is not noticed; a build made where the cells exist packs every map's `streaming/` folder (Release Perf APK 1.45 GB, iOS `.pck` 1.42 GB).
- Import tool (Phase 6a, 6b): shape classification cannot tell lamps from other poles (decor) and finds facade detail only on top of a building's box; some objects stay in no category (always drawn, no collider: 3 of the abstract city's 219, 43 of Safranbolu's 1,173 in a shape-only import); concave building parts above 20,000 triangles keep their hull; units that give a plausible size (the NASA relief's millimetres) are read as metres; zero-area triangles are kept; double-sided materials stay double-sided unless configured; a materialless model renders white; the scored placement is the best of up to 150 candidates around the spawn, not the best of the map (Safranbolu's car is 84 m from the spawn); a map is written only when every mandatory rule passes (or with `--force`); reruns rewrite the binary scenes with other bytes. The `-convcolonly` replacement logs an owner warning (since Phase 6a; harmless).

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

- **Loading on threads (Phase 6e):** the loader relies on rules read from the engine's behaviour (never wait in `load_threaded_get()` for a load in flight, one map load at a time, materials changed only while no loading thread makes meshes with them); a future map script or engine version that breaks one could bring the worker-thread crash back. The tablet has not run the final code.
- **Streaming (Phase 6c):** Godot cannot cancel a threaded load, so a switch waits for the request in flight (one, 26 KB on average); every prime runs on the main thread because threaded requests at the app's start crashed a worker thread on the Mac (7 of 20 launches) for a reason inside the engine that was not found; after a long frame at a camera jump Godot's occlusion culling can draw more hidden objects at that spot (engine behaviour, reproduced without streaming); the tablet's frame times with a loading thread running are not settled (open question 51).
- **Release presets (Phase 6d):** since Phase 6e the exclude filter is written from the release registry (T60), so a new map is left out once the filter is written again (`build_release.sh` does it; the preset test fails until `export_presets.cfg` is committed with it); the written filter still depends on the release maps' needs as `release_package.gd` works them out (dependencies, the scripts' `extends`/`preload`), so a release map that loads a file another way would be left out (the package listing and the device run would show it).
- **Any map now enters the game (Phase 6a, 6b):** every imported map registered in `maps.tres` is packed into every debug and Release Perf build (the Kenney town 1 MB, the abstract city 7.8 MB, the Apollo relief 4.2 MB; a city-sized import hundreds of MB; with every map's cells the Release Perf APK is 1.45 GB), not into the release presets since Phase 6d. Memory scales with the mesh count on the tablet: Safranbolu's 1,173 meshes peak at 328–332 MiB; streaming saves only what is in the streamed categories (open question 50). The NASA relief's single ground occluder has 142,768 triangles (open question 49).

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

- **Review Phase 6e**: the acceptance table ("Phase 6e"), the loading frames before and after, the crash investigation (`docs/perf/phase6e/desktop/crash/README.md`), the decisions T59 and T60, and whether the longer map ready (about +100–150 ms on the iPhone) and the remaining reading frame are acceptable.
- **Review Phase 6d** (if still open): the acceptance table ("Phase 6d"), the package listings (`docs/perf/phase6d/release/`), the decisions T57 (availability from the cells) and T58 (a separate release registry; presets by exclusion, checked by a simulation), and the tablet's repeat that was not run.
- Phase 6c's review items, if still open: the acceptance table ("Phase 6c"), the look comparison (`docs/perf/phase6c/look/`), the criteria that failed or were not completed (map ready, Safranbolu, the relative criterion, the route's 51–55 ms frames), and open questions 50 and 51.
- **On a new machine, after generating the GLBs:** `godot --headless --path . --script res://tools/cell_map.gd -- --all` writes every map's cells (about 11 s on the Mac); without them maps load whole.
- **For the tablet:** a supply the tablet actually draws from while adb stays connected (a maximum charge current above 1 A in `dumpsys battery`; the Mac's port, the powered hub, and the supply of 2026-11-05 all reported 250–350 mA), and the tablet charged: its repeat (open question 51) and the final code's loading frames, map ready, and a switch's peak PSS (open question 37) are not run. It is switched off at 0 % now.
- Phase 6b's review items, if still open: the blind results (`docs/maps/imported/blind/README.md`), the thresholds in `docs/MAP_CONTRACT.md` (C2, C3, C7, the shape rules, R2, the placement scores), the hand labels (`docs/maps/imported/blind/labels/`), and open questions 44 (zero-area triangles, a neutral colour for materialless models), 46 (the imported maps in release packages), 48 (unclassified objects), 49 (huge ground occluders). Question 45 was closed by T54; 47 (Safranbolu as a real map) stays open.
- **A map of your own** would still be the best blind test: put its path in the next task (the field was empty this time).
- The test imports are not in Git: to run their tests on another machine, import the Safranbolu GLB and `assets/istanbul_halic.glb` with the commands in `docs/maps/imported/safranbolu_test.md` and `istanbul_halic_import.md`.

- **Decide whether the tablet's display pairs deserve a task** (open question 43): about one 16.7 / 50 ms pair of presented intervals per second in every launch on the Galaxy Tab A7, not seen by the game loop (`docs/perf/default_map/`); a measurement task would test Swappy's mode or frame pacing off, one change at a time, against presented-frame criteria.
- **iPhone: set Auto-Lock back to its previous value**, if it is still on "Never". Installed now: on the iPhone the release build of `4e101fb` (only the default map), on the tablet an intermediate Release Perf build of Phase 6e (the tablet is switched off). Reinstall a debug build to get the MAP button and the other maps back.
- **iPhone rotation check** (open question 33): start `scenario_orientation` (commands in `docs/ARCHITECTURE.md`, "Device scenario"), hold the phone upright in landscape, and turn it 180° once during the 30 s; the gravity readings in the results file are the evidence.
- The stutter while turning the camera and driving on the iPhone, in your own words.
- Before any release: how ODbL share-alike applies (open question 38). The release presets exist (Phase 6d); building one needs the default map's GLB (SHA-256 `60b9f729…`) and its cells on the machine (`tools/build_release.sh` checks them). Open questions 39 and 40 were decided (D23).
- The other directions after the specification (real models, store preparation) stay open: `PROJECT_CONTEXT.md`, "After the specification".
- Open questions 2 (car model source), 12 (barriers), 22–24 (damage, NPC behaviour beyond Phase 5, roll immunity), 28–29 (camera distance, steering modes), 31–32 (test devices, button sizes), 33 (iPhone orientation), 34–37 (character cost, vehicle–character collisions, the test district in release packages, blocking map loads) remain.
- Later, before any store release: the checklist in `PROJECT_CONTEXT.md`, "Before a store release" (new Apple account and Team ID, final bundle ID, release keystore, AAB build, store metadata; none created).
- Provide or choose character and car models; decide the app name and icon.

## Current priorities

1. Review of Phase 6e ("Phase 6e").
2. The tablet: its repeat (open question 51) and the final code's loading frames, map ready, and switch peak (open question 37), once the user has a supply the tablet draws from.
3. The collision set-up that the loading thread queues, in pieces (the reading frame of 104–181 ms; open question 37); Safranbolu's memory measured (open question 50).
4. Store preparation on top of the release presets, when the user has the accounts and assets ("Before a store release" in `PROJECT_CONTEXT.md`); a presented-frame measurement of the tablet's display pairs if the user wants it (open question 43).

## Recommended next task

Order of the remaining work after Phase 6e (each a separate task, measured against the numbers of 2026-11-01/05):

| # | Work | Why in this place | Measurable acceptance |
|---|---|---|---|
| 1 | **The tablet: the final code and the repeat** (open questions 51, 37; measurement only) | Phase 6d and 6e could not run it for want of power; Phase 6e's tablet numbers are from intermediate builds at 15–18 % battery | Before starting, `dumpsys battery` shows a maximum charge current above 1 A and the level holds for 10 minutes with the game running; then the loading frames (start and switch, debug and release), map ready (three runs, ≤ 4.0 s), a switch's peak PSS (≤ the larger map's stable PSS + 50 MiB, no low-memory kill), D25's relative criterion (nine launches each), the routes (three runs each, traced, presented frames) |
| 2 | **The loading thread's collision set-up in pieces** (open question 37; D26's next infrastructure step) | The one loading frame left over 100 ms on the Mac, the iPhone's debug build, and the tablet is a run of the trimesh shapes' set-up on the main thread (GodotPhysics3D is not threaded); the cell step (or the import tool) could store large trimesh colliders as several shapes of the same triangles, so the set-up comes in smaller runs; the other way, `physics/3d/run_on_separate_thread`, changes the physics' threading and needs the user's decision | Every loading frame ≤ 100 ms on the Mac (editor), the iPhone (debug and release), and the tablet (when it can run); the collision triangles identical (counted per map); every gameplay and collision test passes; map ready not worse than Phase 6e's |
| 3 | **Simple colliders on the İstanbul maps** (imported maps without collision nodes have shape colliders since Phase 6b, T52) | The tablet's physics step (4.4–5.5 ms) is unchanged on every İstanbul map and variant and the largest CPU cost; simpler shapes would also shorten the loading's collision set-up | Physics step ≥ 0.5 ms lower at the three viewpoints (three runs); Phase 1–6e tests pass |
| 4 | **Occluders from building footprints** | Occlusion works (39 draw calls at Galata on the tablet); the bake costs about 40 MiB and 86–220 ms at load | Occluder triangles −80 %; draw calls within 10 %; load time and memory reported |
| 5 | **The tablet's display pairs** (open question 43; only if the user wants it) | About one 16.7 / 50 ms pair of presented intervals per second in every launch that the game loop does not see | With `present_trace.py`, nine launches per variant; at most one setting change |
| 6 | **Normals and degenerate triangles** | No measurable effect | Zero-area and flipped triangles 0, the rest byte-identical |

Smaller follow-ups: Safranbolu's memory measured before deciding on building LOD (open question 50); what the iPhone's +31 MiB footprint after a threaded start is; lamps, lamp glows, and decor of İstanbul • Haliç in cells.

Store track (needs the user's accounts and assets, not code first): the checklist in `PROJECT_CONTEXT.md`, "Before a store release", on top of the release presets (their filter is written from the release registry since Phase 6e).

**Recommendation:** task 1 when the user has a supply the tablet draws from (it is measurement only and settles open questions 51 and the tablet part of 37); otherwise task 2, the next infrastructure step for D26: it is what keeps a loading frame over 100 ms on every device measured.
